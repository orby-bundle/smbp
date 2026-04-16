//
//  SearchView.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import UIKit
import PostHog

// MARK: - Unified Search State
struct DUMPSearchState {
    // Basic
    var keyword: String = ""
    var title: String = ""
    var selectedPublisher: PublisherOption = .du
    var selectedDocumentType: DocumentTypeOption = .all
    var includeExileDatabase = false
    
    // Date fields
    var date: Date? = nil
    var dateEffect: Date? = nil
    var dateEffectFrom: Date? = nil
    var dateEffectTo: Date? = nil
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    var pubDate: Date? = nil
    var pubDateFrom: Date? = nil
    var pubDateTo: Date? = nil
    
    // Numeric fields
    var position: String = ""
    var volume: String = ""
    var year: String = ""
    
    // Selection fields
    var selectedSortBy: SortBy = .title
    var selectedSortDir: SortDirection = .ascending
    var selectedInForce: InForceOption = .all
}

private enum SearchHelpStep: Int, CaseIterable {
    case criteria
    case searchButton
    case alertButton
    case navigationBar

    var message: String {
        switch self {
        case .criteria:
            return "Wprowadź kryteria"
        case .searchButton:
            return "Znajdź wyniki"
        case .alertButton:
            return "Ustaw alert o nowych aktach wg wprowadzonych kryteria"
        case .navigationBar:
            return "Zmieniaj bazy prawnicze"
        }
    }
}

struct SearchView: View, SearchResettable {
    @StateObject private var apiService = APIService.shared
    @ObservedObject private var appStateManager = AppStateManager.shared
    
    // Unified search state
    @State private var state = DUMPSearchState()
    @State private var showingDateFilters = false
    @State private var showingSearchOptions = false
    @State private var showingLegislacjaView = false
    @State private var helpStep: SearchHelpStep = .criteria
    
