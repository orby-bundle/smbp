//
//  NSAHTMLToMarkdownTests.swift
//  Baza PrawnaTests
//
//  Created by Cursor on 15/04/2026.
//

import Testing
@testable import Baza_Prawna

struct NSAHTMLToMarkdownTests {
    @Test("Converts basic headings/paragraphs/lists")
    func convertsBasicBlocks() throws {
        let html = """
        <div>
          <h1>Wyrok</h1>
          <p>Dz. U. z 2020 r. poz. 1234</p>
          <ul><li>Pozycja 1</li><li><strong>Pozycja 2</strong></li></ul>
        </div>
        """
        let md = NSAHTMLToMarkdown.convert(html)
        #expect(md.contains("# Wyrok"))
        #expect(md.contains("Dz. U. z 2020 r. poz. 1234"))
        #expect(md.contains("- Pozycja 1"))
        #expect(md.contains("- **Pozycja 2**"))
    }

    @Test("Converts simple tables to pipe rows")
    func convertsTables() throws {
        let html = """
        <table>
          <tr><th>A</th><th>B</th></tr>
          <tr><td>1</td><td>2</td></tr>
        </table>
        """
        let md = NSAHTMLToMarkdown.convert(html)
        #expect(md.contains("| A | B |"))
        #expect(md.contains("---"))
        #expect(md.contains("| 1 | 2 |"))
    }
}

