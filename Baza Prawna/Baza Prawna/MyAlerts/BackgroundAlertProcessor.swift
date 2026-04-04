//
//  BackgroundAlertProcessor.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 21/10/2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Background Alert Processor

class BackgroundAlertProcessor {
    private weak var alertManager: AlertManager?
    
    private enum ProcessingStatus {
        case notFound
        case inactive
        case processed(newResults: Int)
        case failed
    }
    
    init(alertManager: AlertManager) {
        self.alertManager = alertManager
    }
    
    // MARK: - Setup Methods
    
    func setupBackgroundCheckListener() {
        NotificationCenter.default.addObserver(
            forName: .alertCheckRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Handle new batched format with array of alert IDs
            if let alertIds = notification.userInfo?["alertIds"] as? [String] {
                // Process sequentially to stay within 30-second background limit
                for alertId in alertIds {
                    self?.handleBackgroundAlertCheck(alertId: alertId)
                }
            }
            // Handle legacy single alertId format for backward compatibility
            else if let alertIdString = notification.userInfo?["alertId"] as? String {
                self?.handleBackgroundAlertCheck(alertId: alertIdString)
            }
        }
    }
    
    func setupAuthenticationListener() {
        // Listen for authentication state changes
        NotificationCenter.default.addObserver(
            forName: .authenticationStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAuthenticationStateChange()
        }
    }
    
    // MARK: - Background Alert Check Methods
    
    func handleBackgroundAlertCheck(alertId: String) {
        Task {
            _ = await processSingleAlert(alertId: alertId)
        }
    }

    func processAlertChecks(alertIds: [String]) async -> AlertManager.BackgroundProcessingMetrics {
        var metrics = AlertManager.BackgroundProcessingMetrics()
        
        // Use a task group to process alerts in parallel, capped at a reasonable concurrency
        // to avoid overwhelming the system/network while speeding up total execution time
        await withTaskGroup(of: (String, ProcessingStatus).self) { group in
            // Limit concurrency to 5 simultaneous checks
            let maxConcurrency = 5
            var activeTasks = 0
            var pendingAlertIds = alertIds
            
            // Helper to add tasks up to the limit
            func addTasks() {
                while activeTasks < maxConcurrency && !pendingAlertIds.isEmpty {
                    let alertId = pendingAlertIds.removeFirst()
                    group.addTask {
                        let status = await self.processSingleAlert(alertId: alertId)
                        return (alertId, status)
                    }
                    activeTasks += 1
                }
            }
            
            // Start initial batch
            addTasks()
            
            // Process results as they complete and add new tasks
            for await (_, status) in group {
                activeTasks -= 1
                
                switch status {
                case .processed(let newResults):
                    metrics.processedCount += 1
                    metrics.totalNewResults += newResults
                case .failed:
                    metrics.processedCount += 1
                    metrics.failureCount += 1
                case .inactive:
                    // Inactive alerts are intentionally skipped
                    break
                case .notFound:
                    // No matching alert stored locally
                    break
                }
                
                // Add more tasks if available
                addTasks()
            }
        }
        
        return metrics
    }
    
    private func processSingleAlert(alertId: String) async -> ProcessingStatus {
        guard let alertManager = alertManager else {
            print("❌ Alert manager unavailable")
            return .failed
        }
        
        guard let alert = alertManager.savedAlerts.first(where: { $0.id.uuidString == alertId }) else {
            print("❌ Alert not found: \(alertId)")
            return .notFound
        }
        
        guard alert.isActive else {
            print("⏭️ Alert is inactive, skipping check: \(alertId)")
            return .inactive
        }
        
        print("🔄 Background alert check for: \(alert.title)")
        
        if let newResults = await performBackgroundSearch(for: alert) {
            return .processed(newResults: max(newResults, 0))
        } else {
            return .failed
        }
    }

