import SwiftUI
import PostHog

// MARK: - Search State

struct RPLSearchState {
    var title: String = ""
    var number: String = ""
    var createdFrom: Date?
    var createdTo: Date?
    var selectedType: RPLProjectType? = nil
    var progress: RPLProgressFilter = .inProgress
    var selectedApplicantId: String = ""
    var flags = RPLSearchFlags()
}

struct SearchRPLView: View, SearchResettable {
    @StateObject private var apiService = APIService_RPL.shared
    @State private var state = RPLSearchState()

    @State private var availableApplicants: [RPLApplicant] = [RPLApplicant(id: "", name: "dowolny", isActive: true)]

    // Pagination state
    @State private var currentPage: Int = 1
    @State private var totalPages: Int?
    @State private var hasMoreResults = true
    @State private var isLoadingMore = false

    // Results state
    @State private var searchResults: [RPLProject] = []
    @State private var isLoading = false
    @State private var showingResults = false
    @State private var errorMessage: String?
    @State private var showScrollToTop = false
    @State private var showingAdditionalFilters = false
    @State private var hasLoadedInitialApplicants = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func resetSearchFields() {
        state = RPLSearchState()
        currentPage = 1
        totalPages = nil
        hasMoreResults = true
        isLoadingMore = false
        searchResults = []
        isLoading = false
        showingResults = false
        errorMessage = nil
        showScrollToTop = false
        availableApplicants = [RPLApplicant(id: "", name: "dowolny", isActive: true)]
        hasLoadedInitialApplicants = false
        
        // Reload applicants after reset, similar to initial load
        Task {
            await loadInitialApplicantsIfNeeded()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                        Color.clear.frame(height: 0).id("top")

                        quickFiltersSection
                        dateSection
                        flagsSection

                        UIManager.searchClearAndAlertButtonRow(
                            for: self,
                            searchTitle: "Szukaj",
                            isLoading: isLoading,
                            searchAction: performSearch,
                            alertAction: saveAlertForRPL,
                            hideResultsOnTap: true,
                            showingResults: $showingResults,
                            searchPremiumCheck: nil,
                            alertPremiumCheck: { PaywallManager.shared.checkPremiumAccess() }
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding(horizontalSizeClass == .regular ? 20 : 16)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
                        }

                        if showingResults {
                            ResultsRPLView(
                                searchResults: searchResults,
                                isLoadingMore: isLoadingMore,
                                hasMoreResults: hasMoreResults,
                                onLoadMore: loadMoreResults
                            )
                            .id("searchResults")
                            .onAppear {
                                withAnimation {
                                    showScrollToTop = searchResults.count > 10
                                }
                            }
                            .onChange(of: searchResults.count) { _, newValue in
                                withAnimation {
                                    showScrollToTop = newValue > 10
                                }
                            }
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 24 : 16)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .navigationTitle("Proces legislacyjny")
                .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .large)
                .task {
                    await loadInitialApplicantsIfNeeded()
                }
                .onChange(of: showingResults) { _, newValue in
                    guard newValue else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            proxy.scrollTo("searchResults", anchor: .top)
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

    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
            VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 14 : 12) {
                Text("Wnioskodawca")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                SearchablePicker(
                    selection: $state.selectedApplicantId,
                    options: availableApplicants,
                    placeholder: "dowolny",
                    searchPlaceholder: "Wprowadź nazwę"
                )
            }

            HStack(spacing: horizontalSizeClass == .regular ? 12 : 10) {
                Text("Rodzaj projektu")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Rodzaj projektu", selection: Binding(get: { state.selectedType }, set: { state.selectedType = $0 })) {
                    Text("dowolny").tag(RPLProjectType?.none)
                    ForEach(RPLProjectType.allCases) { type in
                        Text(type.displayName).tag(Optional(type))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: horizontalSizeClass == .regular ? 240 : 180, alignment: .trailing)
            }

            VStack(spacing: horizontalSizeClass == .regular ? 14 : 12) {
                textFieldRow(title: "Tytuł projektu", text: $state.title, placeholder: "lub jego fragment")
                textFieldRow(title: "Numer z wykazu", text: $state.number, placeholder: "np. UD321")
            }

            HStack(spacing: horizontalSizeClass == .regular ? 12 : 10) {
                Text("Status")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Status", selection: $state.progress) {
                    ForEach(RPLProgressFilter.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: horizontalSizeClass == .regular ? 200 : 160, alignment: .trailing)
            }
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 18 : 16) {
            DateRangePickerField(dateFrom: $state.createdFrom, dateTo: $state.createdTo)
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
    }

