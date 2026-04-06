//
//  Search_EU.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import UIKit
import PostHog

// MARK: - Unified Search State
struct EUSearchState {
    // Basic
    var searchText: String = ""
    var selectedLanguage: EULanguage = .polish
    
    // Advanced filters
    var celexNumber: String = ""
    var specificDate: String = ""
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    
    // Document Reference
    var documentYear: String = ""
    var documentNumber: String = ""
    var selectedDocumentType: EUDocumentType = .all
}

struct SearchEU_View: View, SearchResettable {
    @StateObject private var apiService = API_EUService.shared
    
    // Unified search state
    @State private var state = EUSearchState()
    @State private var showingAdvancedFilters = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // MARK: - SearchResettable
    func resetSearchFields() {
        state = EUSearchState() // Reset all search parameters
        showingAdvancedFilters = false
        currentOffset = 0
        isLoadingMore = false
        hasMoreResults = true
        searchResults = []
        isLoading = false
        errorMessage = nil
        showingResults = false
        showScrollToTop = false
    }
    
    // Pagination
    @State private var currentOffset: Int = 0
    @State private var isLoadingMore = false
    @State private var hasMoreResults = true
    
    // Results
    @State private var searchResults: [EUDocument] = []
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
                                EUSearchField(
                                    title: "Szukaj",
                                    text: $state.searchText,
                                    placeholder: "Słowa kluczowe w tytule lub treści",
                                    textFieldMinHeight: 72,
                                    textFieldFont: .title3
                                )
                                
