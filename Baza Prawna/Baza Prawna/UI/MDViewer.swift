//
//  MDViewer.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 04/04/2026.
//

import SwiftUI
import WebKit

// MARK: - Table of Contents Entry

struct MDTOCEntry: Identifiable {
    let id: String
    let title: String
    let level: Int
}

// MARK: - Markdown → HTML Renderer
// Handles headers, GFM tables, lists, paragraphs, and inline formatting.
// To swap in a library like Down: replace the body of `toHTML(_:)` with
//   `try Down(markdownString).toHTML()`
// and inject the same CSS via `wrapInDocument(body:)`.

enum MarkdownRenderer {

    // MARK: TOC Extraction

    static func extractTOC(from markdown: String) -> [MDTOCEntry] {
        var entries: [MDTOCEntry] = []
        var idx = 0
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let match = trimmed.wholeMatch(of: /(#{1,6})\s+(.+)/) else { continue }
            entries.append(MDTOCEntry(
                id: "h\(idx)",
                title: String(match.2).trimmingCharacters(in: .whitespaces),
                level: match.1.count
            ))
            idx += 1
        }
        return entries
    }

    // MARK: Full Conversion

    static func toHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var parts: [String] = []
        var i = 0
        var hIdx = 0

        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)

            if t.isEmpty { i += 1; continue }

            // Headers
            if let m = t.wholeMatch(of: /(#{1,6})\s+(.+)/) {
                let lvl = m.1.count
                parts.append("<h\(lvl) id=\"h\(hIdx)\">\(inlineFmt(String(m.2)))</h\(lvl)>")
                hIdx += 1; i += 1; continue
            }

            // GFM table
            if isTableStart(t, next: i + 1 < lines.count ? lines[i + 1] : nil) {
                parts.append(parseTable(lines, &i)); continue
            }

            // Unordered list
            if t.hasPrefix("- ") || t.hasPrefix("* ") {
                parts.append(parseUL(lines, &i)); continue
            }

            // Ordered list – legal sub-items "1) text"
            if t.firstMatch(of: /^\d+\)\s+\S/) != nil {
                parts.append(parseOL(lines, &i)); continue
            }