    private func performBackgroundSearch(for alert: SavedAlert) async -> Int? {
        print("🔍 Starting background search for alert: \(alert.title)")
        print("📋 Alert searchType: \(alert.searchType.rawValue)")
        print("📋 Alert searchCriteria: \(alert.searchCriteria)")
        
        do {
            var newResults: [Any] = []
            let parameterBuilder = AlertParameterBuilder(alert: alert)
            
            // Perform search based on alert type
            switch alert.searchType {
            case .actsPL:
                let apiService = APIService.shared
                let parameters = parameterBuilder.createActsPLParameters(offset: 0)
                let result = try await apiService.searchActs(parameters: parameters)
                
                // Client-side filtering: Filter by changeDate
                let dateFormatter = DateFormatter()
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                let calendar = Calendar.current
                let cutoffDate = alert.lastSearchDate ?? alert.dateCreated
                let alertCreationDate = alert.dateCreated
                
                // Use the later of cutoffDate or alertCreationDate to ensure we don't show results from before the alert existed
                // But respect the "testing" dates if cutoffDate is explicitly set to the past (before creation)
                let effectiveCutoffDate: Date
                if cutoffDate < alertCreationDate {
                    // Testing scenario or explicit past date set - respect the past date
                    effectiveCutoffDate = calendar.startOfDay(for: cutoffDate)
                } else {
                    // Normal scenario - ensure we don't show results before alert creation
                    // Use the EXACT alert creation date as the floor, not the start of that day
                    // This prevents acts with changeDate (e.g. 11:00) from showing up for alerts created later that same day (e.g. 21:00)
                    let normalizedCutoff = calendar.startOfDay(for: cutoffDate)
                    effectiveCutoffDate = max(alertCreationDate, normalizedCutoff)
                }
                
                newResults = result.items.filter { act in
                    guard let changeDateString = act.changeDate, !changeDateString.isEmpty else {
                        return false
                    }
                    
                    var changeDate: Date?
                    // Try full format first (yyyy-MM-dd'T'HH:mm:ss)
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let date = dateFormatter.date(from: changeDateString) {
                        changeDate = date
                    } else {
                        // Try parsing date only (format: "yyyy-MM-dd")
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        changeDate = dateFormatter.date(from: changeDateString)
                    }
                    
                    guard let actDate = changeDate else {
                        return false
                    }
                    
                    // Compare exact dates if we're using alertCreationDate as the floor
                    // Otherwise compare using start of day normalization for recurring checks
                    if effectiveCutoffDate == alertCreationDate {
                        return actDate >= effectiveCutoffDate
                    } else {
                        let actDayStart = calendar.startOfDay(for: actDate)
                        return actDayStart >= effectiveCutoffDate
                    }
                }
                
            case .actsEU:
                let apiService = API_EUService.shared
                let parameters = parameterBuilder.createActsEUParameters(offset: 0)
                newResults = try await apiService.searchEUDocuments(parameters: parameters)
                
            case .courtPL:
                let apiService = API_CourtPLService.shared
                let parameters = parameterBuilder.createCourtPLParameters(offset: 0)
                newResults = try await apiService.searchCourtJudgments(parameters: parameters)
                
            case .courtNSA:
                let apiService = API_NSAService.shared
                let parameters = parameterBuilder.createCourtNSAParameters(page: 1)
                let result = try await apiService.searchJudgments(parameters: parameters)
                newResults = result.judgments
                
            case .courtSupreme:
                let apiService = API_SupremeService.shared
                let parameters = parameterBuilder.createCourtSupremeParameters(offset: 0)
                let result = try await apiService.searchJudgments(parameters: parameters)
                newResults = result.judgments
                
            case .rplProjects:
                let apiService = APIService_RPL.shared
                let parameters = parameterBuilder.createRPLParameters(page: 1)
                let response = try await apiService.searchProjects(parameters: parameters)
                let cutoffDate = alert.lastSearchDate ?? alert.dateCreated
                let filteredProjects = filterRPLProjects(response.projects, since: cutoffDate)
                newResults = filteredProjects

            case .legisPL:
                print("📋 Processing legisPL alert")
                
                // Check if this alert might actually be a committee sitting alert that was saved incorrectly
                if let committeeCode = alert.searchCriteria["committeeCode"] as? String, !committeeCode.isEmpty {
                    print("⚠️ WARNING: Alert has searchType=.legisPL but contains committeeCode=\(committeeCode)")
                    print("⚠️ This alert should be recreated with searchType=.committeeSittings")
                    print("⚠️ Attempting to process as committee sitting alert instead...")
                    
                    // Process as committee sitting alert
                    let apiService = APIService_Legis.shared
                    let allSittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode)
                    
                    // Filter for PLANNED status only
                    let plannedSittings = allSittings.filter { sitting in
                        sitting.status?.uppercased() == "PLANNED"
                    }
                    
                    // Save all PLANNED sittings (not just new ones) to update accumulated state
                    newResults = plannedSittings
                } else {
                    // Normal legisPL processing
                    let apiService = APIService_Legis.shared
                    let parameters = parameterBuilder.createLegislacjaParameters(offset: 0)
                    
                    // Check if this is a number-based alert or title-based alert
                    if let number = alert.searchCriteria["number"] as? String, !number.isEmpty {
                        // Number-based alert: fetch specific process and check for new stages
                        let currentTerm = apiService.getCurrentTerm()
                        let currentProcess = try await apiService.getProcessDetails(id: number, term: currentTerm)
                        
                        // Always save the current process (to update accumulated results)
                        // We'll check for new stages later when determining if we should notify
                        newResults = [currentProcess]
                    } else {
                        // Title-based alert: search by title and filter by date
                        let allProcesses = try await apiService.searchProcesses(parameters: parameters)
                        
                        // Filter processes that are newer than lastSearchDate
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for consistent comparison
                        
                        let calendar = Calendar.current
                        let lastSearchDate = alert.lastSearchDate ?? alert.dateCreated
                        let cutoffDayStart = calendar.startOfDay(for: lastSearchDate)
                        
                        newResults = allProcesses.filter { process in
                            guard let documentDate = process.documentDate else { return false }
                            if let processDate = dateFormatter.date(from: documentDate) {
                                // Normalize process date to start of day for comparison
                                let processDayStart = calendar.startOfDay(for: processDate)
                                return processDayStart >= cutoffDayStart
                            }
                            return false
                        }
                    }
                }
                
            case .committeeSittings:
                print("Processing committeeSittings alert")
                let apiService = APIService_Legis.shared
                guard let committeeCode = parameterBuilder.createCommitteeSittingsParameters() else {
                    print("❌ Committee code not found in alert criteria")
                    return nil
                }
                
                print("Fetching committee sittings for code: \(committeeCode)")
                // Fetch all sittings for the committee
                let allSittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode)
                
                // Filter for PLANNED status only
                let plannedSittings = allSittings.filter { sitting in
                    sitting.status?.uppercased() == "PLANNED"
                }
                
                // Save all PLANNED sittings (not just new ones) to update accumulated state
                // This ensures we have the full set for next comparison
                newResults = plannedSittings
            }
            
