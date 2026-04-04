//
//  Results_CourtPL_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import SafariServices
import CoreText

struct Results_CourtPL_View: View {
    let searchResults: [CourtJudgment]
    let isLoadingMore: Bool
    let hasMoreResults: Bool
    let onLoadMore: () async -> Void
    let searchText: String
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
                            CourtJudgmentRowView(judgment: judgment, searchText: searchText)
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
                            CourtJudgmentRowView(judgment: judgment, searchText: searchText)
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

// MARK: - Court Judgment Row View
struct CourtJudgmentRowView: View {
    let judgment: CourtJudgment
    let searchText: String
    @State private var showingSafari = false
    @State private var htmlContent: String?
    @State private var isLoadingHTML = false
    @State private var htmlError: String?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            // Case signature as headline
            Text(judgment.caseSignature)
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Court name
            Text(judgment.courtName)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
              // Judgment type
            Text("Typ orzeczenia: \(judgment.judgmentTypeDisplayName)")
                .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                .foregroundColor(.secondary)
            // Judgment date
            Text("Data orzeczenia: \(formatDate(judgment.judgmentDate))")
                .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                .foregroundColor(.secondary)

            
            // Judges list (truncated if too long)
            if !judgment.judgesNames.isEmpty {
                let judgesText = judgment.judgesNames.joined(separator: ", ")
                Text("Sędziowie: \(judgesText)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
                                  
            // Action buttons row
            VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 8 : 6) {
                HStack {
                    Spacer()
                    // Read button
                    Button(action: {
                        Task {
                            await loadHTMLContent()
                        }
                    }) {
                        HStack {
                            if isLoadingHTML {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(horizontalSizeClass == .regular ? 0.8 : 0.7)
                            }
                            Text("Czytaj")
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .underline()
                                .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 12)
                                .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
                        }
                    }
                    .disabled(isLoadingHTML)
                }

                NavigationLink(destination: CourtPLJudgmentPDFView(judgment: judgment)) {
                    PDFPreviewTile(cacheKey: "courtpl_\(judgment.id)") {
                        try await CourtPLJudgmentPDFView.buildPDFData(for: judgment)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
        .shadow(color: .black.opacity(0.08), radius: horizontalSizeClass == .regular ? 3 : 2, x: 0, y: 1)
        .fullScreenCover(isPresented: $showingSafari) {
            if let htmlContent = htmlContent {
                HTMLContentView(htmlContent: htmlContent, isPresented: $showingSafari)
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
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd.MM.yyyy"
        outputFormatter.locale = Locale(identifier: "pl_PL")
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        return dateString
    }
    
    @MainActor
    private func loadHTMLContent() async {
        isLoadingHTML = true
        htmlError = nil
        
        do {
            // Fetch the individual judgment to get full HTML content
            let htmlData = try await API_CourtPLService.shared.getJudgmentHTML(href: judgment.href)
            htmlContent = String(data: htmlData, encoding: .utf8)
            showingSafari = true
        } catch {
            htmlError = error.localizedDescription
            showingSafari = true
        }
        
        isLoadingHTML = false
    }
}

// MARK: - Court PL Judgment PDF View
struct CourtPLJudgmentPDFView: View {
    let judgment: CourtJudgment
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
                    title: judgment.caseSignature,
                    pdfDataProvider: { pdfData }
                )
            }
        }
        .navigationTitle(judgment.caseSignature)
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
    
    static func buildPDFData(for judgment: CourtJudgment) async throws -> Data {
        // Step 1: Get HTML content from the judgment
        let htmlData = try await API_CourtPLService.shared.getJudgmentHTML(href: judgment.href)
        let htmlContent = String(data: htmlData, encoding: .utf8) ?? ""

        // Step 2: Convert HTML to NSAttributedString
        let attributedString = try createAttributedStringFromHTML(htmlContent)

        // Step 3: Convert NSAttributedString to PDF
        return try createPDF(from: attributedString, fileName: judgment.caseSignature)
    }

    private static func createAttributedStringFromHTML(_ htmlContent: String) throws -> NSAttributedString {
        // Convert HTML to NSAttributedString
        guard let data = htmlContent.data(using: .utf8) else {
            throw CourtPLAPIError.parsingError("Failed to convert HTML to data")
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            return try NSAttributedString(data: data, options: options, documentAttributes: nil)
        } catch {
            throw CourtPLAPIError.parsingError("Failed to parse HTML: \(error.localizedDescription)")
        }
    }
    
    private static func createPDF(from attributedString: NSAttributedString, fileName: String) throws -> Data {
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        
        // Standard A4 page size (612 x 792 points)
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            throw CourtPLAPIError.parsingError("Failed to create PDF context")
        }
        
        // Create framesetter for the attributed string
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Create frame path with margins
        let margin: CGFloat = 50
        let frameRect = CGRect(
            x: margin,
            y: margin,
            width: mediaBox.width - (margin * 2),
            height: mediaBox.height - (margin * 2)
        )
        let framePath = CGPath(rect: frameRect, transform: nil)
        
        // Multi-page rendering
        var currentRange = CFRangeMake(0, 0)
        var pageNumber = 1
        
        while currentRange.location < attributedString.length {
            // Begin new page
            pdfContext.beginPDFPage(nil)
            
            // Create frame for current page
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)
            
            // Draw the frame
            CTFrameDraw(frame, pdfContext)
            
            // Get the range of text that was actually drawn
            let frameRange = CTFrameGetVisibleStringRange(frame)
            
            // Move to next page
            currentRange.location = frameRange.location + frameRange.length
            currentRange.length = 0
            
            // End current page
            pdfContext.endPDFPage()
            pageNumber += 1
            
            // Safety check to prevent infinite loop
            if pageNumber > 1000 {
                throw CourtPLAPIError.parsingError("PDF generation exceeded maximum page limit")
            }
        }
        
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}

// MARK: - Court PL API Error
enum CourtPLAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        }
    }
}

#Preview {
    Results_CourtPL_View(
        searchResults: [],
        isLoadingMore: false,
        hasMoreResults: true,
        onLoadMore: {},
        searchText: ""
    )
}
