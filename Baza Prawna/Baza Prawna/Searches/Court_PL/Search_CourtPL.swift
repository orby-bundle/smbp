//
//  Search_CourtPL_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import PostHog

// MARK: - Unified Search State
struct CourtPLSearchState {
    // Basic
    var searchText: String = ""
    var caseNumber: String = ""
    var selectedCourtType: CourtType = .commonCourts
    var selectedJudgmentType: JudgmentType = .all

    // Common Courts
    var ccCourtName: String = ""
    var ccDivisionName: String = ""
    var ccCourtCode: String = ""
    var selectedAppealCourtId: Int? = nil
    var selectedRegionalCourtId: Int? = nil
    var selectedDistrictCourtId: Int? = nil
    var selectedDivisionId: Int? = nil

    // Supreme Court
    var scChamberName: String = ""
    var scDivisionName: String = ""

    // Advanced
    var judgeName: String = ""
    var legalBase: String = ""
    var referencedRegulation: String = ""
    var lawJournalEntryCode: String = ""
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
}

struct Search_CourtPL_View: View, SearchResettable {
    @StateObject private var apiService = API_CourtPLService.shared
    
    // Unified search state (single source of truth)
    @State private var state = CourtPLSearchState()
    
    // Court dictionary
    private let courtDictionary = CourtPLDictionary.shared
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Computed property to get the selected court ID
    private var selectedCourtId: Int? {
        return state.selectedAppealCourtId ?? state.selectedRegionalCourtId ?? state.selectedDistrictCourtId
    }
    
    // Function to clear other court selections when one is selected
    private func clearOtherCourtSelections(exclude: CourtSelectionType) {
        switch exclude {
        case .appeal:
            state.selectedRegionalCourtId = nil
            state.selectedDistrictCourtId = nil
        case .regional:
            state.selectedAppealCourtId = nil
            state.selectedDistrictCourtId = nil
        case .district:
            state.selectedAppealCourtId = nil
            state.selectedRegionalCourtId = nil
        }
    }
    
    enum CourtSelectionType {
        case appeal, regional, district
    }
    
    // UI flags (non-search)
    @State private var showingAdvancedFilters = false
    
    // Pagination
    @State private var currentOffset: Int = 0
    @State private var isLoadingMore = false
    @State private var hasMoreResults = true
    
    // Results
    @State private var searchResults: [CourtJudgment] = []
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
                                CourtSearchField(title: "Szukaj", text: $state.searchText, placeholder: "Treść orzeczenia lub część sygnatury")                                
                                CourtSearchField(title: "Dokładny numer sygnatury", text: $state.caseNumber, placeholder: "np. I Ca 123/24")
                                
                                // Court Type Picker - Commented out, default set to commonCourts
                                // CourtPickerField(title: "Typ sądu", selection: $selectedCourtType)
                                
