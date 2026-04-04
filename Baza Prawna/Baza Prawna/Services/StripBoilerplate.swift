import Foundation

/// Utility that preserves the meaningful HTML body while stripping boilerplate wrappers.
///
/// The cleaner removes:
/// - DOCTYPE declarations
/// - HTML comments
/// - Entire `<head>` sections (metadata, scripts, stylesheets)
/// - Embedded `<script>`, `<style>`, `<link>`, `<meta>`, `<noscript>`, `<iframe>`, `<object>`, and `<embed>` blocks
/// - Common HTML entities (&nbsp;, &mdash;, &ndash;, &hellip;, &quot;, &apos;, &#39;, &rsquo;, &lsquo;, &rdquo;, &ldquo;, &laquo;, &raquo;, &amp;) are normalised
///
/// All other markup—including `<body>` contents, headings, tables, paragraphs, and footnotes—is untouched so
/// downstream processors receive the full document text without layout/analytics boilerplate.
struct StripBoilerplate {
    static func cleaned(html: String) -> String {
        var result = html
        remove(pattern: "(?is)<!DOCTYPE.*?>", from: &result)
        remove(pattern: "(?is)<!--.*?-->", from: &result)
        remove(pattern: "(?is)<head.*?</head>", from: &result)
        remove(pattern: "(?is)<script\\b.*?</script>", from: &result)
        remove(pattern: "(?is)<style\\b.*?</style>", from: &result)
        remove(pattern: "(?is)<link\\b[^>]*?>", from: &result)
        remove(pattern: "(?is)<meta\\b[^>]*?>", from: &result)
        remove(pattern: "(?is)<noscript\\b.*?</noscript>", from: &result)
        remove(pattern: "(?is)<iframe\\b.*?</iframe>", from: &result)
        remove(pattern: "(?is)<object\\b.*?</object>", from: &result)
        remove(pattern: "(?is)<embed\\b.*?</embed>", from: &result)
        replaceHTMLEntities(in: &result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func remove(pattern: String, from text: inout String) {
        text = text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
    }
    
    private static func replaceHTMLEntities(in text: inout String) {
        let replacements: [String: String] = [
            "&nbsp;": " ",
            "&nbsp": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "...",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&rsquo;": "'",
            "&lsquo;": "'",
            "&rdquo;": "\"",
            "&ldquo;": "\"",
            "&laquo;": "«",
            "&raquo;": "»"
        ]
        replacements.forEach { key, value in
            text = text.replacingOccurrences(of: key, with: value)
        }
    }
}
