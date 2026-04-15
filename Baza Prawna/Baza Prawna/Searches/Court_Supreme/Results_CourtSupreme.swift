//
//  Results_CourtSupreme_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import SafariServices

struct Results_CourtSupreme_View: View {
    let searchResults: [SupremeCourtJudgment]
    let isLoadingMore: Bool
    let hasMoreResults: Bool
    let onLoadMore: () async -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
            Text("Wyniki wyszukiwania")
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
            
            if searchResults.isEmpty {
                NoSearchResultsMessage()
            } else {
                if horizontalSizeClass == .regular {
                    // iPad: 2-column grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(searchResults) { judgment in
                            SupremeCourtJudgmentRowView(judgment: judgment)
                                .onAppear {
                                    if judgment.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
                                        Task { await onLoadMore() }
                                    }
                                }
                        }
                    }
                } else {
                    // iPhone: full-width stack to avoid narrow single tiles
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { judgment in
                            SupremeCourtJudgmentRowView(judgment: judgment)
                                .onAppear {
                                    if judgment.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
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
    }
}

// MARK: - Supreme Court Judgment Row View
struct SupremeCourtJudgmentRowView: View {
    let judgment: SupremeCourtJudgment
    @State private var showingSafari = false
    @State private var isLoadingHTML = false
    @State private var htmlError: String?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            // Case signature as headline
            Text(judgment.signature)
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Decision type
            Text(judgment.decisionTypeDisplayName)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.secondary)
            
            // Date in separate row
            Text(judgment.date)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.secondary)
            
            // PDF preview + PDF • Czytaj (same pattern as Results_DUMP)
            VStack(spacing: 0) {
                NavigationLink(destination: SupremeCourtJudgmentPDFView(judgment: judgment)) {
                    PDFPreviewTile(cacheKey: "supreme_\(judgment.fullURL)", openText: "") {
                        try await SupremeCourtJudgmentPDFView.buildPDFData(for: judgment)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                HStack(spacing: 12) {
                    Spacer()

                    NavigationLink(destination: SupremeCourtJudgmentPDFView(judgment: judgment)) {
                        ResultFormatChipLabel(title: ".pdf")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("|")
                        .foregroundColor(.secondary)

                    Button(action: {
                        Task {
                            await loadHTMLContent()
                        }
                    }) {
                        ResultFormatChipReadActionLabel(isLoading: isLoadingHTML, title: "Czytaj >>")
                    }
                    .disabled(isLoadingHTML)
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 12)
                .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
        .shadow(color: .black.opacity(0.08), radius: horizontalSizeClass == .regular ? 3 : 2, x: 0, y: 1)
        .fullScreenCover(isPresented: $showingSafari) {
            if let htmlURL = htmlURL {
                SafariView(url: htmlURL)
            } else if let error = htmlError {
                VStack {
                    Text("Błąd ładowania")
                        .font(.headline)
                        .padding()
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Button("Zamknij") {
                        showingSafari = false
                    }
                    .padding()
                }
            }
        }
    }
    
    @State private var htmlURL: URL?
    
    @MainActor
    private func loadHTMLContent() async {
        isLoadingHTML = true
        htmlError = nil
        htmlURL = nil
        
        do {
            // First, fetch the search result page to get the HTML link
            let searchPageURL = URL(string: judgment.fullURL)!
            let (data, _) = try await URLSession.shared.data(from: searchPageURL)
            let htmlString = String(data: data, encoding: .utf8) ?? ""
            
            // Parse the HTML to find the link to the detailed judgment
            if let htmlLink = extractHTMLLink(from: htmlString) {
                htmlURL = URL(string: htmlLink)
                showingSafari = true
            } else {
                htmlError = "Nie znaleziono linku do treści orzeczenia"
                showingSafari = true
            }
        } catch {
            htmlError = error.localizedDescription
            showingSafari = true
        }
        
        isLoadingHTML = false
    }
    
    private func extractHTMLLink(from html: String) -> String? {
        // Look for links that point to the HTML content
        // Pattern: href="/sites/orzecznictwo/OrzeczeniaHTML/..."
        let patterns = [
            #"href="([^"]*sites/orzecznictwo/OrzeczeniaHTML/[^"]*\.html[^"]*)"#,
            #"href='([^']*sites/orzecznictwo/OrzeczeniaHTML/[^']*\.html[^']*)'"#,
            #"href="([^"]*OrzeczeniaHTML/[^"]*\.html[^"]*)"#,
            #"href='([^']*OrzeczeniaHTML/[^']*\.html[^']*)'"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let linkRange = Range(match.range(at: 1), in: html) {
                    var link = String(html[linkRange])
                    
                    // Convert relative URLs to absolute URLs
                    if link.hasPrefix("/") {
                        link = "https://www.sn.pl" + link
                    } else if !link.hasPrefix("http") {
                        link = "https://www.sn.pl/" + link
                    }
                    
                    return link
                }
            }
        }
        
        return nil
    }
    
}