            // Paragraph (fallback)
            parts.append(parseParagraph(lines, &i))
        }

        return wrapInDocument(body: parts.joined(separator: "\n"))
    }

    // MARK: - Block Parsers

    private static func isTableStart(_ line: String, next: String?) -> Bool {
        guard line.contains("|"),
              let nextTrimmed = next?.trimmingCharacters(in: .whitespaces) else { return false }
        return nextTrimmed.contains("|") && nextTrimmed.contains("---")
    }

    private static func parseTable(_ lines: [String], _ i: inout Int) -> String {
        var html = "<div class=\"table-wrapper\"><table><thead><tr>"
        for cell in splitRow(lines[i]) { html += "<th>\(inlineFmt(cell))</th>" }
        html += "</tr></thead><tbody>"
        i += 2 // skip header + separator row
        while i < lines.count {
            let row = lines[i].trimmingCharacters(in: .whitespaces)
            guard !row.isEmpty, row.contains("|") else { break }
            html += "<tr>"
            for cell in splitRow(lines[i]) { html += "<td>\(inlineFmt(cell))</td>" }
            html += "</tr>"
            i += 1
        }
        return html + "</tbody></table></div>"
    }

    private static func splitRow(_ row: String) -> [String] {
        var cells = row.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }

    private static func parseUL(_ lines: [String], _ i: inout Int) -> String {
        var html = "<ul>"
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("- ") {
                html += "<li>\(inlineFmt(String(t.dropFirst(2))))</li>"
            } else if t.hasPrefix("* ") {
                html += "<li>\(inlineFmt(String(t.dropFirst(2))))</li>"
            } else {
                break
            }
            i += 1
        }
        return html + "</ul>"
    }

    private static func parseOL(_ lines: [String], _ i: inout Int) -> String {
        var items: [String] = []
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            guard let m = t.firstMatch(of: /^\d+\)\s+(.+)$/) else { break }
            items.append(String(m.1))
            i += 1
        }
        guard !items.isEmpty else { return "" }
        var html = "<ol>"
        for item in items { html += "<li>\(inlineFmt(item))</li>" }
        return html + "</ol>"
    }

    private static func parseParagraph(_ lines: [String], _ i: inout Int) -> String {
        var acc: [String] = []
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty { break }
            if t.hasPrefix("#") { break }
            if isTableStart(t, next: i + 1 < lines.count ? lines[i + 1] : nil) { break }
            if t.hasPrefix("- ") || t.hasPrefix("* ") { break }
            if t.firstMatch(of: /^\d+\)\s+\S/) != nil { break }
            acc.append(t)
            i += 1
        }
        guard !acc.isEmpty else { i += 1; return "" }
        return "<p>\(inlineFmt(acc.joined(separator: " ")))</p>"
    }

    // MARK: - Inline Formatting

    private static func inlineFmt(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        s = s.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        s = s.replacingOccurrences(
            of: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)",
            with: "<em>$1</em>",
            options: .regularExpression
        )
        return s
    }

    // MARK: - HTML Document Wrapper

    private static func wrapInDocument(body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="pl">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=5,user-scalable=yes">
        <style>
        \(css)
        </style>
        </head>
        <body>
        \(body)
        \(searchJS)
        </body>
        </html>
        """
    }

    private static let searchJS = """
    <script>
    let searchResults = [];
    let currentSearchIndex = 0;

    function performSearch(searchText) {
        clearHighlights();
        if (!searchText || searchText.trim() === '') {
            searchResults = [];
            currentSearchIndex = 0;
            notifySearchResults(0, 0);
            return;
        }
        const text = document.body.innerText;
        const regex = new RegExp(searchText.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'gi');
        const matches = text.match(regex);
        if (matches) {
            searchResults = matches;
            highlightText(searchText);
            currentSearchIndex = 0;
            scrollToCurrentMatch();
            notifySearchResults(matches.length, 0);
        } else {
            searchResults = [];
            currentSearchIndex = 0;
            notifySearchResults(0, 0);
        }
    }

    function highlightText(searchText) {
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
        const textNodes = [];
        let node;
        while (node = walker.nextNode()) { textNodes.push(node); }
        const regex = new RegExp(searchText.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'gi');
        textNodes.forEach(tn => {
            if (regex.test(tn.textContent)) {
                regex.lastIndex = 0;
                const wrapper = document.createElement('span');
                wrapper.innerHTML = tn.textContent.replace(regex, '<span class="search-highlight">$&</span>');
                tn.parentNode.replaceChild(wrapper, tn);
            }
        });
    }

    function clearHighlights() {
        document.querySelectorAll('.search-highlight').forEach(h => {
            const parent = h.parentNode;
            parent.replaceChild(document.createTextNode(h.textContent), h);
            parent.normalize();
        });
    }

    function scrollToCurrentMatch() {
        const highlights = document.querySelectorAll('.search-highlight');
        if (highlights.length > 0 && currentSearchIndex < highlights.length) {
            highlights.forEach(h => h.classList.remove('current'));
            const cur = highlights[currentSearchIndex];
            cur.classList.add('current');
            const rect = cur.getBoundingClientRect();
            if (rect.top < 0 || rect.bottom > window.innerHeight) {
                cur.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }
    }

    function nextMatch() {
        if (searchResults.length > 0) {
            currentSearchIndex = (currentSearchIndex + 1) % searchResults.length;
            scrollToCurrentMatch();
            notifySearchResults(searchResults.length, currentSearchIndex);
        }
    }

    function previousMatch() {
        if (searchResults.length > 0) {
            currentSearchIndex = currentSearchIndex === 0 ? searchResults.length - 1 : currentSearchIndex - 1;
            scrollToCurrentMatch();
            notifySearchResults(searchResults.length, currentSearchIndex);
        }
    }

    function notifySearchResults(count, currentIndex) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.searchResults) {
            window.webkit.messageHandlers.searchResults.postMessage({ count: count, currentIndex: currentIndex });
        }
    }

    window.searchFunctions = {
        performSearch: performSearch,
        nextMatch: nextMatch,
        previousMatch: previousMatch,
        clearHighlights: clearHighlights
    };
    </script>
    """

    private static let css = """
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; scroll-padding-top: 16px; }

    body {
        font-family: -apple-system, 'SF Pro Text', 'Helvetica Neue', sans-serif;
        font-size: 17px; line-height: 1.65;
        color: #1d1d1f; background: #ffffff;
        padding: 16px 20px 100px; margin: 0;
        -webkit-text-size-adjust: 100%;
        word-wrap: break-word; overflow-wrap: break-word;
    }

    @media (prefers-color-scheme: dark) {
        body { color: #f5f5f7; background: #1c1c1e; }
        h1, h2, h3, h4 { color: #f5f5f7; }
        h2 { border-bottom-color: #3a3a3c; }
        table, th, td { border-color: #3a3a3c; }
        th { background: #2c2c2e; color: #f5f5f7; }
        tr:nth-child(even) { background: rgba(255,255,255,0.04); }
        .table-wrapper { border-color: #3a3a3c; }
    }

    h1 { font-size: 26px; font-weight: 700; margin: 32px 0 16px; }
    h2 { font-size: 21px; font-weight: 700; margin: 28px 0 12px;
         padding-bottom: 8px; border-bottom: 1px solid #d1d1d6; }
    h3 { font-size: 17px; font-weight: 600; margin: 24px 0 8px; }

    p  { margin: 8px 0 12px; text-align: justify; }

    ul, ol { padding-left: 28px; margin: 8px 0; }
    li     { margin: 4px 0; }

    .table-wrapper {
        overflow-x: auto; -webkit-overflow-scrolling: touch;
        margin: 16px 0; border-radius: 8px;
        border: 1px solid #d1d1d6;
    }
    table { border-collapse: collapse; min-width: 100%;
            font-size: 14px; font-variant-numeric: tabular-nums; }
    th, td { padding: 8px 12px; text-align: left;
             border: 1px solid #d1d1d6; white-space: nowrap; }
    th { background: #f2f2f7; font-weight: 600;
         position: sticky; top: 0; z-index: 1; }
    tr:nth-child(even) { background: #f9f9fb; }

    strong { font-weight: 600; }
    em     { font-style: italic; }

    .search-highlight {
        background-color: rgba(0, 122, 255, 0.3);
        color: inherit;
        padding: 1px 2px;
        border-radius: 2px;
    }
    .search-highlight.current {
        background-color: #FFD700;
        color: #000;
    }
    """
}

// MARK: - WKWebView Wrapper

struct MarkdownWebView: UIViewRepresentable {
    let html: String
    @Binding var scrollToID: String?
    let onSearchResults: (Int, Int) -> Void
    let onCoordinatorReady: (Coordinator) -> Void
    /// Called on the main queue when `loadHTMLString` navigation finishes (document ready to display).
    let onDocumentLoaded: (() -> Void)?

    init(html: String,
         scrollToID: Binding<String?>,
         onSearchResults: @escaping (Int, Int) -> Void = { _, _ in },
         onCoordinatorReady: @escaping (Coordinator) -> Void = { _ in },
         onDocumentLoaded: (() -> Void)? = nil) {
        self.html = html
        self._scrollToID = scrollToID
        self.onSearchResults = onSearchResults
        self.onCoordinatorReady = onCoordinatorReady
        self.onDocumentLoaded = onDocumentLoaded
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "searchResults")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.searchResultsHandler = onSearchResults
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            onCoordinatorReady(coordinator)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.searchResultsHandler = onSearchResults

        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            context.coordinator.isPageReady = false
            webView.loadHTMLString(html, baseURL: nil)
        }

        guard let targetID = scrollToID else { return }

        if context.coordinator.isPageReady {
            context.coordinator.scroll(to: targetID, in: webView)
        } else {
            context.coordinator.pendingScrollID = targetID
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "searchResults")
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownWebView
        var webView: WKWebView?
        var loadedHTML: String?
        var isPageReady = false
        var pendingScrollID: String?
        var pendingSearchText: String?
        var searchResultsHandler: ((Int, Int) -> Void)?

        init(_ parent: MarkdownWebView) { self.parent = parent }

        // MARK: Search

        func performSearch(_ text: String) {
            guard isPageReady else {
                pendingSearchText = text
                return
            }
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            webView?.evaluateJavaScript("window.searchFunctions.performSearch('\(escaped)');")
        }

        func nextMatch() {
            webView?.evaluateJavaScript("window.searchFunctions.nextMatch();")
        }

        func previousMatch() {
            webView?.evaluateJavaScript("window.searchFunctions.previousMatch();")
        }

        func clearSearch() {
            webView?.evaluateJavaScript("window.searchFunctions.clearHighlights();")
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "searchResults",
                  let body = message.body as? [String: Any],
                  let count = body["count"] as? Int,
                  let currentIndex = body["currentIndex"] as? Int else { return }
            DispatchQueue.main.async { self.searchResultsHandler?(count, currentIndex) }
        }

        // MARK: Navigation

        func scroll(to id: String, in webView: WKWebView) {
            webView.evaluateJavaScript(
                "document.getElementById('\(id)')?.scrollIntoView({behavior:'smooth',block:'start'})"
            )
            DispatchQueue.main.async { self.parent.scrollToID = nil }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true
            if let id = pendingScrollID {
                scroll(to: id, in: webView)
                pendingScrollID = nil
            }
            if let text = pendingSearchText, !text.isEmpty {
                pendingSearchText = nil
                performSearch(text)
            }
            if let onDocumentLoaded = parent.onDocumentLoaded {
                DispatchQueue.main.async {
                    onDocumentLoaded()
                }
            }
        }
    }
}

// MARK: - Table of Contents Sheet

struct MDTableOfContents: View {
    let entries: [MDTOCEntry]
    let onSelect: (MDTOCEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredEntries: [MDTOCEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredEntries) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.level <= 2 ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(width: 3)

                        Text(entry.title)
                            .font(entry.level <= 2 ? .subheadline.weight(.semibold) : .footnote)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.leading, CGFloat(max(0, entry.level - 2)) * 16)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Szukaj w spisie treści")
            .navigationTitle("Spis treści")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Main Viewer

struct MDViewer: View {
    let title: String
    private let markdownURL: URL?
    private let eli: String?

    @State private var htmlContent = ""
    @State private var tocEntries: [MDTOCEntry] = []
    @State private var showTOC = false
    @State private var scrollToID: String?
    /// True until markdown is fetched and the WebView has finished loading the HTML (avoids a blank gap after network load).
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Search
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var searchResultsCount = 0
    @State private var currentMatchIndex = 0
    @State private var webViewCoordinator: MarkdownWebView.Coordinator?

    // Favorites
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var isFavorited = false
    @State private var showingRemoveConfirmation = false

    init(resourceName: String) {
        self.title = resourceName
        self.markdownURL = Bundle.main.url(forResource: resourceName, withExtension: "md")
        self.eli = nil
    }

    init(title: String, fileURL: URL) {
        self.title = title
        self.markdownURL = fileURL
        self.eli = nil
    }
    
    init(title: String, eli: String) {
        self.title = title
        self.markdownURL = nil
        self.eli = eli
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingSearch {
                HTMLSearchBarView(
                    searchText: $searchText,
                    searchResultsCount: $searchResultsCount,
                    currentMatchIndex: $currentMatchIndex,
                    onSearch: { text in
                        webViewCoordinator?.performSearch(text)
                    },
                    onPrevious: {
                        webViewCoordinator?.previousMatch()
                    },
                    onNext: {
                        webViewCoordinator?.nextMatch()
                    },
                    onClose: {
                        showingSearch = false
                        searchText = ""
                        webViewCoordinator?.clearSearch()
                    }
                )
                .background(Color(.systemGray6))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else if htmlContent.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                        Text("Ładowanie dokumentu…")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ZStack {
                        MarkdownWebView(
                            html: htmlContent,
                            scrollToID: $scrollToID,
                            onSearchResults: { count, index in
                                searchResultsCount = count
                                currentMatchIndex = index
                            },
                            onCoordinatorReady: { coordinator in
                                webViewCoordinator = coordinator
                            },
                            onDocumentLoaded: {
                                isLoading = false
                            }
                        )
                        .opacity(isLoading ? 0.001 : 1)
                        .ignoresSafeArea(.container, edges: .bottom)

                        if isLoading {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(1.5)
                                Text("Ładowanie dokumentu…")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                            .allowsHitTesting(true)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingSearch)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        showingSearch.toggle()
                        if !showingSearch {
                            searchText = ""
                            webViewCoordinator?.clearSearch()
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(showingSearch ? .blue : .primary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if isFavorited {
                        showingRemoveConfirmation = true
                    } else {
                        addToFavorites()
                    }
                } label: {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .foregroundColor(isFavorited ? .yellow : .primary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !tocEntries.isEmpty {
                    Button {
                        showTOC = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
        .sheet(isPresented: $showTOC) {
            MDTableOfContents(entries: tocEntries) { entry in
                showTOC = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    scrollToID = entry.id
                }
            }
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
            loadMarkdown()
            checkFavoriteStatus()
        }
    }

    private func loadMarkdown() {
        Task {
            do {
                let markdown: String
                
                if let url = markdownURL {
                    markdown = try String(contentsOf: url, encoding: .utf8)
                } else if let eli = eli {
                    let cacheKey = "md_\(eli)"
                    if let cachedData = CacheManager.shared.data(forKey: cacheKey, category: .persistentMD),
                       let decoded = String(data: cachedData, encoding: .utf8) {
                        markdown = decoded
                    } else {
                        let url = try await FirebaseManager.shared.getMarkdownDownloadURL(for: eli)
                        let (data, response) = try await URLSession.shared.data(from: url)
                        
                        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                            throw URLError(.badServerResponse)
                        }
                        
                        guard let decoded = String(data: data, encoding: .utf8) else {
                            throw URLError(.cannotDecodeRawData)
                        }
                        
                        // Store it persistently until the app is uninstalled
                        try? CacheManager.shared.storeData(data, forKey: cacheKey, category: .persistentMD)
                        
                        markdown = decoded
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Nie znaleziono pliku."
                        self.isLoading = false
                    }
                    return
                }
                
                let extractedTOC = MarkdownRenderer.extractTOC(from: markdown)
                let html = MarkdownRenderer.toHTML(markdown)
                
                await MainActor.run {
                    self.tocEntries = extractedTOC
                    self.htmlContent = html
                    // Keep isLoading true until MarkdownWebView reports WKWebView didFinish
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Nie udało się wczytać pliku: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Favorites

    private func addToFavorites() {
        Task {
            do {
                let data: Data
                if let url = markdownURL {
                    data = try Data(contentsOf: url)
                } else if let eli = eli {
                    let cacheKey = "md_\(eli)"
                    if let cachedData = CacheManager.shared.data(forKey: cacheKey, category: .persistentMD) {
                        data = cachedData
                    } else {
                        let url = try await FirebaseManager.shared.getMarkdownDownloadURL(for: eli)
                        let (fetchedData, response) = try await URLSession.shared.data(from: url)
                        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                            return
                        }
                        data = fetchedData
                        
                        try? CacheManager.shared.storeData(data, forKey: cacheKey, category: .persistentMD)
                    }
                } else {
                    return
                }
                
                await MainActor.run {
                    favoritesManager.addFavorite(title: title, pdfData: data, fileExtension: "md")
                    isFavorited = true
                }
            } catch {
                print("Error adding to favorites: \(error)")
            }
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