            // Save results if any found
            var newResultsCount = 0
            if !newResults.isEmpty {
                // For number-based alerts, we need to check if there are actually new stages
                let isNumberBasedAlert = alert.searchCriteria["number"] as? String != nil
                let isCommitteeSittingsAlert = alert.searchType == .committeeSittings
                let shouldNotify: Bool
                
                if isNumberBasedAlert {
                    // For number-based alerts, check if there are new stages
                    let lastProcess = getLastKnownProcess(for: alert)
                    if let currentProcess = newResults.first as? LegislativeProcess {
                        let newStages = findNewStages(current: currentProcess, lastKnown: lastProcess)
                        shouldNotify = (newStages != nil && !newStages!.isEmpty)
                    } else {
                        shouldNotify = true
                    }
                } else if isCommitteeSittingsAlert {
                    // For committee sitting alerts, check if there are actually new PLANNED sittings
                    // newResults contains all PLANNED sittings, but we need to check if there are new ones
                    let lastKnownSittings = getLastKnownPlannedSittings(for: alert)
                    if let currentSittings = newResults as? [CommitteeSitting] {
                        let newPlannedSittings = findNewPlannedSittings(current: currentSittings, lastKnown: lastKnownSittings)
                        shouldNotify = !newPlannedSittings.isEmpty
                    } else {
                        shouldNotify = true
                    }
                } else {
                    shouldNotify = true
                }
                
                // Calculate new count for committee sitting alerts before MainActor block
                var newPlannedSittingsCount = 0
                if isCommitteeSittingsAlert, let currentSittings = newResults as? [CommitteeSitting] {
                    let lastKnownSittings = getLastKnownPlannedSittings(for: alert)
                    let newPlannedSittings = findNewPlannedSittings(current: currentSittings, lastKnown: lastKnownSittings)
                    newPlannedSittingsCount = newPlannedSittings.count
                }
                
                newResultsCount = await MainActor.run { () -> Int in
                    guard let alertManager = self.alertManager else { return 0 }
                    
                    // Always save results to update accumulated state
                    let resultsCount = alertManager.saveSearchResults(for: alert, results: newResults)
                    
                    // For committee sitting alerts, use pre-calculated count
                    var actualNewCount = 0
                    if isCommitteeSittingsAlert {
                        actualNewCount = newPlannedSittingsCount
                    } else {
                        // Only count as "new" if there are actually new items (for number alerts, this means new stages)
                        actualNewCount = shouldNotify ? resultsCount : 0
                    }
                    
                    print("✅ Background search completed: \(newResults.count) results for \(alert.title), \(actualNewCount) new")
                    
                    if actualNewCount > 0 {
                        Task {
                            await NotificationManager.shared.scheduleImmediateResultsNotification(
                                alertTitle: alert.title,
                                newResultsCount: actualNewCount,
                                alertId: alert.id
                            )
                        }
                    }
                    return actualNewCount
                }
            } else {
                await MainActor.run {
                    guard let alertManager = self.alertManager else { return }
                    alertManager.updateLastSearchDate(for: alert)
                    print("✅ Background search completed: No new results for \(alert.title)")
                }
            }
            