// MARK: - Supreme Court Judgment PDF View
struct SupremeCourtJudgmentPDFView: View {
    let judgment: SupremeCourtJudgment
    @State private var pdfData: Data?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(horizontalSizeClass == .regular ? 1.4 : 1.2)
                    Text("Ładowanie PDF...")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, horizontalSizeClass == .regular ? 12 : 8)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: horizontalSizeClass == .regular ? 56 : 48))
                        .foregroundColor(.orange)
                    
                    Text("Błąd ładowania PDF")
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .foregroundColor(.primary)
                    
                    Text(errorMessage)
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                }
                .padding(horizontalSizeClass == .regular ? 24 : 16)
            } else if let pdfData = pdfData {
                UnifiedPDFViewer(
                    title: judgment.signature,
                    pdfDataProvider: { pdfData }
                )
            }
        }
        .navigationTitle(judgment.signature)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPDF()
        }
    }
    
    @MainActor
    private func loadPDF() async {
        isLoading = true
        errorMessage = nil
        
        do {
            self.pdfData = try await Self.buildPDFData(for: judgment)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    static func buildPDFData(for judgment: SupremeCourtJudgment) async throws -> Data {
        // First, fetch the search result page to get the PDF link
        let searchPageURL = URL(string: judgment.fullURL)!
        let (data, _) = try await URLSession.shared.data(from: searchPageURL)
        let htmlString = String(data: data, encoding: .utf8) ?? ""

        // Parse the HTML to find the link to the PDF
        guard let pdfLink = extractPDFLink(from: htmlString) else {
            throw NSError(
                domain: "SupremeCourtJudgmentPDFView",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Nie znaleziono linku do pliku PDF"]
            )
        }
        guard let pdfURL = URL(string: pdfLink) else {
            throw URLError(.badURL)
        }

        let (pdfData, _) = try await URLSession.shared.data(from: pdfURL)
        return pdfData
    }

    private static func extractPDFLink(from html: String) -> String? {
        // Look for links that point to the PDF content
        // Pattern: href="/sites/orzecznictwo/Orzeczenia3/..."
        let patterns = [
            #"href="([^"]*sites/orzecznictwo/Orzeczenia3/[^"]*\.pdf[^"]*)"#,
            #"href='([^']*sites/orzecznictwo/Orzeczenia3/[^']*\.pdf[^']*)'"#,
            #"href="([^"]*Orzeczenia3/[^"]*\.pdf[^"]*)"#,
            #"href='([^']*Orzeczenia3/[^']*\.pdf[^']*)'"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let linkRange = Range(match.range(at: 1), in: html) {
                    var link = String(html[linkRange])
                    
                    // Convert relative URLs to absolute URLs
                    if link.hasPrefix("/") {
                        link = "https://www.sn.pl" + link
                    } else if !link.hasPrefix("http") {
                        link = "https://www.sn.pl/" + link
                    }
                    
                    return link
                }
            }
        }
        
        return nil
    }
}

#Preview {
    Results_CourtSupreme_View(
        searchResults: [],
        isLoadingMore: false,
        hasMoreResults: true,
        onLoadMore: {}
    )
}