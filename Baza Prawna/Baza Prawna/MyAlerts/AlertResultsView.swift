//
//  AlertResultsView.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 21/10/2025.
//

import SwiftUI

// MARK: - Alert Results View
struct AlertResultsView: View {
    let alert: SavedAlert
    let onBack: () -> Void
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchResults: [Any] = []
    @State private var hasMoreResults = true
    @State private var isLoadingMore = false
    @State private var currentOffset = 0
    @State private var currentPage = 1
    @State private var newResultsCount = 0
    @State private var rplCutoffDate: Date?
    @State private var searchSessionCutoffDate: Date? // Store cutoff date for this search session
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Computed property for committee sittings to help with type checking
    private var committeeSittings: [CommitteeSitting] {
        let result = searchResults.compactMap { $0 as? CommitteeSitting }
        if alert.searchType == .committeeSittings {
            print("📋 Committee Sittings Display: searchResults.count=\(searchResults.count), committeeSittings.count=\(result.count)")
            if !searchResults.isEmpty && result.isEmpty {
                print("⚠️ Committee Sittings: Type casting failed! First result type: \(type(of: searchResults.first))")
                if let first = searchResults.first {
                    print("⚠️ Committee Sittings: First result: \(first)")
                }
            }
        }
        return result
    }
    
