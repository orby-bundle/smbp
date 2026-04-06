//
//  MDViewer.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 04/04/2026.
//

import SwiftUI
import UIKit
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
        \(notesJS)
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

    mark.user-note-highlight {
        background-color: rgba(52, 199, 89, 0.35);
        color: inherit;
        padding: 1px 2px;
        border-radius: 2px;
        cursor: pointer;
        -webkit-tap-highlight-color: rgba(52, 199, 89, 0.25);
    }
    @media (prefers-color-scheme: dark) {
        mark.user-note-highlight {
            background-color: rgba(48, 209, 88, 0.30);
        }
    }
    """
}

// MARK: - Injected notes script (text quote + mark)

extension MarkdownRenderer {
    fileprivate static let notesJS = """
    <script>
    (function() {
    function scriptStyleFilter(node) {
        let p = node.parentElement;
        while (p) {
            const t = p.tagName;
            if (t === 'SCRIPT' || t === 'STYLE' || t === 'NOSCRIPT') return NodeFilter.FILTER_REJECT;
            p = p.parentElement;
        }
        return NodeFilter.FILTER_ACCEPT;
    }

    function bodyPlainString() {
        const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, { acceptNode: scriptStyleFilter });
        let s = '';
        while (w.nextNode()) s += w.currentNode.textContent;
        return s;
    }

    function plainOffsetForBoundary(container, offset) {
        if (container.nodeType === Node.TEXT_NODE) {
            const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, { acceptNode: scriptStyleFilter });
            let pos = 0;
            while (w.nextNode()) {
                const n = w.currentNode;
                if (n === container) return pos + Math.min(offset, n.textContent.length);
                pos += n.textContent.length;
            }
        }
        const r = document.createRange();
        r.setStart(document.body, 0);
        r.setEnd(container, offset);
        return r.toString().length;
    }

    function nearestHeadingId(range) {
        let n = range.commonAncestorContainer;
        if (n.nodeType !== Node.ELEMENT_NODE) n = n.parentElement;
        while (n && n !== document.body) {
            if (n.tagName && /^H[1-6]$/i.test(n.tagName)) {
                return n.id || null;
            }
            n = n.parentElement;
        }
        return null;
    }

    function getSelectionPayload() {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return null;
        const range = sel.getRangeAt(0);
        if (range.collapsed) return null;
        const start = plainOffsetForBoundary(range.startContainer, range.startOffset);
        const end = plainOffsetForBoundary(range.endContainer, range.endOffset);
        const full = bodyPlainString();
        if (start > end || end > full.length) return null;
        const exact = full.substring(start, end);
        if (!exact.trim()) return null;
        const prefix = full.substring(Math.max(0, start - 64), start);
        const suffix = full.substring(end, Math.min(full.length, end + 64));
        const headingId = nearestHeadingId(range);
        return JSON.stringify({ exact: exact, prefix: prefix, suffix: suffix, headingId: headingId });
    }

    function stripUserNoteHighlights() {
        document.querySelectorAll('mark.user-note-highlight').forEach(function(m) {
            const parent = m.parentNode;
            if (!parent) return;
            while (m.firstChild) parent.insertBefore(m.firstChild, m);
            parent.removeChild(m);
            parent.normalize();
        });
    }

    function findQuoteInPlain(full, exact, prefix, suffix) {
        const needle = prefix + exact + suffix;
        let i = full.indexOf(needle);
        if (i >= 0) {
            return { start: i + prefix.length, end: i + prefix.length + exact.length };
        }
        i = full.indexOf(exact);
        if (i < 0) return null;
        const j = full.indexOf(exact, i + 1);
        if (j >= 0) return null;
        return { start: i, end: i + exact.length };
    }

    function createRangeForPlainIndices(start, end) {
        const full = bodyPlainString();
        if (end > full.length || start < 0 || start > end) return null;
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, { acceptNode: scriptStyleFilter });
        let acc = 0;
        let startNode = null, startOff = 0, endNode = null, endOff = 0;
        let foundStart = false;
        while (walker.nextNode()) {
            const n = walker.currentNode;
            const len = n.textContent.length;
            const next = acc + len;
            if (!foundStart && next > start) {
                startNode = n;
                startOff = start - acc;
                foundStart = true;
            }
            if (next >= end) {
                endNode = n;
                endOff = end - acc;
                break;
            }
            acc = next;
        }
        if (!startNode || !endNode) return null;
        try {
            const r = document.createRange();
            r.setStart(startNode, Math.min(Math.max(0, startOff), startNode.textContent.length));
            r.setEnd(endNode, Math.min(Math.max(0, endOff), endNode.textContent.length));
            return r;
        } catch (e) { return null; }
    }

    function applyNotesFromBase64(b64) {
        stripUserNoteHighlights();
        if (!b64) return;
        let items;
        try {
            const bin = atob(b64);
            const bytes = new Uint8Array(bin.length);
            for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            const json = new TextDecoder().decode(bytes);
            items = JSON.parse(json);
        } catch (e) { return; }
        if (!Array.isArray(items)) return;
        const full = bodyPlainString();
        const sorted = items.map(function(item) {
            const a = item.anchor || {};
            const pos = findQuoteInPlain(full, a.exact || '', a.prefix || '', a.suffix || '');
            return { item: item, pos: pos };
        }).filter(function(x) { return x.pos !== null; })
          .sort(function(a, b) { return b.pos.start - a.pos.start; });
        sorted.forEach(function(entry) {
            const id = entry.item.id;
            const a = entry.item.anchor || {};
            const pos = entry.pos;
            const range = createRangeForPlainIndices(pos.start, pos.end);
            if (!range) return;
            try {
                const mark = document.createElement('mark');
                mark.className = 'user-note-highlight';
                mark.setAttribute('data-note-id', id);
                range.surroundContents(mark);
            } catch (e) {
                try {
                    const contents = range.extractContents();
                    const mark = document.createElement('mark');
                    mark.className = 'user-note-highlight';
                    mark.setAttribute('data-note-id', id);
                    mark.appendChild(contents);
                    range.insertNode(mark);
                } catch (e2) {}
            }
        });
    }

    function scrollToUserNote(noteId) {
        const id = String(noteId).replace(/\\\\/g, '').replace(/"/g, '');
        const el = document.querySelector('mark.user-note-highlight[data-note-id="' + id + '"]');
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }

    function installNoteHighlightTapHandler() {
        if (window.__noteTapInstalled) return;
        window.__noteTapInstalled = true;
        document.body.addEventListener('click', function(ev) {
            let el = ev.target;
            if (el.nodeType === Node.TEXT_NODE) el = el.parentElement;
            const mark = el && el.closest ? el.closest('mark.user-note-highlight[data-note-id]') : null;
            if (!mark) return;
            ev.preventDefault();
            ev.stopPropagation();
            const id = mark.getAttribute('data-note-id');
            if (!id) return;
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.noteHighlightTap) {
                window.webkit.messageHandlers.noteHighlightTap.postMessage({ noteId: id });
            }
        }, true);
    }
    installNoteHighlightTapHandler();

    window.noteFunctions = {
        getSelectionPayload: getSelectionPayload,
        applyNotesFromBase64: applyNotesFromBase64,
        stripUserNoteHighlights: stripUserNoteHighlights,
        scrollToUserNote: scrollToUserNote
    };
    })();
    </script>
    """
}

// MARK: - WKWebView (selection menu: “Dodaj notatkę”)

/// Subclass so `buildMenu(with:)` runs on the same view WebKit uses for the text edit menu.
private final class MarkdownWKWebView: WKWebView {
    var onAddNoteFromSelection: (() -> Void)?

    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard onAddNoteFromSelection != nil else { return }
        let addNote = UIAction(
            title: "Dodaj notatkę",
            image: UIImage(systemName: "square.and.pencil")
        ) { [weak self] _ in
            self?.onAddNoteFromSelection?()
        }
        let inline = UIMenu(title: "", options: .displayInline, children: [addNote])
        builder.insertSibling(inline, afterMenu: .standardEdit)
    }
}

// MARK: - WKWebView Wrapper

struct MarkdownWebView: UIViewRepresentable {
    let html: String
    @Binding var scrollToID: String?
    let onSearchResults: (Int, Int) -> Void
    let onCoordinatorReady: (Coordinator) -> Void
    /// Called on the main queue when `loadHTMLString` navigation finishes (document ready to display).
    let onDocumentLoaded: (() -> Void)?
    /// Shown in the system text selection menu next to Copy, Look Up, etc.
    var onAddNoteFromContextMenu: (() -> Void)?
    /// User tapped a green `mark.user-note-highlight` in the document.
    var onNoteHighlightTap: ((String) -> Void)?

    init(html: String,
         scrollToID: Binding<String?>,
         onSearchResults: @escaping (Int, Int) -> Void = { _, _ in },
         onCoordinatorReady: @escaping (Coordinator) -> Void = { _ in },
         onDocumentLoaded: (() -> Void)? = nil,
         onAddNoteFromContextMenu: (() -> Void)? = nil,
         onNoteHighlightTap: ((String) -> Void)? = nil) {
        self.html = html
        self._scrollToID = scrollToID
        self.onSearchResults = onSearchResults
        self.onCoordinatorReady = onCoordinatorReady
        self.onDocumentLoaded = onDocumentLoaded
        self.onAddNoteFromContextMenu = onAddNoteFromContextMenu
        self.onNoteHighlightTap = onNoteHighlightTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "searchResults")
        config.userContentController.add(context.coordinator, name: "noteHighlightTap")
        let webView = MarkdownWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.searchResultsHandler = onSearchResults
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        syncAddNoteHandler(webView, context: context)
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            onCoordinatorReady(coordinator)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.searchResultsHandler = onSearchResults
        if let md = webView as? MarkdownWKWebView {
            syncAddNoteHandler(md, context: context)
        }

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

    private func syncAddNoteHandler(_ webView: MarkdownWKWebView, context: Context) {
        let coord = context.coordinator
        webView.onAddNoteFromSelection = { [weak coord] in
            guard let coord else { return }
            coord.parent.onAddNoteFromContextMenu?()
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "searchResults")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "noteHighlightTap")
        (uiView as? MarkdownWKWebView)?.onAddNoteFromSelection = nil
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

        // MARK: Notes (highlights)

        private struct NoteHighlightPayload: Encodable {
            let id: String
            let anchor: Anchor
            struct Anchor: Encodable {
                let exact: String
                let prefix: String
                let suffix: String
                let headingId: String?
            }
        }

        func applyUserNotes(_ notes: [DocumentNote]) {
            guard isPageReady else { return }
            let payload = notes.map {
                NoteHighlightPayload(
                    id: $0.id,
                    anchor: .init(
                        exact: $0.anchor.exact,
                        prefix: $0.anchor.prefix,
                        suffix: $0.anchor.suffix,
                        headingId: $0.anchor.headingId
                    )
                )
            }
            guard let data = try? JSONEncoder().encode(payload) else { return }
            let b64 = data.base64EncodedString()
            webView?.evaluateJavaScript("window.noteFunctions.applyNotesFromBase64('\(b64)');")
        }

        func getSelectionTextQuote(completion: @escaping (TextQuoteAnchor?) -> Void) {
            webView?.evaluateJavaScript("window.noteFunctions.getSelectionPayload();") { result, _ in
                guard let json = result as? String,
                      let data = json.data(using: .utf8) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                struct SelectionPayload: Decodable {
                    let exact: String
                    let prefix: String
                    let suffix: String
                    let headingId: String?
                }
                guard let decoded = try? JSONDecoder().decode(SelectionPayload.self, from: data) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let anchor = TextQuoteAnchor(
                    exact: decoded.exact,
                    prefix: decoded.prefix,
                    suffix: decoded.suffix,
                    headingId: decoded.headingId
                )
                DispatchQueue.main.async { completion(anchor) }
            }
        }

        func scrollToUserNote(id: String) {
            let escaped = id
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView?.evaluateJavaScript("window.noteFunctions.scrollToUserNote('\(escaped)');")
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "searchResults":
                guard let body = message.body as? [String: Any],
                      let count = body["count"] as? Int,
                      let currentIndex = body["currentIndex"] as? Int else { return }
                DispatchQueue.main.async { self.searchResultsHandler?(count, currentIndex) }
            case "noteHighlightTap":
                guard let body = message.body as? [String: Any],
                      let noteId = body["noteId"] as? String else { return }
                DispatchQueue.main.async { self.parent.onNoteHighlightTap?(noteId) }
            default:
                break
            }
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
    /// When opened from Moje akty, keeps the same note store as the on-disk file.
    private let favoriteDocumentId: String?
    private let bundleResourceName: String?

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

    // Notes
    @ObservedObject private var notesManager = NotesManager.shared
    @ObservedObject private var appStateManager = AppStateManager.shared
    @State private var showNotesSheet = false
    @State private var noteEditorSheet: NoteEditorSheetState?
    @State private var newNoteText = ""
    @State private var noSelectionAlert = false

    init(resourceName: String) {
        self.title = resourceName
        self.markdownURL = Bundle.main.url(forResource: resourceName, withExtension: "md")
        self.eli = nil
        self.favoriteDocumentId = nil
        self.bundleResourceName = resourceName
    }

    init(title: String, fileURL: URL, favoriteDocumentId: String? = nil) {
        self.title = title
        self.markdownURL = fileURL
        self.eli = nil
        self.favoriteDocumentId = favoriteDocumentId
        self.bundleResourceName = nil
    }

    init(title: String, eli: String) {
        self.title = title
        self.markdownURL = nil
        self.eli = eli
        self.favoriteDocumentId = nil
        self.bundleResourceName = nil
    }

    /// Canonical key for persisted notes (ELI, favorite id, file path, or bundle name).
    private var effectiveDocumentKey: String {
        NotesManager.effectiveDocumentKey(
            title: title,
            favoriteDocumentId: favoriteDocumentId,
            eli: eli,
            markdownURL: markdownURL,
            bundleResourceName: bundleResourceName,
            isFavorited: isFavorited,
            favoritesManager: favoritesManager
        )
    }

    /// Spotlight + coach mark for the table-of-contents control (only when the document has headings).
    private var showMDNavigationHelpOverlay: Bool {
        appStateManager.shouldShowMDNavigationHelp && !tocEntries.isEmpty
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
                                refreshNoteHighlights()
                            },
                            onAddNoteFromContextMenu: {
                                tryAddNoteFromSelection()
                            },
                            onNoteHighlightTap: { noteId in
                                guard let note = notesManager.note(id: noteId) else { return }
                                newNoteText = note.noteText
                                noteEditorSheet = .editing(note)
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
                Button {
                    showNotesSheet = true
                } label: {
                    Image(systemName: "note.text")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !tocEntries.isEmpty {
                    Button {
                        showTOC = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: showMDNavigationHelpOverlay ? 18 : 16, weight: showMDNavigationHelpOverlay ? .semibold : .medium))
                            .foregroundStyle(showMDNavigationHelpOverlay ? Color.blue : Color.primary)
                    }
                    .anchorPreference(key: MDViewerHelpAnchorPreferenceKey.self, value: .bounds) { [.tableOfContentsButton: $0] }
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
                notes: notesManager.notes(forDocumentKey: effectiveDocumentKey),
                onAddFromSelection: {
                    showNotesSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        tryAddNoteFromSelection()
                    }
                },
                onSelectNote: { note in
                    webViewCoordinator?.scrollToUserNote(id: note.id)
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
                    refreshNoteHighlights()
                }
            )
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
            "Czy na pewno chcesz usunąć ze Swoich Akt? Stracisz również notatki w dokumencie.",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Tak", role: .destructive) {
                removeFromFavorites()
            }
            Button("Nie", role: .cancel) { }
        }
        .alert("Zaznacz fragment tekstu w dokumencie", isPresented: $noSelectionAlert) {
            Button("OK", role: .cancel) {}
        }
        .overlayPreferenceValue(MDViewerHelpAnchorPreferenceKey.self) { anchors in
            MDViewerNavigationHelpOverlay(
                anchors: anchors,
                isVisible: showMDNavigationHelpOverlay,
                onComplete: {
                    appStateManager.markMDNavigationHelpSeen()
                }
            )
        }
        .onChange(of: isLoading) { _, loading in
            if !loading, tocEntries.isEmpty, appStateManager.shouldShowMDNavigationHelp {
                appStateManager.markMDNavigationHelpSeen()
            }
        }
        .onAppear {
            loadMarkdown()
            checkFavoriteStatus()
        }
    }

    private func refreshNoteHighlights() {
        let list = notesManager.notes(forDocumentKey: effectiveDocumentKey)
        webViewCoordinator?.applyUserNotes(list)
    }

    private func tryAddNoteFromSelection() {
        webViewCoordinator?.getSelectionTextQuote { anchor in
            guard let anchor else {
                noSelectionAlert = true
                return
            }
            newNoteText = ""
            noteEditorSheet = .newNote(anchor: anchor, draftId: UUID())
        }
    }

    private func saveNoteEditor(state: NoteEditorSheetState) {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = effectiveDocumentKey
        switch state {
        case .newNote(let anchor, _):
            let note = DocumentNote(documentKey: key, noteText: trimmed, anchor: anchor)
            notesManager.add(note)
            noteEditorSheet = nil
            newNoteText = ""
            Task { @MainActor in
                let isFav = await notesManager.ensureActInFavoritesAndMigrateNotesIfNeeded(
                    title: title,
                    eli: eli,
                    markdownURL: markdownURL,
                    favoritesManager: favoritesManager
                )
                if isFav { isFavorited = true }
                refreshNoteHighlights()
            }
        case .editing(var note):
            note.noteText = trimmed
            notesManager.update(note)
            noteEditorSheet = nil
            newNoteText = ""
            refreshNoteHighlights()
        }
    }

    private func loadMarkdown() {
        Task {
            do {
                let markdown = try await NotesManager.loadMarkdownString(markdownURL: markdownURL, eli: eli)
                let extractedTOC = MarkdownRenderer.extractTOC(from: markdown)
                let html = MarkdownRenderer.toHTML(markdown)
                await MainActor.run {
                    self.tocEntries = extractedTOC
                    self.htmlContent = html
                }
            } catch NotesManager.ActMarkdownError.noDocumentSource {
                await MainActor.run {
                    self.errorMessage = "Nie znaleziono pliku."
                    self.isLoading = false
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
        Task { @MainActor in
            guard let data = await NotesManager.loadMarkdownData(markdownURL: markdownURL, eli: eli) else {
                return
            }
            favoritesManager.addFavorite(title: title, pdfData: data, fileExtension: "md")
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
