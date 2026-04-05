//
//  Search_CourtSupreme_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import PostHog

// MARK: - Unified Search State
struct SupremeCourtSearchState {
    // Basic
    var searchText: String = "" // trescOrzeczenia
    var caseSignature: String = "" // sygnatura
    var judgeInPanel: String = "" // sedziaWSkladzie
    var selectedChamber: SupremeCourtChamber = .all
    var selectedDecisionForm: SupremeCourtDecisionForm = .all

    // Dates
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
}

// MARK: - SearchResettable
extension Search_CourtSupreme_View {
    func resetSearchFields() {
        state = SupremeCourtSearchState()
        currentOffset = 0
        isLoadingMore = false
        hasMoreResults = true
        searchResults = []
        isLoading = false
        errorMessage = nil
        showingResults = false
        showScrollToTop = false
    }
}

struct Search_CourtSupreme_View: View, SearchResettable {
    @StateObject private var apiService = API_SupremeService.shared
    
    // Unified search state
    @State private var state = SupremeCourtSearchState()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Pagination (hidden from UI)
    @State private var currentOffset: Int = 0
    @State private var isLoadingMore = false
    @State private var hasMoreResults = true
    
    // Results
    @State private var searchResults: [SupremeCourtJudgment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingResults = false
    
    // Scroll to top
    @State private var showScrollToTop = false
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                        Color.clear.frame(height: 0).id("top")
                        
                        // Basic Search Section
                        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
                            VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                                SupremeCourtSearchField(title: "Treść orzeczenia", text: $state.searchText, placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
                                
                                SupremeCourtSearchField(title: "Sygnatura", text: $state.caseSignature, placeholder: "np. I CSK 123/2023")
                                
                                SupremeCourtSearchField(title: "Sędzia w składzie", text: $state.judgeInPanel, placeholder: "np. Kowalski")
                                
                                // Chamber Picker
                                SupremeCourtChamberPickerField(title: "Izba", selection: $state.selectedChamber)
                                
                                // Decision Form Picker
                                SupremeCourtDecisionFormPickerField(title: "Forma orzeczenia", selection: $state.selectedDecisionForm)
                            }
                        }
                        .padding(horizontalSizeClass == .regular ? 20 : 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                        
                        // Date Filters Section
                        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 12 : 8) {
                            VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                                DateRangePickerField(dateFrom: $state.dateFrom, dateTo: $state.dateTo)
                            }
                        }
                        .padding(horizontalSizeClass == .regular ? 20 : 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                        
                        // Search, Clear, and Alert Buttons in one row
                        UIManager.searchClearAndAlertButtonRow(
                            for: self,
                            searchTitle: "Szukaj",
                            isLoading: isLoading,
                            searchAction: performSearch,
                            alertAction: { frequency in
                                saveAlertForCourtSupreme(frequency: frequency)
                            },
                            hideResultsOnTap: true,
                            showingResults: $showingResults,
                            searchPremiumCheck: nil, // No premium check for search (free feature)
                            alertPremiumCheck: { PaywallManager.shared.checkPremiumAccess() }
                        )
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(horizontalSizeClass == .regular ? 20 : 16)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
                        }
                        
                        // Results Section
                        if showingResults {
                            Results_CourtSupreme_View(
                                searchResults: searchResults,
                                isLoadingMore: isLoadingMore,
                                hasMoreResults: hasMoreResults,
                                onLoadMore: loadMoreResults
                            )
                            .id("searchResults")
                            .onAppear {
                                withAnimation {
                                    showScrollToTop = searchResults.count > 5
                                }
                            }
                            .onDisappear {
                                withAnimation {
                                    showScrollToTop = false
                                }
                            }
                            .onChange(of: searchResults.count) { _, newCount in
                                withAnimation {
                                    showScrollToTop = newCount > 5
                                }
                            }
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 24 : 16)
                }
                .navigationTitle("Sąd Najwyższy")
                .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .large)
                .onChange(of: showingResults) { _, newValue in
                    if newValue {
                        // Scroll to results when search completes (regardless of whether results are found)
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
        }
    }
    
    private func performSearch() {
        // Track search event
        PostHogSDK.shared.capture("Search Performed", properties: [
            "search_type": "Court Supreme",
            "search_text": state.searchText,
            "case_signature": state.caseSignature,
            "chamber": state.selectedChamber.rawValue,
            "decision_form": state.selectedDecisionForm.rawValue,
            "has_date_filter": state.dateFrom != nil
        ])
        
        Task {
            await searchSupremeCourtJudgments()
        }
    }
    
    @MainActor
    private func searchSupremeCourtJudgments() async {
        isLoading = true
        errorMessage = nil
        
        // Reset pagination for new search
        currentOffset = 0
        hasMoreResults = true
        searchResults = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let parameters = SupremeCourtSearchParameters(
            trescOrzeczenia: state.searchText.isEmpty ? nil : state.searchText,
            sygnatura: state.caseSignature.isEmpty ? nil : state.caseSignature,
            formaOrzeczenia: state.selectedDecisionForm.formValue.isEmpty ? nil : state.selectedDecisionForm.formValue,
            izba: state.selectedChamber.formValue.isEmpty ? nil : state.selectedChamber.formValue,
            sedziaWSkladzie: state.judgeInPanel.isEmpty ? nil : state.judgeInPanel,
            dataOd: state.dateFrom.map { dateFormatter.string(from: $0) },
            dataDo: state.dateTo.map { dateFormatter.string(from: $0) },
            offset: currentOffset,
            pageSize: 10
        )
        
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            searchResults = result.judgments
            hasMoreResults = result.hasNextPage
            showingResults = true
            errorMessage = nil
        } catch {
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
            searchResults = []
            showingResults = false
        }
        
        isLoading = false
    }
    
    @MainActor
    private func loadMoreResults() async {
        guard !isLoadingMore && hasMoreResults else { return }
        
        isLoadingMore = true
        currentOffset += 10
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let parameters = SupremeCourtSearchParameters(
            trescOrzeczenia: state.searchText.isEmpty ? nil : state.searchText,
            sygnatura: state.caseSignature.isEmpty ? nil : state.caseSignature,
            formaOrzeczenia: state.selectedDecisionForm.formValue.isEmpty ? nil : state.selectedDecisionForm.formValue,
            izba: state.selectedChamber.formValue.isEmpty ? nil : state.selectedChamber.formValue,
            sedziaWSkladzie: state.judgeInPanel.isEmpty ? nil : state.judgeInPanel,
            dataOd: state.dateFrom.map { dateFormatter.string(from: $0) },
            dataDo: state.dateTo.map { dateFormatter.string(from: $0) },
            offset: currentOffset,
            pageSize: 10
        )
        
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            withAnimation(.easeInOut(duration: 0.5)) {
                searchResults.append(contentsOf: result.judgments)
            }
            
            hasMoreResults = result.hasNextPage
        } catch {
            // If error, revert offset
            currentOffset -= 10
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }
        
        isLoadingMore = false
    }
    
    private func saveAlertForCourtSupreme(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria = convertStateToCriteria()
        
        let alert = SavedAlert(
            searchType: .courtSupreme,
            title: alertTitle,
            searchCriteria: searchCriteria,
            frequency: frequency
        )
        
        AlertManager.shared.saveAlert(alert)
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func generateAlertTitle() -> String {
        if !state.searchText.isEmpty {
            return state.searchText
        } else if !state.caseSignature.isEmpty {
            return "Sygnatura: \(state.caseSignature)"
        } else if !state.judgeInPanel.isEmpty {
            return "Sędzia: \(state.judgeInPanel)"
        } else {
            return "Sąd Najwyższy"
        }
    }
    
    private func convertStateToCriteria() -> [String: Any] {
        var criteria: [String: Any] = [:]
        
        if !state.searchText.isEmpty {
            criteria["searchText"] = state.searchText
        }
        if !state.caseSignature.isEmpty {
            criteria["caseSignature"] = state.caseSignature
        }
        if !state.judgeInPanel.isEmpty {
            criteria["judgeInPanel"] = state.judgeInPanel
        }
        
        criteria["selectedChamber"] = state.selectedChamber.rawValue
        criteria["selectedDecisionForm"] = state.selectedDecisionForm.rawValue
        
        if let dateFrom = state.dateFrom {
            criteria["dateFrom"] = dateFrom.timeIntervalSince1970
        }
        if let dateTo = state.dateTo {
            criteria["dateTo"] = dateTo.timeIntervalSince1970
        }
        
        return criteria
    }
}

// MARK: - Supreme Court Custom Field Views
struct SupremeCourtSearchField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 6 : 4) {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                ClearSearchButton(
                    searchText: $text,
                    onClear: { }
                )
            }
        }
    }
}


// MARK: - Supreme Court Chamber Picker Field
struct SupremeCourtChamberPickerField: View {
    let title: String
    @Binding var selection: SupremeCourtChamber
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(SupremeCourtChamber.allCases, id: \.self) { chamber in
                    Text(chamber.displayName).tag(chamber)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .clipped()
        }
    }
}

// MARK: - Supreme Court Decision Form Picker Field
struct SupremeCourtDecisionFormPickerField: View {
    let title: String
    @Binding var selection: SupremeCourtDecisionForm
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(SupremeCourtDecisionForm.allCases, id: \.self) { decisionForm in
                    Text(decisionForm.displayName).tag(decisionForm)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .clipped()
        }
    }
}

#Preview {
    Search_CourtSupreme_View()
}