    private var flagsSection: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 18 : 16) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAdditionalFilters.toggle()
                }
            }) {
                HStack {
                    Text("Filtry dodatkowe")
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: showingAdditionalFilters ? "chevron.up" : "chevron.down")
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if showingAdditionalFilters {
                VStack(spacing: horizontalSizeClass == .regular ? 12 : 10) {
                    RPLFlagToggle(title: "Realizuje prawo UE", systemImage: "globe.europe.africa", isOn: $state.flags.requiresEUImplementation)
                    RPLFlagToggle(title: "Wykonuje orzeczenie TK", systemImage: "building.columns", isOn: $state.flags.requiresConstitutionalTribunal)
                    RPLFlagToggle(title: "Na podstawie założeń projektu", systemImage: "doc.text.magnifyingglass", isOn: $state.flags.requiresBasedOnAssumptions)
                    RPLFlagToggle(title: "Tryb odrębny", systemImage: "exclamationmark.triangle", isOn: $state.flags.requiresSeparateMode)
                    RPLFlagToggle(title: "Ogłoszono w DU", systemImage: "doc.text.fill", isOn: $state.flags.requiresAnnouncedInJournal)
                    RPLFlagToggle(title: "Skierowano do Sejmu", systemImage: "building.2", isOn: $state.flags.requiresSubmittedToSejm)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
    }

    private var primaryTypes: [RPLProjectType] {
        RPLProjectType.allCases
    }

    private func textFieldRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack {
                TextField(placeholder, text: text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                ClearSearchButton(searchText: text, onClear: {})
            }
        }
    }

    private func performSearch() {
        // Track search event
        PostHogSDK.shared.capture("Search Performed", properties: [
            "search_type": "Legislacja Rzad",
            "title": state.title,
            "number": state.number,
            "project_type": 	state.selectedType?.rawValue ?? "Any",
            "applicant": state.selectedApplicantId,
            "progress": state.progress.rawValue,
            "has_date_filter": state.createdFrom != nil
        ])
        
        Task { await searchProjects(resetPagination: true) }
    }

    @MainActor
    private func searchProjects(resetPagination: Bool) async {
        if resetPagination {
            isLoading = true
            errorMessage = nil
            currentPage = 1
            totalPages = nil
            hasMoreResults = true
            searchResults = []
        } else {
            isLoadingMore = true
        }

        let targetPage = resetPagination ? 1 : currentPage + 1
        let parameters = buildParameters(page: targetPage)

        do {
            let response = try await apiService.searchProjects(parameters: parameters)
            if resetPagination {
                searchResults = response.projects
            } else {
                searchResults.append(contentsOf: response.projects)
            }

            currentPage = targetPage
            totalPages = response.totalPages
            hasMoreResults = response.hasMore
            showingResults = true

            if !response.availableApplicants.isEmpty {
                availableApplicants = response.availableApplicants
                if !availableApplicants.contains(where: { $0.id == state.selectedApplicantId }) {
                    state.selectedApplicantId = ""
                }
            }

            if searchResults.isEmpty {
                showScrollToTop = false
            }
        } catch {
            if resetPagination {
                errorMessage = "Serwis legislacja.gov.pl jest chwilowo niedostępny. Spróbuj ponownie później."
                showingResults = false
                searchResults = []
            }
        }

        isLoading = false
        isLoadingMore = false
    }

    private func loadMoreResults() async {
        await searchProjects(resetPagination: false)
    }

    @MainActor
    private func loadInitialApplicantsIfNeeded() async {
        guard !hasLoadedInitialApplicants, availableApplicants.count <= 1 else { return }
        hasLoadedInitialApplicants = true

        do {
            let response = try await apiService.searchProjects(parameters: RPLSearchParameters())
            if !response.availableApplicants.isEmpty {
                availableApplicants = response.availableApplicants
            }
        } catch {
            hasLoadedInitialApplicants = false
        }
    }

    private func saveAlertForRPL(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria = convertStateToCriteria()

        let alert = SavedAlert(
            searchType: .rplProjects,
            title: alertTitle,
            searchCriteria: searchCriteria,
            frequency: frequency
        )

        AlertManager.shared.saveAlert(alert)

        Haptics.impact(.medium)
    }

    private func generateAlertTitle() -> String {
        if !state.title.isEmpty {
            return state.title
        }

        if !state.number.isEmpty {
            return "Projekt \(state.number)"
        }

        if let applicantName = selectedApplicantName {
            return "Procesy – \(applicantName)"
        }

        if let typeName = state.selectedType?.displayName {
            return "Procesy – \(typeName)"
        }

        return "Legislacja - Rząd"
    }

    private func convertStateToCriteria() -> [String: Any] {
        var criteria: [String: Any] = [:]

        if !state.title.isEmpty {
            criteria["title"] = state.title
        }

        if !state.number.isEmpty {
            criteria["number"] = state.number
        }

        if let selectedType = state.selectedType {
            criteria["selectedType"] = selectedType.rawValue
            criteria["selectedTypeName"] = selectedType.displayName
        }

        if state.progress != .inProgress {
            criteria["progress"] = state.progress.rawValue
        }

        if !state.selectedApplicantId.isEmpty {
            criteria["selectedApplicantId"] = state.selectedApplicantId
            if let applicantName = selectedApplicantName {
                criteria["selectedApplicantName"] = applicantName
            }
        }

        if let createdFrom = state.createdFrom {
            criteria["createdFrom"] = createdFrom.timeIntervalSince1970
        }

        if let createdTo = state.createdTo {
            criteria["createdTo"] = createdTo.timeIntervalSince1970
        }

        if state.flags.requiresEUImplementation {
            criteria["requiresEUImplementation"] = true
        }

        if state.flags.requiresConstitutionalTribunal {
            criteria["requiresConstitutionalTribunal"] = true
        }

        if state.flags.requiresBasedOnAssumptions {
            criteria["requiresBasedOnAssumptions"] = true
        }

        if state.flags.requiresSeparateMode {
            criteria["requiresSeparateMode"] = true
        }

        if state.flags.requiresAnnouncedInJournal {
            criteria["requiresAnnouncedInJournal"] = true
        }

        if state.flags.requiresSubmittedToSejm {
            criteria["requiresSubmittedToSejm"] = true
        }

        return criteria
    }

    private var selectedApplicantName: String? {
        guard !state.selectedApplicantId.isEmpty else { return nil }
        return availableApplicants.first(where: { $0.id == state.selectedApplicantId })?.name
    }

    private func buildParameters(page: Int) -> RPLSearchParameters {
        var parameters = RPLSearchParameters()
        parameters.typeIdentifiers = state.selectedType.map { [$0] } ?? []
        parameters.title = state.title
        parameters.legislativeNumber = state.number
        parameters.createdFrom = state.createdFrom
        parameters.createdTo = state.createdTo
        parameters.progress = state.progress
        parameters.applicantId = state.selectedApplicantId.isEmpty ? nil : state.selectedApplicantId
        parameters.flags = state.flags
        parameters.page = page
        parameters.sortKey = .createdDate
        parameters.sortDirection = .descending
        return parameters
    }
}

// MARK: - Flag Toggle

private struct RPLFlagToggle: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
    }
}

#if DEBUG
#Preview {
    SearchRPLView()
}
#endif

