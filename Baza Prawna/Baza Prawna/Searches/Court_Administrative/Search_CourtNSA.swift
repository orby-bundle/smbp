//
//  Search_CourtNSA_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import PostHog

// MARK: - Unified Search State
struct NSASearchState {
    // Basic
    var searchText: String = "" // wszystkieSlowa
    var caseSignature: String = "" // sygnatura
    var selectedCourtType: NSACourtType = .dowolny
    var selectedJudgmentType: NSAJudgmentType = .dowolny
    var selectedOccurrence: String = "gdziekolwiek" // wystepowanie
    var withWordVariations: Bool = true // odmiana

    // Advanced
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    var judgeName: String = "" // sedziowie
    var selectedJudgeFunction: NSAJudgeFunction = .dowolna // funkcja
    var symbole: String = "" // legal symbols
    var akty: String = "" // legal acts
    var przepisy: String = "" // regulations
    var publikacje: String = "" // publications
    var glosy: String = "" // commentaries
}

struct Search_CourtNSA_View: View, SearchResettable {
    @StateObject private var apiService = API_NSAService.shared
    
    // Unified search state
    @State private var state = NSASearchState()
    @State private var showingAdvancedFilters = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // MARK: - SearchResettable
    func resetSearchFields() {
        state = NSASearchState() // Reset all search parameters
        showingAdvancedFilters = false
        currentPage = 1
        isLoadingMore = false
        isLoadingNext = false
        isLoadingPrevious = false
        hasMoreResults = true
        searchResults = []
        isLoading = false
        errorMessage = nil
        showingResults = false
        showScrollToTop = false
    }
    
    // Pagination
    @State private var currentPage: Int = 1
    // pageSize: the site always returns 10 results per page. We keep the state for clarity/future enhancements.
    @State private var pageSize: Int = 10
    @State private var isLoadingMore = false
    @State private var isLoadingNext = false
    @State private var isLoadingPrevious = false
    @State private var hasMoreResults = true
    
    // Results
    @State private var searchResults: [NSAJudgment] = []
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
                                NSASearchField(
                                    title: "Szukaj",
                                    text: $state.searchText,
                                    placeholder: "Treść orzeczenia lub część sygnatury",
                                    textFieldMinHeight: 72,
                                    textFieldFont: .title3
                                )
                                
                                NSASearchField(title: "Dokładny numer sygnatury", text: $state.caseSignature, placeholder: "np. II SA/Ol 564/25")
                                
                                // Court Type Picker
                                NSACourtPickerField(title: "Sąd", selection: $state.selectedCourtType)
                                
                                // Judgment Type Picker
                                NSAJudgmentTypePickerField(title: "Typ orzeczenia", selection: $state.selectedJudgmentType)
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
                                    DateRangePickerField(dateFrom: $state.dateFrom, dateTo: $state.dateTo)
                                    // Occurrence Picker
                                    NSAPickerField(title: "Występowanie", selection: $state.selectedOccurrence, options: [
                                        ("gdziekolwiek", "gdziekolwiek"),
                                        ("w+sentencji", "w sentencji"),
                                        ("w+tezach", "w tezach"),
                                        ("w+uzasadnieniu", "w uzasadnieniu")
                                    ])
                                    
                                    // Word Variations Checkbox
                                    NSACheckboxField(title: "Z odmianą słów", isChecked: $state.withWordVariations)
                                                                                                            
                                    // Judge name search
                                    NSASearchField(title: "Nazwisko sędziego", text: $state.judgeName, placeholder: "np. Kowalski")
                                    
