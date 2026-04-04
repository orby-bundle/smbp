//
//  HTMLViewer.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - Shareable HTML Content
struct ShareableHTMLContent: Transferable {
    let htmlContent: String
    let title: String
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .html) { content in
            // Create a complete HTML document for sharing
            let completeHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>\(content.title)</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        line-height: 1.6;
                        margin: 20px;
                        color: #333;
                        background-color: #fff;
                    }
                    h1, h2, h3 {
                        color: #1a1a1a;
                        margin-top: 20px;
                        margin-bottom: 10px;
                    }
                    p {
                        margin-bottom: 10px;
                    }
                </style>
            </head>
            <body>
                <h1>\(content.title)</h1>
                \(content.htmlContent)
            </body>
            </html>
            """
            return completeHTML.data(using: .utf8) ?? Data()
        } importing: { data in
            let htmlString = String(data: data, encoding: .utf8) ?? ""
            return ShareableHTMLContent(htmlContent: htmlString, title: "Shared Document")
        }
        
        DataRepresentation(contentType: .plainText) { content in
            // Strip HTML tags for plain text sharing
            let plainText = content.htmlContent
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let formattedText = "\(content.title)\n\n\(plainText)"
            return formattedText.data(using: .utf8) ?? Data()
        } importing: { data in
            let textString = String(data: data, encoding: .utf8) ?? ""
            return ShareableHTMLContent(htmlContent: textString, title: "Shared Document")
        }
    }
}



// MARK: - HTML Content View
struct HTMLContentView: View {
    let htmlContent: String
    @Binding var isPresented: Bool
    let title: String
    let closeButtonText: String
    let initialSearchText: String
    
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var searchResultsCount = 0
    @State private var currentMatchIndex = 0
    @State private var webViewCoordinator: WebView.Coordinator?
    
    init(htmlContent: String, isPresented: Binding<Bool>, title: String = "Treść dokumentu", closeButtonText: String = "Zamknij", initialSearchText: String = "") {
        self.htmlContent = htmlContent
        self._isPresented = isPresented
        self.title = title
        self.closeButtonText = closeButtonText
        self.initialSearchText = initialSearchText
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar (shown when searching)
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
                }
                
                // WebView with search functionality
                WebView(
                    htmlContent: htmlContent,
                    searchText: searchText,
                    onSearchResults: { count, currentIndex in
                        searchResultsCount = count
                        currentMatchIndex = currentIndex
                    },
                    onCoordinatorReady: { coordinator in
                        webViewCoordinator = coordinator
                    }
                )
                
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSearch.toggle()
                        if !showingSearch {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(showingSearch ? .blue : .primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Share button
                        // ShareLink(
                        //     item: ShareableHTMLContent(htmlContent: htmlContent, title: title),
                        //     preview: SharePreview(title)
                        // ) {
                        //     Image(systemName: "square.and.arrow.up")
                        //         .font(.system(size: 16, weight: .medium))
                        // }
                        
                        // Close button
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
        }
        .onAppear {
            // If there's an initial search text, automatically perform the search
            if !initialSearchText.isEmpty {
                searchText = initialSearchText
                showingSearch = true
                // Perform search after a short delay to ensure WebView is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    webViewCoordinator?.performSearch(initialSearchText)
                }
            }
        }
    }
}

// MARK: - WebView for HTML Content
struct WebView: UIViewRepresentable {
    let htmlContent: String
    let customCSS: String?
    let maxWidth: CGFloat
    let searchText: String
    let onSearchResults: (Int, Int) -> Void
    let onCoordinatorReady: (Coordinator) -> Void
    
    init(htmlContent: String, customCSS: String? = nil, maxWidth: CGFloat = 800, searchText: String = "", onSearchResults: @escaping (Int, Int) -> Void = { _, _ in }, onCoordinatorReady: @escaping (Coordinator) -> Void = { _ in }) {
        self.htmlContent = htmlContent
        self.customCSS = customCSS
        self.maxWidth = maxWidth
        self.searchText = searchText
        self.onSearchResults = onSearchResults
        self.onCoordinatorReady = onCoordinatorReady
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.searchResultsHandler = onSearchResults
        
        // Set up message handler for search results (only once)
        // Since we're in makeUIView, the handler won't exist yet, so we can safely add it
        webView.configuration.userContentController.add(context.coordinator, name: "searchResults")
        
        onCoordinatorReady(context.coordinator)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Create a complete HTML document with proper styling and search functionality
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 17px; /* Large text size for body */
                    line-height: 1.47; /* Apple's recommended line height */
                    margin: 20px;
                    color: #1d1d1f; /* Apple's primary text color */
                    background-color: #fff;
                    -webkit-text-size-adjust: 100%; /* Prevent text size adjustment */
                }
                
                /* Apple's typography scale */
                h1 {
                    font-size: 34px;
                    font-weight: 700; /* Bold */
                    line-height: 1.12;
                    color: #1d1d1f;
                    margin-top: 24px;
                    margin-bottom: 16px;
                }
                
                h2 {
                    font-size: 28px;
                    font-weight: 600; /* Semibold */
                    line-height: 1.14;
                    color: #1d1d1f;
                    margin-top: 20px;
                    margin-bottom: 12px;
                }
                
                h3 {
                    font-size: 22px;
                    font-weight: 600; /* Semibold */
                    line-height: 1.18;
                    color: #1d1d1f;
                    margin-top: 18px;
                    margin-bottom: 10px;
                }
                
                h4 {
                    font-size: 20px;
                    font-weight: 600; /* Semibold */
                    line-height: 1.2;
                    color: #1d1d1f;
                    margin-top: 16px;
                    margin-bottom: 8px;
                }
                
                h5 {
                    font-size: 17px;
                    font-weight: 600; /* Semibold */
                    line-height: 1.29;
                    color: #1d1d1f;
                    margin-top: 14px;
                    margin-bottom: 6px;
                }
                
                h6 {
                    font-size: 15px;
                    font-weight: 600; /* Semibold */
                    line-height: 1.33;
                    color: #1d1d1f;
                    margin-top: 12px;
                    margin-bottom: 4px;
                }
                
                p {
                    font-size: 17px; /* Large text size */
                    line-height: 1.47;
                    margin-bottom: 12px;
                    color: #1d1d1f;
                }
                
                /* Small text for captions, footnotes */
                small, .caption {
                    font-size: 13px;
                    line-height: 1.38;
                    color: #6e6e73; /* Apple's secondary text color */
                }
                
                /* Medium text for subheadings */
                .subheadline {
                    font-size: 15px;
                    line-height: 1.33;
                    color: #6e6e73;
                }
                
                /* Large title for important headings */
                .large-title {
                    font-size: 34px;
                    font-weight: 400; /* Regular */
                    line-height: 1.12;
                    color: #1d1d1f;
                }
                
                /* Title for section headers */
                .title {
                    font-size: 28px;
                    font-weight: 400; /* Regular */
                    line-height: 1.14;
                    color: #1d1d1f;
                }
                
                /* Headline for important text */
                .headline {
                    font-size: 17px;
                    font-weight: 600; /* Semibold */
                    line-height: 1.29;
                    color: #1d1d1f;
                }
                
                /* Body text */
                .body {
                    font-size: 17px;
                    line-height: 1.47;
                    color: #1d1d1f;
                }
                
                /* Callout for highlighted text */
                .callout {
                    font-size: 16px;
                    line-height: 1.5;
                    color: #1d1d1f;
                }
                
                /* Footnote for small details */
                .footnote {
                    font-size: 13px;
                    line-height: 1.38;
                    color: #6e6e73;
                }
                
                /* Caption for image captions, etc. */
                .caption2 {
                    font-size: 11px;
                    line-height: 1.36;
                    color: #6e6e73;
                }
                
                .content-wrapper {
                    max-width: \(Int(maxWidth))px;
                    margin: 0 auto;
                }
                
                .search-highlight {
                    background-color: rgba(0, 122, 255, 0.3); /* Subtle blue like system selection */
                    color: inherit; /* Keep original text color */
                    padding: 1px 2px;
                    border-radius: 2px;
                }
                
                .search-highlight.current {
                    background-color: #FFD700; /* Yellow for current match */
                    color: #000;
                }
                
                /* Remove link styling */
                a, a:link, a:visited, a:hover, a:active {
                    color: inherit !important;
                    text-decoration: none !important;
                    background-color: transparent !important;
                    border: none !important;
                    outline: none !important;
                }
                
                /* Ensure no clickable elements */
                * {
                    cursor: default !important;
                }
                
                /* Allow text selection */
                body, p, div, span, h1, h2, h3, h4, h5, h6 {
                    -webkit-user-select: text;
                    -moz-user-select: text;
                    -ms-user-select: text;
                    user-select: text;
                }
                
                /* Responsive typography for smaller screens */
                @media (max-width: 768px) {
                    body {
                        font-size: 16px;
                        margin: 16px;
                    }
                    
                    h1 { font-size: 28px; }
                    h2 { font-size: 24px; }
                    h3 { font-size: 20px; }
                    h4 { font-size: 18px; }
                    h5 { font-size: 16px; }
                    h6 { font-size: 14px; }
                    
                    p { font-size: 16px; }
                }
                
                \(customCSS ?? "")
            </style>
        </head>
        <body>
            <div class="content-wrapper">
                \(htmlContent)
            </div>
            
            <script>
                let searchResults = [];
                let currentSearchIndex = 0;
                let originalContent = '';
                
                // Store original content when page loads
                document.addEventListener('DOMContentLoaded', function() {
                    // Clean hyperlinks first
                    cleanHyperlinks();
                    originalContent = document.body.innerHTML;
                });
                
                // Function to clean hyperlinks from HTML content
                function cleanHyperlinks() {
                    // Find all anchor tags
                    const links = document.querySelectorAll('a');
                    
                    links.forEach(link => {
                        // Preserve any nested formatting (bold, italic, etc.)
                        if (link.children.length > 0) {
                            // If link has nested elements, unwrap them
                            const parent = link.parentNode;
                            while (link.firstChild) {
                                parent.insertBefore(link.firstChild, link);
                            }
                            parent.removeChild(link);
                        } else {
                            // Simple case: just replace with text
                            const textNode = document.createTextNode(link.textContent);
                            link.parentNode.replaceChild(textNode, link);
                        }
                    });
                    
                    // Clean any onclick handlers
                    const elementsWithOnclick = document.querySelectorAll('[onclick]');
                    elementsWithOnclick.forEach(element => {
                        element.removeAttribute('onclick');
                    });
                    
                    // Remove any remaining href attributes
                    const elementsWithHref = document.querySelectorAll('[href]');
                    elementsWithHref.forEach(element => {
                        element.removeAttribute('href');
                    });
                    
                    // Remove any target attributes
                    const elementsWithTarget = document.querySelectorAll('[target]');
                    elementsWithTarget.forEach(element => {
                        element.removeAttribute('target');
                    });
                    
                    // Remove any rel attributes
                    const elementsWithRel = document.querySelectorAll('[rel]');
                    elementsWithRel.forEach(element => {
                        element.removeAttribute('rel');
                    });
                    
                    // Clean any JavaScript event handlers
                    const eventAttributes = ['onclick', 'onmouseover', 'onmouseout', 'onmousedown', 'onmouseup', 'onfocus', 'onblur'];
                    eventAttributes.forEach(attr => {
                        const elements = document.querySelectorAll('[' + attr + ']');
                        elements.forEach(element => {
                            element.removeAttribute(attr);
                        });
                    });
                }
                
                function performSearch(searchText) {
                    // Clear previous highlights
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
                    const walker = document.createTreeWalker(
                        document.body,
                        NodeFilter.SHOW_TEXT,
                        null,
                        false
                    );
                    
                    const textNodes = [];
                    let node;
                    while (node = walker.nextNode()) {
                        textNodes.push(node);
                    }
                    
                    textNodes.forEach(textNode => {
                        const text = textNode.textContent;
                        const regex = new RegExp(searchText.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'gi');
                        
                        if (regex.test(text)) {
                            const highlightedHTML = text.replace(regex, '<span class="search-highlight">$&</span>');
                            const wrapper = document.createElement('span');
                            wrapper.innerHTML = highlightedHTML;
                            textNode.parentNode.replaceChild(wrapper, textNode);
                        }
                    });
                }
                
                function clearHighlights() {
                    const highlights = document.querySelectorAll('.search-highlight');
                    highlights.forEach(highlight => {
                        const parent = highlight.parentNode;
                        parent.replaceChild(document.createTextNode(highlight.textContent), highlight);
                        parent.normalize();
                    });
                }
                
                function scrollToCurrentMatch() {
                    const highlights = document.querySelectorAll('.search-highlight');
                    if (highlights.length > 0 && currentSearchIndex < highlights.length) {
                        // Remove current class from all highlights
                        highlights.forEach(h => h.classList.remove('current'));
                        
                        // Add current class to the active highlight
                        const currentHighlight = highlights[currentSearchIndex];
                        currentHighlight.classList.add('current');
                        
                        // Only scroll if the highlight is not already visible in the viewport
                        const rect = currentHighlight.getBoundingClientRect();
                        const isVisible = rect.top >= 0 && rect.bottom <= window.innerHeight;
                        
                        if (!isVisible) {
                            // Scroll to the current highlight
                            currentHighlight.scrollIntoView({
                                behavior: 'smooth',
                                block: 'center'
                            });
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
                    // Send message to native code
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.searchResults) {
                        window.webkit.messageHandlers.searchResults.postMessage({
                            count: count,
                            currentIndex: currentIndex
                        });
                    }
                }
                
                // Expose functions globally for native code to call
                window.searchFunctions = {
                    performSearch: performSearch,
                    nextMatch: nextMatch,
                    previousMatch: previousMatch,
                    clearHighlights: clearHighlights
                };
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(styledHTML, baseURL: nil)
        
        // Stash pending search to run after content finishes loading
        context.coordinator.pendingSearchText = searchText
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // Remove the message handler to prevent crashes
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "searchResults")
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var searchResultsHandler: ((Int, Int) -> Void)?
        var webView: WKWebView?
        var pendingSearchText: String = ""
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "searchResults" {
                if let body = message.body as? [String: Any],
                   let count = body["count"] as? Int,
                   let currentIndex = body["currentIndex"] as? Int {
                    DispatchQueue.main.async {
                        self.searchResultsHandler?(count, currentIndex)
                    }
                }
            }
        }
        
        func performSearch(_ searchText: String) {
            let script = "window.searchFunctions.performSearch('\(searchText.replacingOccurrences(of: "'", with: "\\'"))');"
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }
        
        func nextMatch() {
            webView?.evaluateJavaScript("window.searchFunctions.nextMatch();", completionHandler: nil)
        }
        
        func previousMatch() {
            webView?.evaluateJavaScript("window.searchFunctions.previousMatch();", completionHandler: nil)
        }
        
        func clearSearch() {
            webView?.evaluateJavaScript("window.searchFunctions.clearHighlights();", completionHandler: nil)
        }

        // Ensure search executes after the HTML content is fully loaded
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !pendingSearchText.isEmpty {
                let text = pendingSearchText
                // Clear pending to avoid duplicate runs on subsequent loads
                pendingSearchText = ""
                performSearch(text)
            }
        }
    }
}

// MARK: - HTML Search Bar View
struct HTMLSearchBarView: View {
    @Binding var searchText: String
    @Binding var searchResultsCount: Int
    @Binding var currentMatchIndex: Int
    let onSearch: (String) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Search text field
            HStack {
                                
                TextField("Szukaj w tekście...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 17, weight: .regular)) /* Apple's body text size */
                    .onSubmit {
                        onSearch(searchText)
                    }
                    .onChange(of: searchText) { _, newValue in
                        onSearch(newValue)
                    }
                
                ClearSearchButton(
                    searchText: $searchText,
                    onClear: { onSearch("") }
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            
            // Search results info and navigation
            if !searchText.isEmpty && searchResultsCount > 0 {
                Text("\(currentMatchIndex + 1) z \(searchResultsCount)")
                    .font(.system(size: 13, weight: .regular)) /* Apple's footnote size */
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60)
                
                // Previous button
                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(searchResultsCount == 0)
                
                // Next button
                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(searchResultsCount == 0)
            }
            
            // Close search button
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
