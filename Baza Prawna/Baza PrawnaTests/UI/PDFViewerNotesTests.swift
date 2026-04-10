//
//  PDFViewerNotesTests.swift
//  Baza PrawnaTests
//
//  PDFKit note bridge and quote resolution (UnifiedPDFViewer / PDFViewer note-taking path).
//

import Testing
@testable import Baza_Prawna
import Foundation
import PDFKit

@MainActor
struct PDFViewerNotesTests {

    @Test("PDFKitNoteBridge applies highlight annotations for a note with page index")
    func testApplyUserNotesAddsAnnotations() {
        let data = FavoritesTestUtilities.createTestPDFData()
        let document = PDFDocument(data: data)
        #expect(document != nil)
        guard let document, let page = document.page(at: 0) else { return }

        let before = page.annotations.count
        let anchor = TextQuoteAnchor(
            exact: "Test PDF",
            prefix: "",
            suffix: "",
            headingId: nil,
            pdfPageIndex: 0
        )
        let note = DocumentNote(
            id: "pdf-note-1",
            documentKey: "pdfdoc:eli:TEST/1",
            noteText: "comment",
            anchor: anchor
        )

        let bridge = PDFKitNoteBridge()
        bridge.applyUserNotes([note], document: document)

        #expect(page.annotations.count > before)
    }

    @Test("PDFKitNoteBridge clear + reapply is idempotent for same notes")
    func testApplyUserNotesTwiceReplacesHighlights() {
        let data = FavoritesTestUtilities.createTestPDFData()
        let document = PDFDocument(data: data)
        #expect(document != nil)
        guard let document, let page = document.page(at: 0) else { return }

        let anchor = TextQuoteAnchor(
            exact: "Test PDF",
            prefix: "",
            suffix: "",
            headingId: nil,
            pdfPageIndex: 0
        )
        let note = DocumentNote(
            id: "pdf-note-2",
            documentKey: "pdfdoc:test",
            noteText: "c",
            anchor: anchor
        )
        let bridge = PDFKitNoteBridge()
        bridge.applyUserNotes([note], document: document)
        let afterFirst = page.annotations.count
        bridge.applyUserNotes([note], document: document)
        #expect(page.annotations.count == afterFirst)
    }

    @Test("PDFKitNoteBridge scrollToUserNote does not crash when selection resolves")
    func testScrollToUserNoteWithResolvedQuote() {
        let data = FavoritesTestUtilities.createTestPDFData()
        let document = PDFDocument(data: data)
        #expect(document != nil)
        guard let document else { return }

        let anchor = TextQuoteAnchor(
            exact: "Test PDF",
            prefix: "",
            suffix: "",
            headingId: nil,
            pdfPageIndex: 0
        )
        let note = DocumentNote(
            id: "pdf-note-3",
            documentKey: "k",
            noteText: "c",
            anchor: anchor
        )
        let bridge = PDFKitNoteBridge()
        bridge.scrollToUserNote(note, document: document)
    }
}
