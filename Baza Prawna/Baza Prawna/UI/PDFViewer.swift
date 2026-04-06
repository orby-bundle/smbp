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

// MARK: - PDF note highlight annotation

private final class BazaPDFNoteHighlightAnnotation: PDFAnnotation {
    let noteId: String

    init(bounds: CGRect, noteId: String) {
        self.noteId = noteId
        super.init(bounds: bounds, forType: .highlight, withProperties: nil)
        color = UIColor.systemGreen.withAlphaComponent(0.35)
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

// MARK: - Resolve quoted text on a PDF page (prefix + exact + suffix)

private enum PDFQuoteResolver {
    static func rangeInPageText(_ full: String, exact: String, prefix: String, suffix: String) -> NSRange? {
        let ns = full as NSString
        let needle = prefix + exact + suffix
        var r = ns.range(of: needle)
        if r.location != NSNotFound {
            let start = r.location + (prefix as NSString).length
            let len = (exact as NSString).length
            return NSRange(location: start, length: len)
        }
        r = ns.range(of: exact)
        if r.location == NSNotFound { return nil }
        let rest = NSRange(location: r.location + 1, length: ns.length - r.location - 1)
        if rest.length > 0, ns.range(of: exact, options: [], range: rest).location != NSNotFound {
            return nil
        }
        return r
    }

    static func anchor(from selection: PDFSelection, document: PDFDocument) -> TextQuoteAnchor? {
        guard let raw = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let page = selection.pages.first else { return nil }
        let pageIndex = document.index(for: page)
        let pageText = page.string ?? ""
        guard let range = rangeInPageText(pageText, exact: raw, prefix: "", suffix: "") else { return nil }
        let start = range.location
        let end = start + range.length
        let prefix = (pageText as NSString).substring(with: NSRange(location: max(0, start - 64), length: min(64, start)))
        let suffixLen = min(64, pageText.count - end)
        let suffix = suffixLen > 0 ? (pageText as NSString).substring(with: NSRange(location: end, length: suffixLen)) : ""
        return TextQuoteAnchor(
            exact: raw,
            prefix: prefix,
            suffix: suffix,
            headingId: nil,
            pdfPageIndex: pageIndex
        )
    }

    static func selection(for note: DocumentNote, document: PDFDocument) -> PDFSelection? {
        guard let pageIdx = note.anchor.pdfPageIndex,
              let page = document.page(at: pageIdx) else { return nil }
        let full = page.string ?? ""
        guard let range = rangeInPageText(
            full,
            exact: note.anchor.exact,
            prefix: note.anchor.prefix,
            suffix: note.anchor.suffix
        ) else { return nil }
        return page.selection(for: range)
    }
}

// MARK: - PDFKit note bridge (selection, highlights, scroll)

final class PDFKitNoteBridge {
    weak var pdfView: NoteAwarePDFView?

    func anchorFromCurrentSelection(document: PDFDocument) -> TextQuoteAnchor? {
        guard let pdfView,
              let sel = pdfView.currentSelection else { return nil }
        return PDFQuoteResolver.anchor(from: sel, document: document)
    }

    func applyUserNotes(_ notes: [DocumentNote], document: PDFDocument) {
        clearUserNoteAnnotations(from: document)
        for note in notes {
            guard note.anchor.pdfPageIndex != nil,
                  let selection = PDFQuoteResolver.selection(for: note, document: document) else { continue }
            // iOS PDFSelection has no `selections(by:)`; use union bounds per page (same as one highlight region).
            for page in selection.pages {
                let bounds = selection.bounds(for: page)
                guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { continue }
                let ann = BazaPDFNoteHighlightAnnotation(bounds: bounds, noteId: note.id)
                page.addAnnotation(ann)
            }
        }
    }

    func scrollToUserNote(_ note: DocumentNote, document: PDFDocument) {
        guard let pdfView,
              let selection = PDFQuoteResolver.selection(for: note, document: document) else { return }
        pdfView.go(to: selection)
    }

    private func clearUserNoteAnnotations(from document: PDFDocument) {
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let toRemove = page.annotations.filter { $0 is BazaPDFNoteHighlightAnnotation }
            for ann in toRemove {
                page.removeAnnotation(ann)
            }
        }
    }
}

// MARK: - PDFView with “Dodaj notatkę” + tap on note highlights

/// Internal to this module so `PDFKitNoteBridge` can hold a reference without access-control errors.
final class NoteAwarePDFView: PDFView {
    var onAddNoteFromSelection: (() -> Void)?
    var onNoteHighlightTapped: ((String) -> Void)?

    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard onAddNoteFromSelection != nil else { return }
        guard let sel = currentSelection,
              let t = sel.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !t.isEmpty else { return }
        let addNote = UIAction(
            title: "Dodaj notatkę",
            image: UIImage(systemName: "square.and.pencil")
        ) { [weak self] _ in
            self?.onAddNoteFromSelection?()
        }
        let inline = UIMenu(title: "", options: .displayInline, children: [addNote])
        builder.insertSibling(inline, beforeMenu: .standardEdit)
    }

