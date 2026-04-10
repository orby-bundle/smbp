//
//  MarkdownRendererTests.swift
//  Baza PrawnaTests
//
//  Covers `MarkdownRenderer` in MDViewer.swift (TOC + HTML conversion).
//

import Testing
@testable import Baza_Prawna
import Foundation

struct MarkdownRendererTests {

    @Test("extractTOC collects ATX headings with levels")
    func testExtractTOCHeadings() {
        let md = """
        # Title One
        Intro line

        ## Section A
        - item

        ### Deep
        text
        """
        let toc = MarkdownRenderer.extractTOC(from: md)
        #expect(toc.count == 3)
        #expect(toc[0].title == "Title One")
        #expect(toc[0].level == 1)
        #expect(toc[0].id == "h0")
        #expect(toc[1].title == "Section A")
        #expect(toc[1].level == 2)
        #expect(toc[2].title == "Deep")
        #expect(toc[2].level == 3)
    }

    @Test("extractTOC ignores non-heading lines")
    func testExtractTOCskipsPlainLines() {
        let md = """
        plain
        ## Only Heading
        """
        let toc = MarkdownRenderer.extractTOC(from: md)
        #expect(toc.count == 1)
        #expect(toc[0].title == "Only Heading")
    }

    @Test("toHTML wraps headers with sequential ids")
    func testToHTMLHeadersAndIds() {
        let md = "# First\n\n## Second\n"
        let html = MarkdownRenderer.toHTML(md)
        #expect(html.contains("id=\"h0\""))
        #expect(html.contains("<h1"))
        #expect(html.contains("First"))
        #expect(html.contains("id=\"h1\""))
        #expect(html.contains("<h2"))
        #expect(html.contains("Second"))
    }

    @Test("toHTML renders unordered list")
    func testToHTMLUnorderedList() {
        let md = "- one\n- two\n"
        let html = MarkdownRenderer.toHTML(md)
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>one</li>"))
        #expect(html.contains("<li>two</li>"))
    }

    @Test("toHTML escapes ampersands in paragraph text")
    func testToHTMLEscapesAmpersand() {
        let md = "A & B"
        let html = MarkdownRenderer.toHTML(md)
        #expect(html.contains("&amp;"))
        #expect(!html.contains("A & B</p>"))
    }
}