                                    // Judge function picker
                                    NSAJudgeFunctionPickerField(title: "Funkcja sędziego", selection: $state.selectedJudgeFunction)
                                    
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
                                saveAlertForCourtNSA(frequency: frequency)
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
                            Results_CourtNSA_View(
                                searchResults: searchResults,
                                hasMoreResults: hasMoreResults,
                                searchText: state.searchText
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

                        // Pagination Controls
                        if showingResults {
                            HStack {
                                Button(action: {
                                    Task { await loadPreviousPage() }
                                }) {
                                    HStack {
                                        if isLoadingPrevious {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                .scaleEffect(horizontalSizeClass == .regular ? 1.0 : 0.8)
                                        } else {
                                            Image(systemName: "chevron.left")
                                        }
                                    }
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
                                    .padding(.vertical, horizontalSizeClass == .regular ? 12 : 10)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(horizontalSizeClass == .regular ? 10 : 8)
                                }
                                .disabled(currentPage <= 1 || isLoadingMore || isLoading)
                                .opacity(isLoadingNext ? 0.5 : 1.0)
                                
                                Spacer()
                                
                                Text("Strona \(currentPage)")
                                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    Task { await loadNextPage() }
                                }) {
                                    HStack {
                                        if isLoadingNext {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                .scaleEffect(horizontalSizeClass == .regular ? 1.0 : 0.8)
                                        } else {
                                            Image(systemName: "chevron.right")
                                        }
                                    }
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
                                    .padding(.vertical, horizontalSizeClass == .regular ? 12 : 10)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(horizontalSizeClass == .regular ? 10 : 8)
                                }
                                .disabled(!hasMoreResults || isLoadingMore || isLoading)
                                .opacity(isLoadingPrevious ? 0.5 : 1.0)
                            }
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 24 : 16)
                }
                .navigationTitle("Sądy Administracyjne")
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
            "search_type": "Court NSA",
            "search_text": state.searchText,
            "case_signature": state.caseSignature,
            "court_type": state.selectedCourtType.displayName,
            "judgment_type": state.selectedJudgmentType.displayName,
            "occurrence": state.selectedOccurrence,
            "has_date_filter": state.dateFrom != nil
        ])
        
        Task {
            await searchCourtJudgments()
        }
    }
    
    @MainActor
    private func searchCourtJudgments() async {
        isLoading = true
        errorMessage = nil
        
        // Reset pagination for new search
        currentPage = 1
        hasMoreResults = true
        searchResults = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let parameters = NSASearchParameters(
            wszystkieSlowa: state.searchText.isEmpty ? nil : state.searchText,
            wystepowanie: state.selectedOccurrence,
            odmiana: state.withWordVariations,
            sygnatura: state.caseSignature.isEmpty ? nil : state.caseSignature,
            sad: state.selectedCourtType.formValue,
            rodzaj: state.selectedJudgmentType.formValue,
            symbole: state.symbole.isEmpty ? nil : state.symbole,
            odDaty: state.dateFrom.map { dateFormatter.string(from: $0) },
            doDaty: state.dateTo.map { dateFormatter.string(from: $0) },
            sedziowie: state.judgeName.isEmpty ? nil : state.judgeName,
            funkcja: state.selectedJudgeFunction.formValue,
            rodzaj_organu: nil,
            hasla: nil,
            akty: state.akty.isEmpty ? nil : state.akty,
            przepisy: state.przepisy.isEmpty ? nil : state.przepisy,
            publikacje: state.publikacje.isEmpty ? nil : state.publikacje,
            glosy: state.glosy.isEmpty ? nil : state.glosy,
            offset: currentPage,
            pageSize: pageSize
        )
        
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.8)) {
                searchResults = result.judgments
            }
            hasMoreResults = result.hasNextPage
            // Update current page flag to enable/disable previous button
            if currentPage > 1 && !result.hasPreviousPage {
                currentPage = 1
            }
            showingResults = true
            errorMessage = nil
        } catch {
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
            withAnimation(.easeInOut(duration: 0.3)) {
                searchResults = []
            }
            showingResults = false
        }
        
        isLoading = false
    }
    
    @MainActor
    private func loadNextPage() async {
        guard !isLoading && !isLoadingMore && hasMoreResults else { return }
        isLoadingMore = true
        isLoadingNext = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let nextPage = currentPage + 1

        let parameters = NSASearchParameters(
            wszystkieSlowa: state.searchText.isEmpty ? nil : state.searchText,
            wystepowanie: state.selectedOccurrence,
            odmiana: state.withWordVariations,
            sygnatura: state.caseSignature.isEmpty ? nil : state.caseSignature,
            sad: state.selectedCourtType.formValue,
            rodzaj: state.selectedJudgmentType.formValue,
            symbole: state.symbole.isEmpty ? nil : state.symbole,
            odDaty: state.dateFrom.map { dateFormatter.string(from: $0) },
            doDaty: state.dateTo.map { dateFormatter.string(from: $0) },
            sedziowie: state.judgeName.isEmpty ? nil : state.judgeName,
            funkcja: state.selectedJudgeFunction.formValue,
            rodzaj_organu: nil,
            hasla: nil,
            akty: state.akty.isEmpty ? nil : state.akty,
            przepisy: state.przepisy.isEmpty ? nil : state.przepisy,
            publikacje: state.publikacje.isEmpty ? nil : state.publikacje,
            glosy: state.glosy.isEmpty ? nil : state.glosy,
            offset: nextPage,
            pageSize: pageSize
        )

        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.6)) {
                searchResults = result.judgments
            }
            currentPage = nextPage
            hasMoreResults = result.hasNextPage
            showingResults = true
            errorMessage = nil
        } catch {
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        isLoadingMore = false
        isLoadingNext = false
    }

    @MainActor
    private func loadPreviousPage() async {
        guard !isLoading && !isLoadingMore && currentPage > 1 else { return }
        isLoadingMore = true
        isLoadingPrevious = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let previousPage = max(1, currentPage - 1)

        let parameters = NSASearchParameters(
            wszystkieSlowa: state.searchText.isEmpty ? nil : state.searchText,
            wystepowanie: state.selectedOccurrence,
            odmiana: state.withWordVariations,
            sygnatura: state.caseSignature.isEmpty ? nil : state.caseSignature,
            sad: state.selectedCourtType.formValue,
            rodzaj: state.selectedJudgmentType.formValue,
            symbole: state.symbole.isEmpty ? nil : state.symbole,
            odDaty: state.dateFrom.map { dateFormatter.string(from: $0) },
            doDaty: state.dateTo.map { dateFormatter.string(from: $0) },
            sedziowie: state.judgeName.isEmpty ? nil : state.judgeName,
            funkcja: state.selectedJudgeFunction.formValue,
            rodzaj_organu: nil,
            hasla: nil,
            akty: state.akty.isEmpty ? nil : state.akty,
            przepisy: state.przepisy.isEmpty ? nil : state.przepisy,
            publikacje: state.publikacje.isEmpty ? nil : state.publikacje,
            glosy: state.glosy.isEmpty ? nil : state.glosy,
            offset: previousPage,
            pageSize: pageSize
        )

        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.6)) {
                searchResults = result.judgments
            }
            currentPage = previousPage
            hasMoreResults = result.hasNextPage
            showingResults = true
            errorMessage = nil
        } catch {
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        isLoadingMore = false
        isLoadingPrevious = false
    }
    
    private func saveAlertForCourtNSA(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria = convertStateToCriteria()
        
        let alert = SavedAlert(
            searchType: .courtNSA,
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
        } else {
            return "Sądy Administracyjne"
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
        if !state.judgeName.isEmpty {
            criteria["judgeName"] = state.judgeName
        }
        if !state.symbole.isEmpty {
            criteria["symbole"] = state.symbole
        }
        if !state.akty.isEmpty {
            criteria["akty"] = state.akty
        }
        if !state.przepisy.isEmpty {
            criteria["przepisy"] = state.przepisy
        }
        if !state.publikacje.isEmpty {
            criteria["publikacje"] = state.publikacje
        }
        if !state.glosy.isEmpty {
            criteria["glosy"] = state.glosy
        }
        
        criteria["selectedCourtType"] = state.selectedCourtType.rawValue
        criteria["selectedJudgmentType"] = state.selectedJudgmentType.rawValue
        criteria["selectedOccurrence"] = state.selectedOccurrence
        criteria["withWordVariations"] = state.withWordVariations
        criteria["selectedJudgeFunction"] = state.selectedJudgeFunction.rawValue
        
        if let dateFrom = state.dateFrom {
            criteria["dateFrom"] = dateFrom.timeIntervalSince1970
        }
        if let dateTo = state.dateTo {
            criteria["dateTo"] = dateTo.timeIntervalSince1970
        }
        
        return criteria
    }
}

