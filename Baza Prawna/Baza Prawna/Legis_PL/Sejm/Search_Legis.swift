//
//  Search_Legis.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 03/11/2025.
//

import SwiftUI
import PostHog

// MARK: - Unified Search State
struct LegislacjaSearchState {
    var title: String = ""
    var number: String = ""
}

struct SearchLegislacjaView: View, SearchResettable {
    @StateObject private var apiService = APIService_Legis.shared
    
    // Unified search state
    @State private var state = LegislacjaSearchState()
    
    init() {
        // Customize any UI appearance if needed
    }
    
    // MARK: - SearchResettable
    func resetSearchFields() {
        state = LegislacjaSearchState()
        currentOffset = 0
        isLoadingMore = false
        hasMoreResults = true
        searchResults = []
        isLoading = false
        errorMessage = nil
        showingResults = false
        showScrollToTop = false
    }
    
    // Pagination (hidden from UI)
    @State private var currentOffset: Int = 0
    @State private var isLoadingMore = false
    @State private var hasMoreResults = true
    
    // Results
    @State private var searchResults: [LegislativeProcess] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingResults = false
    
    // Scroll to top
    @State private var showScrollToTop = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                        Color.clear.frame(height: 0).id("top")
                        
                        // Basic Search Section
                        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
                            VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                                SearchField(
                                    title: "Tytuł lub Opis",
                                    text: $state.title,
                                    placeholder: "Poszukiwana treść",
                                    disabled: !state.number.isEmpty,
                                    textFieldMinHeight: 72,
                                    textFieldFont: .title3
                                )
                                .onChange(of: state.title) { _, newValue in
                                    // Clear number field when title gets input
                                    if !newValue.isEmpty && !state.number.isEmpty {
                                        state.number = ""
                                    }
                                }
                                SearchField(
                                    title: "Numer",
                                    text: $state.number,
                                    placeholder: "np. 1463",
                                    disabled: !state.title.isEmpty
                                )
                                .onChange(of: state.number) { _, newValue in
                                    // Clear title field when number gets input
                                    if !newValue.isEmpty && !state.title.isEmpty {
                                        state.title = ""
                                    }
                                }
                            }
                        }
                        .padding(horizontalSizeClass == .regular ? 20 : 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                        
                        // Search, Clear, and Alert Buttons
                        UIManager.searchClearAndAlertButtonRow(
                            for: self,
                            searchTitle: "Szukaj",
                            isLoading: isLoading,
                            searchAction: performSearch,
                            alertAction: { frequency in
                                saveAlertForLegislacja(frequency: frequency)
                            },
                            hideResultsOnTap: true,
                            showingResults: $showingResults,
                            searchPremiumCheck: nil,
                            alertPremiumCheck: { PaywallManager.shared.checkPremiumAccess() }
                        )
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding(horizontalSizeClass == .regular ? 20 : 16)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
                        }
                        
                        // Results Section
                        if showingResults {
                            ResultsLegislacjaView(
                                searchResults: searchResults,
                                isLoadingMore: isLoadingMore,
                                hasMoreResults: hasMoreResults,
                                onLoadMore: loadMoreResults,
                                onELITapped: { _ in }
                            )
                            .id("searchResults")
                            .onAppear {
                                withAnimation {
                                    showScrollToTop = searchResults.count > 10
                                }
                            }
                            .onDisappear {
                                withAnimation {
                                    showScrollToTop = false
                                }
                            }
                            .onChange(of: searchResults.count) { _, newCount in
                                withAnimation {
                                    showScrollToTop = newCount > 10
                                }
                            }
                        }
                    }
                }
                .padding(horizontalSizeClass == .regular ? 24 : 16)
                .onTapGesture {
                    // Dismiss keyboard when tapping outside text fields
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onChange(of: showingResults) { _, newValue in
                    if newValue {
                        // Scroll to results when search completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                proxy.scrollTo("searchResults", anchor: .top)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    ScrollToTopButton(showButton: $showScrollToTop) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("Legislacja - Sejm")
            .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .large)
        }
    }
    
    private func performSearch() {
        // Track search event
        PostHogSDK.shared.capture("Search Performed", properties: [
            "search_type": "Legislacja Sejm",
            "title": state.title,
            "number": state.number
        ])
        
        Task {
            await searchProcesses()
        }
    }
    
    @MainActor
    private func searchProcesses() async {
        isLoading = true
        errorMessage = nil
        
        // Reset pagination for new search
        currentOffset = 0
        hasMoreResults = true
        searchResults = []
        
        // If number is provided, fetch that specific process and ignore other filters
        if !state.number.isEmpty {
            do {
                let process = try await apiService.getProcessDetails(id: state.number)
                searchResults = [process]
                showingResults = true
            } catch {
                errorMessage = "Nie znaleziono procesu o numerze \(state.number)."
                searchResults = []
                showingResults = false
            }
        } else {
            // Regular search with filters
            // Fixed pagination values
            let limitValue = 10
            let offsetValue = currentOffset
            
            let parameters = LegislacjaSearchParameters(
                title: state.title.isEmpty ? nil : state.title,
                number: nil, // number already handled above
                dateFrom: nil,
                dateTo: nil,
                passed: nil,
                offset: offsetValue,
                limit: limitValue,
                sort_by: nil
            )
            
            do {
                let response = try await apiService.searchProcesses(parameters: parameters)
                searchResults = response
                showingResults = true
            } catch {
                errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
                searchResults = []
                showingResults = false
            }
        }
        
        isLoading = false
    }
    
    @MainActor
    private func loadMoreResults() async {
        guard !isLoadingMore && hasMoreResults else { return }
        
        // Don't load more if searching by number (single result)
        if !state.number.isEmpty {
            return
        }
        
        isLoadingMore = true
        currentOffset += 10
        
        let parameters = LegislacjaSearchParameters(
            title: state.title.isEmpty ? nil : state.title,
            number: nil, // number already handled in main search
            dateFrom: nil,
            dateTo: nil,
            passed: nil,
            offset: currentOffset,
            limit: 10,
            sort_by: nil
        )
        
        do {
            let response = try await apiService.searchProcesses(parameters: parameters)
            
            withAnimation(.easeInOut(duration: 0.5)) {
                searchResults.append(contentsOf: response)
            }
            
            // Check if we have more results
            hasMoreResults = response.count == 10
        } catch {
            // If error, revert offset
            currentOffset -= 10
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }
        
        isLoadingMore = false
    }
    
    private func saveAlertForLegislacja(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria = convertStateToCriteria()
        
        let alert = SavedAlert(
            searchType: .legisPL,
            title: alertTitle,
            searchCriteria: searchCriteria,
            frequency: frequency
        )
        
        AlertManager.shared.saveAlert(alert)
        
        // Show success feedback
        Haptics.impact(.medium)
    }
    
    private func generateAlertTitle() -> String {
        if !state.title.isEmpty {
            return state.title
        } else if !state.number.isEmpty {
            return "Legislacja #\(state.number)"
        } else {
            return "Legislacja - Sejm"
        }
    }
    
    private func convertStateToCriteria() -> [String: Any] {
        var criteria: [String: Any] = [:]
        
        // If number is provided, store only number (number-based alert)
        if !state.number.isEmpty {
            criteria["number"] = state.number
        } else if !state.title.isEmpty {
            // Otherwise, store title (title-based alert)
            criteria["title"] = state.title
        }
        
        return criteria
    }
}

#Preview {
    SearchLegislacjaView()
}
