import SwiftUI
import UIKit
import PostHog

// MARK: - Everywhere search

struct EverywhereSearchView: View, SearchResettable {
    private enum Source: String, CaseIterable, Identifiable {
        case actsPL
        case actsEU
        case courtPL
        case courtNSA
        case courtSupreme
        case legisRPL
        case legisSejm

        var id: String { rawValue }

        var title: String {
            switch self {
            case .actsPL: return "Dz.U. / M.P."
            case .actsEU: return "Prawo Unijne"
            case .courtPL: return "Sądy Powszechne"
            case .courtNSA: return "Sądy Administracyjne"
            case .courtSupreme: return "Sąd Najwyższy"
            case .legisRPL: return "Rząd"
            case .legisSejm: return "Sejm"
            }
        }
    }

    // Inputs
    @State private var keyword: String = ""
    @State private var yearFrom: String = ""
    @State private var yearTo: String = ""

    // Source toggles + results tab selection
    @State private var enabledSources: Set<Source> = Set(Source.allCases)
    @State private var selectedResultsTab: Source = .actsPL

    // Global UI flags
    @State private var showingResults: Bool = false

    // MARK: - Per-source state

    // Acts PL
    @State private var actsPLResults: [Act] = []
    @State private var actsPLIsLoading: Bool = false
    @State private var actsPLIsLoadingMore: Bool = false
    @State private var actsPLHasMore: Bool = true
    @State private var actsPLOffset: Int = 0
    @State private var actsPLError: String?

    // Acts EU
    @State private var actsEUResults: [EUDocument] = []
    @State private var actsEUIsLoading: Bool = false
    @State private var actsEUIsLoadingMore: Bool = false
    @State private var actsEUHasMore: Bool = true
    @State private var actsEUOffset: Int = 0
    @State private var actsEUError: String?
    private let actsEUSelectedLanguage: EULanguage = .polish
    private let actsEUSelectedDocumentType: EUDocumentType = .all

    // Court PL
    @State private var courtPLResults: [CourtJudgment] = []
    @State private var courtPLIsLoading: Bool = false
    @State private var courtPLIsLoadingMore: Bool = false
    @State private var courtPLHasMore: Bool = true
    @State private var courtPLOffset: Int = 0
    @State private var courtPLError: String?

    // Court NSA
    @State private var courtNSAResults: [NSAJudgment] = []
    @State private var courtNSAIsLoading: Bool = false
    @State private var courtNSAIsLoadingMore: Bool = false
    @State private var courtNSAIsLoadingNext: Bool = false
    @State private var courtNSAIsLoadingPrevious: Bool = false
    @State private var courtNSAHasMore: Bool = true
    @State private var courtNSACurrentPage: Int = 1
    @State private var courtNSAError: String?
    private let courtNSAPageSize: Int = 10

    // Court Supreme
    @State private var courtSupremeResults: [SupremeCourtJudgment] = []
    @State private var courtSupremeIsLoading: Bool = false
    @State private var courtSupremeIsLoadingMore: Bool = false
    @State private var courtSupremeHasMore: Bool = true
    @State private var courtSupremeOffset: Int = 0
    @State private var courtSupremeError: String?

    // RPL
    @State private var rplResults: [RPLProject] = []
    @State private var rplIsLoading: Bool = false
    @State private var rplIsLoadingMore: Bool = false
    @State private var rplHasMore: Bool = true
    @State private var rplCurrentPage: Int = 1
    @State private var rplTotalPages: Int?
    @State private var rplError: String?

    // Legislacja Sejm
    @State private var legisResults: [LegislativeProcess] = []
    @State private var legisIsLoading: Bool = false
    @State private var legisIsLoadingMore: Bool = false
    @State private var legisHasMore: Bool = true
    @State private var legisOffset: Int = 0
    @State private var legisError: String?