    init() {
        // Customize segmented control appearance
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = UIColor.systemBlue
        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 16, weight: .medium)
        ], for: .selected)
        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 16, weight: .medium)
        ], for: .normal)
    }
    
    // MARK: - SearchResettable
    func resetSearchFields() {
        state = DUMPSearchState() // Reset all search parameters
        showingDateFilters = false
        showingSearchOptions = false
        showingLegislacjaView = false
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
    @State private var searchResults: [Act] = []
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
                            
                            // Publisher Segmented Control
                            VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
                                Text("Rodzaj")
                                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Picker("Rodzaj", selection: $state.selectedPublisher) {
                                    ForEach(PublisherOption.allCases, id: \.self) { option in
                                        Text(option.displayName)
                                            .font(.system(size: 16, weight: .medium))
                                            .tag(option)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(height: 45)
                                .anchorPreference(key: SearchHelpAnchorPreferenceKey.self, value: .bounds) { [.publisherSegmented: $0] }
                                .onChange(of: state.selectedPublisher) { _, newValue in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if newValue == .legis {
                                        showingLegislacjaView = true
                                    }
                                }
                            }
                            SearchField(
                                title: "Tytuł",
                                text: $state.title,
                                placeholder: "Poszukiwana treść",
                                textFieldMinHeight: 72,
                                textFieldFont: .title3
                            )
                                .anchorPreference(key: SearchHelpAnchorPreferenceKey.self, value: .bounds) { [.titleField: $0] }
                            PickerField(title: "Typ dokumentu", selection: $state.selectedDocumentType)
                                .anchorPreference(key: SearchHelpAnchorPreferenceKey.self, value: .bounds) { [.documentType: $0] }
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 20 : 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                    
                    // Numeric Fields Section
                    VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 18 : 16) {
                        // Always visible Publication Year and Position in one row
                        ViewThatFits {
                            HStack(spacing: 12) {
                                NumericField(title: "Rok wydania", text: $state.year, placeholder: "dowolny", maxLength: 4)
                                    .anchorPreference(key: SearchHelpAnchorPreferenceKey.self, value: .bounds) { [.yearField: $0] }
                                NumericField(title: "Pozycja", text: $state.position, placeholder: "dowolna", maxLength: 4)
                            }
                            VStack(spacing: 12) {
                                NumericField(title: "Rok wydania", text: $state.year, placeholder: "dowolny", maxLength: 4)
                                    .anchorPreference(key: SearchHelpAnchorPreferenceKey.self, value: .bounds) { [.yearField: $0] }
                                NumericField(title: "Pozycja", text: $state.position, placeholder: "dowolna", maxLength: 4)
                            }
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 20 : 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                    
                    // Date Search Section (Collapsible)
                    VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 18 : 16) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingDateFilters.toggle()
                            }
                        }) {
                            HStack {
                                Text("Ustawienia dat")
                                    .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: showingDateFilters ? "chevron.up" : "chevron.down")
                                    .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(showingDateFilters ? 0 : 0))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showingDateFilters {
                            VStack(spacing: horizontalSizeClass == .regular ? 14 : 12) {
                                DatePickerField(title: "Data wydania", date: $state.date)
                                DateRangePickerField(dateFrom: $state.dateFrom, dateTo: $state.dateTo)
                                DatePickerField(title: "Data wejścia w życie", date: $state.dateEffect)
                                DateRangePickerField(dateFrom: $state.dateEffectFrom, dateTo: $state.dateEffectTo)
                                DatePickerField(title: "Data ogłoszenia", date: $state.pubDate)
                                DateRangePickerField(dateFrom: $state.pubDateFrom, dateTo: $state.pubDateTo)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 20 : 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                    
                    // Search Options Section (Collapsible)
                    VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 18 : 16) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSearchOptions.toggle()
                            }
                        }) {
                            HStack {
                                Text("Dodatkowe ustawienia")
                                    .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: showingSearchOptions ? "chevron.up" : "chevron.down")
                                    .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(showingSearchOptions ? 0 : 0))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showingSearchOptions {
                            VStack(spacing: horizontalSizeClass == .regular ? 14 : 12) {
                                //PickerField(title: "Sortowanie po", selection: $state.selectedSortBy)
                                //PickerField(title: "Kierunek sortowania", selection: $state.selectedSortDir)
                                PickerField(title: "Status dokumentu", selection: $state.selectedInForce)
                                NumericField(title: "Numer Wydania", text: $state.volume, placeholder: "dowolny", maxLength: 4)
                                
                                
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
                            saveAlertForActsPL(frequency: frequency)
                        },
                        hideResultsOnTap: true,
                        showingResults: $showingResults,
                        searchPremiumCheck: nil, // No premium check for search (free feature)
                        alertPremiumCheck: { PaywallManager.shared.checkPremiumAccess() }, // Premium check for alerts
                        showSearchHelpAnchors: true
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
                        ResultsDUMP_View(
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
                .onTapGesture {
                    // Dismiss keyboard when tapping outside text fields
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("Akty Polskie")
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
            .overlayPreferenceValue(SearchHelpAnchorPreferenceKey.self) { anchors in
                SearchHelpOverlay(
                    anchors: anchors,
                    isVisible: appStateManager.shouldShowSearchHelp,
                    step: $helpStep,
                    onComplete: {
                        appStateManager.markSearchHelpSeen()
                    }
                )
            }
            .navigationDestination(isPresented: $showingLegislacjaView) {
                LegislacjaInlineView()
            }
            .onChange(of: showingLegislacjaView) { _, newValue in
                // Reset to Dziennik Ustaw when returning from LegislacjaPlaceholderView
                if !newValue && state.selectedPublisher == .legis {
                    state.selectedPublisher = .du
                }
            }
            .onAppear {
                if appStateManager.shouldShowSearchHelp {
                    helpStep = .criteria
                }
            }
            .onChange(of: appStateManager.shouldShowSearchHelp) { _, newValue in
                if newValue {
                    helpStep = .criteria
                }
            }
            }
        }
    }
    
    private func performSearch() {
        // Track search event
        PostHogSDK.shared.capture("Search Performed", properties: [
            "search_type": "Acts PL",
            "keyword": state.keyword,
            "title": state.title,
            "publisher": state.selectedPublisher.rawValue,
            "year": state.year,
            "has_date_filter": state.date != nil || state.dateFrom != nil
        ])
        
        Task {
            await searchActs()
        }
    }
    
    @MainActor
    private func searchActs() async {
        // Don't perform search if Legislacja is selected
        if state.selectedPublisher == .legis {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Reset pagination for new search
        currentOffset = 0
        hasMoreResults = true
        searchResults = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Fixed pagination values
        let limitValue = 10
        let offsetValue = currentOffset
        
        let parameters = SearchParameters(
            date: state.date.map { dateFormatter.string(from: $0) },
            dateEffect: state.dateEffect.map { dateFormatter.string(from: $0) },
            dateEffectFrom: state.dateEffectFrom.map { dateFormatter.string(from: $0) },
            dateEffectTo: state.dateEffectTo.map { dateFormatter.string(from: $0) },
            dateFrom: state.dateFrom.map { dateFormatter.string(from: $0) },
            dateTo: state.dateTo.map { dateFormatter.string(from: $0) },
            exile: state.includeExileDatabase ? "E" : nil,
            inForce: state.selectedInForce.rawValue.isEmpty ? nil : state.selectedInForce.rawValue,
            keyword: state.keyword.isEmpty ? nil : state.keyword,
            limit: limitValue,
            offset: offsetValue,
            position: state.position.isEmpty ? nil : Int(state.position),
            pubDate: state.pubDate.map { dateFormatter.string(from: $0) },
            pubDateFrom: state.pubDateFrom.map { dateFormatter.string(from: $0) },
            pubDateTo: state.pubDateTo.map { dateFormatter.string(from: $0) },
            publisher: state.selectedPublisher.rawValue,
            sortBy: nil, // Don't send default sort parameters
            sortDir: nil, // Don't send default sort parameters
            title: state.title.isEmpty ? nil : state.title,
            type: state.selectedDocumentType.rawValue.isEmpty ? nil : state.selectedDocumentType.rawValue,
            volume: state.volume.isEmpty ? nil : Int(state.volume),
            year: state.year.isEmpty ? nil : Int(state.year)
        )
        
        do {
            let response = try await apiService.searchActs(parameters: parameters)
            searchResults = response.items
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
        
        // Don't load more results if Legislacja is selected
        if state.selectedPublisher == .legis {
            return
        }
        
        isLoadingMore = true
        currentOffset += 10
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let parameters = SearchParameters(
            date: state.date.map { dateFormatter.string(from: $0) },
            dateEffect: state.dateEffect.map { dateFormatter.string(from: $0) },
            dateEffectFrom: state.dateEffectFrom.map { dateFormatter.string(from: $0) },
            dateEffectTo: state.dateEffectTo.map { dateFormatter.string(from: $0) },
            dateFrom: state.dateFrom.map { dateFormatter.string(from: $0) },
            dateTo: state.dateTo.map { dateFormatter.string(from: $0) },
            exile: state.includeExileDatabase ? "E" : nil,
            inForce: state.selectedInForce.rawValue.isEmpty ? nil : state.selectedInForce.rawValue,
            keyword: state.keyword.isEmpty ? nil : state.keyword,
            limit: 10,
            offset: currentOffset,
            position: state.position.isEmpty ? nil : Int(state.position),
            pubDate: state.pubDate.map { dateFormatter.string(from: $0) },
            pubDateFrom: state.pubDateFrom.map { dateFormatter.string(from: $0) },
            pubDateTo: state.pubDateTo.map { dateFormatter.string(from: $0) },
            publisher: state.selectedPublisher.rawValue,
            sortBy: nil,
            sortDir: nil,
            title: state.title.isEmpty ? nil : state.title,
            type: state.selectedDocumentType.rawValue.isEmpty ? nil : state.selectedDocumentType.rawValue,
            volume: state.volume.isEmpty ? nil : Int(state.volume),
            year: state.year.isEmpty ? nil : Int(state.year)
        )
        
        do {
            let response = try await apiService.searchActs(parameters: parameters)
            
            withAnimation(.easeInOut(duration: 0.5)) {
                searchResults.append(contentsOf: response.items)
            }
            
            // Check if we have more results
            hasMoreResults = response.items.count == 10
        } catch {
            // If error, revert offset
            currentOffset -= 10
            errorMessage = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }
        
        isLoadingMore = false
    }
    
    private func saveAlertForActsPL(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria = convertStateToCriteria()
        
        let alert = SavedAlert(
            searchType: .actsPL,
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
        if !state.title.isEmpty {
            return state.title
        } else if !state.keyword.isEmpty {
            return state.keyword
        } else {
            return "Akty Polskie"
        }
    }
    
    private func convertStateToCriteria() -> [String: Any] {
        var criteria: [String: Any] = [:]
        
        if !state.keyword.isEmpty {
            criteria["keyword"] = state.keyword
        }
        if !state.title.isEmpty {
            criteria["title"] = state.title
        }
        if !state.position.isEmpty {
            criteria["position"] = state.position
        }
        if !state.volume.isEmpty {
            criteria["volume"] = state.volume
        }
        if !state.year.isEmpty {
            criteria["year"] = state.year
        }
        
        criteria["selectedPublisher"] = state.selectedPublisher.rawValue
        criteria["selectedDocumentType"] = state.selectedDocumentType.rawValue
        criteria["selectedSortBy"] = state.selectedSortBy.rawValue
        criteria["selectedSortDir"] = state.selectedSortDir.rawValue
        criteria["selectedInForce"] = state.selectedInForce.rawValue
        criteria["includeExileDatabase"] = state.includeExileDatabase
        
        if let date = state.date {
            criteria["date"] = date.timeIntervalSince1970
        }
        if let dateEffect = state.dateEffect {
            criteria["dateEffect"] = dateEffect.timeIntervalSince1970
        }
        if let dateEffectFrom = state.dateEffectFrom {
            criteria["dateEffectFrom"] = dateEffectFrom.timeIntervalSince1970
        }
        if let dateEffectTo = state.dateEffectTo {
            criteria["dateEffectTo"] = dateEffectTo.timeIntervalSince1970
        }
        if let dateFrom = state.dateFrom {
            criteria["dateFrom"] = dateFrom.timeIntervalSince1970
        }
        if let dateTo = state.dateTo {
            criteria["dateTo"] = dateTo.timeIntervalSince1970
        }
        if let pubDate = state.pubDate {
            criteria["pubDate"] = pubDate.timeIntervalSince1970
        }
        if let pubDateFrom = state.pubDateFrom {
            criteria["pubDateFrom"] = pubDateFrom.timeIntervalSince1970
        }
        if let pubDateTo = state.pubDateTo {
            criteria["pubDateTo"] = pubDateTo.timeIntervalSince1970
        }
        
        return criteria
    }
}

private struct SearchHelpOverlay: View {
    let anchors: [SearchHelpTarget: Anchor<CGRect>]
    let isVisible: Bool
    @Binding var step: SearchHelpStep
    let onComplete: () -> Void
    
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency

    var body: some View {
        if isVisible {
            GeometryReader { proxy in
                if let (highlightRects, unionRect) = highlightRects(in: proxy) {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .overlay(
                                ZStack {
                                    ForEach(Array(highlightRects.enumerated()), id: \.offset) { _, rect in
                                        RoundedRectangle(cornerRadius: 12)
                                            .frame(width: rect.width, height: rect.height)
                                            .position(x: rect.midX, y: rect.midY)
                                            .blendMode(.destinationOut)
                                    }
                                }
                            )
                            .compositingGroup()

                        ForEach(Array(highlightRects.enumerated()), id: \.offset) { _, rect in
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }

                        coachMark(for: unionRect, in: proxy)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        advanceStep()
                    }
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: step)
        }
    }

    private func highlightRects(in proxy: GeometryProxy) -> ([CGRect], CGRect)? {
        let targets = highlightTargets(for: step)
        let rects = targets.compactMap { target in
            anchors[target].map { proxy[$0].insetBy(dx: -6, dy: -6) }
        }
        guard !rects.isEmpty else { return nil }
        let unionRect = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        return (rects, unionRect)
    }

    private func highlightTargets(for step: SearchHelpStep) -> [SearchHelpTarget] {
        switch step {
        case .criteria:
            return [.titleField, .documentType, .yearField]
        case .searchButton:
            return [.searchButton]
        case .alertButton:
            return [.alertButton]
        case .navigationBar:
            return [.publisherSegmented]
        }
    }

    @ViewBuilder
    private func coachMark(for targetRect: CGRect, in proxy: GeometryProxy) -> some View {
        let placeBelow = targetRect.midY < proxy.size.height * 0.55
        let bubbleOffset: CGFloat = 70
        let rawBubbleY = placeBelow ? targetRect.maxY + bubbleOffset : targetRect.minY - bubbleOffset
        let minY: CGFloat = 80
        let maxY: CGFloat = proxy.size.height - 80
        let bubbleY = min(max(rawBubbleY, minY), maxY)
        let bubbleMaxWidth = max(220, min(proxy.size.width - 96, 360))

        VStack(spacing: 8) {
            Text(step.message)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: bubbleMaxWidth)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fillAdaptiveUltraThinMaterial(reduceTransparency: accessibilityReduceTransparency)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
        }
        .position(x: proxy.size.width / 2, y: bubbleY)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private func advanceStep() {
        guard let currentIndex = SearchHelpStep.allCases.firstIndex(of: step) else {
            onComplete()
            return
        }

        let nextIndex = SearchHelpStep.allCases.index(after: currentIndex)
        if nextIndex < SearchHelpStep.allCases.endIndex {
            step = SearchHelpStep.allCases[nextIndex]
        } else {
            onComplete()
        }
    }
}

// MARK: - Custom Field Views
struct SearchField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var disabled: Bool = false
    /// Minimum height for the text field (e.g. ~2× default ~36pt single-line height).
    var textFieldMinHeight: CGFloat? = nil
    /// Typography for typed text and placeholder; defaults to body.
    var textFieldFont: Font? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                TextField(placeholder, text: $text)
                    .font(textFieldFont ?? .body)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(disabled)
                    .modifier(SearchFieldOptionalMinHeight(minHeight: textFieldMinHeight))
                
                ClearSearchButton(
                    searchText: $text,
                    onClear: { }
                )
                .disabled(disabled)
            }
            .opacity(disabled ? 0.6 : 1.0)
        }
    }
}

