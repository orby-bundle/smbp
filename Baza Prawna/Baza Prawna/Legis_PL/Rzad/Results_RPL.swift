import SwiftUI

struct ResultsRPLView: View {
    let searchResults: [RPLProject]
    let isLoadingMore: Bool
    let hasMoreResults: Bool
    let onLoadMore: () async -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
            Text("Wyniki wyszukiwania")
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)

            if searchResults.isEmpty {
                NoSearchResultsMessage()
            } else {
                resultsGrid

                if isLoadingMore {
                    loadingFooter
                }

                if !hasMoreResults && !searchResults.isEmpty {
                    endOfListFooter
                }
            }
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
    }

    @ViewBuilder
    private var resultsGrid: some View {
        if horizontalSizeClass == .regular {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(searchResults) { project in
                    RPLProjectRowView(project: project)
                        .onAppear {
                            triggerPaginationIfNeeded(current: project)
                        }
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(searchResults) { project in
                    RPLProjectRowView(project: project)
                        .onAppear {
                            triggerPaginationIfNeeded(current: project)
                        }
                }
            }
        }
    }

    private func triggerPaginationIfNeeded(current project: RPLProject) {
        guard project.id == searchResults.last?.id, hasMoreResults, !isLoadingMore else { return }
        Task { await onLoadMore() }
    }

    private var loadingFooter: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(horizontalSizeClass == .regular ? 1.0 : 0.8)
            Text("Ładuję jeszcze...")
                .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .transition(.opacity.combined(with: .scale))
    }

    private var endOfListFooter: some View {
        HStack {
            Spacer()
            Text("Koniec listy")
                .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
        .transition(.opacity)
    }
}

// MARK: - Project Row

private struct RPLProjectRowView: View {
    let project: RPLProject
    @State private var showDetailSafari = false
    @State private var showStageSafari = false
    @State private var stageInfo: RPLStageInfo?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            headerSection
            applicantSection
            numberSection
            stageSection
        }
        .frame(maxWidth: .infinity)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
        .shadow(color: .black.opacity(0.08), radius: horizontalSizeClass == .regular ? 3 : 2, x: 0, y: 1)
        .sheet(isPresented: $showDetailSafari) {
            if let url = project.detailURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showStageSafari) {
            if let url = stageInfo?.url {
                SafariView(url: url)
            }
        }
        .task {
            await loadStageInfo()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(project.title)
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if project.detailURL != nil {
                Button(action: { showDetailSafari = true }) {
                    Image(systemName: "arrow.right.circle")
                        .font(horizontalSizeClass == .regular ? .title : .title)
                        .foregroundColor(.blue)
                        .frame(alignment: .center)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Otwórz projekt w legislacja.gov.pl")
            }
        }
    }

    private var applicantSection: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "tray")
                .foregroundColor(.secondary)
            Text(project.applicantName)
                .font(horizontalSizeClass == .regular ? .subheadline : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var stageSection: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("Etap")
                .font(horizontalSizeClass == .regular ? .subheadline : .subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            if let stageInfo {
                Button(action: { showStageSafari = true }) {
                    HStack(spacing: 6) {
                        Text(stageInfo.title)
                            .font(horizontalSizeClass == .regular ? .subheadline : .subheadline)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.right")
                            .font(horizontalSizeClass == .regular ? .caption : .caption)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(horizontalSizeClass == .regular ? 0.8 : 0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func loadStageInfo() async {
        guard stageInfo == nil else { return }
        guard let info = try? await APIService_RPL.shared.fetchLatestStage(projectId: project.id) else { return }
        await MainActor.run {
            stageInfo = info
        }
    }
}

private extension RPLProjectRowView {
    @ViewBuilder
    var numberSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !project.legislativeNumber.isEmpty {
                Text("Numer: \(project.legislativeNumber)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.secondary)
            }

            if !project.createdDateText.isEmpty {
                Text("Utworzony: \(project.createdDateText)")
                    .font(horizontalSizeClass == .regular ? .caption : .caption)
                    .foregroundColor(.secondary)
            }

            if !project.updatedDateText.isEmpty {
                Text("Zmodyfikowany: \(project.updatedDateText)")
                    .font(horizontalSizeClass == .regular ? .caption : .caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    let sampleProject = RPLProject(
        id: "12403952",
        title: "Projekt rozporządzenia Ministra Zdrowia w sprawie potwierdzania kwalifikacji",
        detailURL: URL(string: "https://legislacja.gov.pl/projekt/12403952"),
        applicantId: "1",
        applicantName: "Minister Zdrowia",
        applicantURL: URL(string: "https://legislacja.gov.pl/lista?applicantId=1"),
        legislativeNumber: "MZDER1815",
        externalURL: URL(string: "https://www.gov.pl/web/zdrowie/program-prac-legislacyjnych"),
        createdDateText: "05-11-2025",
        updatedDateText: "05-11-2025"
    )

    return NavigationStack {
        ScrollView {
            ResultsRPLView(
                searchResults: [sampleProject, sampleProject],
                isLoadingMore: false,
                hasMoreResults: false,
                onLoadMore: {}
            )
        }
        .padding()
    }
}
#endif

