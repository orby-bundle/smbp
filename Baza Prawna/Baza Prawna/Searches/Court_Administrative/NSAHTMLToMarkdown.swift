//
//  NSAHTMLToMarkdown.swift
//  Baza Prawna
//
//  Created by Cursor on 15/04/2026.
//

import Foundation

/// Best-effort converter for NSA stripped HTML fragments (`API_NSAService.getStrippedJudgmentHTML`).
/// Goal: stable, readable markdown that `MDViewer` can render (TOC/search/notes/share/favourites).
enum NSAHTMLToMarkdown {
    static func convert(_ strippedHTML: String) -> String {
        var s = strippedHTML

        // Normalize newlines early.
        s = s.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")

        // Remove scripts/styles defensively.
        s = s.replacingOccurrences(
            of: "(?is)<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        s = s.replacingOccurrences(
            of: "(?is)<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Convert line breaks and paragraphs/divs into paragraph spacing.
        s = s.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</p\\s*>", with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<p\\b[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</div\\s*>", with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<div\\b[^>]*>", with: "", options: .regularExpression)

        // Headings.
        for level in (1...6).reversed() {
            let open = "(?i)<h\(level)\\b[^>]*>"
            let close = "(?i)</h\(level)\\s*>"
            s = s.replacingOccurrences(of: open, with: "\n\n\(String(repeating: "#", count: level)) ", options: .regularExpression)
            s = s.replacingOccurrences(of: close, with: "\n\n", options: .regularExpression)
        }

        // Lists: keep as simple bullets / numbered items. We purposely flatten nested lists.
        s = s.replacingOccurrences(of: "(?i)</li\\s*>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<li\\b[^>]*>", with: "- ", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</ul\\s*>", with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<ul\\b[^>]*>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</ol\\s*>", with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<ol\\b[^>]*>", with: "\n", options: .regularExpression)

        // Basic inline formatting.
        s = s.replacingOccurrences(of: "(?i)</(strong|b)\\s*>", with: "**", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<(strong|b)\\b[^>]*>", with: "**", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</(em|i)\\s*>", with: "*", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<(em|i)\\b[^>]*>", with: "*", options: .regularExpression)

        // Tables: naive conversion to pipes so MarkdownRenderer can pick up GFM-like structure.
        // Convert cells first.
        s = s.replacingOccurrences(of: "(?i)</t[dh]\\s*>", with: " | ", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<t[dh]\\b[^>]*>", with: "", options: .regularExpression)
        // Rows into lines.
        s = s.replacingOccurrences(of: "(?i)</tr\\s*>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<tr\\b[^>]*>", with: "| ", options: .regularExpression)
        // Drop wrappers.
        s = s.replacingOccurrences(of: "(?i)</?(table|thead|tbody)\\b[^>]*>", with: "\n", options: .regularExpression)

        // Links: keep visible text only (MDViewer will generate act links later from plain text citations).
        s = s.replacingOccurrences(of: "(?is)<a\\b[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</a\\s*>", with: "", options: .regularExpression)

        // Strip remaining tags.
        s = s.replacingOccurrences(of: "(?is)<[^>]+>", with: "", options: .regularExpression)

        // Decode common entities.
        s = decodeHTMLEntities(s)

        // Normalize whitespace: preserve newlines but collapse repeated spaces and excessive blank lines.
        s = s.replacingOccurrences(of: "[\\t\\u{00A0}]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " *\n *", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        // Ensure table separator exists for any pipe-rows (best-effort).
        s = ensureGFMTableSeparator(markdown: s)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLEntities(_ input: String) -> String {
        var s = input
        let map: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'"
        ]
        for (k, v) in map { s = s.replacingOccurrences(of: k, with: v) }
        return s
    }

    /// Inserts a simple `| --- |` separator row after a first pipe header row, when missing.
    private static func ensureGFMTableSeparator(markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var out: [String] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            out.append(line)

            let isPipeRow = line.contains("|") && line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
            if isPipeRow {
                let next = (i + 1 < lines.count) ? lines[i + 1] : ""
                let nextTrim = next.trimmingCharacters(in: .whitespaces)
                let nextLooksLikeSeparator = nextTrim.contains("---") && nextTrim.contains("|")

                if !nextLooksLikeSeparator {
                    // Build separator with same-ish number of columns.
                    let cols = max(1, line.split(separator: "|").count - 1)
                    let sep = "|" + Array(repeating: " --- |", count: cols).joined()
                    out.append(sep)
                }
            }

            i += 1
        }
        return out.joined(separator: "\n")
    }
}

