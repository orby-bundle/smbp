//
//  Results_CourtNSA_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import SafariServices
import CoreText

struct Results_CourtNSA_View: View {
    let searchResults: [NSAJudgment]
    let hasMoreResults: Bool
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
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, judgment in
                            NSAJudgmentRowView(judgment: judgment, searchText: searchText)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .bottom))
                                ))
                                .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.1), value: searchResults.count)
                        }
                    }
                } else {
                    // iPhone: full-width stack to avoid narrow single tiles
                    LazyVStack(spacing: 8) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, judgment in
                            NSAJudgmentRowView(judgment: judgment, searchText: searchText)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .bottom))
                                ))
                                .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.1), value: searchResults.count)
                        }
                    }
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
        .animation(.easeInOut(duration: 0.6), value: searchResults.count)
    }
}

// MARK: - NSA Judgment Row View
struct NSAJudgmentRowView: View {
    let judgment: NSAJudgment
    let searchText: String
    @State private var isLoadingHTML = false
    @State private var htmlError: String?
    @State private var mdDestination: NSAMarkdownDestination?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private struct NSAMarkdownDestination: Identifiable, Hashable {
        let id: String
        let judgmentId: String
        let title: String
        let markdown: String
        let documentKey: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            // Case signature as headline
            Text(judgment.caseSignature)
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                      
            // PDF preview + PDF • Czytaj (same pattern as Results_DUMP)
            VStack(spacing: 0) {
                NavigationLink(destination: NSAJudgmentPDFView(judgment: judgment)) {
                    PDFPreviewTile(cacheKey: "nsa_\(judgment.id)", openText: "") {
                        try await NSAJudgmentPDFView.buildPDFData(for: judgment)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                HStack(spacing: 12) {
                    Spacer()

                    NavigationLink(destination: NSAJudgmentPDFView(judgment: judgment)) {
                        ResultFormatChipLabel(title: ".pdf")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("|")
                        .foregroundColor(.secondary)

                    Button(action: {
                        Task {
                            await openInMDViewer()
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
        .navigationDestination(item: $mdDestination) { dest in
            MDViewer(title: dest.title, markdown: dest.markdown, documentKey: dest.documentKey)
        }
        .alert("Błąd ładowania", isPresented: Binding(
            get: { htmlError != nil },
            set: { if !$0 { htmlError = nil } }
        )) {
            Button("OK", role: .cancel) { htmlError = nil }
        } message: {
            Text(htmlError ?? "")
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
    private func openInMDViewer() async {
        isLoadingHTML = true
        htmlError = nil
        
        do {
            let stripped = try await API_NSAService.shared.getStrippedJudgmentHTML(docPath: judgment.docPath)
            let md = NSAHTMLToMarkdown.convert(stripped)
            mdDestination = nil
            mdDestination = NSAMarkdownDestination(
                id: UUID().uuidString,
                judgmentId: judgment.id,
                title: judgment.caseSignature,
                markdown: md,
                documentKey: "nsa:\(judgment.id)"
            )
        } catch {
            htmlError = error.localizedDescription
        }
        
        isLoadingHTML = false
    }
    
}

// MARK: - RTF Content View
struct RTFContentView: View {
    let rtfContent: NSAttributedString
    @Binding var isPresented: Bool
    let initialSearchText: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(AttributedString(rtfContent))
                    .padding()
            }
            .navigationTitle("Orzeczenie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zamknij") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - NSA Judgment PDF View
struct NSAJudgmentPDFView: View {
    let judgment: NSAJudgment
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
    
    static func buildPDFData(for judgment: NSAJudgment) async throws -> Data {
        // Step 1: Download RTF file
        let rtfURL = "https://orzeczenia.nsa.gov.pl/doc/\(judgment.id).rtf"
        guard let url = URL(string: rtfURL) else {
            throw NSAAPIError.invalidURL
        }

        let (rtfData, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSAAPIError.invalidResponse
        }

        // Step 2: Convert RTF data to NSAttributedString
        let attributedString = try NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )

        // Step 3: Convert NSAttributedString to PDF
        return try createPDF(from: attributedString, fileName: judgment.caseSignature)
    }

    private static func createPDF(from attributedString: NSAttributedString, fileName: String) throws -> Data {
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        
        // Standard A4 page size (612 x 792 points)
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            throw NSAAPIError.parsingError("Failed to create PDF context")
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
                throw NSAAPIError.parsingError("PDF generation exceeded maximum page limit")
            }
        }
        
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}

#Preview {
    Results_CourtNSA_View(
        searchResults: [],
        hasMoreResults: true,
        searchText: ""
    )
}
