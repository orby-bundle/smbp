//
//  AlertManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 21/10/2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Alert Manager

class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var savedAlerts: [SavedAlert] = []
    
    private let userDefaults = UserDefaults.standard
    private let alertsKey = "SavedAlerts"
    private let offlineAlertsKey = "OfflineAlerts"
    private let offlineDeletionsKey = "OfflineDeletions"
    private let pendingBackgroundBatchKey = "PendingBackgroundAlertCheckBatch"
    
    private var backgroundProcessor: BackgroundAlertProcessor?
    
    struct BackgroundProcessingMetrics {
        var processedCount: Int = 0
        var totalNewResults: Int = 0
        var failureCount: Int = 0
    }

    struct PendingBackgroundAlertCheckBatch: Codable {
        let alertIds: [String]
        let baselineLastSearchTime: [String: TimeInterval]
        let receivedAt: TimeInterval
    }
    
    private init() {
        loadAlerts()
        backgroundProcessor = BackgroundAlertProcessor(alertManager: self)
        backgroundProcessor?.setupAuthenticationListener()
        backgroundProcessor?.setupBackgroundCheckListener()
    }
    
    func processBackgroundAlertChecks(alertIds: [String]) async -> BackgroundProcessingMetrics {
        guard let backgroundProcessor = backgroundProcessor else {
            return BackgroundProcessingMetrics()
        }
        return await backgroundProcessor.processAlertChecks(alertIds: alertIds)
    }

    func recordPendingBackgroundCheck(alertIds: [String], receivedAt: Date = Date()) {
        var baseline: [String: TimeInterval] = [:]
        for alertId in alertIds {
            let lastSearchTime = savedAlerts.first(where: { $0.id.uuidString == alertId })?.lastSearchDate?.timeIntervalSince1970
            baseline[alertId] = lastSearchTime ?? -1
        }

        let batch = PendingBackgroundAlertCheckBatch(
            alertIds: alertIds,
            baselineLastSearchTime: baseline,
            receivedAt: receivedAt.timeIntervalSince1970
        )

        if let data = try? JSONEncoder().encode(batch) {
            userDefaults.set(data, forKey: pendingBackgroundBatchKey)
        }
    }

    func loadPendingBackgroundCheckBatch() -> PendingBackgroundAlertCheckBatch? {
        guard let data = userDefaults.data(forKey: pendingBackgroundBatchKey) else {
            return nil
        }
        return try? JSONDecoder().decode(PendingBackgroundAlertCheckBatch.self, from: data)
    }

    func clearPendingBackgroundCheckBatch() {
        userDefaults.removeObject(forKey: pendingBackgroundBatchKey)
    }

    func pendingBatchHasUpdates(_ batch: PendingBackgroundAlertCheckBatch) -> Bool {
        for alertId in batch.alertIds {
            let baselineTime = batch.baselineLastSearchTime[alertId] ?? -1
            let currentTime = savedAlerts.first(where: { $0.id.uuidString == alertId })?.lastSearchDate?.timeIntervalSince1970 ?? -1

            if baselineTime < 0 {
                if currentTime >= 0 {
                    return true
                }
            } else if currentTime > baselineTime {
                return true
            }
        }
        return false
    }

    func alerts(for batch: PendingBackgroundAlertCheckBatch) -> [SavedAlert] {
        savedAlerts.filter { batch.alertIds.contains($0.id.uuidString) }
    }
    
    func saveAlert(_ alert: SavedAlert) {
        savedAlerts.append(alert)
        saveAlerts()
        
        // Check if user is authenticated
        if let userId = AuthenticationManager.shared.userUID, let frequency = alert.frequency {
            // User is authenticated - sync to Firebase immediately
            Task {
                await FirebaseManager.shared.syncAlertToFirebase(
                    userId: userId,
                    alertId: alert.id.uuidString,
                    frequency: frequency.rawValue,
                    initDate: alert.dateCreated
                )
            }
        } else if alert.frequency != nil {
            // User is not authenticated - store as offline alert
            storeOfflineAlert(alert)
            secureLog("Alert stored offline for later sync")
        }
        
        // Schedule notification if alert has frequency
        if alert.frequency != nil {
            secureLog("Alert includes frequency; starting notification scheduling")
            Task { @MainActor in
                secureLog("Calling NotificationManager.scheduleNotification")
                let nextCheckDate = await NotificationManager.shared.scheduleNotification(for: alert)
                secureLog("Notification scheduling completed; next run date available: \(nextCheckDate != nil)")
                // Update the alert with the scheduled date
                if let nextDate = nextCheckDate {
                    secureLog("Notification scheduled with next run date \(nextDate)")
                    updateNextScheduledCheck(for: alert, nextDate: nextDate)
                } else {
                    secureLog("Notification scheduling failed—likely due to permission status")
                    // Show user feedback about notification permission
                    DispatchQueue.main.async {
                        // You could show an alert here to inform the user about notification permission
                        secureLog("Notification permission missing; user feedback not implemented")
                    }
                }
            }
        } else {
            secureLog("Alert has no frequency; skipping notification scheduling")
        }
    }
    
    func deleteAlert(_ alert: SavedAlert) {
        savedAlerts.removeAll { $0.id == alert.id }
        saveAlerts()
        
        // Check if user is authenticated
        if let userId = AuthenticationManager.shared.userUID {
            // User is authenticated - delete from Firebase immediately
            Task {
                await FirebaseManager.shared.deleteAlertFromFirebase(
                    userId: userId,
                    alertId: alert.id.uuidString
                )
            }
        } else {
            // User is not authenticated - track for offline deletion
            trackOfflineDeletion(alertId: alert.id.uuidString)
            secureLog("Alert deletion recorded offline for later sync")
        }
        
        // Cancel notification for deleted alert
        Task {
            await NotificationManager.shared.cancelNotification(for: alert.id)
        }
    }
    
    func toggleAlert(_ alert: SavedAlert) {
        if let index = savedAlerts.firstIndex(where: { $0.id == alert.id }) {
            let newAlert = SavedAlert(
                id: alert.id,
                searchType: alert.searchType,
                title: alert.title,
                searchCriteria: alert.searchCriteria,
                dateCreated: alert.dateCreated,
                isActive: !alert.isActive,
                frequency: alert.frequency,
                nextScheduledCheck: alert.nextScheduledCheck,
                accumulatedResults: alert.accumulatedResults,
                lastSearchDate: alert.lastSearchDate,
                resultCount: alert.resultCount
            )
            savedAlerts[index] = newAlert
            saveAlerts()
            
            // Handle Firebase sync based on active state
            if let userId = AuthenticationManager.shared.userUID, let frequency = alert.frequency {
                Task {
                    if newAlert.isActive {
                        // Unmuting: Recreate in Firebase with original dates
                        await FirebaseManager.shared.syncAlertToFirebase(
                            userId: userId,
                            alertId: alert.id.uuidString,
                            frequency: frequency.rawValue,
                            initDate: alert.dateCreated  // Original creation date
                        )
                        
                        // Update last_check_date if we have a lastSearchDate
                        if let lastSearch = alert.lastSearchDate {
                            await FirebaseManager.shared.updateAlertLastCheckDate(
                                userId: userId,
                                alertId: alert.id.uuidString,
                                lastCheckDate: lastSearch
                            )
                        }
                    } else {
                        // Muting: Delete from Firebase
                        await FirebaseManager.shared.deleteAlertFromFirebase(
                            userId: userId,
                            alertId: alert.id.uuidString
                        )
                    }
                }
            } else if alert.frequency != nil {
                // User is not authenticated - handle offline sync
                if newAlert.isActive {
                    // Unmuting offline - store as offline alert for later sync
                    storeOfflineAlert(newAlert)
                    secureLog("Alert unmuted offline; will sync when user authenticates")
                } else {
                    // Muting offline - track for offline deletion
                    trackOfflineDeletion(alertId: alert.id.uuidString)
                    secureLog("Alert muted offline; deletion will sync when user authenticates")
                }
            }
            
            // Handle notification scheduling based on active state
            Task { @MainActor in
                if newAlert.isActive && newAlert.frequency != nil {
                    let nextDate = await NotificationManager.shared.scheduleNotification(for: newAlert)
                    if let nextCheckDate = nextDate {
                        updateNextScheduledCheck(for: newAlert, nextDate: nextCheckDate)
                    }
                } else {
                    await NotificationManager.shared.cancelNotification(for: alert.id)
                    // Clear nextScheduledCheck when deactivating
                    updateNextScheduledCheck(for: newAlert, nextDate: nil)
                }
            }
        }
    }
    
    private func saveAlerts() {
        do {
            let data = try JSONEncoder().encode(savedAlerts)
            userDefaults.set(data, forKey: alertsKey)
        } catch {
            secureLog("Failed to save alerts: \(error.localizedDescription)")
        }
    }
    
    private func loadAlerts() {
        guard let data = userDefaults.data(forKey: alertsKey) else { return }
        
        do {
            savedAlerts = try JSONDecoder().decode([SavedAlert].self, from: data)
        } catch {
            secureLog("Failed to load alerts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Result Storage Methods
    
    func saveSearchResults(for alert: SavedAlert, results: [Any]) -> Int {
        guard let index = savedAlerts.firstIndex(where: { $0.id == alert.id }) else { 
            return 0
        }
        
        // Get the current alert from the array to ensure we're working with the latest version
        let currentAlert = savedAlerts[index]
        
        // Delegate to AlertResultManager
        let (updatedResults, resultCount, newResultsCount) = AlertResultManager.shared.processAndSaveResults(
            for: currentAlert,
            newResults: results,
            existingResults: currentAlert.accumulatedResults
        )
        
        // Update the alert with new results and lastSearchDate
        let updatedAlert = SavedAlert(
            id: currentAlert.id,
            searchType: currentAlert.searchType,
            title: currentAlert.title,
            searchCriteria: currentAlert.searchCriteria,
            dateCreated: currentAlert.dateCreated,
            isActive: currentAlert.isActive,
            frequency: currentAlert.frequency,
            nextScheduledCheck: currentAlert.nextScheduledCheck,
            accumulatedResults: updatedResults,
            lastSearchDate: Date(),
            resultCount: resultCount
        )
        
        savedAlerts[index] = updatedAlert
        saveAlerts()
        
        // Sync last_check_date to Firebase if user is authenticated
        if let userId = AuthenticationManager.shared.userUID {
            Task {
                await FirebaseManager.shared.updateAlertLastCheckDate(
                    userId: userId,
                    alertId: alert.id.uuidString,
                    lastCheckDate: Date()
                )
            }
        }
        
        // Reschedule notification based on new lastSearchDate
        if updatedAlert.frequency != nil && updatedAlert.isActive {
            Task { @MainActor in
                let nextCheckDate = await NotificationManager.shared.scheduleNotification(for: updatedAlert)
                if let nextDate = nextCheckDate {
                    updateNextScheduledCheck(for: updatedAlert, nextDate: nextDate)
                }
            }
        }
        
        return newResultsCount
    }
    
    func getAccumulatedResults(for alert: SavedAlert) -> [Any]? {
        guard let currentAlert = savedAlerts.first(where: { $0.id == alert.id }) else {
            return nil
        }
        return AlertResultManager.shared.getResults(for: currentAlert, from: currentAlert.accumulatedResults)
    }
    
    func updateLastSearchDate(for alert: SavedAlert) {
        guard let index = savedAlerts.firstIndex(where: { $0.id == alert.id }) else { return }
        
        let updatedAlert = SavedAlert(
            id: alert.id,
            searchType: alert.searchType,
            title: alert.title,
            searchCriteria: alert.searchCriteria,
            dateCreated: alert.dateCreated,
            isActive: alert.isActive,
            frequency: alert.frequency,
            nextScheduledCheck: alert.nextScheduledCheck, // Preserve the scheduled check time
            accumulatedResults: alert.accumulatedResults,
            lastSearchDate: Date(),
            resultCount: alert.resultCount
        )
        
        savedAlerts[index] = updatedAlert
        saveAlerts()
        
        // Sync last_check_date to Firebase if user is authenticated
        if let userId = AuthenticationManager.shared.userUID {
            Task {
                await FirebaseManager.shared.updateAlertLastCheckDate(
                    userId: userId,
                    alertId: alert.id.uuidString,
                    lastCheckDate: Date()
                )
            }
        }
        
        // Reschedule notification based on new lastSearchDate
        if updatedAlert.frequency != nil && updatedAlert.isActive {
            Task { @MainActor in
                let nextCheckDate = await NotificationManager.shared.scheduleNotification(for: updatedAlert)
                if let nextDate = nextCheckDate {
                    updateNextScheduledCheck(for: updatedAlert, nextDate: nextDate)
                }
            }
        }
    }
    
    @MainActor
    func updateNextScheduledCheck(for alert: SavedAlert, nextDate: Date?) {
        guard let index = savedAlerts.firstIndex(where: { $0.id == alert.id }) else { 
            return 
        }
        
        
        let updatedAlert = SavedAlert(
            id: alert.id,
            searchType: alert.searchType,
            title: alert.title,
            searchCriteria: alert.searchCriteria,
            dateCreated: alert.dateCreated,
            isActive: alert.isActive,
            frequency: alert.frequency,
            nextScheduledCheck: nextDate,
            accumulatedResults: alert.accumulatedResults,
            lastSearchDate: alert.lastSearchDate,
            resultCount: alert.resultCount
        )
        
        savedAlerts[index] = updatedAlert
        saveAlerts()
    }
    
    func clearAccumulatedResults(for alert: SavedAlert) {
        guard let index = savedAlerts.firstIndex(where: { $0.id == alert.id }) else { return }
        
        let updatedAlert = SavedAlert(
            id: alert.id,
            searchType: alert.searchType,
            title: alert.title,
            searchCriteria: alert.searchCriteria,
            dateCreated: alert.dateCreated,
            isActive: alert.isActive,
            frequency: alert.frequency,
            nextScheduledCheck: alert.nextScheduledCheck,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
        
        savedAlerts[index] = updatedAlert
        saveAlerts()
    }
    
    // MARK: - Testing Helper Methods
    
    func setLastSearchDateForTesting(for alert: SavedAlert, daysAgo: Int) {
        guard let index = savedAlerts.firstIndex(where: { $0.id == alert.id }) else { 
            return 
        }
        
        let testDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        
        let updatedAlert = SavedAlert(
            id: alert.id,
            searchType: alert.searchType,
            title: alert.title,
            searchCriteria: alert.searchCriteria,
            dateCreated: alert.dateCreated,
            isActive: alert.isActive,
            frequency: alert.frequency,
            nextScheduledCheck: alert.nextScheduledCheck,
            accumulatedResults: alert.accumulatedResults,
            lastSearchDate: testDate,
            resultCount: alert.resultCount
        )
        
        savedAlerts[index] = updatedAlert
        saveAlerts()
    }
    
    func setLastSearchDateTo7DaysAgo(for alert: SavedAlert) {
        setLastSearchDateForTesting(for: alert, daysAgo: 7) 
    }
    
    func setLastSearchDateTo3DaysAgo(for alert: SavedAlert) {
        setLastSearchDateForTesting(for: alert, daysAgo: 2) 
    }
    
    // MARK: - Alert Rename Method
    
    func renameAlert(for alert: SavedAlert, newTitle: String) {
        guard let index = savedAlerts.firstIndex(where: { $0.id == alert.id }) else { return }
        
        let updatedAlert = SavedAlert(
            id: alert.id,
            searchType: alert.searchType,
            title: newTitle,
            searchCriteria: alert.searchCriteria,
            dateCreated: alert.dateCreated,
            isActive: alert.isActive,
            frequency: alert.frequency,
            nextScheduledCheck: alert.nextScheduledCheck,
            accumulatedResults: alert.accumulatedResults,
            lastSearchDate: alert.lastSearchDate,
            resultCount: alert.resultCount
        )
        
        savedAlerts[index] = updatedAlert
        saveAlerts()
    }
    
    
    // MARK: - Offline Alert Management
    
    private func storeOfflineAlert(_ alert: SavedAlert) {
        var offlineAlerts = getOfflineAlerts()
        offlineAlerts.append(alert)
        saveOfflineAlerts(offlineAlerts)
    }
    
    func getOfflineAlerts() -> [SavedAlert] {
        guard let data = userDefaults.data(forKey: offlineAlertsKey),
              let alerts = try? JSONDecoder().decode([SavedAlert].self, from: data) else {
            return []
        }
        return alerts
    }
    
    private func saveOfflineAlerts(_ alerts: [SavedAlert]) {
        if let data = try? JSONEncoder().encode(alerts) {
            userDefaults.set(data, forKey: offlineAlertsKey)
        }
    }
    
    func clearOfflineAlerts() {
        userDefaults.removeObject(forKey: offlineAlertsKey)
    }
    
    private func trackOfflineDeletion(alertId: String) {
        var offlineDeletions = getOfflineDeletions()
        offlineDeletions.append(alertId)
        saveOfflineDeletions(offlineDeletions)
    }
    
    func getOfflineDeletions() -> [String] {
        return userDefaults.stringArray(forKey: offlineDeletionsKey) ?? []
    }
    
    private func saveOfflineDeletions(_ deletions: [String]) {
        userDefaults.set(deletions, forKey: offlineDeletionsKey)
    }
    
    func clearOfflineDeletions() {
        userDefaults.removeObject(forKey: offlineDeletionsKey)
    }
    
    // MARK: - Bulk Operations
    
    func bulkToggleAlerts(ids: [UUID]) {
        for id in ids {
            if let alert = savedAlerts.first(where: { $0.id == id }) {
                toggleAlert(alert)
            }
        }
    }
    
    func bulkDeleteAlerts(ids: [UUID]) {
        let alertsToDelete = savedAlerts.filter { ids.contains($0.id) }
        
        for alert in alertsToDelete {
            deleteAlert(alert)
        }
    }
    
    
}