private struct SearchFieldOptionalMinHeight: ViewModifier {
    let minHeight: CGFloat?

    func body(content: Content) -> some View {
        if let h = minHeight {
            content.frame(minHeight: h)
        } else {
            content
        }
    }
}



struct PickerField<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
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


// MARK: - Extensions
extension CaseIterable where Self: RawRepresentable, Self.RawValue == String {
    var displayName: String {
        if let sortBy = self as? SortBy {
            return sortBy.displayName
        } else if let sortDir = self as? SortDirection {
            return sortDir.displayName
        } else if let inForce = self as? InForceOption {
            return inForce.displayName
        } else if let publisher = self as? PublisherOption {
            return publisher.displayName
        } else if let documentType = self as? DocumentTypeOption {
            return documentType.displayName
        } else if let passedStatus = self as? PassedStatusOption {
            return passedStatus.displayName
        }
        return rawValue.capitalized
    }
}

private enum LegislacjaTabSelection: String, CaseIterable, Identifiable {
    case rzad
    case sejm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rzad:
            return "Rząd"
        case .sejm:
            return "Sejm"
        }
    }
}

private struct LegislacjaInlineView: View {
    @State private var selection: LegislacjaTabSelection = .rzad
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init() {
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = UIColor.systemBlue
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
    }

    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
            Picker("Legislacja", selection: $selection) {
                ForEach(LegislacjaTabSelection.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selection) { _, _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .padding(horizontalSizeClass == .regular ? 8 : 4)

            ZStack {
                SearchRPLView()
                    .opacity(selection == .rzad ? 1 : 0)
                    .allowsHitTesting(selection == .rzad)

                SearchLegislacjaView()
                    .opacity(selection == .sejm ? 1 : 0)
                    .allowsHitTesting(selection == .sejm)
            }
        }
        .padding(.top, horizontalSizeClass == .regular ? 16 : 12)
        .navigationTitle("Legislacja")
        .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .inline)
    }
}


#Preview {
    SearchView()
}