// MARK: - NSA Custom Field Views
struct NSASearchField: View {
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
                    .modifier(NSASearchFieldOptionalMinHeight(minHeight: textFieldMinHeight))
                
                ClearSearchButton(
                    searchText: $text,
                    onClear: { }
                )
            }
        }
    }
}

private struct NSASearchFieldOptionalMinHeight: ViewModifier {
    let minHeight: CGFloat?

    func body(content: Content) -> some View {
        if let h = minHeight {
            content.frame(minHeight: h)
        } else {
            content
        }
    }
}


// MARK: - NSA Picker Field
struct NSAPickerField: View {
    let title: String
    @Binding var selection: String
    let options: [(String, String)] // (value, displayName)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

// MARK: - NSA Court Picker Field
struct NSACourtPickerField: View {
    let title: String
    @Binding var selection: NSACourtType
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(NSACourtType.allCases, id: \.self) { courtType in
                    Text(courtType.displayName).tag(courtType)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

// MARK: - NSA Judgment Type Picker Field
struct NSAJudgmentTypePickerField: View {
    let title: String
    @Binding var selection: NSAJudgmentType
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(NSAJudgmentType.allCases, id: \.self) { judgmentType in
                    Text(judgmentType.displayName).tag(judgmentType)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

// MARK: - NSA Checkbox Field
struct NSACheckboxField: View {
    let title: String
    @Binding var isChecked: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                isChecked.toggle()
            }) {
                HStack(spacing: horizontalSizeClass == .regular ? 10 : 8) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .foregroundColor(isChecked ? .blue : .secondary)
                        .font(horizontalSizeClass == .regular ? .title : .title2)
                    
                    Text(isChecked ? "Tak" : "Nie")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - NSA Judge Function Picker Field
struct NSAJudgeFunctionPickerField: View {
    let title: String
    @Binding var selection: NSAJudgeFunction
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(NSAJudgeFunction.allCases, id: \.self) { function in
                    Text(function.displayName).tag(function)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

#Preview {
    Search_CourtNSA_View()
}