    @objc func handleNoteHighlightTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let onNoteHighlightTapped else { return }
        let location = gesture.location(in: self)
        guard let page = self.page(for: location, nearest: true) else { return }
        let p = convert(location, to: page)
        for ann in page.annotations.reversed() {
            guard let hi = ann as? BazaPDFNoteHighlightAnnotation else { continue }
            if hi.bounds.contains(p) {
                onNoteHighlightTapped(hi.noteId)
                return
            }
        }
    }
}

// MARK: - Unified PDF Viewer
struct UnifiedPDFViewer: View {
    let title: String
    let pdfDataProvider: () async throws -> Data
    private let favoriteDocumentId: String?
    private let pdfEli: String?
    private let pdfCelex: String?

    init(
        title: String,
        pdfDataProvider: @escaping () async throws -> Data,
        favoriteDocumentId: String? = nil,
        pdfEli: String? = nil,
        pdfCelex: String? = nil
    ) {
        self.title = title
        self.pdfDataProvider = pdfDataProvider
        self.favoriteDocumentId = favoriteDocumentId
        self.pdfEli = pdfEli
        self.pdfCelex = pdfCelex
    }

    private var pdfNotesDocumentKey: String {
        NotesManager.pdfNotesDocumentKey(
            title: title,
            favoriteDocumentId: favoriteDocumentId,
            eli: pdfEli,
            celex: pdfCelex
        )
    }
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
    
    // Favorites
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var isFavorited = false
    @State private var showingRemoveConfirmation = false