            // Update last_check_date in Firebase
            if let userId = AuthenticationManager.shared.userUID {
                await FirebaseManager.shared.updateAlertLastCheckDate(
                    userId: userId,
                    alertId: alert.id.uuidString,
                    lastCheckDate: Date()
                )
            }
            
            // Reschedule notification based on new lastSearchDate instead of canceling
            if alert.frequency != nil && alert.isActive {
                // Get the updated alert from the array (which has the new lastSearchDate)
                if let alertManager = self.alertManager,
                   let updatedAlert = alertManager.savedAlerts.first(where: { $0.id == alert.id }) {
                    let nextCheckDate = await NotificationManager.shared.scheduleNotification(for: updatedAlert)
                    if let nextDate = nextCheckDate {
                        await MainActor.run {
                            alertManager.updateNextScheduledCheck(for: updatedAlert, nextDate: nextDate)
                        }
                    }
                }
            }
            
            return newResultsCount
        } catch {
            print("❌ Background search failed for \(alert.title): \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods for Legislacja Alerts
    
    private func getLastKnownProcess(for alert: SavedAlert) -> LegislativeProcess? {
        guard let accumulatedResults = alert.accumulatedResults[alert.searchType.rawValue] else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let processes = try decoder.decode([LegislativeProcess].self, from: accumulatedResults)
            // Return the most recent process (should be only one for number-based alerts)
            return processes.first
        } catch {
            print("Failed to decode last known process: \(error)")
            return nil
        }
    }
    
    private func findNewStages(current: LegislativeProcess, lastKnown: LegislativeProcess?) -> [ProcessStage]? {
        guard let currentStages = current.stages else { return nil }
        
        // Flatten current stages
        let currentFlatStages = flattenStages(currentStages)
        
        // If no last known process, all stages are new
        guard let lastKnown = lastKnown, let lastStages = lastKnown.stages else {
            return currentFlatStages.isEmpty ? nil : currentFlatStages
        }
        
        // Flatten last known stages
        let lastFlatStages = flattenStages(lastStages)
        
        // Find stages that are in current but not in last known
        // Compare by stageName and date combination
        let lastStageIdentifiers = Set(lastFlatStages.map { "\($0.stageName)-\($0.date ?? "")" })
        let newStages = currentFlatStages.filter { stage in
            let identifier = "\(stage.stageName)-\(stage.date ?? "")"
            return !lastStageIdentifiers.contains(identifier)
        }
        
        return newStages.isEmpty ? nil : newStages
    }
    
    private func flattenStages(_ stages: [ProcessStage]) -> [ProcessStage] {
        var result: [ProcessStage] = []
        for stage in stages {
            result.append(stage)
            if let children = stage.children {
                result.append(contentsOf: flattenStages(children))
            }
        }
        return result
    }

    private func filterRPLProjects(_ projects: [RPLProject], since cutoff: Date) -> [RPLProject] {
        let calendar = Calendar.current
        let cutoffDay = calendar.startOfDay(for: cutoff)

        return projects.filter { project in
            guard let projectDate = parseRPLDate(project.createdDateText) else {
                return false
            }
            let projectDay = calendar.startOfDay(for: projectDate)
            return projectDay >= cutoffDay
        }
    }

    private func parseRPLDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        return BackgroundAlertProcessor.rplDateFormatter.date(from: string)
    }
    
    // MARK: - Helper Methods for Committee Sitting Alerts
    
    private func getLastKnownPlannedSittings(for alert: SavedAlert) -> [CommitteeSitting] {
        guard let accumulatedResults = alert.accumulatedResults[alert.searchType.rawValue] else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let allSittings = try decoder.decode([CommitteeSitting].self, from: accumulatedResults)
            // Filter for PLANNED status only from stored results
            return allSittings.filter { sitting in
                sitting.status?.uppercased() == "PLANNED"
            }
        } catch {
            print("Failed to decode last known planned sittings: \(error)")
            return []
        }
    }
    
    private func findNewPlannedSittings(current: [CommitteeSitting], lastKnown: [CommitteeSitting]) -> [CommitteeSitting] {
        // If no last known sittings, all current PLANNED sittings are new
        guard !lastKnown.isEmpty else {
            return current
        }
        
        // Create a set of IDs from last known sittings
        let lastKnownIds = Set(lastKnown.map { $0.id })
        
        // Find sittings that are in current but not in last known
        let newSittings = current.filter { sitting in
            !lastKnownIds.contains(sitting.id)
        }
        
        return newSittings
    }
    
    // MARK: - Authentication State Change Handling
    
    private func handleAuthenticationStateChange() {
        // Check if user just logged in
        if AuthenticationManager.shared.isAuthenticated,
           let userId = AuthenticationManager.shared.userUID {
            syncOfflineAlertsToFirebase(userId: userId)
        }
    }
    
    private func syncOfflineAlertsToFirebase(userId: String) {
        guard let alertManager = alertManager else { return }
        
        let offlineAlerts = alertManager.getOfflineAlerts()
        let offlineDeletions = alertManager.getOfflineDeletions()
        
        // Sync offline alerts if any exist
        if !offlineAlerts.isEmpty {
            print("Syncing \(offlineAlerts.count) offline alerts to Firebase...")
            
            Task {
                await FirebaseManager.shared.syncOfflineAlertsToFirebase(
                    userId: userId,
                    alerts: offlineAlerts
                )
                
                // Clear offline alerts after successful sync
                await MainActor.run {
                    alertManager.clearOfflineAlerts()
                    print("Offline alerts synced and cleared")
                }
            }
        }
        
        // Sync offline deletions if any exist
        if !offlineDeletions.isEmpty {
            print("Syncing \(offlineDeletions.count) offline deletions to Firebase...")
            
            Task {
                await FirebaseManager.shared.deleteOfflineAlertsFromFirebase(
                    userId: userId,
                    alertIds: offlineDeletions
                )
                
                // Clear offline deletions after successful sync
                await MainActor.run {
                    alertManager.clearOfflineDeletions()
                    print("Offline deletions synced and cleared")
                }
            }
        }
    }
}

private extension BackgroundAlertProcessor {
    static let rplDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