    // Shared
    @State private var showScrollToTop: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - SearchResettable
    func resetSearchFields() {
        keyword = ""
        yearFrom = ""
        yearTo = ""

        enabledSources = Set(Source.allCases)
        selectedResultsTab = .actsPL

        showingResults = false
        resetAllResultsAndPaging()
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                        Color.clear.frame(height: 0).id("top")

                        criteriaSection
                        sourcesSection

                        UIManager.searchAndClearButtonRow(
                            for: self,
                            searchTitle: "Szukaj",
                            isLoading: isAnyLoading,
                            searchAction: performSearch,
                            hideResultsOnTap: true,
                            showingResults: $showingResults
                        )

                        if showingResults {
                            resultsTabsPicker
                                .id("resultsTabs")
                            resultsTabContent
                                .id("searchResults")
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 24 : 16)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .navigationTitle("Wyszukiwanie globalne")
                .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .large)
                .onChange(of: showingResults) { _, newValue in
                    if !newValue {
                        withAnimation {
                            showScrollToTop = false
                        }
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            proxy.scrollTo("resultsTabs", anchor: .top)
                        }
                    }
                    updateScrollToTopVisibility()
                }
                .onChange(of: selectedResultsTab) { _, _ in
                    updateScrollToTopVisibility()
                }
                .onChange(of: enabledSources) { _, _ in
                    updateScrollToTopVisibility()
                }
                .onChange(of: actsPLResults.count) { _, _ in updateScrollToTopVisibility() }
                .onChange(of: actsEUResults.count) { _, _ in updateScrollToTopVisibility() }
                .onChange(of: courtPLResults.count) { _, _ in updateScrollToTopVisibility() }
                .onChange(of: courtNSAResults.count) { _, _ in updateScrollToTopVisibility() }
                .onChange(of: courtSupremeResults.count) { _, _ in updateScrollToTopVisibility() }
                .onChange(of: rplResults.count) { _, _ in updateScrollToTopVisibility() }
                .onChange(of: legisResults.count) { _, _ in updateScrollToTopVisibility() }
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

    // MARK: - Sections

    private var criteriaSection: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 18 : 16) {
            SearchField(
                title: "Słowa kluczowe",
                text: $keyword,
                placeholder: "np. podatki, odwołanie, dyrektywa",
                textFieldMinHeight: 56,
                textFieldFont: .title3
            )

            ViewThatFits {
                HStack(spacing: 12) {
                    NumericField(title: "Rok od", text: $yearFrom, placeholder: "dowolny", maxLength: 4)
                    NumericField(title: "Rok do", text: $yearTo, placeholder: "dowolny", maxLength: 4)
                }
                VStack(spacing: 12) {
                    NumericField(title: "Rok od", text: $yearFrom, placeholder: "dowolny", maxLength: 4)
                    NumericField(title: "Rok do", text: $yearTo, placeholder: "dowolny", maxLength: 4)
                }
            }
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 14 : 12) {
            Text("Źródła")
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)

            let columns: [GridItem] = [
                GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 120 : 92), spacing: 10, alignment: .leading)
            ]

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(Source.allCases) { source in
                    sourceToggleChip(source)
                }
            }
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
    }

    private var resultsTabsPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            let columns: [GridItem] = [
                GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 120 : 92), spacing: 10, alignment: .leading)
            ]

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(visibleResultsTabs) { source in
                    resultsTabChip(source)
                }
            }
        }
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func resultsTabChip(_ source: Source) -> some View {
        let isSelected = selectedResultsTab == source
        let isMuted = !enabledSources.contains(source)

        return Button {
            selectedResultsTab = source
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 8) {
                Text(source.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if isMuted {
                    Image(systemName: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.95) : Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .background {
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemGroupedBackground))
            }
            .overlay {
                Capsule()
                    .stroke(Color(.systemGray4), lineWidth: isSelected ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMuted ? "\(source.title), wyciszone" : source.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var visibleResultsTabs: [Source] {
        Source.allCases.filter { source in
            // Keep muted tabs visible (so user can see "Wyciszone" and re-enable).
            if !enabledSources.contains(source) { return true }
            // Keep tabs visible if there is an error (so user can switch and see the message).
            if errorMessage(for: source) != nil { return true }
            // Hide tabs with no results (prevents showing "Nic nie znaleziono" tabs in navigation).
            return resultsCount(for: source) > 0
        }
    }

    @ViewBuilder
    private var resultsTabContent: some View {
        switch selectedResultsTab {
        case .actsPL:
            resultsContainer(
                isMuted: !enabledSources.contains(.actsPL),
                isLoading: actsPLIsLoading,
                errorMessage: actsPLError
            ) {
                ResultsDUMP_View(
                    searchResults: actsPLResults,
                    isLoadingMore: actsPLIsLoadingMore,
                    hasMoreResults: actsPLHasMore,
                    onLoadMore: loadMoreActsPL
                )
            }

        case .actsEU:
            resultsContainer(
                isMuted: !enabledSources.contains(.actsEU),
                isLoading: actsEUIsLoading,
                errorMessage: actsEUError
            ) {
                ResultsEU_View(
                    searchResults: actsEUResults,
                    isLoadingMore: actsEUIsLoadingMore,
                    hasMoreResults: actsEUHasMore,
                    onLoadMore: loadMoreActsEU,
                    selectedLanguage: actsEUSelectedLanguage
                )
            }

        case .courtPL:
            resultsContainer(
                isMuted: !enabledSources.contains(.courtPL),
                isLoading: courtPLIsLoading,
                errorMessage: courtPLError
            ) {
                Results_CourtPL_View(
                    searchResults: courtPLResults,
                    isLoadingMore: courtPLIsLoadingMore,
                    hasMoreResults: courtPLHasMore,
                    onLoadMore: loadMoreCourtPL,
                    searchText: keyword
                )
            }

        case .courtNSA:
            resultsContainer(
                isMuted: !enabledSources.contains(.courtNSA),
                isLoading: courtNSAIsLoading || courtNSAIsLoadingMore,
                errorMessage: courtNSAError
            ) {
                VStack(spacing: 12) {
                    Results_CourtNSA_View(
                        searchResults: courtNSAResults,
                        hasMoreResults: courtNSAHasMore,
                        searchText: keyword
                    )

                    nsaPaginationControls
                }
            }

        case .courtSupreme:
            resultsContainer(
                isMuted: !enabledSources.contains(.courtSupreme),
                isLoading: courtSupremeIsLoading,
                errorMessage: courtSupremeError
            ) {
                Results_CourtSupreme_View(
                    searchResults: courtSupremeResults,
                    isLoadingMore: courtSupremeIsLoadingMore,
                    hasMoreResults: courtSupremeHasMore,
                    onLoadMore: loadMoreCourtSupreme
                )
            }

        case .legisRPL:
            resultsContainer(
                isMuted: !enabledSources.contains(.legisRPL),
                isLoading: rplIsLoading,
                errorMessage: rplError
            ) {
                ResultsRPLView(
                    searchResults: rplResults,
                    isLoadingMore: rplIsLoadingMore,
                    hasMoreResults: rplHasMore,
                    onLoadMore: loadMoreRPL
                )
            }

        case .legisSejm:
            resultsContainer(
                isMuted: !enabledSources.contains(.legisSejm),
                isLoading: legisIsLoading,
                errorMessage: legisError
            ) {
                ResultsLegislacjaView(
                    searchResults: legisResults,
                    isLoadingMore: legisIsLoadingMore,
                    hasMoreResults: legisHasMore,
                    onLoadMore: loadMoreLegisSejm,
                    onELITapped: { _ in }
                )
            }
        }
    }

    // MARK: - UI helpers

    private func sourceToggleChip(_ source: Source) -> some View {
        let isEnabled = enabledSources.contains(source)
        return Button {
            Haptics.impact(.light)
            if isEnabled {
                enabledSources.remove(source)
            } else {
                enabledSources.insert(source)
            }
        } label: {
            Text(source.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            .foregroundStyle(isEnabled ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .background {
                Capsule()
                    .fill(isEnabled ? Color.accentColor : Color(.systemGroupedBackground))
            }
            .overlay {
                Capsule()
                    .stroke(Color(.systemGray4), lineWidth: isEnabled ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(source.title)
        .accessibilityAddTraits(isEnabled ? [.isSelected] : [])
    }

    @ViewBuilder
    private func resultsContainer<Content: View>(
        isMuted: Bool,
        isLoading: Bool,
        errorMessage: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isMuted {
            VStack(spacing: 10) {
                Text("Wyciszone")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Aktywuj to źródło w parametrach i uruchom wyszukiwanie ponownie.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
        } else if let errorMessage {
            Text(errorMessage)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(horizontalSizeClass == .regular ? 20 : 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
        } else if isLoading && !showingResults {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else {
            content()
        }
    }

    private var nsaPaginationControls: some View {
        HStack {
            Button {
                Task { await loadPreviousNSA() }
            } label: {
                HStack {
                    if courtNSAIsLoadingPrevious {
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
            .disabled(courtNSACurrentPage <= 1 || courtNSAIsLoadingMore || courtNSAIsLoading)
            .opacity(courtNSAIsLoadingNext ? 0.5 : 1.0)

            Spacer()

            Text("Strona \(courtNSACurrentPage)")
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                Task { await loadNextNSA() }
            } label: {
                HStack {
                    if courtNSAIsLoadingNext {
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
            .disabled(!courtNSAHasMore || courtNSAIsLoadingMore || courtNSAIsLoading)
            .opacity(courtNSAIsLoadingPrevious ? 0.5 : 1.0)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
        .padding(.vertical, 6)
    }

    // MARK: - Computed helpers

    private var isAnyLoading: Bool {
        actsPLIsLoading
        || actsEUIsLoading
        || courtPLIsLoading
        || courtNSAIsLoading
        || courtSupremeIsLoading
        || rplIsLoading
        || legisIsLoading
        || actsPLIsLoadingMore
        || actsEUIsLoadingMore
        || courtPLIsLoadingMore
        || courtNSAIsLoadingMore
        || courtSupremeIsLoadingMore
        || rplIsLoadingMore
        || legisIsLoadingMore
    }

    private func updateScrollToTopVisibility() {
        normalizeSelectedResultsTab()
        guard showingResults else {
            withAnimation { showScrollToTop = false }
            return
        }
        guard enabledSources.contains(selectedResultsTab) else {
            withAnimation { showScrollToTop = false }
            return
        }

        let count: Int
        let threshold: Int

        switch selectedResultsTab {
        case .actsPL:
            count = actsPLResults.count
            threshold = 5
        case .actsEU:
            count = actsEUResults.count
            threshold = 5
        case .courtPL:
            count = courtPLResults.count
            threshold = 5
        case .courtNSA:
            count = courtNSAResults.count
            threshold = 10
        case .courtSupreme:
            count = courtSupremeResults.count
            threshold = 5
        case .legisRPL:
            count = rplResults.count
            threshold = 10
        case .legisSejm:
            count = legisResults.count
            threshold = 10
        }

        withAnimation {
            showScrollToTop = count > threshold
        }
    }

    private func resetAllResultsAndPaging() {
        // Acts PL
        actsPLResults = []
        actsPLIsLoading = false
        actsPLIsLoadingMore = false
        actsPLHasMore = true
        actsPLOffset = 0
        actsPLError = nil

        // Acts EU
        actsEUResults = []
        actsEUIsLoading = false
        actsEUIsLoadingMore = false
        actsEUHasMore = true
        actsEUOffset = 0
        actsEUError = nil

        // Court PL
        courtPLResults = []
        courtPLIsLoading = false
        courtPLIsLoadingMore = false
        courtPLHasMore = true
        courtPLOffset = 0
        courtPLError = nil

        // NSA
        courtNSAResults = []
        courtNSAIsLoading = false
        courtNSAIsLoadingMore = false
        courtNSAIsLoadingNext = false
        courtNSAIsLoadingPrevious = false
        courtNSAHasMore = true
        courtNSACurrentPage = 1
        courtNSAError = nil

        // Supreme
        courtSupremeResults = []
        courtSupremeIsLoading = false
        courtSupremeIsLoadingMore = false
        courtSupremeHasMore = true
        courtSupremeOffset = 0
        courtSupremeError = nil

        // RPL
        rplResults = []
        rplIsLoading = false
        rplIsLoadingMore = false
        rplHasMore = true
        rplCurrentPage = 1
        rplTotalPages = nil
        rplError = nil

        // Sejm
        legisResults = []
        legisIsLoading = false
        legisIsLoadingMore = false
        legisHasMore = true
        legisOffset = 0
        legisError = nil
    }

    private func normalizeSelectedResultsTab() {
        let visible = visibleResultsTabs
        guard !visible.isEmpty else { return }
        if !visible.contains(selectedResultsTab) {
            selectedResultsTab = visible[0]
        }
    }

    private func resultsCount(for source: Source) -> Int {
        switch source {
        case .actsPL: return actsPLResults.count
        case .actsEU: return actsEUResults.count
        case .courtPL: return courtPLResults.count
        case .courtNSA: return courtNSAResults.count
        case .courtSupreme: return courtSupremeResults.count
        case .legisRPL: return rplResults.count
        case .legisSejm: return legisResults.count
        }
    }

    private func errorMessage(for source: Source) -> String? {
        switch source {
        case .actsPL: return actsPLError
        case .actsEU: return actsEUError
        case .courtPL: return courtPLError
        case .courtNSA: return courtNSAError
        case .courtSupreme: return courtSupremeError
        case .legisRPL: return rplError
        case .legisSejm: return legisError
        }
    }

    private func parsedYear(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4, let year = Int(trimmed), year >= 1900, year <= Calendar.current.component(.year, from: Date()) + 3 else {
            return nil
        }
        return year
    }

    private func yearRangeDates() -> (from: Date?, to: Date?) {
        let calendar = Calendar(identifier: .gregorian)

        let fromYear = parsedYear(yearFrom)
        let toYear = parsedYear(yearTo)

        var fromDate: Date? = nil
        var toDate: Date? = nil

        if let y = fromYear {
            fromDate = calendar.date(from: DateComponents(year: y, month: 1, day: 1))
        }
        if let y = toYear {
            toDate = calendar.date(from: DateComponents(year: y, month: 12, day: 31))
        }

        // If user entered only "to", we still treat it as an upper bound.
        return (fromDate, toDate)
    }

    private func dateString(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func performSearch() {
        showingResults = true
        resetAllResultsAndPaging()

        let enabled = enabledSources
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()

        PostHogSDK.shared.capture("Search Performed", properties: [
            "search_type": "Everywhere",
            "keyword": keyword,
            "enabled_sources": enabled.map(\.rawValue).sorted(),
            "year_from": yearFrom,
            "year_to": yearTo,
            "has_year_filter": fromDate != nil || toDate != nil
        ])

        Task {
            await searchAll(enabled: enabled, keyword: keyword, fromDate: fromDate, toDate: toDate)
        }
    }

    private func searchAll(enabled: Set<Source>, keyword: String, fromDate: Date?, toDate: Date?) async {
        await MainActor.run {
            if enabled.contains(.actsPL) { actsPLIsLoading = true }
            if enabled.contains(.actsEU) { actsEUIsLoading = true }
            if enabled.contains(.courtPL) { courtPLIsLoading = true }
            if enabled.contains(.courtNSA) { courtNSAIsLoading = true }
            if enabled.contains(.courtSupreme) { courtSupremeIsLoading = true }
            if enabled.contains(.legisRPL) { rplIsLoading = true }
            if enabled.contains(.legisSejm) { legisIsLoading = true }
        }

        await withTaskGroup(of: Void.self) { group in
            if enabled.contains(.actsPL) {
                group.addTask { await searchActsPL(keyword: keyword, fromDate: fromDate, toDate: toDate) }
            }
            if enabled.contains(.actsEU) {
                group.addTask { await searchActsEU(keyword: keyword, fromDate: fromDate, toDate: toDate) }
            }
            if enabled.contains(.courtPL) {
                group.addTask { await searchCourtPL(keyword: keyword, fromDate: fromDate, toDate: toDate) }
            }
            if enabled.contains(.courtNSA) {
                group.addTask { await searchNSA(keyword: keyword, fromDate: fromDate, toDate: toDate) }
            }
            if enabled.contains(.courtSupreme) {
                group.addTask { await searchCourtSupreme(keyword: keyword, fromDate: fromDate, toDate: toDate) }
            }
            if enabled.contains(.legisRPL) {
                group.addTask { await searchRPL(keyword: keyword, fromDate: fromDate, toDate: toDate) }
            }
            if enabled.contains(.legisSejm) {
                group.addTask { await searchLegisSejm(keyword: keyword) }
            }
        }
    }

    // MARK: - Acts PL

    private func searchActsPL(keyword: String, fromDate: Date?, toDate: Date?) async {
        let parameters = SearchParameters(
            date: nil,
            dateEffect: nil,
            dateEffectFrom: nil,
            dateEffectTo: nil,
            dateFrom: nil,
            dateTo: nil,
            exile: nil,
            inForce: nil,
            // Same field as "Tytuł" in SearchView (DUMPSearchState.title) — not keyword
            keyword: nil,
            limit: 10,
            offset: 0,
            position: nil,
            pubDate: nil,
            pubDateFrom: dateString(fromDate),
            pubDateTo: dateString(toDate),
            publisher: PublisherOption.du.rawValue,
            sortBy: nil,
            sortDir: nil,
            title: keyword.isEmpty ? nil : keyword,
            type: nil,
            volume: nil,
            year: nil
        )

        do {
            let response = try await APIService.shared.searchActs(parameters: parameters)
            await MainActor.run {
                actsPLResults = response.items
                actsPLHasMore = response.items.count == 10
                actsPLOffset = 0
                actsPLError = nil
                actsPLIsLoading = false
            }
        } catch {
            await MainActor.run {
                actsPLError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
                actsPLResults = []
                actsPLIsLoading = false
            }
        }
    }

    @MainActor
    private func loadMoreActsPL() async {
        guard enabledSources.contains(.actsPL) else { return }
        guard !actsPLIsLoadingMore && actsPLHasMore else { return }

        actsPLIsLoadingMore = true
        actsPLOffset += 10

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()

        let parameters = SearchParameters(
            date: nil,
            dateEffect: nil,
            dateEffectFrom: nil,
            dateEffectTo: nil,
            dateFrom: nil,
            dateTo: nil,
            exile: nil,
            inForce: nil,
            keyword: nil,
            limit: 10,
            offset: actsPLOffset,
            position: nil,
            pubDate: nil,
            pubDateFrom: dateString(fromDate),
            pubDateTo: dateString(toDate),
            publisher: PublisherOption.du.rawValue,
            sortBy: nil,
            sortDir: nil,
            title: keyword.isEmpty ? nil : keyword,
            type: nil,
            volume: nil,
            year: nil
        )

        do {
            let response = try await APIService.shared.searchActs(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.5)) {
                actsPLResults.append(contentsOf: response.items)
            }
            actsPLHasMore = response.items.count == 10
        } catch {
            actsPLOffset -= 10
            actsPLError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        actsPLIsLoadingMore = false
    }

    // MARK: - Acts EU

    private func searchActsEU(keyword: String, fromDate: Date?, toDate: Date?) async {
        let parameters = EUSearchParameters(
            query: keyword.isEmpty ? nil : keyword,
            documentType: actsEUSelectedDocumentType,
            language: actsEUSelectedLanguage,
            specificDate: nil,
            dateFrom: dateString(fromDate),
            dateTo: dateString(toDate),
            celexNumber: nil,
            documentYear: nil,
            documentNumber: nil,
            limit: 10,
            offset: 0
        )

        do {
            let documents = try await API_EUService.shared.searchEUDocuments(parameters: parameters)
            await MainActor.run {
                actsEUResults = documents
                actsEUHasMore = documents.count == 10
                actsEUOffset = 0
                actsEUError = nil
                actsEUIsLoading = false
            }
        } catch {
            await MainActor.run {
                actsEUError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
                actsEUResults = []
                actsEUIsLoading = false
            }
        }
    }

    @MainActor
    private func loadMoreActsEU() async {
        guard enabledSources.contains(.actsEU) else { return }
        guard !actsEUIsLoadingMore && actsEUHasMore else { return }

        actsEUIsLoadingMore = true
        actsEUOffset += 10

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()

        let parameters = EUSearchParameters(
            query: keyword.isEmpty ? nil : keyword,
            documentType: actsEUSelectedDocumentType,
            language: actsEUSelectedLanguage,
            specificDate: nil,
            dateFrom: dateString(fromDate),
            dateTo: dateString(toDate),
            celexNumber: nil,
            documentYear: nil,
            documentNumber: nil,
            limit: 10,
            offset: actsEUOffset
        )

        do {
            let documents = try await API_EUService.shared.searchEUDocuments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.5)) {
                actsEUResults.append(contentsOf: documents)
            }
            actsEUHasMore = documents.count == 10
        } catch {
            actsEUOffset -= 10
            actsEUError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        actsEUIsLoadingMore = false
    }

    // MARK: - Court PL

    private func searchCourtPL(keyword: String, fromDate: Date?, toDate: Date?) async {
        let parameters = CourtSearchParameters(
            search: keyword.isEmpty ? nil : keyword,
            caseNumber: nil,
            judgmentDateFrom: dateString(fromDate),
            judgmentDateTo: dateString(toDate),
            courtType: nil,
            judgmentType: nil,
            sortField: "JUDGMENT_DATE",
            sortDirection: "DESC",
            ccCourtName: nil,
            ccDivisionName: nil,
            ccCourtCode: nil,
            ccCourtId: nil,
            ccDivisionId: nil,
            scChamberName: nil,
            scDivisionName: nil,
            judgeName: nil,
            legalBase: nil,
            referencedRegulation: nil,
            lawJournalEntryCode: nil,
            limit: 10,
            offset: 0
        )

        do {
            let judgments = try await API_CourtPLService.shared.searchCourtJudgments(parameters: parameters)
            await MainActor.run {
                courtPLResults = judgments
                courtPLHasMore = judgments.count == 10
                courtPLOffset = 0
                courtPLError = nil
                courtPLIsLoading = false
            }
        } catch {
            await MainActor.run {
                courtPLError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
                courtPLResults = []
                courtPLIsLoading = false
            }
        }
    }

    @MainActor
    private func loadMoreCourtPL() async {
        guard enabledSources.contains(.courtPL) else { return }
        guard !courtPLIsLoadingMore && courtPLHasMore else { return }

        courtPLIsLoadingMore = true
        courtPLOffset += 10

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()

        let parameters = CourtSearchParameters(
            search: keyword.isEmpty ? nil : keyword,
            caseNumber: nil,
            judgmentDateFrom: dateString(fromDate),
            judgmentDateTo: dateString(toDate),
            courtType: nil,
            judgmentType: nil,
            sortField: "JUDGMENT_DATE",
            sortDirection: "DESC",
            ccCourtName: nil,
            ccDivisionName: nil,
            ccCourtCode: nil,
            ccCourtId: nil,
            ccDivisionId: nil,
            scChamberName: nil,
            scDivisionName: nil,
            judgeName: nil,
            legalBase: nil,
            referencedRegulation: nil,
            lawJournalEntryCode: nil,
            limit: 10,
            offset: courtPLOffset
        )

        do {
            let judgments = try await API_CourtPLService.shared.searchCourtJudgments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.5)) {
                courtPLResults.append(contentsOf: judgments)
            }
            courtPLHasMore = judgments.count == 10
        } catch {
            courtPLOffset -= 10
            courtPLError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        courtPLIsLoadingMore = false
    }

    // MARK: - Court NSA

    private func buildNSAParameters(keyword: String, fromDate: Date?, toDate: Date?, page: Int) -> NSASearchParameters {
        NSASearchParameters(
            wszystkieSlowa: keyword.isEmpty ? nil : keyword,
            wystepowanie: "gdziekolwiek",
            odmiana: true,
            sygnatura: nil,
            sad: NSACourtType.dowolny.formValue,
            rodzaj: NSAJudgmentType.dowolny.formValue,
            symbole: nil,
            odDaty: dateString(fromDate),
            doDaty: dateString(toDate),
            sedziowie: nil,
            funkcja: NSAJudgeFunction.dowolna.formValue,
            rodzaj_organu: nil,
            hasla: nil,
            akty: nil,
            przepisy: nil,
            publikacje: nil,
            glosy: nil,
            offset: page,
            pageSize: courtNSAPageSize
        )
    }

    private func searchNSA(keyword: String, fromDate: Date?, toDate: Date?) async {
        let parameters = buildNSAParameters(keyword: keyword, fromDate: fromDate, toDate: toDate, page: 1)

        do {
            let result = try await API_NSAService.shared.searchJudgments(parameters: parameters)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) {
                    courtNSAResults = result.judgments
                }
                courtNSACurrentPage = 1
                courtNSAHasMore = result.hasNextPage
                courtNSAError = nil
                courtNSAIsLoading = false
            }
        } catch {
            await MainActor.run {
                courtNSAError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
                courtNSAResults = []
                courtNSAIsLoading = false
            }
        }
    }

    @MainActor
    private func loadNextNSA() async {
        guard enabledSources.contains(.courtNSA) else { return }
        guard !courtNSAIsLoading && !courtNSAIsLoadingMore && courtNSAHasMore else { return }

        courtNSAIsLoadingMore = true
        courtNSAIsLoadingNext = true

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()
        let nextPage = courtNSACurrentPage + 1
        let parameters = buildNSAParameters(keyword: keyword, fromDate: fromDate, toDate: toDate, page: nextPage)

        do {
            let result = try await API_NSAService.shared.searchJudgments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.6)) {
                courtNSAResults = result.judgments
            }
            courtNSACurrentPage = nextPage
            courtNSAHasMore = result.hasNextPage
            courtNSAError = nil
        } catch {
            courtNSAError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        courtNSAIsLoadingMore = false
        courtNSAIsLoadingNext = false
    }

    @MainActor
    private func loadPreviousNSA() async {
        guard enabledSources.contains(.courtNSA) else { return }
        guard !courtNSAIsLoading && !courtNSAIsLoadingMore && courtNSACurrentPage > 1 else { return }

        courtNSAIsLoadingMore = true
        courtNSAIsLoadingPrevious = true

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()
        let previousPage = max(1, courtNSACurrentPage - 1)
        let parameters = buildNSAParameters(keyword: keyword, fromDate: fromDate, toDate: toDate, page: previousPage)

        do {
            let result = try await API_NSAService.shared.searchJudgments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.6)) {
                courtNSAResults = result.judgments
            }
            courtNSACurrentPage = previousPage
            courtNSAHasMore = result.hasNextPage
            courtNSAError = nil
        } catch {
            courtNSAError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        courtNSAIsLoadingMore = false
        courtNSAIsLoadingPrevious = false
    }

    // MARK: - Court Supreme

    private func buildSupremeParameters(keyword: String, fromDate: Date?, toDate: Date?, offset: Int) -> SupremeCourtSearchParameters {
        SupremeCourtSearchParameters(
            trescOrzeczenia: keyword.isEmpty ? nil : keyword,
            sygnatura: nil,
            formaOrzeczenia: nil,
            izba: nil,
            sedziaWSkladzie: nil,
            dataOd: dateString(fromDate),
            dataDo: dateString(toDate),
            offset: offset,
            pageSize: 10
        )
    }

    private func searchCourtSupreme(keyword: String, fromDate: Date?, toDate: Date?) async {
        let parameters = buildSupremeParameters(keyword: keyword, fromDate: fromDate, toDate: toDate, offset: 0)

        do {
            let result = try await API_SupremeService.shared.searchJudgments(parameters: parameters)
            await MainActor.run {
                courtSupremeResults = result.judgments
                courtSupremeHasMore = result.hasNextPage
                courtSupremeOffset = 0
                courtSupremeError = nil
                courtSupremeIsLoading = false
            }
        } catch {
            await MainActor.run {
                courtSupremeError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
                courtSupremeResults = []
                courtSupremeIsLoading = false
            }
        }
    }

    @MainActor
    private func loadMoreCourtSupreme() async {
        guard enabledSources.contains(.courtSupreme) else { return }
        guard !courtSupremeIsLoadingMore && courtSupremeHasMore else { return }

        courtSupremeIsLoadingMore = true
        courtSupremeOffset += 10

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()
        let parameters = buildSupremeParameters(keyword: keyword, fromDate: fromDate, toDate: toDate, offset: courtSupremeOffset)

        do {
            let result = try await API_SupremeService.shared.searchJudgments(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.5)) {
                courtSupremeResults.append(contentsOf: result.judgments)
            }
            courtSupremeHasMore = result.hasNextPage
        } catch {
            courtSupremeOffset -= 10
            courtSupremeError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        courtSupremeIsLoadingMore = false
    }

    // MARK: - RPL

    private func buildRPLParameters(keyword: String, fromDate: Date?, toDate: Date?, page: Int) -> RPLSearchParameters {
        var parameters = RPLSearchParameters()
        parameters.title = keyword
        parameters.createdFrom = fromDate
        parameters.createdTo = toDate
        parameters.page = page
        parameters.sortKey = .createdDate
        parameters.sortDirection = .descending
        return parameters
    }

    private func searchRPL(keyword: String, fromDate: Date?, toDate: Date?) async {
        let parameters = buildRPLParameters(keyword: keyword, fromDate: fromDate, toDate: toDate, page: 1)
        do {
            let response = try await APIService_RPL.shared.searchProjects(parameters: parameters)
            await MainActor.run {
                rplResults = response.projects
                rplCurrentPage = 1
                rplTotalPages = response.totalPages
                rplHasMore = response.hasMore
                rplError = nil
                rplIsLoading = false
            }
        } catch {
            await MainActor.run {
                rplError = "Serwis legislacja.gov.pl jest chwilowo niedostępny. Spróbuj ponownie później."
                rplResults = []
                rplIsLoading = false
            }
        }
    }

    @MainActor
    private func loadMoreRPL() async {
        guard enabledSources.contains(.legisRPL) else { return }
        guard !rplIsLoadingMore && rplHasMore else { return }

        rplIsLoadingMore = true
        let nextPage = rplCurrentPage + 1

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let (fromDate, toDate) = yearRangeDates()
        let parameters = buildRPLParameters(keyword: keyword, fromDate: fromDate, toDate: toDate, page: nextPage)

        do {
            let response = try await APIService_RPL.shared.searchProjects(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.5)) {
                rplResults.append(contentsOf: response.projects)
            }
            rplCurrentPage = nextPage
            rplTotalPages = response.totalPages
            rplHasMore = response.hasMore
        } catch {
            rplError = "Serwis legislacja.gov.pl jest chwilowo niedostępny. Spróbuj ponownie później."
        }

        rplIsLoadingMore = false
    }

    // MARK: - Legislacja Sejm

    private func buildLegisParameters(keyword: String, offset: Int) -> LegislacjaSearchParameters {
        LegislacjaSearchParameters(
            title: keyword.isEmpty ? nil : keyword,
            number: nil,
            dateFrom: nil,
            dateTo: nil,
            passed: nil,
            offset: offset,
            limit: 10,
            sort_by: nil
        )
    }

    private func searchLegisSejm(keyword: String) async {
        let parameters = buildLegisParameters(keyword: keyword, offset: 0)

        do {
            let response = try await APIService_Legis.shared.searchProcesses(parameters: parameters)
            await MainActor.run {
                legisResults = response
                legisHasMore = response.count == 10
                legisOffset = 0
                legisError = nil
                legisIsLoading = false
            }
        } catch {
            await MainActor.run {
                legisError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
                legisResults = []
                legisIsLoading = false
            }
        }
    }

    @MainActor
    private func loadMoreLegisSejm() async {
        guard enabledSources.contains(.legisSejm) else { return }
        guard !legisIsLoadingMore && legisHasMore else { return }

        legisIsLoadingMore = true
        legisOffset += 10

        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let parameters = buildLegisParameters(keyword: keyword, offset: legisOffset)

        do {
            let response = try await APIService_Legis.shared.searchProcesses(parameters: parameters)
            withAnimation(.easeInOut(duration: 0.5)) {
                legisResults.append(contentsOf: response)
            }
            legisHasMore = response.count == 10
        } catch {
            legisOffset -= 10
            legisError = "Serwis jest obecnie niedostępny. Spróbuj ponownie później."
        }

        legisIsLoadingMore = false
    }
}

#if DEBUG
#Preview {
    EverywhereSearchView()
}
#endif