    // Notes
    @ObservedObject private var notesManager = NotesManager.shared
    @State private var pdfNoteBridge: PDFKitNoteBridge?
    @State private var showNotesSheet = false
    @State private var noteEditorSheet: NoteEditorSheetState?
    @State private var newNoteText = ""
    @State private var noSelectionAlert = false
    
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
                            onPageChange: goToPage,
                            userNotes: notesManager.notes(forDocumentKey: pdfNotesDocumentKey),
                            onBridgeReady: { bridge in
                                pdfNoteBridge = bridge
                                bridge.applyUserNotes(
                                    notesManager.notes(forDocumentKey: pdfNotesDocumentKey),
                                    document: pdfDocument
                                )
                            },
                            onNoteHighlightTap: { noteId in
                                guard let note = notesManager.note(id: noteId) else { return }
                                newNoteText = note.noteText
                                noteEditorSheet = .editing(note)
                            },
                            onAddNoteFromMenu: {
                                tryAddNoteFromSelection()
                            }
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
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showNotesSheet = true
                        } label: {
                            Image(systemName: "note.text")
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
        .sheet(item: $noteEditorSheet) { state in
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fragment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(fragmentText(for: state))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                        .textSelection(.enabled)
                    Text("Treść notatki")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    NoteBodyTextEditor(text: $newNoteText, autoFocusKeyboard: state.autoFocusNoteBodyKeyboard)
                        .frame(minHeight: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .padding()
                .navigationTitle(editorTitle(for: state))
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if case .editing(let note) = state {
                        newNoteText = note.noteText
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Anuluj") {
                            noteEditorSheet = nil
                            newNoteText = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Zapisz") {
                            saveNoteEditor(state: state)
                        }
                        .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showNotesSheet) {
            MDDocumentNotesSheet(
                notes: notesManager.notes(forDocumentKey: pdfNotesDocumentKey),
                onAddFromSelection: {
                    showNotesSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        tryAddNoteFromSelection()
                    }
                },
                onSelectNote: { note in
                    pdfNoteBridge?.scrollToUserNote(note, document: pdfDocument!)
                    showNotesSheet = false
                },
                onEdit: { note in
                    showNotesSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        newNoteText = note.noteText
                        noteEditorSheet = .editing(note)
                    }
                },
                onDelete: { note in
                    notesManager.remove(id: note.id)
                    if let doc = pdfDocument {
                        pdfNoteBridge?.applyUserNotes(notesManager.notes(forDocumentKey: pdfNotesDocumentKey), document: doc)
                    }
                }
            )
        }
        .alert("Zaznacz fragment tekstu w dokumencie", isPresented: $noSelectionAlert) {
            Button("OK", role: .cancel) {}
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
        pdfNoteBridge?.pdfView
    }

    private func refreshPDFNoteHighlights() {
        guard let doc = pdfDocument else { return }
        pdfNoteBridge?.applyUserNotes(notesManager.notes(forDocumentKey: pdfNotesDocumentKey), document: doc)
    }

    private func tryAddNoteFromSelection() {
        guard let doc = pdfDocument else { return }
        guard let anchor = pdfNoteBridge?.anchorFromCurrentSelection(document: doc) else {
            noSelectionAlert = true
            return
        }
        newNoteText = ""
        noteEditorSheet = .newNote(anchor: anchor, draftId: UUID())
    }

    private func saveNoteEditor(state: NoteEditorSheetState) {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = pdfNotesDocumentKey
        switch state {
        case .newNote(let anchor, _):
            let note = DocumentNote(documentKey: key, noteText: trimmed, anchor: anchor)
            notesManager.add(note)
            noteEditorSheet = nil
            newNoteText = ""
            Task { @MainActor in
                let ok = await notesManager.ensurePDFInFavoritesAndMigrateNotesIfNeeded(
                    title: title,
                    favoriteDocumentIdWhenOpened: favoriteDocumentId,
                    pdfEli: pdfEli,
                    pdfCelex: pdfCelex,
                    pdfData: pdfDocument?.dataRepresentation(),
                    favoritesManager: favoritesManager
                )
                if ok { isFavorited = true }
                refreshPDFNoteHighlights()
            }
        case .editing(var note):
            note.noteText = trimmed
            notesManager.update(note)
            noteEditorSheet = nil
            newNoteText = ""
            refreshPDFNoteHighlights()
        }
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
            favoritesManager.addFavorite(title: title, pdfData: pdfData, fileExtension: "pdf")
            isFavorited = true
        }
    }
    
    private func removeFromFavorites() {
        if let id = favoritesManager.getFavoriteID(title: title, fileExtension: "pdf") {
            favoritesManager.removeFavorite(id: id)
            isFavorited = false
        }
    }
    
    private func checkFavoriteStatus() {
        isFavorited = favoritesManager.isFavorite(title: title, fileExtension: "pdf")
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var searchResults: [PDFSelection]
    @Binding var currentSearchIndex: Int
    @Binding var currentPage: Int
    let onPageChange: (Int) -> Void
    let userNotes: [DocumentNote]
    let onBridgeReady: (PDFKitNoteBridge) -> Void
    let onNoteHighlightTap: (String) -> Void
    let onAddNoteFromMenu: () -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = NoteAwarePDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displayBox = .cropBox
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.highlightedSelections = []

        let bridge = PDFKitNoteBridge()
        bridge.pdfView = pdfView
        context.coordinator.bridge = bridge
        context.coordinator.notePDFView = pdfView
        context.coordinator.onPageChange = onPageChange
        context.coordinator.currentPageBinding = $currentPage

        syncNoteCallbacks(pdfView, context: context)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleNoteTap(_:)))
        tap.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.documentChanged),
            name: .PDFViewDocumentChanged,
            object: pdfView
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }

        DispatchQueue.main.async {
            if !context.coordinator.didEmitBridge {
                context.coordinator.didEmitBridge = true
                onBridgeReady(bridge)
            }
        }

        return pdfView
    }

    private func syncNoteCallbacks(_ pdfView: NoteAwarePDFView, context: Context) {
        pdfView.onAddNoteFromSelection = { [weak pdfView] in
            guard pdfView != nil else { return }
            onAddNoteFromMenu()
        }
        pdfView.onNoteHighlightTapped = onNoteHighlightTap
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.parentDocument = document
        if let nv = uiView as? NoteAwarePDFView {
            syncNoteCallbacks(nv, context: context)
        }

        uiView.document = document

        if context.coordinator.isInitialLoad {
            uiView.displayBox = .cropBox
            uiView.scaleFactor = uiView.scaleFactorForSizeToFit
            context.coordinator.isInitialLoad = false
        }

        if let targetPage = document.page(at: currentPage) {
            uiView.go(to: targetPage)
        }

        let notesHash = userNotes.map(\.id).sorted().joined(separator: "|")
        if context.coordinator.lastAppliedNotesHash != notesHash {
            context.coordinator.lastAppliedNotesHash = notesHash
            context.coordinator.bridge?.applyUserNotes(userNotes, document: document)
        }

        if !searchResults.isEmpty && currentSearchIndex < searchResults.count {
            let currentSelection = searchResults[currentSearchIndex]
            currentSelection.color = UIColor.systemYellow
            uiView.highlightedSelections = [currentSelection]
            uiView.go(to: currentSelection)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.centerSelectionInView(uiView, selection: currentSelection)
            }
        } else {
            uiView.highlightedSelections = []
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
        weak var notePDFView: NoteAwarePDFView?
        var bridge: PDFKitNoteBridge?
        var onPageChange: ((Int) -> Void)?
        var currentPageBinding: Binding<Int>?
        var isInitialLoad = true
        var didEmitBridge = false
        var lastAppliedNotesHash: String?
        var parentDocument: PDFDocument?

        @objc func handleNoteTap(_ gesture: UITapGestureRecognizer) {
            notePDFView?.handleNoteHighlightTap(gesture)
        }

        @objc func pageChanged() {
            guard let pdfView = notePDFView,
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
            guard let pdfView = notePDFView else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            }
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
        self.init(
            title: act.title ?? act.displayAddress,
            pdfDataProvider: {
                let apiService = APIService.shared
                return try await apiService.getActText(eli: act.ELI, format: .pdf)
            },
            favoriteDocumentId: nil,
            pdfEli: act.ELI,
            pdfCelex: nil
        )
    }
    
    // Convenience initializer for EU documents
    init(document: EUDocument, language: EULanguage) {
        self.init(
            title: document.title,
            pdfDataProvider: {
                let apiService = API_EUService.shared
                return try await apiService.getEUDocumentPDF(
                    cellarId: document.cellarId,
                    language: language,
                    celex: document.celex
                )
            },
            favoriteDocumentId: nil,
            pdfEli: nil,
            pdfCelex: document.celex
        )
    }
    
    // Convenience initializer for ProcessStage PDF (stage-specific PDF)
    init(stage: ProcessStage, processTitle: String, term: String) {
        self.init(
            title: "\(processTitle) - \(stage.stageName)",
            pdfDataProvider: {
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
            },
            favoriteDocumentId: nil,
            pdfEli: nil,
            pdfCelex: nil
        )
    }
}
