//
//  PDFViewer.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import PDFKit
import Combine
import UniformTypeIdentifiers

// MARK: - Unified PDF Viewer
struct UnifiedPDFViewer: View {
    let title: String
    let pdfDataProvider: () async throws -> Data
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pdfOpacity = 0.0
    @Environment(\.dismiss) private var dismiss
    
    // Search functionality
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [PDFSelection] = []
    @State private var currentSearchIndex = 0
    @State private var showingSearchBar = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // Page navigation
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var showingPageControls = false
    
    // Info sheet
    @State private var showingInfoSheet = false
    
    // Favorites
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var isFavorited = false
    @State private var showingRemoveConfirmation = false
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar (shown when searching) - at the top
                if showingSearchBar {
                    SearchBarView(
                        searchText: $searchText,
                        searchResults: searchResults,
                        currentIndex: $currentSearchIndex,
                        isSearchFieldFocused: $isSearchFieldFocused,
                        onSearch: performSearch,
                        onNavigate: navigateToSearchResult,
                        onClear: clearSearch
                    )
                    .background(Color(.systemGray6))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Main content
                ZStack {
                    if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                            
                            Text("Pobranie PDF...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    } else if errorMessage != nil {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("Dokument nie jest jeszcze dostępny")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Spróbuj później")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            // Back button
                            Button(action: {
                                dismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.subheadline)
                                    Text("Wróć")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .padding(.top, 20)
                         
                        }
                    } else if let pdfDocument = pdfDocument {
                        PDFKitView(
                            document: pdfDocument,
                            searchResults: $searchResults,
                            currentSearchIndex: $currentSearchIndex,
                            currentPage: $currentPage,
                            onPageChange: goToPage
                        )
                        .opacity(pdfOpacity)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            
                            Text("Brak PDF")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Ten dokument jeszcze nie ma dostępnej wersji PDF")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if pdfDocument != nil {
                        Button(action: {
                            if showingPageControls {
                                showingPageControls = false
                            }
                            showingSearchBar.toggle()
                            if showingSearchBar {
                                // Focus the search field and show keyboard
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFieldFocused = true
                                }
                            } else {
                                clearSearch()
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(showingSearchBar ? .blue : .primary)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if pdfDocument != nil, totalPages > 1 {
                        Button(action: {
                            if showingSearchBar {
                                showingSearchBar = false
                                clearSearch()
                            }
                            showingPageControls.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Text("\(currentPage + 1)/\(totalPages)")
                                    .font(.headline)
                                    .foregroundColor(showingPageControls ? .blue : .primary)
                                
                                Image(systemName: "slider.horizontal.below.rectangle")
                                    .font(.caption)
                                    .foregroundColor(showingPageControls ? .blue : .primary)
                            }
                            .frame(minWidth: 60, minHeight: 30)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Circle()
                                    .fill(Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if let pdfDocument = pdfDocument {
                    // Star button for favorites
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            if isFavorited {
                                showingRemoveConfirmation = true
                            } else {
                                addToFavorites()
                            }
                        }) {
                            Image(systemName: isFavorited ? "star.fill" : "star")
                                .foregroundColor(isFavorited ? .yellow : .primary)
                        }
                    }
                    
                    // Info button as its own toolbar item
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingInfoSheet = true
                        }) {
                            Image(systemName: "info.circle")
                        }
                    }
                    
                    // Share button as its own toolbar item
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(
                            item: PDFShareItem(document: pdfDocument, title: title),
                            preview: SharePreview(title)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showingPageControls && totalPages > 1 {
                    PageNavigationView(
                        currentPage: $currentPage,
                        totalPages: totalPages,
                        onPageChange: goToPage
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showingInfoSheet) {
            DocumentInfoSheet(
                title: title,
                document: pdfDocument
            )
        }
        .confirmationDialog(
            "Czy na pewno chcesz usunąć ze Swoich Akt?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Tak", role: .destructive) {
                removeFromFavorites()
            }
            Button("Nie", role: .cancel) { }
        }
        .onAppear {
            loadPDF()
            checkFavoriteStatus()
        }
    }
    
    private func loadPDF() {
        Task {
            await downloadPDF()
        }
    }
    
    @MainActor
    private func downloadPDF() async {
        isLoading = true
        errorMessage = nil
        pdfOpacity = 0.0
        
        do {
            let pdfData = try await pdfDataProvider()
            
            if let document = PDFDocument(data: pdfData) {
                self.pdfDocument = document
                self.totalPages = document.pageCount
                self.currentPage = 0
                self.isLoading = false
                
                // Fade in the PDF with animation
                withAnimation(.easeIn(duration: 0.8)) {
                    self.pdfOpacity = 1.0
                }
            } else {
                self.errorMessage = "Failed to create PDF document from downloaded data"
                self.isLoading = false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    // MARK: - Search Functionality
    private func performSearch() {
        guard let document = pdfDocument, !searchText.isEmpty else { return }
        
        let selections = document.findString(searchText, withOptions: .caseInsensitive)
        searchResults = selections
        currentSearchIndex = 0
        
        if !searchResults.isEmpty {
            navigateToSearchResult(index: 0)
        }
    }
    
    private func navigateToSearchResult(index: Int) {
        guard !searchResults.isEmpty, index >= 0, index < searchResults.count else { return }
        
        currentSearchIndex = index
        let selection = searchResults[index]
        
        // Set yellow color for search highlighting to match HTMLViewer
        selection.color = UIColor.systemYellow
        
        // Highlight the current selection and center it
        if let pdfView = findPDFView() {
            pdfView.highlightedSelections = [selection]
            pdfView.go(to: selection)
            
            // Center the selection in the view after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.centerSelectionInView(pdfView, selection: selection)
            }
        }
    }
    
    private func navigateToSearchResult(direction: SearchDirection) {
        guard !searchResults.isEmpty else { return }
        
        let newIndex: Int
        switch direction {
        case .next:
            newIndex = (currentSearchIndex + 1) % searchResults.count
        case .previous:
            newIndex = currentSearchIndex > 0 ? currentSearchIndex - 1 : searchResults.count - 1
        }
        
        navigateToSearchResult(index: newIndex)
    }
    
    private func clearSearch() {
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
        
        if let pdfView = findPDFView() {
            pdfView.highlightedSelections = []
        }
    }
    
    private func findPDFView() -> PDFView? {
        return nil 
    }
    
    // MARK: - Page Navigation
    private func goToPage(_ page: Int) {
        guard pdfDocument != nil, page >= 0, page < totalPages else { return }
        
        currentPage = page
        
        // The PDFKitView will handle the actual page navigation in updateUIView
    }
    
    private func goToNextPage() {
        if currentPage < totalPages - 1 {
            goToPage(currentPage + 1)
        }
    }
    
    private func goToPreviousPage() {
        if currentPage > 0 {
            goToPage(currentPage - 1)
        }
    }
    
    private func centerSelectionInView(_ pdfView: PDFView, selection: PDFSelection) {
        guard let page = selection.pages.first else { return }
        
        // Get the selection bounds in page coordinates
        let selectionBounds = selection.bounds(for: page)
        
        // Get the page bounds
        let pageBounds = page.bounds(for: .mediaBox)
        
        // Convert selection center to PDF view coordinates
        let selectionCenter = CGPoint(
            x: selectionBounds.midX,
            y: pageBounds.height - selectionBounds.midY
        )
        
        // Get the visible area of the PDF view
        let visibleRect = pdfView.bounds
        
        // Calculate the center point of the visible area
        let visibleCenter = CGPoint(
            x: visibleRect.midX,
            y: visibleRect.midY
        )
        
        // Calculate the offset needed to center the selection
        let offsetX = selectionCenter.x - visibleCenter.x
        let offsetY = selectionCenter.y - visibleCenter.y
        
        // Apply the offset to center the selection
        if let scrollView = pdfView.documentView as? UIScrollView {
            let currentOffset = scrollView.contentOffset
            let newOffset = CGPoint(
                x: currentOffset.x + offsetX,
                y: currentOffset.y + offsetY
            )
            scrollView.setContentOffset(newOffset, animated: true)
        }
    }
    
    // MARK: - Favorites Functionality
    private func addToFavorites() {
        if let pdfData = pdfDocument?.dataRepresentation() {
            favoritesManager.addFavorite(title: title, pdfData: pdfData)
            isFavorited = true
        }
    }
    
    private func removeFromFavorites() {
        if let id = favoritesManager.getFavoriteID(title: title) {
            favoritesManager.removeFavorite(id: id)
            isFavorited = false
        }
    }
    
    private func checkFavoriteStatus() {
        isFavorited = favoritesManager.isFavorite(title: title)
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var searchResults: [PDFSelection]
    @Binding var currentSearchIndex: Int
    @Binding var currentPage: Int
    let onPageChange: (Int) -> Void
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displayBox = .cropBox
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        
        // Set yellow highlighting for search results to match HTMLViewer
        pdfView.highlightedSelections = []
        if let selection = pdfView.currentSelection {
            selection.color = UIColor.systemYellow
        }
        
        // Store reference for search functionality and page navigation
        context.coordinator.pdfView = pdfView
        context.coordinator.onPageChange = onPageChange
        context.coordinator.currentPageBinding = $currentPage
        
        // Set up page change notification
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        // Set up document change notification for proper scaling
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.documentChanged),
            name: .PDFViewDocumentChanged,
            object: pdfView
        )
        
        // Ensure proper scaling after layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
        
        // Only apply fit-to-width scaling on initial load
        // Preserve user's zoom level during page navigation
        if context.coordinator.isInitialLoad {
            uiView.displayBox = .cropBox
            uiView.scaleFactor = uiView.scaleFactorForSizeToFit
            context.coordinator.isInitialLoad = false
        }
        
        // Update current page if it has changed
        if let targetPage = document.page(at: currentPage) {
            uiView.go(to: targetPage)
        }
        
        // Update search highlighting and center the selection
        if !searchResults.isEmpty && currentSearchIndex < searchResults.count {
            let currentSelection = searchResults[currentSearchIndex]
            // Set yellow color for search highlighting to match HTMLViewer
            currentSelection.color = UIColor.systemYellow
            uiView.highlightedSelections = [currentSelection]
            uiView.go(to: currentSelection)
            
            // Center the selection in the view after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.centerSelectionInView(uiView, selection: currentSelection)
            }
        }
    }
    
    private func centerSelectionInView(_ pdfView: PDFView, selection: PDFSelection) {
        guard let page = selection.pages.first else { return }
        
        // Get the selection bounds in page coordinates
        let selectionBounds = selection.bounds(for: page)
        
        // Get the page bounds
        let pageBounds = page.bounds(for: .mediaBox)
        
        // Convert selection center to PDF view coordinates
        let selectionCenter = CGPoint(
            x: selectionBounds.midX,
            y: pageBounds.height - selectionBounds.midY
        )
        
        // Get the visible area of the PDF view
        let visibleRect = pdfView.bounds
        
        // Calculate the center point of the visible area
        let visibleCenter = CGPoint(
            x: visibleRect.midX,
            y: visibleRect.midY
        )
        
        // Calculate the offset needed to center the selection
        let offsetX = selectionCenter.x - visibleCenter.x
        let offsetY = selectionCenter.y - visibleCenter.y
        
        // Apply the offset to center the selection
        if let scrollView = pdfView.documentView as? UIScrollView {
            let currentOffset = scrollView.contentOffset
            let newOffset = CGPoint(
                x: currentOffset.x + offsetX,
                y: currentOffset.y + offsetY
            )
            scrollView.setContentOffset(newOffset, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    class Coordinator: NSObject {
        var pdfView: PDFView?
        var onPageChange: ((Int) -> Void)?
        var currentPageBinding: Binding<Int>?
        var isInitialLoad = true
        
        @objc func pageChanged() {
            guard let pdfView = pdfView,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            
            let pageIndex = document.index(for: currentPage)
            guard currentPageBinding?.wrappedValue != pageIndex else { return }
            DispatchQueue.main.async { [weak self] in
                guard self?.currentPageBinding?.wrappedValue != pageIndex else { return }
                self?.currentPageBinding?.wrappedValue = pageIndex
            }
        }
        
        @objc func documentChanged() {
            guard let pdfView = pdfView else { return }
            
            // Ensure proper scaling when document is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            }
        }
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Search Direction Enum
enum SearchDirection {
    case next
    case previous
}

// MARK: - Page Navigation View
struct PageNavigationView: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onPageChange: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Previous page button
                Button(action: {
                    if currentPage > 0 {
                        onPageChange(currentPage - 1)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(currentPage > 0 ? .blue : .gray)
                }
                .disabled(currentPage <= 0)
                
                // Page indicator
                VStack(spacing: 4) {
                    Text("Strona \(currentPage + 1) z \(totalPages)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Page slider
                    HStack {                 
                        Slider(
                            value: Binding(
                                get: { Double(currentPage) },
                                set: { onPageChange(Int($0)) }
                            ),
                            in: 0...Double(totalPages - 1),
                            step: 1
                        )
                        .accentColor(.blue)
                    }
                }
                
                // Next page button
                Button(action: {
                    if currentPage < totalPages - 1 {
                        onPageChange(currentPage + 1)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(currentPage < totalPages - 1 ? .blue : .gray)
                }
                .disabled(currentPage >= totalPages - 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
        }
    }
}

// MARK: - Search Bar View
struct SearchBarView: View {
    @Binding var searchText: String
    let searchResults: [PDFSelection]
    @Binding var currentIndex: Int
    @FocusState.Binding var isSearchFieldFocused: Bool
    let onSearch: () -> Void
    let onNavigate: (SearchDirection) -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Search input field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Szukaj w tekście...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            onSearch()
                        }
                        .onChange(of: searchText) { _, newValue in
                            if !newValue.isEmpty {
                                onSearch()
                            } else {
                                onClear()
                            }
                        }
                    
                    ClearSearchButton(
                        searchText: $searchText,
                        onClear: onClear
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Result count and navigation
                if !searchResults.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(currentIndex + 1) z \(searchResults.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            onNavigate(.previous)
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(searchResults.isEmpty)
                        
                        Button(action: {
                            onNavigate(.next)
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(searchResults.isEmpty)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
        }
    }
}

// MARK: - Document Info Sheet
struct DocumentInfoSheet: View {
    let title: String
    let document: PDFDocument?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Document Title Section
                    VStack(alignment: .leading, spacing: 12) {
                                               
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // PDF Details Section
                    if let document = document {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Szczegóły PDF")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(title: "Strony", value: "\(document.pageCount)")
                                
                                if let documentAttributes = document.documentAttributes,
                                   let creationDate = documentAttributes[PDFDocumentAttribute.creationDateAttribute] as? Date {
                                    InfoRow(title: "Stworzony", value: DateFormatter.localizedString(from: creationDate, dateStyle: .medium, timeStyle: .none))
                                }
                                
                                if let documentAttributes = document.documentAttributes,
                                   let modificationDate = documentAttributes[PDFDocumentAttribute.modificationDateAttribute] as? Date {
                                    InfoRow(title: "Zmieniony", value: DateFormatter.localizedString(from: modificationDate, dateStyle: .medium, timeStyle: .none))
                                }
                                
                                if let documentAttributes = document.documentAttributes,
                                   let author = documentAttributes[PDFDocumentAttribute.authorAttribute] as? String {
                                    InfoRow(title: "Autor", value: author)
                                }
                                
                                if let documentAttributes = document.documentAttributes,
                                   let subject = documentAttributes[PDFDocumentAttribute.subjectAttribute] as? String {
                                    InfoRow(title: "Temat", value: subject)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Dokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

// MARK: - PDF Share Item
struct PDFShareItem: Transferable {
    let document: PDFDocument
    let title: String
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .pdf) { pdfShareItem in
            // Create a temporary file with the custom filename
            let filename = "\(pdfShareItem.sanitizedTitle).pdf"
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempURL = tempDirectory.appendingPathComponent(filename)
            
            guard let pdfData = pdfShareItem.document.dataRepresentation() else {
                throw TransferError.missingPDFData
            }
            
            do {
                try pdfData.write(to: tempURL, options: [.atomic])
            } catch {
                throw TransferError.failedToWriteFile(error)
            }
            
            return SentTransferredFile(tempURL)
        } importing: { received in
            // This is for importing, not needed for sharing
            throw TransferError.importNotSupported
        }
    }
    
    private var sanitizedTitle: String {
        let fallbackName = "Document"
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.controlCharacters)
        let whitespaceSet = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\u{00A0}\u{202F}"))
        
        var sanitized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if sanitized.isEmpty {
            return fallbackName
        }
        
        // Replace whitespace (including non-breaking) with underscores
        sanitized = sanitized.components(separatedBy: whitespaceSet)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        
        // Remove invalid characters and collapse duplicate underscores
        sanitized = sanitized.components(separatedBy: invalidCharacters).joined(separator: "_")
        sanitized = sanitized.replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
        
        // Strip diacritics for broader filesystem compatibility
        sanitized = sanitized.applyingTransform(.stripCombiningMarks, reverse: false) ?? sanitized
        
        // Ensure filename does not exceed common filesystem limits
        let maxLength = 120
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }
        
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "._"))
        
        return sanitized.isEmpty ? fallbackName : sanitized
    }
}

// MARK: - Transfer Error
enum TransferError: Error {
    case importNotSupported
    case missingPDFData
    case failedToWriteFile(Error)
}

extension TransferError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .importNotSupported:
            return "Importing PDF content is not supported."
        case .missingPDFData:
            return "The PDF data is not available for sharing."
        case .failedToWriteFile(let error):
            return "Failed to persist PDF for sharing: \(error.localizedDescription)"
        }
    }
}

// MARK: - PDFDocument Transferable Extension
extension PDFDocument: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .pdf) { pdf in
            pdf.dataRepresentation() ?? Data()
        } importing: { data in
            PDFDocument(data: data) ?? PDFDocument()
        }
    }
}

// MARK: - Convenience Initializers
extension UnifiedPDFViewer {
    // Convenience initializer for Act objects (Polish legal documents)
    init(act: Act) {
        self.title = act.title ?? act.displayAddress
        self.pdfDataProvider = {
            let apiService = APIService.shared
            return try await apiService.getActText(eli: act.ELI, format: .pdf)
        }
    }
    
    // Convenience initializer for EU documents
    init(document: EUDocument, language: EULanguage) {
        self.title = document.title
        self.pdfDataProvider = {
            let apiService = API_EUService.shared
            return try await apiService.getEUDocumentPDF(
                cellarId: document.cellarId,
                language: language,
                celex: document.celex
            )
        }
    }
    
    // Convenience initializer for ProcessStage PDF (stage-specific PDF)
    init(stage: ProcessStage, processTitle: String, term: String) {
        self.title = "\(processTitle) - \(stage.stageName)"
        self.pdfDataProvider = {
            // First, try to get PDF from links array if available
            if let links = stage.links,
               let pdfLink = links.first(where: { link in
                   link.href.lowercased().hasSuffix(".pdf") ||
                   link.rel?.lowercased().contains("pdf") == true
               }) {
                // Download PDF from direct URL
                // Handle relative URLs by converting to absolute
                var hrefString = pdfLink.href
                if hrefString.hasPrefix("/") {
                    // Relative URL - prepend base URL
                    hrefString = "https://api.sejm.gov.pl" + hrefString
                } else if !hrefString.hasPrefix("http") {
                    // Relative URL without leading slash
                    hrefString = "https://api.sejm.gov.pl/" + hrefString
                }
                
                guard let url = URL(string: hrefString) else {
                    throw LegisAPIError.invalidURL
                }
                
                // Check cache first
                let cacheManager = CacheManager.shared
                let cacheKey = hrefString // Use absolute URL for cache key
                
                if let cachedData = cacheManager.data(forKey: cacheKey, category: .pdf) {
                    return cachedData
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/pdf", forHTTPHeaderField: "Accept")
                request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LegisAPIError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                    throw LegisAPIError.serverError(httpResponse.statusCode, responseString)
                }
                
                // Store in cache
                do {
                    try cacheManager.storeData(data, forKey: cacheKey, category: .pdf)
                } catch {
                    print("⚠️ Failed to cache PDF for link \(hrefString): \(error.localizedDescription)")
                }
                
                return data
            }
            
            // Fallback to printNumber if available
            guard let printNumber = stage.printNumber, !printNumber.isEmpty else {
                throw LegisAPIError.invalidURL
            }
            
            let apiService = APIService_Legis.shared
            return try await apiService.getProcessPDF(number: printNumber, term: term)
        }
    }
}
