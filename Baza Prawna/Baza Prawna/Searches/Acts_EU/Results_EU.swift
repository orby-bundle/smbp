//
//  ResultsEU_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import SafariServices
#if canImport(Translation)
import Translation
#endif

struct ResultsEU_View: View {
    let searchResults: [EUDocument]
    let isLoadingMore: Bool
    let hasMoreResults: Bool
    let onLoadMore: () async -> Void
    let selectedLanguage: EULanguage
    @State private var summaryAvailability: SummaryAvailability = .available
    @State private var translationReadiness: TranslationReadiness = .unknown
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
            Text("Wyniki wyszukiwania")
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
            
            // Display warning messages at the top
            if !searchResults.isEmpty {
                topLevelGuidanceMessages
            }
            
            if searchResults.isEmpty {
                NoSearchResultsMessage()
            } else {
                if horizontalSizeClass == .regular {
                    // iPad: 2-column grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(searchResults) { document in
                            EUDocumentRowView(document: document, selectedLanguage: selectedLanguage)
                                .onAppear {
                                    if document.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
                                        Task { await onLoadMore() }
                                    }
                                }
                        }
                    }
                } else {
                    // iPhone: full-width stack to avoid narrow single tiles
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { document in
                            EUDocumentRowView(document: document, selectedLanguage: selectedLanguage)
                                .onAppear {
                                    if document.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
                                        Task { await onLoadMore() }
                                    }
                                }
                        }
                    }
                }
                
                // Loading indicator for more results
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(horizontalSizeClass == .regular ? 1.0 : 0.8)
                        Text("Ładowanie kolejnych wyników...")
                            .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(horizontalSizeClass == .regular ? 16 : 12)
                    .transition(.opacity.combined(with: .scale))
                }
                
                // End of results indicator
                if !hasMoreResults && searchResults.count > 0 {
                    HStack {
                        Spacer()
                        Text("Brak kolejnych wyników")
                            .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
        .task {
            await refreshComplianceStates()
        }
    }
    
    @ViewBuilder
    private var topLevelGuidanceMessages: some View {
        VStack(alignment: .leading, spacing: 4) {
            let messages = ComplianceChecks.guidanceMessages(
                for: selectedLanguage,
                summaryAvailability: summaryAvailability,
                translationReadiness: translationReadiness
            )
            ForEach(messages, id: \.self) { guidance in
                TranslationGuidanceBanner(guidance: guidance)
            }
        }
    }
    
    private func refreshComplianceStates() async {
        let states = await ComplianceChecks.complianceStates(for: selectedLanguage)
        await MainActor.run {
            summaryAvailability = states.summary
            translationReadiness = states.translation
        }
    }
}