                                // Language Picker
                                HStack {
                                    Text("Język")
                                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("Język", selection: $state.selectedLanguage) {
                                        ForEach(EULanguage.allCases, id: \.self) { language in
                                            Text(language.displayName).tag(language)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .onChange(of: state.selectedLanguage) { _, _ in
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    .frame(maxWidth: horizontalSizeClass == .regular ? 300 : 200)
                                }
                                
                                // Document Reference Section
                                VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 14 : 12) {
                                    Text("Referencja dokumentu")
                                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    ViewThatFits {
                                        HStack(spacing: 12) {
                                            NumericField(title: "Rok", text: $state.documentYear, placeholder: "np. 2024", maxLength: 4)
                                            NumericField(title: "Numer", text: $state.documentNumber, placeholder: "np. 123")
                                        }
                                        VStack(spacing: 12) {
                                            NumericField(title: "Rok", text: $state.documentYear, placeholder: "np. 2024", maxLength: 4)
                                            NumericField(title: "Numer", text: $state.documentNumber, placeholder: "np. 123")
                                        }
                                    }
                                    
                                    // Document Type Picker
                                    EUPickerField(title: "Typ dokumentu", selection: $state.selectedDocumentType)
                                }
                            }
                        }
                        .padding(horizontalSizeClass == .regular ? 20 : 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                        
                        // Advanced Filters Section (Collapsible)
                        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 18 : 16) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingAdvancedFilters.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Zaawansowane filtry")
                                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: showingAdvancedFilters ? "chevron.up" : "chevron.down")
                                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                        .foregroundColor(.blue)
                                        .rotationEffect(.degrees(showingAdvancedFilters ? 0 : 0))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showingAdvancedFilters {
                                VStack(spacing: horizontalSizeClass == .regular ? 14 : 12) {
                                    EUSearchField(title: "Numer CELEX", text: $state.celexNumber, placeholder: "np. 32014R0001")
                                    
                                    EUSearchField(title: "Konkretna data", text: $state.specificDate, placeholder: "dd/mm/rrrr, mm/rrrr lub rrrr")
                                    
                                    DateRangePickerField(dateFrom: $state.dateFrom, dateTo: $state.dateTo)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
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
                                saveAlertForActsEU(frequency: frequency)
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
                            ResultsEU_View(
                                searchResults: searchResults,
                                isLoadingMore: isLoadingMore,
                                hasMoreResults: hasMoreResults,
                                onLoadMore: loadMoreResults,
                                selectedLanguage: state.selectedLanguage
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
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .navigationTitle("Prawo Unijne")
                .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .large)
                .onChange(of: showingResults) { _, newValue in
                    if newValue {
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
            "search_type": "Acts EU",
            "search_text": state.searchText,
            "language": state.selectedLanguage.rawValue,
            "document_type": state.selectedDocumentType.rawValue,
            "celex": state.celexNumber,
            "has_date_filter": state.dateFrom != nil || !state.specificDate.isEmpty
        ])
        
        Task {
            await searchEUDocuments()
        }
    }
    
    
    @MainActor
    private func searchEUDocuments() async {
        isLoading = true
        errorMessage = nil
        
        // Reset pagination for new search
        currentOffset = 0
        hasMoreResults = true
        searchResults = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let parameters = EUSearchParameters(
            query: state.searchText.isEmpty ? nil : state.searchText,
            documentType: state.selectedDocumentType,
            language: state.selectedLanguage,
            specificDate: state.specificDate.isEmpty ? nil : state.specificDate,
            dateFrom: state.dateFrom.map { dateFormatter.string(from: $0) },
            dateTo: state.dateTo.map { dateFormatter.string(from: $0) },
            celexNumber: state.celexNumber.isEmpty ? nil : state.celexNumber,
            documentYear: state.documentYear.isEmpty ? nil : state.documentYear,
            documentNumber: state.documentNumber.isEmpty ? nil : state.documentNumber,
            limit: 10,
            offset: currentOffset
        )
        
        do {
            let documents = try await apiService.searchEUDocuments(parameters: parameters)
            searchResults = documents
            showingResults = true
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
        
        let parameters = EUSearchParameters(
            query: state.searchText.isEmpty ? nil : state.searchText,
            documentType: state.selectedDocumentType,
            language: state.selectedLanguage,
            specificDate: state.specificDate.isEmpty ? nil : state.specificDate,
            dateFrom: state.dateFrom.map { dateFormatter.string(from: $0) },
            dateTo: state.dateTo.map { dateFormatter.string(from: $0) },
            celexNumber: state.celexNumber.isEmpty ? nil : state.celexNumber,
            documentYear: state.documentYear.isEmpty ? nil : state.documentYear,
            documentNumber: state.documentNumber.isEmpty ? nil : state.documentNumber,
            limit: 10,
            offset: currentOffset
        )
        
        do {
            let documents = try await apiService.searchEUDocuments(parameters: parameters)
            
            withAnimation(.easeInOut(duration: 0.5)) {
                searchResults.append(contentsOf: documents)
            }
            
            // Check if we have more results
            hasMoreResults = documents.count == 10
        } catch {
            // If error, revert offset
            currentOffset -= 10
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }
        
        isLoadingMore = false
    }
    
    private func saveAlertForActsEU(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria = convertStateToCriteria()
        
        let alert = SavedAlert(
            searchType: .actsEU,
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
        } else if !state.celexNumber.isEmpty {
            return "CELEX: \(state.celexNumber)"
        } else {
            return "Prawo Unijne"
        }
    }
    
    private func convertStateToCriteria() -> [String: Any] {
        var criteria: [String: Any] = [:]
        
        if !state.searchText.isEmpty {
            criteria["searchText"] = state.searchText
        }
        if !state.celexNumber.isEmpty {
            criteria["celexNumber"] = state.celexNumber
        }
        if !state.specificDate.isEmpty {
            criteria["specificDate"] = state.specificDate
        }
        if !state.documentYear.isEmpty {
            criteria["documentYear"] = state.documentYear
        }
        if !state.documentNumber.isEmpty {
            criteria["documentNumber"] = state.documentNumber
        }
        
        criteria["selectedLanguage"] = state.selectedLanguage.rawValue
        criteria["selectedDocumentType"] = state.selectedDocumentType.rawValue
        
        if let dateFrom = state.dateFrom {
            criteria["dateFrom"] = dateFrom.timeIntervalSince1970
        }
        if let dateTo = state.dateTo {
            criteria["dateTo"] = dateTo.timeIntervalSince1970
        }
        
        return criteria
    }
    
}

// MARK: - Custom Field Views (EU-specific)
struct EUSearchField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var textFieldMinHeight: CGFloat? = nil
    var textFieldFont: Font? = nil
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 6 : 4) {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                TextField(placeholder, text: $text)
                    .font(textFieldFont ?? .body)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .modifier(EUSearchFieldOptionalMinHeight(minHeight: textFieldMinHeight))
                
                ClearSearchButton(
                    searchText: $text,
                    onClear: { }
                )
            }
        }
    }
}

private struct EUSearchFieldOptionalMinHeight: ViewModifier {
    let minHeight: CGFloat?

    func body(content: Content) -> some View {
        if let h = minHeight {
            content.frame(minHeight: h)
        } else {
            content
        }
    }
}


struct EUPickerField<T: CaseIterable & Hashable & RawRepresentable & DisplayNameProvider>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

#Preview {
    SearchEU_View()
}