    // Extracted results view to help with type checking
    @ViewBuilder
    private var resultsView: some View {
        switch alert.searchType {
        case .actsPL:
            if let results = searchResults as? [Act], !results.isEmpty {
                ResultsDUMP_View(
                    searchResults: results,
                    isLoadingMore: isLoadingMore,
                    hasMoreResults: hasMoreResults,
                    onLoadMore: loadMoreResults
                )
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        case .actsEU:
            if let results = searchResults as? [EUDocument], !results.isEmpty {
                ResultsEU_View(
                    searchResults: results,
                    isLoadingMore: isLoadingMore,
                    hasMoreResults: hasMoreResults,
                    onLoadMore: loadMoreResults,
                    selectedLanguage: getEULanguage()
                )
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        case .courtPL:
            if let results = searchResults as? [CourtJudgment], !results.isEmpty {
                Results_CourtPL_View(
                    searchResults: results,
                    isLoadingMore: isLoadingMore,
                    hasMoreResults: hasMoreResults,
                    onLoadMore: loadMoreResults,
                    searchText: getSearchText()
                )
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        case .courtNSA:
            if let results = searchResults as? [NSAJudgment], !results.isEmpty {
                VStack(spacing: 16) {
                    Results_CourtNSA_View(
                        searchResults: results,
                        hasMoreResults: hasMoreResults,
                        searchText: getSearchText()
                    )
                    
                    // Auto-load trigger at the bottom - automatically loads next page when scrolled into view
                    if hasMoreResults && !isLoadingMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                // Automatically load next page when scrolling to bottom (right chevron action)
                                Task {
                                    await loadNextNSAPage()
                                }
                            }
                    }
                    
                }
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        case .courtSupreme:
            if let results = searchResults as? [SupremeCourtJudgment], !results.isEmpty {
                Results_CourtSupreme_View(
                    searchResults: results,
                    isLoadingMore: isLoadingMore,
                    hasMoreResults: hasMoreResults,
                    onLoadMore: loadMoreResults
                )
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        case .rplProjects:
            if let results = searchResults as? [RPLProject], !results.isEmpty {
                ResultsRPLView(
                    searchResults: results,
                    isLoadingMore: isLoadingMore,
                    hasMoreResults: hasMoreResults,
                    onLoadMore: loadMoreResults
                )
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        case .legisPL:
            let legisPLResults = searchResults.compactMap { $0 as? LegislativeProcess }
            if !legisPLResults.isEmpty {
                ResultsLegislacjaView(
                    searchResults: legisPLResults,
                    isLoadingMore: isLoadingMore,
                    hasMoreResults: hasMoreResults,
                    onLoadMore: loadMoreResults,
                    onELITapped: { _ in }
                )
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        case .committeeSittings:
            // Filter for PLANNED status only when displaying
            let plannedSittings = committeeSittings.filter { sitting in
                sitting.status?.uppercased() == "PLANNED"
            }
            
            if !plannedSittings.isEmpty {
                VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                    ForEach(plannedSittings) { sitting in
                        VStack(alignment: .leading, spacing: 0) {
                            CommitteeSittingRow(
                                sitting: sitting,
                                horizontalSizeClass: horizontalSizeClass
                            )
                            .padding(horizontalSizeClass == .regular ? 16 : 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
                            .shadow(color: .black.opacity(0.08), radius: horizontalSizeClass == .regular ? 3 : 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
            } else {
                EmptyResultsView(searchType: alert.searchType)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                    // Header
                    VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 12 : 8) {
                        HStack {
                            Text(alert.title)
                                .font(horizontalSizeClass == .regular ? .largeTitle : .title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(2)
                            
                            if let firstParam = getFirstSearchParameter() {
                                Text("• \(firstParam)")
                                    .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                    .foregroundColor(.secondary)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }                        
                        
                        // Result count and search status
                        HStack {
                            Text("Najnowsze na początku")
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .foregroundColor(.secondary)
                            
                            if isLoading {
                                HStack(spacing: horizontalSizeClass == .regular ? 6 : 4) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(horizontalSizeClass == .regular ? 0.8 : 0.7)
                                    Text("Sprawdzanie...")
                                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(horizontalSizeClass == .regular ? 20 : 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                    
                    // Results based on search type - show always
                    resultsView
                    
                    
                    // Loading state
                    if isLoading {
                        VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(horizontalSizeClass == .regular ? 1.2 : 1.0)
                            Text("Wyszukiwanie...")
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(horizontalSizeClass == .regular ? 24 : 16)
                    }
                    
                    // Error state
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(horizontalSizeClass == .regular ? .body : .subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(horizontalSizeClass == .regular ? 20 : 16)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
                    }
                }
                .padding(horizontalSizeClass == .regular ? 20 : 16)
            }
            .navigationTitle("Wyniki Alertu")
            .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        onBack()
                    }) {
                        Image(systemName: "xmark")
                            .font(horizontalSizeClass == .regular ? .title : .title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                // Always perform search when opening alert results
                performSearch()
                
                // Clear unseen results count for this alert
                NotificationManager.shared.clearUnseenResults(for: alert.id)
            }
        }
    }
    
    private func performSearch() {
        rplCutoffDate = alert.lastSearchDate ?? alert.dateCreated
        Task {
            await searchFromAlert()
        }
    }
    
    @MainActor
    private func searchFromAlert() async {
        isLoading = true
        errorMessage = nil
        newResultsCount = 0
        let cutoffDate = rplCutoffDate ?? alert.lastSearchDate ?? alert.dateCreated
        
        // Store the cutoff date BEFORE updating lastSearchDate
        // This ensures we use the correct date for filtering new results
        // Get the current alert from AlertManager to ensure we have the latest accumulated results
        let currentAlertAtStart = AlertManager.shared.savedAlerts.first(where: { $0.id == alert.id }) ?? alert
        let searchCutoffDate = currentAlertAtStart.lastSearchDate ?? currentAlertAtStart.dateCreated
        searchSessionCutoffDate = searchCutoffDate // Store for pagination
        
        // Load accumulated results first from the current alert
        if let accumulatedResults = AlertManager.shared.getAccumulatedResults(for: currentAlertAtStart) {
            searchResults = accumulatedResults
            if alert.searchType == .actsPL {
                print("📋 ActsPL: Loaded \(accumulatedResults.count) accumulated results initially")
            } else if alert.searchType == .committeeSittings {
                print("📋 Committee Sittings: Loaded \(accumulatedResults.count) accumulated results initially")
            }
        } else {
            searchResults = []
            if alert.searchType == .actsPL {
                print("📋 ActsPL: No accumulated results found initially")
            } else if alert.searchType == .committeeSittings {
                print("📋 Committee Sittings: No accumulated results found initially")
            }
        }
        
        hasMoreResults = true
        currentOffset = 0
        currentPage = 1
        
        do {
            var newResults: [Any] = []
            
            // Create a temporary alert with the old lastSearchDate for parameter building
            // This ensures we search for results published AFTER the last check, not after NOW
            // Use currentAlertAtStart to ensure we have the latest accumulated results
            let alertForSearch = createAlertWithLastSearchDate(baseAlert: currentAlertAtStart, lastSearchDate: searchCutoffDate)
            
            switch alert.searchType {
            case .actsPL:
                let results = try await searchActsPL(offset: currentOffset, alertForSearch: alertForSearch)
                // Client-side filtering: Filter by announcementDate accounting for 1-day offset
                newResults = filterActsPL(results, since: searchCutoffDate, alertCreationDate: alert.dateCreated)
            case .actsEU:
                let results = try await searchActsEU(offset: currentOffset, alertForSearch: alertForSearch)
                newResults = results
            case .courtPL:
                let results = try await searchCourtPL(offset: currentOffset, alertForSearch: alertForSearch)
                newResults = results
            case .courtNSA:
                let apiService = API_NSAService.shared
                let parameterBuilder = AlertParameterBuilder(alert: alertForSearch)
                let parameters = parameterBuilder.createCourtNSAParameters(page: currentPage, useLastSearchDate: true)
                let result = try await apiService.searchJudgments(parameters: parameters)
                newResults = result.judgments
                hasMoreResults = result.hasNextPage
            case .courtSupreme:
                let results = try await searchCourtSupreme(offset: currentOffset, alertForSearch: alertForSearch)
                newResults = results
            case .rplProjects:
                let apiService = APIService_RPL.shared
                currentPage = 1
                let parameterBuilder = AlertParameterBuilder(alert: alertForSearch)
                let parameters = parameterBuilder.createRPLParameters(page: currentPage)
                let response = try await apiService.searchProjects(parameters: parameters)
                let filteredProjects = filterRPLProjects(response.projects, since: cutoffDate)
                newResults = filteredProjects as [Any]
                hasMoreResults = response.hasMore && !filteredProjects.isEmpty
            case .legisPL:
                print("📋 LegisPL: Processing alert")
                let apiService = APIService_Legis.shared
                let parameterBuilder = AlertParameterBuilder(alert: alertForSearch)
                
                // Check if this is a number-based alert or title-based alert
                if let number = alert.searchCriteria["number"] as? String, !number.isEmpty {
                    print("📋 LegisPL: Number-based alert for number: \(number)")
                    // Number-based alert: fetch specific process (no date filtering)
                    let currentTerm = apiService.getCurrentTerm()
                    let process = try await apiService.getProcessDetails(id: number, term: currentTerm)
                    newResults = [process]
                    hasMoreResults = false // Single process, no pagination
                    print("📋 LegisPL: Fetched process: \(process.title ?? "no title")")
                } else {
                    print("📋 LegisPL: Title-based alert")
                    // Title-based alert: search by title and filter by alert creation date, then remove duplicates
                    var parameters = parameterBuilder.createLegislacjaParameters(offset: currentOffset)
                    parameters.limit = 10 // Use smaller limit for pagination
                    print("📋 LegisPL: Search parameters: title=\(parameters.title ?? "nil"), offset=\(parameters.offset), limit=\(parameters.limit)")
                    let allProcesses = try await apiService.searchProcesses(parameters: parameters)
                    print("📋 LegisPL: Fetched \(allProcesses.count) total processes")
                    
                    // Filter by alert creation date (not lastSearchDate) - allow any results from alert creation date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for consistent comparison
                    
                    // Normalize alert creation date to start of day for comparison
                    let calendar = Calendar.current
                    let alertCreationDayStart = calendar.startOfDay(for: alert.dateCreated)
                    print("📋 LegisPL: Alert creation date: \(alert.dateCreated), normalized to start of day: \(alertCreationDayStart)")
                    
                    // First filter: only include processes from or after alert creation date
                    let dateFilteredProcesses = allProcesses.filter { process in
                        guard let documentDate = process.documentDate else { 
                            print("⚠️ LegisPL: Process \(process.number) has no documentDate")
                            return false 
                        }
                        if let processDate = dateFormatter.date(from: documentDate) {
                            // Normalize process date to start of day for comparison
                            let processDayStart = calendar.startOfDay(for: processDate)
                            let isAfter = processDayStart >= alertCreationDayStart
                            if !isAfter {
                                print("⚠️ LegisPL: Process \(process.number) documentDate \(documentDate) (normalized: \(processDayStart)) is before alert creation date (normalized: \(alertCreationDayStart))")
                            }
                            return isAfter
                        }
                        print("⚠️ LegisPL: Failed to parse documentDate: \(documentDate)")
                        return false
                    }
                    
                    print("📋 LegisPL: After date filtering (by alert creation date): \(dateFilteredProcesses.count) processes")
                    
                    // Second filter: remove processes that are already in accumulated results
                    let existingAccumulatedResults = AlertManager.shared.getAccumulatedResults(for: currentAlertAtStart)
                    let existingProcessIDs = Set((existingAccumulatedResults as? [LegislativeProcess] ?? []).map { $0.id })
                    
                    let filteredProcesses = dateFilteredProcesses.filter { process in
                        let isNew = !existingProcessIDs.contains(process.id)
                        if !isNew {
                            print("📋 LegisPL: Process \(process.number) already exists in accumulated results, filtering out")
                        }
                        return isNew
                    }
                    
                    print("📋 LegisPL: After duplicate filtering: \(filteredProcesses.count) new processes")
                    newResults = filteredProcesses
                    hasMoreResults = allProcesses.count == 10 // Use original count for pagination
                }
            case .committeeSittings:
                // For committee sittings, fetch current PLANNED sittings and update accumulated results
                let apiService = APIService_Legis.shared
                let parameterBuilder = AlertParameterBuilder(alert: alertForSearch)
                guard let committeeCode = parameterBuilder.createCommitteeSittingsParameters() else {
                    throw NSError(domain: "AlertResultsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Committee code not found"])
                }
                
                print("📋 Committee Sittings: Fetching sittings for committee: \(committeeCode)")
                let allSittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode)
                print("📋 Committee Sittings: Fetched \(allSittings.count) total sittings")
                
                // Filter for PLANNED status only
                let plannedSittings = allSittings.filter { sitting in
                    sitting.status?.uppercased() == "PLANNED"
                }
                print("📋 Committee Sittings: Found \(plannedSittings.count) PLANNED sittings")
                
                newResults = plannedSittings
                hasMoreResults = false // No pagination for committee sittings
            }
            
            // Save new results to accumulated storage (if any)
            // Get the current alert from AlertManager to ensure we're working with the latest version
            let currentAlertForSave = AlertManager.shared.savedAlerts.first(where: { $0.id == alert.id }) ?? alert
            
            if !newResults.isEmpty {
                if alert.searchType == .actsPL {
                    print("📋 ActsPL: Saving \(newResults.count) new results to accumulated storage")
                } else if alert.searchType == .committeeSittings {
                    print("📋 Committee Sittings: Saving \(newResults.count) results to accumulated storage")
                }
                let newResultsCountFromSave = AlertManager.shared.saveSearchResults(for: currentAlertForSave, results: newResults)
                newResultsCount = newResultsCountFromSave
                if alert.searchType == .actsPL {
                    print("📋 ActsPL: Saved, newResultsCount=\(newResultsCountFromSave)")
                } else if alert.searchType == .committeeSittings {
                    print("📋 Committee Sittings: Saved, newResultsCount=\(newResultsCountFromSave)")
                }
            }
            
            // Always refresh searchResults from accumulated results after the search
            // This ensures we display the latest state even if there were no new results
            // Get the updated alert from AlertManager after saving
            let updatedAlertForDisplay = AlertManager.shared.savedAlerts.first(where: { $0.id == alert.id }) ?? alert
            if let updatedAccumulatedResults = AlertManager.shared.getAccumulatedResults(for: updatedAlertForDisplay) {
                if alert.searchType == .committeeSittings {
                    print("📋 Committee Sittings: Retrieved \(updatedAccumulatedResults.count) accumulated results")
                } else if alert.searchType == .legisPL {
                    print("📋 LegisPL: Retrieved \(updatedAccumulatedResults.count) accumulated results")
                }
                
                // Apply alert-specific filtering for accumulated results
                let filteredResults: [Any]
                if alert.searchType == .actsPL,
                   let acts = updatedAccumulatedResults as? [Act] {
                    print("📋 ActsPL: Successfully cast to [Act], filtering by announcementDate")
                    let beforeFilter = acts.count
                    filteredResults = filterActsPL(acts, since: alert.dateCreated, alertCreationDate: alert.dateCreated)
                    print("📋 ActsPL: After date filtering: \(filteredResults.count) acts (was \(beforeFilter))")
                } else if alert.searchType == .legisPL {
                    // For LegisPL, accumulated results are already filtered by alert creation date
                    // and duplicates are removed when saving, so we can use them directly
                    if let processes = updatedAccumulatedResults as? [LegislativeProcess] {
                        print("📋 LegisPL: Successfully cast to [LegislativeProcess], using \(processes.count) accumulated results")
                        filteredResults = processes
                    } else {
                        print("📋 LegisPL: Using accumulated results directly (type: \(type(of: updatedAccumulatedResults.first)))")
                        filteredResults = updatedAccumulatedResults
                    }
                } else {
                    filteredResults = updatedAccumulatedResults
                }
                
                searchResults = filteredResults
                
                // Debug logging for LegisPL
                if alert.searchType == .legisPL {
                    print("📋 LegisPL: Final searchResults.count=\(searchResults.count)")
                    print("📋 LegisPL: filteredResults.count=\(filteredResults.count)")
                    if !searchResults.isEmpty {
                        print("📋 LegisPL: First result type: \(type(of: searchResults.first))")
                        if let first = searchResults.first as? LegislativeProcess {
                            print("📋 LegisPL: First result number: \(first.number), title: \(first.title ?? "nil")")
                        }
                    }
                }
                
                if !newResults.isEmpty {
                    // Show success message for new results
                    if alert.searchType == .legisPL {
                        print("📋 LegisPL: Added \(newResultsCount) new results (total: \(updatedAccumulatedResults.count), filtered: \(filteredResults.count))")
                    } else {
                        print("Added \(newResultsCount) new results (total: \(updatedAccumulatedResults.count))")
                    }
                } else {
                    if alert.searchType == .legisPL {
                        print("📋 LegisPL: No new results found, displaying \(filteredResults.count) filtered accumulated results (total: \(updatedAccumulatedResults.count))")
                    } else {
                        print("No new results found, displaying \(updatedAccumulatedResults.count) accumulated results")
                    }
                }
            } else {
                if alert.searchType == .legisPL {
                    print("⚠️ LegisPL: No accumulated results found after search")
                } else if alert.searchType == .actsPL {
                    print("⚠️ ActsPL: No accumulated results found after search")
                }
            }
            
            // Note: lastSearchDate is already updated by saveSearchResults() if new results were saved
            // If no new results were found, we still want to update lastSearchDate to prevent re-checking the same period
            if newResults.isEmpty {
                // Only update lastSearchDate if no new results were found (saveSearchResults already updates it when results are saved)
                AlertManager.shared.updateLastSearchDate(for: updatedAlertForDisplay)
            }
            
        } catch {
            errorMessage = error.localizedDescription
            // Don't update lastSearchDate if search failed
        }
        
        isLoading = false
    }
    
    private func loadMoreResults() async {
        guard !isLoadingMore && hasMoreResults else { return }
        
        isLoadingMore = true
        
        do {
            var newResults: [Any] = []
            
            // Use the stored cutoff date for pagination to ensure consistency
            let cutoffDateForPagination = searchSessionCutoffDate ?? alert.lastSearchDate ?? alert.dateCreated
            let alertForPagination = createAlertWithLastSearchDate(baseAlert: alert, lastSearchDate: cutoffDateForPagination)
            
            switch alert.searchType {
            case .actsPL:
                currentOffset += 10
                let results = try await searchActsPL(offset: currentOffset, alertForSearch: alertForPagination)
                // Client-side filtering: Filter by announcementDate accounting for 1-day offset
                newResults = filterActsPL(results, since: cutoffDateForPagination, alertCreationDate: alert.dateCreated)
                hasMoreResults = newResults.count == 10
            case .actsEU:
                currentOffset += 10
                newResults = try await searchActsEU(offset: currentOffset, alertForSearch: alertForPagination)
                hasMoreResults = newResults.count == 10
            case .courtPL:
                currentOffset += 10
                newResults = try await searchCourtPL(offset: currentOffset, alertForSearch: alertForPagination)
                hasMoreResults = newResults.count == 10
            case .courtNSA:
                // NSA uses separate pagination methods
                break
            case .courtSupreme:
                currentOffset += 10
                let cutoffDateForPagination = searchSessionCutoffDate ?? alert.lastSearchDate ?? alert.dateCreated
                let alertForPagination = createAlertWithLastSearchDate(baseAlert: alert, lastSearchDate: cutoffDateForPagination)
                newResults = try await searchCourtSupreme(offset: currentOffset, alertForSearch: alertForPagination)
                hasMoreResults = newResults.count == 10
            case .rplProjects:
                let apiService = APIService_RPL.shared
                let nextPage = currentPage + 1
                let parameterBuilder = AlertParameterBuilder(alert: alert)
                let parameters = parameterBuilder.createRPLParameters(page: nextPage)
                let response = try await apiService.searchProjects(parameters: parameters)
                currentPage = nextPage
                let cutoffDate = rplCutoffDate ?? alert.lastSearchDate ?? alert.dateCreated
                let filteredProjects = filterRPLProjects(response.projects, since: cutoffDate)
                newResults = filteredProjects as [Any]
                hasMoreResults = response.hasMore && !filteredProjects.isEmpty
            case .legisPL:
                // Check if this is a number-based alert (no pagination) or title-based
                if alert.searchCriteria["number"] as? String != nil {
                    // Number-based: no pagination needed
                    hasMoreResults = false
                } else {
                    // Title-based: paginate
                    currentOffset += 10
                    let apiService = APIService_Legis.shared
                    let parameterBuilder = AlertParameterBuilder(alert: alert)
                    var parameters = parameterBuilder.createLegislacjaParameters(offset: currentOffset)
                    parameters.limit = 10
                    let allProcesses = try await apiService.searchProcesses(parameters: parameters)
                    
                    // Filter by alert creation date (not lastSearchDate) - allow any results from alert creation date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for consistent comparison
                    
                    // Normalize alert creation date to start of day for comparison
                    let calendar = Calendar.current
                    let alertCreationDayStart = calendar.startOfDay(for: alert.dateCreated)
                    
                    // First filter: only include processes from or after alert creation date
                    let dateFilteredProcesses = allProcesses.filter { process in
                        guard let documentDate = process.documentDate else { return false }
                        if let processDate = dateFormatter.date(from: documentDate) {
                            // Normalize process date to start of day for comparison
                            let processDayStart = calendar.startOfDay(for: processDate)
                            return processDayStart >= alertCreationDayStart
                        }
                        return false
                    }
                    
                    // Second filter: remove processes that are already in accumulated results
                    let existingAccumulatedResults = AlertManager.shared.getAccumulatedResults(for: alert)
                    let existingProcessIDs = Set((existingAccumulatedResults as? [LegislativeProcess] ?? []).map { $0.id })
                    
                    let filteredProcesses = dateFilteredProcesses.filter { process in
                        !existingProcessIDs.contains(process.id)
                    }
                    
                    newResults = filteredProcesses
                    hasMoreResults = allProcesses.count == 10 // Use original count for pagination
                }
            case .committeeSittings:
                // Committee sittings don't support pagination
                hasMoreResults = false
                break
            }
            
            // Save new results to accumulated storage with duplicate removal
            if !newResults.isEmpty {
                let newResultsCountFromSave = AlertManager.shared.saveSearchResults(for: alert, results: newResults)
                
                // Update searchResults with combined results (now deduplicated)
                if let updatedAccumulatedResults = AlertManager.shared.getAccumulatedResults(for: alert) {
                    searchResults = updatedAccumulatedResults
                    
                    // Show feedback for new results
                    if newResultsCountFromSave > 0 {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingMore = false
    }
    
    // MARK: - NSA Pagination Methods
    
    private func loadNextNSAPage() async {
        guard !isLoadingMore && hasMoreResults else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        do {
            // Use the stored cutoff date for pagination to ensure consistency
            let cutoffDateForPagination = searchSessionCutoffDate ?? alert.lastSearchDate ?? alert.dateCreated
            let alertForPagination = createAlertWithLastSearchDate(baseAlert: alert, lastSearchDate: cutoffDateForPagination)
            
            let apiService = API_NSAService.shared
            let parameterBuilder = AlertParameterBuilder(alert: alertForPagination)
            let parameters = parameterBuilder.createCourtNSAParameters(page: nextPage, useLastSearchDate: true)
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            // Save new results to accumulated storage with duplicate removal
            if !result.judgments.isEmpty {
                let newResultsCountFromSave = AlertManager.shared.saveSearchResults(for: alert, results: result.judgments)
                
                // Update searchResults with combined results (now deduplicated)
                if let updatedAccumulatedResults = AlertManager.shared.getAccumulatedResults(for: alert) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        searchResults = updatedAccumulatedResults
                    }
                    
                    // Show feedback for new results
                    if newResultsCountFromSave > 0 {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
            }
            
            currentPage = nextPage
            hasMoreResults = result.hasNextPage
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Search Methods for Each Type
    
    private func searchActsPL(offset: Int = 0, alertForSearch: SavedAlert? = nil) async throws -> [Act] {
        let apiService = APIService.shared
        let alertToUse = alertForSearch ?? alert
        let parameterBuilder = AlertParameterBuilder(alert: alertToUse)
        let parameters = parameterBuilder.createActsPLParameters(offset: offset)
        let result = try await apiService.searchActs(parameters: parameters)
        return result.items
    }
    
    private func searchActsEU(offset: Int = 0, alertForSearch: SavedAlert? = nil) async throws -> [EUDocument] {
        let apiService = API_EUService.shared
        let alertToUse = alertForSearch ?? alert
        let parameterBuilder = AlertParameterBuilder(alert: alertToUse)
        let parameters = parameterBuilder.createActsEUParameters(offset: offset)
        let results = try await apiService.searchEUDocuments(parameters: parameters)
        return results
    }
    
    private func searchCourtPL(offset: Int = 0, alertForSearch: SavedAlert? = nil) async throws -> [CourtJudgment] {
        let apiService = API_CourtPLService.shared
        let alertToUse = alertForSearch ?? alert
        let parameterBuilder = AlertParameterBuilder(alert: alertToUse)
        let parameters = parameterBuilder.createCourtPLParameters(offset: offset)
        print("🔍 Alert Court PL API Parameters: \(parameters)")
        let results = try await apiService.searchCourtJudgments(parameters: parameters)
        print("✅ Alert Court PL API Response - Found \(results.count) results")
        return results
    }
    
    private func searchCourtNSA(page: Int = 1) async throws -> [NSAJudgment] {
        let apiService = API_NSAService.shared
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createCourtNSAParameters(page: page, useLastSearchDate: false)
        let result = try await apiService.searchJudgments(parameters: parameters)
        return result.judgments
    }
    
    private func searchCourtSupreme(offset: Int = 0, alertForSearch: SavedAlert? = nil) async throws -> [SupremeCourtJudgment] {
        let apiService = API_SupremeService.shared
        let alertToUse = alertForSearch ?? alert
        let parameterBuilder = AlertParameterBuilder(alert: alertToUse)
        let parameters = parameterBuilder.createCourtSupremeParameters(offset: offset)
        let result = try await apiService.searchJudgments(parameters: parameters)
        return result.judgments
    }
    
    // MARK: - Helper Methods
    
    private func getEULanguage() -> EULanguage {
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        return parameterBuilder.getEULanguage()
    }
    
    private func getSearchText() -> String {
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        return parameterBuilder.getSearchText()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private func getFirstSearchParameter() -> String? {
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let modifiedParams = parameterBuilder.getModifiedParameters()
        return modifiedParams.first
    }
    
    // MARK: - Helper Functions for DRY
    
    /// Creates a SavedAlert with a custom lastSearchDate for search/pagination operations
    /// - Parameters:
    ///   - baseAlert: The source alert to copy properties from
    ///   - lastSearchDate: The custom lastSearchDate to use
    /// - Returns: A new SavedAlert instance with the specified lastSearchDate
    private func createAlertWithLastSearchDate(baseAlert: SavedAlert, lastSearchDate: Date) -> SavedAlert {
        return SavedAlert(
            id: baseAlert.id,
            searchType: baseAlert.searchType,
            title: baseAlert.title,
            searchCriteria: baseAlert.searchCriteria,
            dateCreated: baseAlert.dateCreated,
            isActive: baseAlert.isActive,
            frequency: baseAlert.frequency,
            nextScheduledCheck: baseAlert.nextScheduledCheck,
            accumulatedResults: baseAlert.accumulatedResults,
            lastSearchDate: lastSearchDate,
            resultCount: baseAlert.resultCount
        )
    }

    private func filterActsPL(_ acts: [Act], since cutoffDate: Date, alertCreationDate: Date) -> [Act] {
        // Client-side filtering: Filter by changeDate
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for consistent comparison
        
        let calendar = Calendar.current
        
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
            
            // If the cutoff (start of day) is before or equal to creation date, use exact creation date
            // otherwise use the cutoff (which would be a later date's start)
            effectiveCutoffDate = max(alertCreationDate, normalizedCutoff)
        }
        
        return acts.filter { act in
            guard let changeDateString = act.changeDate, !changeDateString.isEmpty else {
                return false
            }
            
            // Try parsing changeDate
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
        return AlertResultsView.rplDateFormatter.date(from: string)
    }

    private static let rplDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}


// MARK: - Empty Results View
struct EmptyResultsView: View {
    let searchType: SearchType
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
            Image(systemName: "text.badge.xmark")
                .font(.system(size: horizontalSizeClass == .regular ? 70 : 50))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("Jeszcze nie ma nowych wyników")
                .font(horizontalSizeClass == .regular ? .largeTitle : .title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Ale stale sprawdzamy zgodnie z ustawioną częstotliwością")
                .font(horizontalSizeClass == .regular ? .title3 : .body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, horizontalSizeClass == .regular ? 60 : 40)
    }
}