// MARK: - EU Document Row View
struct EUDocumentRowView: View {
    let document: EUDocument
    let selectedLanguage: EULanguage
    @State private var showingSafari = false
    @State private var showingSummarySheet = false
    @State private var showingTranslationSheet = false
    @State private var summaryText: String = ""
    @State private var summaryError: String?
    @State private var isGeneratingSummary = false
    @State private var summaryAvailability: SummaryAvailability = .available
    @State private var translationReadiness: TranslationReadiness = .unknown
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            Text(document.title)
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let celex = document.celex {
                Text("CELEX: \(celex)")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
                       
            if let publicationDate = document.publicationDate {
                Text("Data publikacji: \(publicationDate)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.secondary)
            }
            
            // PDF preview + PDF • Czytaj (same pattern as Acts PL / Results_DUMP)
            if document.celex != nil {
                VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 8 : 6) {
                    if shouldShowSummaryButton {
                        HStack {
                            Spacer()
                            Button(action: {
                                handleSummaryAction()
                            }) {
                                Text("Skrót")
                                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .underline()
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 12)
                                    .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        NavigationLink(destination: UnifiedPDFViewer(document: document, language: selectedLanguage)) {
                            PDFPreviewTile(cacheKey: "eu_\(document.cellarId)_\(selectedLanguage.rawValue)", openText: "") {
                                try await API_EUService.shared.getEUDocumentPDF(
                                    cellarId: document.cellarId,
                                    language: selectedLanguage,
                                    celex: document.celex
                                )
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        HStack(spacing: 12) {
                            Spacer()

                            NavigationLink(destination: UnifiedPDFViewer(document: document, language: selectedLanguage)) {
                                HStack(spacing: 8) {
                                    Text(".pdf")
                                        .font(.subheadline)
                                        .bold()
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Text("|")
                                .foregroundColor(.secondary)

                            Button(action: {
                                showingSafari = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("Czytaj >>")
                                        .font(.subheadline)
                                        .bold()
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 12)
                        .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
                    }
                }
            }
            
        }
        .frame(maxWidth: .infinity)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
        .shadow(color: .black.opacity(0.08), radius: horizontalSizeClass == .regular ? 3 : 2, x: 0, y: 1)
        .fullScreenCover(isPresented: $showingSafari) {
            if let celex = document.celex {
                SafariView(url: createHTMLURL(celex: celex), entersReaderIfAvailable: false)
            }
        }
        .sheet(isPresented: $showingSummarySheet) {
            SummarySheet(
                summaryText: $summaryText,
                isLoading: $isGeneratingSummary,
                error: $summaryError,
                documentTitle: document.title,
                summaryManager: SummaryManager.shared
            )
        }
        .sheet(isPresented: $showingTranslationSheet) {
            TranslationSheet(
                summaryText: $summaryText,
                isLoading: $isGeneratingSummary,
                error: $summaryError,
                documentTitle: document.title,
                summaryManager: SummaryManager.shared,
                translationManager: TranslationManager.shared
            )
        }
        .task {
            await refreshComplianceStates()
        }
    }
    
    private func createHTMLURL(celex: String) -> URL {
        // Get language code from the document or default to Polish
        let languageCode = getLanguageCode()
        let urlString = "https://eur-lex.europa.eu/legal-content/\(languageCode)/TXT/HTML/?uri=CELEX:\(celex)"
        return URL(string: urlString) ?? URL(string: "https://eur-lex.europa.eu")!
    }
    
    private func getLanguageCode() -> String {
        return selectedLanguage.rawValue.uppercased()
    }
    
    private func handleSummaryAction() {
        if let message = ComplianceChecks.summaryBlockingMessage(for: selectedLanguage, availability: summaryAvailability) {
            summaryError = message
            showingSummarySheet = true
            return
        }
        
        if let message = ComplianceChecks.translationBlockingMessage(for: selectedLanguage, readiness: translationReadiness) {
            summaryError = message
            showingTranslationSheet = true
            return
        }
        
        // Check if CELEX number is available
        guard let celex = document.celex, !celex.isEmpty else {
            summaryError = "Podsumowanie nie jest dostępne dla tego dokumentu."
            showingSummarySheet = true
            return
        }
        
        // Start summarization process
        Task {
            await generateSummary(celex: celex)
        }
    }
    
    @MainActor
    private func generateSummary(celex: String) async {
        // Present the appropriate sheet and set loading before any awaits
        if selectedLanguage == .polish {
            if !showingTranslationSheet { showingTranslationSheet = true }
        } else {
            if !showingSummarySheet { showingSummarySheet = true }
        }
        if summaryText.isEmpty { summaryText = "" }
        summaryError = nil
        isGeneratingSummary = true
        
        do {
            // Fetch HTML content - always fetch English content for summarization
            let apiService = API_EUService.shared
            let htmlContent = try await apiService.getEUDocumentHTML(celex: celex, language: .english)
            let cleanedHTML = StripBoilerplate.cleaned(html: htmlContent)
            
            // Generate summary using SummaryManager
            let summaryManager = SummaryManager.shared
            let englishSummary = try await summaryManager.generateSummary(from: cleanedHTML, documentIdentifier: celex)
            
            if selectedLanguage == .polish {
                if #available(iOS 26.0, *) {
                    let translationManager = TranslationManager.shared
                    // Translate the first batch of the summary
                    let translatedSummary = try await translationManager.translateToPolish(text: englishSummary)
                    summaryText = translatedSummary
                } else {
                    summaryError = TranslationError.notSupported.errorDescription
                    summaryText = ""
                }
            } else {
                summaryText = englishSummary
            }
            isGeneratingSummary = false
        } catch {
            summaryError = error.localizedDescription
            isGeneratingSummary = false
        }
    }
    
    private var shouldShowSummaryButton: Bool {
        ComplianceChecks.canShowSummaryButton(
            for: selectedLanguage,
            summaryAvailability: summaryAvailability,
            translationReadiness: translationReadiness
        )
    }
    
    private func refreshComplianceStates() async {
        let states = await ComplianceChecks.complianceStates(for: selectedLanguage)
        await MainActor.run {
            summaryAvailability = states.summary
            translationReadiness = states.translation
        }
    }
}

#Preview {
    ResultsEU_View(
        searchResults: [],
        isLoadingMore: false,
        hasMoreResults: true,
        onLoadMore: {},
        selectedLanguage: .polish
    )
}