                                // Court-specific filters (conditional)
                                if state.selectedCourtType == .commonCourts {
                                    VStack(spacing: horizontalSizeClass == .regular ? 12 : 10) {
                                        // Court Type Title
                                        HStack {
                                            Text("Sąd")
                                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                                //.fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        
                                        // Appeal Courts Picker
                                        CourtNamePickerField(
                                            title: "Apelacyjny",
                                            selection: $state.selectedAppealCourtId,
                                            options: courtDictionary.appealCourts,
                                            placeholder: "dowolny"
                                        )
                                        .onChange(of: state.selectedAppealCourtId) { _, newValue in
                                            if newValue != nil {
                                                clearOtherCourtSelections(exclude: .appeal)
                                            }
                                        }
                                        
                                        // Regional Courts Picker
                                        CourtNamePickerField(
                                            title: "Okręgowy",
                                            selection: $state.selectedRegionalCourtId,
                                            options: courtDictionary.regionalCourts,
                                            placeholder: "dowolny"
                                        )
                                        .onChange(of: state.selectedRegionalCourtId) { _, newValue in
                                            if newValue != nil {
                                                clearOtherCourtSelections(exclude: .regional)
                                            }
                                        }
                                        
                                        // District Courts Picker with Search
                                        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
                                            Text("Rejonowy")
                                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                            
                                            SearchablePicker(
                                                selection: Binding(
                                                    get: { state.selectedDistrictCourtId.map { String($0) } ?? "" },
                                                    set: { newValue in
                                                        state.selectedDistrictCourtId = newValue.isEmpty ? nil : Int(newValue)
                                                        if state.selectedDistrictCourtId != nil {
                                                            clearOtherCourtSelections(exclude: .district)
                                                        }
                                                    }
                                                ),
                                                options: courtDictionary.districtCourts.map { $0.pickerOption },
                                                placeholder: "dowolny",
                                                searchPlaceholder: "Wprowadź nazwę..."
                                            )
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.top, 8)
                                    .padding(.horizontal, 12)
                                    //.background(Color(.systemGray5))
                                    .cornerRadius(8)
                                }
                                
                                if state.selectedCourtType == .supremeCourt {
                                    VStack(spacing: horizontalSizeClass == .regular ? 10 : 8) {
                                        CourtSearchField(title: "Izba", text: $state.scChamberName, placeholder: "np. Izba Cywilna")
                                        CourtSearchField(title: "Wydział", text: $state.scDivisionName, placeholder: "np. I Wydział Cywilny")
                                    }
                                    .padding(.top, horizontalSizeClass == .regular ? 10 : 8)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
                                    //.background(Color(.systemGray5))
                                    .cornerRadius(horizontalSizeClass == .regular ? 10 : 8)
                                }
                                
                                // Judgment Type Picker
                                CourtPickerField(title: "Typ orzeczenia", selection: $state.selectedJudgmentType)
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
                                    
                                    // Court-specific advanced fields (only show for common courts)
                                    if state.selectedCourtType == .commonCourts {
                                        // Division Name
                                        //CourtSearchField(title: "Wydział", text: $state.ccDivisionName, placeholder: "np. I Wydział Cywilny")
                                        
                                        // Court Code
                                        NumericField(title: "Kod sądu", text: $state.ccCourtCode, placeholder: "np. 15150000")
                                    }
                                    
                                    // Judge name search
                                    CourtSearchField(title: "Nazwisko sędziego", text: $state.judgeName, placeholder: "np. Kowalski")
                                    
                                    // Legal base search
                                    CourtSearchField(title: "Podstawa prawna", text: $state.legalBase, placeholder: "np. art. 448 k.c.")
                                    
                                    // Referenced regulation search
                                    CourtSearchField(title: "Przepis prawny", text: $state.referencedRegulation, placeholder: "np. Kodeks cywilny")
                                    
                                    // Law journal entry code
                                    CourtSearchField(title: "Dziennik Ustaw", text: $state.lawJournalEntryCode, placeholder: "np. 2011/112")
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
                                saveAlertForCourtPL(frequency: frequency)
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
                            Results_CourtPL_View(
                                searchResults: searchResults,
                                isLoadingMore: isLoadingMore,
                                hasMoreResults: hasMoreResults,
                                onLoadMore: loadMoreResults,
                                searchText: state.searchText
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
                        // Dismiss keyboard when tapping outside text fields
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .navigationTitle("Sądy Powszechne")
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
    
    // MARK: - SearchResettable
    func resetSearchFields() {
        state = CourtPLSearchState()
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
    
    private func performSearch() {
        // Track search event
        PostHogSDK.shared.capture("Search Performed", properties: [
            "search_type": "Court PL",
            "search_text": state.searchText,
            "case_number": state.caseNumber,
            "court_type": state.selectedCourtType.rawValue,
            "judgment_type": state.selectedJudgmentType.rawValue,
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
        currentOffset = 0
        hasMoreResults = true
        searchResults = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let parameters = CourtSearchParameters(
            search: state.searchText.isEmpty ? nil : state.searchText,
            caseNumber: state.caseNumber.isEmpty ? nil : state.caseNumber,
            judgmentDateFrom: state.dateFrom.map { dateFormatter.string(from: $0) },
            judgmentDateTo: state.dateTo.map { dateFormatter.string(from: $0) },
            courtType: state.selectedCourtType == .all ? nil : state.selectedCourtType,
            judgmentType: state.selectedJudgmentType == .all ? nil : state.selectedJudgmentType,
            sortField: "JUDGMENT_DATE",
            sortDirection: "DESC",
            ccCourtName: state.ccCourtName.isEmpty ? nil : state.ccCourtName,
            ccDivisionName: state.ccDivisionName.isEmpty ? nil : state.ccDivisionName,
            ccCourtCode: state.ccCourtCode.isEmpty ? nil : state.ccCourtCode,
            ccCourtId: selectedCourtId,
            ccDivisionId: state.selectedDivisionId,
            scChamberName: state.scChamberName.isEmpty ? nil : state.scChamberName,
            scDivisionName: state.scDivisionName.isEmpty ? nil : state.scDivisionName,
            judgeName: state.judgeName.isEmpty ? nil : state.judgeName,
            legalBase: state.legalBase.isEmpty ? nil : state.legalBase,
            referencedRegulation: state.referencedRegulation.isEmpty ? nil : state.referencedRegulation,
            lawJournalEntryCode: state.lawJournalEntryCode.isEmpty ? nil : state.lawJournalEntryCode,
            limit: 10,
            offset: currentOffset
        )
        
        do {
            let judgments = try await apiService.searchCourtJudgments(parameters: parameters)
            searchResults = judgments
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
        
        let parameters = CourtSearchParameters(
            search: state.searchText.isEmpty ? nil : state.searchText,
            caseNumber: state.caseNumber.isEmpty ? nil : state.caseNumber,
            judgmentDateFrom: state.dateFrom.map { dateFormatter.string(from: $0) },
            judgmentDateTo: state.dateTo.map { dateFormatter.string(from: $0) },
            courtType: state.selectedCourtType == .all ? nil : state.selectedCourtType,
            judgmentType: state.selectedJudgmentType == .all ? nil : state.selectedJudgmentType,
            sortField: "JUDGMENT_DATE",
            sortDirection: "DESC",
            ccCourtName: state.ccCourtName.isEmpty ? nil : state.ccCourtName,
            ccDivisionName: state.ccDivisionName.isEmpty ? nil : state.ccDivisionName,
            ccCourtCode: state.ccCourtCode.isEmpty ? nil : state.ccCourtCode,
            ccCourtId: selectedCourtId,
            ccDivisionId: state.selectedDivisionId,
            scChamberName: state.scChamberName.isEmpty ? nil : state.scChamberName,
            scDivisionName: state.scDivisionName.isEmpty ? nil : state.scDivisionName,
            judgeName: state.judgeName.isEmpty ? nil : state.judgeName,
            legalBase: state.legalBase.isEmpty ? nil : state.legalBase,
            referencedRegulation: state.referencedRegulation.isEmpty ? nil : state.referencedRegulation,
            lawJournalEntryCode: state.lawJournalEntryCode.isEmpty ? nil : state.lawJournalEntryCode,
            limit: 10,
            offset: currentOffset
        )
        
        do {
            let judgments = try await apiService.searchCourtJudgments(parameters: parameters)
            
            withAnimation(.easeInOut(duration: 0.5)) {
                searchResults.append(contentsOf: judgments)
            }
            
            // Check if we have more results
            hasMoreResults = judgments.count == 10
        } catch {
            // If error, revert offset
            currentOffset -= 10
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }
        
        isLoadingMore = false
    }
    
    private func saveAlertForCourtPL(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria = convertStateToCriteria()
        
        let alert = SavedAlert(
            searchType: .courtPL,
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
        } else if !state.caseNumber.isEmpty {
            return "Sygnatura: \(state.caseNumber)"
        } else {
            return "Sądy Powszechne"
        }
    }
    
    private func convertStateToCriteria() -> [String: Any] {
        var criteria: [String: Any] = [:]
        
        if !state.searchText.isEmpty {
            criteria["searchText"] = state.searchText
        }
        if !state.caseNumber.isEmpty {
            criteria["caseNumber"] = state.caseNumber
        }
        if !state.ccCourtName.isEmpty {
            criteria["ccCourtName"] = state.ccCourtName
        }
        if !state.ccDivisionName.isEmpty {
            criteria["ccDivisionName"] = state.ccDivisionName
        }
        if !state.ccCourtCode.isEmpty {
            criteria["ccCourtCode"] = state.ccCourtCode
        }
        if !state.scChamberName.isEmpty {
            criteria["scChamberName"] = state.scChamberName
        }
        if !state.scDivisionName.isEmpty {
            criteria["scDivisionName"] = state.scDivisionName
        }
        if !state.judgeName.isEmpty {
            criteria["judgeName"] = state.judgeName
        }
        if !state.legalBase.isEmpty {
            criteria["legalBase"] = state.legalBase
        }
        if !state.referencedRegulation.isEmpty {
            criteria["referencedRegulation"] = state.referencedRegulation
        }
        if !state.lawJournalEntryCode.isEmpty {
            criteria["lawJournalEntryCode"] = state.lawJournalEntryCode
        }
        
        criteria["selectedCourtType"] = state.selectedCourtType.rawValue
        criteria["selectedJudgmentType"] = state.selectedJudgmentType.rawValue
        
        if let selectedAppealCourtId = state.selectedAppealCourtId {
            criteria["selectedAppealCourtId"] = selectedAppealCourtId
        }
        if let selectedRegionalCourtId = state.selectedRegionalCourtId {
            criteria["selectedRegionalCourtId"] = selectedRegionalCourtId
        }
        if let selectedDistrictCourtId = state.selectedDistrictCourtId {
            criteria["selectedDistrictCourtId"] = selectedDistrictCourtId
        }
        if let selectedDivisionId = state.selectedDivisionId {
            criteria["selectedDivisionId"] = selectedDivisionId
        }
        
        if let dateFrom = state.dateFrom {
            criteria["dateFrom"] = dateFrom.timeIntervalSince1970
        }
        if let dateTo = state.dateTo {
            criteria["dateTo"] = dateTo.timeIntervalSince1970
        }
        
        return criteria
    }
}

// MARK: - Custom Field Views (Court-specific)
struct CourtSearchField: View {
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


struct CourtPickerField<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
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
                    Text(option.displayNameCourtPL).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .clipped()
        }
    }
}

// MARK: - Court Name Picker Field
struct CourtNamePickerField: View {
    let title: String
    @Binding var selection: Int?
    let options: [CourtInfo]
    let placeholder: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack {
            Text(title)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                Text(placeholder).tag(nil as Int?)
                ForEach(options, id: \.id) { court in
                    Text(court.name)
                        .tag(court.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .clipped()
        }
    }
}

// MARK: - Extensions
extension CaseIterable where Self: RawRepresentable, Self.RawValue == String {
    var displayNameCourtPL: String {
        if let courtType = self as? CourtType {
            return courtType.displayName
        } else if let judgmentType = self as? JudgmentType {
            return judgmentType.displayName
        }
        return rawValue.capitalized
    }
}

#Preview {
    Search_CourtPL_View()
}
