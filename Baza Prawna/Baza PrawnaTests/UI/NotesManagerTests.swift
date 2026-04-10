//
//  NotesManagerTests.swift
//  Baza PrawnaTests
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct NotesManagerTests {

    private let prefix = "test.nm."

    // MARK: - Document key helpers

    @Test("documentKey variants encode namespaces")
    func testDocumentKeyFormats() {
        #expect(NotesManager.documentKey(eli: "DU/2024/1") == "eli:DU/2024/1")
        let url = URL(fileURLWithPath: "/tmp/doc.md")
        #expect(NotesManager.documentKey(fileURL: url) == "file:/tmp/doc.md")
        #expect(NotesManager.documentKey(bundleResourceName: "x") == "bundle:x")
        #expect(NotesManager.documentKey(favoriteId: "fid") == "favorite:fid")
    }

    @Test("pdfNotesDocumentKey prefers favorite, then eli, then celex, then title slug")
    func testPdfNotesDocumentKeyPriority() {
        #expect(
            NotesManager.pdfNotesDocumentKey(title: "Any", favoriteDocumentId: "f1", eli: "E", celex: "C")
            == "pdfdoc:favorite:f1"
        )
        #expect(
            NotesManager.pdfNotesDocumentKey(title: "Any", favoriteDocumentId: nil, eli: "E", celex: "C")
            == "pdfdoc:eli:E"
        )
        #expect(
            NotesManager.pdfNotesDocumentKey(title: "Any", favoriteDocumentId: "", eli: nil, celex: "C")
            == "pdfdoc:celex:C"
        )
        let slug = NotesManager.pdfNotesDocumentKey(title: "Hello World!", favoriteDocumentId: nil, eli: nil, celex: nil)
        #expect(slug.hasPrefix("pdfdoc:title:"))
        #expect(slug.contains("hello"))
    }

    @Test("effectiveDocumentKey uses favorite id when provided")
    func testEffectiveDocumentKeyFavoriteId() {
        let fm = FavoritesManager.shared
        let key = NotesManager.effectiveDocumentKey(
            title: "T",
            favoriteDocumentId: "fid-1",
            eli: "DU/1/1",
            markdownURL: nil,
            bundleResourceName: nil,
            isFavorited: false,
            favoritesManager: fm
        )
        #expect(key == "favorite:fid-1")
    }

    @Test("effectiveDocumentKey uses ELI when no favorite id")
    func testEffectiveDocumentKeyEli() {
        let fm = FavoritesManager.shared
        let key = NotesManager.effectiveDocumentKey(
            title: "T",
            favoriteDocumentId: nil,
            eli: "DU/2024/5",
            markdownURL: nil,
            bundleResourceName: nil,
            isFavorited: false,
            favoritesManager: fm
        )
        #expect(key == "eli:DU/2024/5")
    }

    // MARK: - CRUD + migration

    @Test("notes(forDocumentKey:) sorts newest first")
    func testNotesSortedByCreatedAt() async throws {
        let docKey = "\(prefix)sort"
        NotesTestHelpers.removeNotes(documentKeyPrefix: prefix)
        defer { NotesTestHelpers.removeNotes(documentKeyPrefix: prefix) }

        let older = Date().addingTimeInterval(-100)
        let newer = Date()
        let a = TextQuoteAnchor(exact: "a", prefix: "", suffix: "")
        let n1 = DocumentNote(id: "\(docKey)-1", documentKey: docKey, createdAt: older, noteText: "1", anchor: a)
        let n2 = DocumentNote(id: "\(docKey)-2", documentKey: docKey, createdAt: newer, noteText: "2", anchor: a)
        NotesManager.shared.add(n1)
        NotesManager.shared.add(n2)
        let list = NotesManager.shared.notes(forDocumentKey: docKey)
        #expect(list.map(\.noteText) == ["2", "1"])
    }

    @Test("update replaces note text")
    func testUpdateNote() {
        let docKey = "\(prefix)upd"
        NotesTestHelpers.removeNotes(documentKeyPrefix: prefix)
        defer { NotesTestHelpers.removeNotes(documentKeyPrefix: prefix) }

        let anchor = TextQuoteAnchor(exact: "q", prefix: "", suffix: "")
        var note = DocumentNote(id: "\(docKey)-u1", documentKey: docKey, noteText: "old", anchor: anchor)
        NotesManager.shared.add(note)
        note.noteText = "new"
        NotesManager.shared.update(note)
        #expect(NotesManager.shared.note(id: note.id)?.noteText == "new")
    }

    @Test("migrateNotes moves notes between keys")
    func testMigrateNotes() {
        let oldK = "\(prefix)old"
        let newK = "\(prefix)new"
        NotesTestHelpers.removeNotes(documentKeyPrefix: prefix)
        defer { NotesTestHelpers.removeNotes(documentKeyPrefix: prefix) }

        let anchor = TextQuoteAnchor(exact: "q", prefix: "", suffix: "")
        NotesManager.shared.add(DocumentNote(id: "\(oldK)-m1", documentKey: oldK, noteText: "x", anchor: anchor))
        NotesManager.shared.migrateNotes(from: oldK, to: newK)
        #expect(NotesManager.shared.notes(forDocumentKey: oldK).isEmpty)
        #expect(NotesManager.shared.notes(forDocumentKey: newK).count == 1)
    }

    @Test("DocumentNote round-trips Codable")
    func testDocumentNoteCodable() throws {
        let anchor = TextQuoteAnchor(exact: "e", prefix: "p", suffix: "s", headingId: "h1", pdfPageIndex: 2)
        let original = DocumentNote(
            id: "id-1",
            documentKey: "eli:X",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            noteText: "hello",
            tags: ["a", "b"],
            anchor: anchor
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DocumentNote.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Auto-favorite + note key migration (MDViewer / PDFViewer flows)

    @Test("ensureActInFavoritesAndMigrateNotesIfNeeded saves markdown to favorites and migrates eli: notes")
    func testEnsureActAddsFavoriteAndMigratesNotes() async throws {
        let p = "\(prefix)auto.md."
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        NotesTestHelpers.removeNotes(documentKeyPrefix: p)

        let title = "Auto Favorite MD \(UUID().uuidString.prefix(6))"
        let eli = "DU/2026/4242"
        let eliKey = NotesManager.documentKey(eli: eli)
        let anchor = TextQuoteAnchor(exact: "q", prefix: "", suffix: "")
        NotesManager.shared.add(
            DocumentNote(id: "\(p)n1", documentKey: eliKey, noteText: "body", anchor: anchor)
        )

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(p)\(UUID().uuidString).md")
        try "# Treść\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let ok = await NotesManager.shared.ensureActInFavoritesAndMigrateNotesIfNeeded(
            title: title,
            eli: eli,
            markdownURL: tmp,
            favoritesManager: FavoritesManager.shared
        )
        #expect(ok)
        #expect(FavoritesManager.shared.isFavorite(title: title, fileExtension: "md"))

        guard let fid = FavoritesManager.shared.getFavoriteID(title: title, fileExtension: "md") else {
            NotesTestHelpers.removeNotes(documentKeyPrefix: p)
            FavoritesTestUtilities.clearAllFavorites()
            return
        }
        let favKey = NotesManager.documentKey(favoriteId: fid)
        #expect(NotesManager.shared.notes(forDocumentKey: favKey).count == 1)
        #expect(NotesManager.shared.notes(forDocumentKey: eliKey).isEmpty)

        NotesTestHelpers.removeNotes(documentKeyPrefix: p)
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
    }

    @Test("ensurePDFInFavoritesAndMigrateNotesIfNeeded saves PDF to favorites and migrates pdfdoc notes")
    func testEnsurePDFFavoriteAndMigratesPdfNotes() async throws {
        let p = "\(prefix)auto.pdf."
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        NotesTestHelpers.removeNotes(documentKeyPrefix: p)

        let title = "Auto Favorite PDF \(UUID().uuidString.prefix(6))"
        let pdfEli = "DU/2025/100"
        let oldKey = NotesManager.pdfNotesDocumentKey(
            title: title,
            favoriteDocumentId: nil,
            eli: pdfEli,
            celex: nil
        )
        let anchor = TextQuoteAnchor(exact: "Test PDF", prefix: "", suffix: "", headingId: nil, pdfPageIndex: 0)
        NotesManager.shared.add(
            DocumentNote(id: "\(p)n1", documentKey: oldKey, noteText: "pdf note", anchor: anchor)
        )

        let pdfData = FavoritesTestUtilities.createTestPDFData()
        let ok = await NotesManager.shared.ensurePDFInFavoritesAndMigrateNotesIfNeeded(
            title: title,
            favoriteDocumentIdWhenOpened: nil,
            pdfEli: pdfEli,
            pdfCelex: nil,
            pdfData: pdfData,
            favoritesManager: FavoritesManager.shared
        )
        #expect(ok)
        #expect(FavoritesManager.shared.isFavorite(title: title, fileExtension: "pdf"))

        guard let fid = FavoritesManager.shared.getFavoriteID(title: title, fileExtension: "pdf") else {
            NotesTestHelpers.removeNotes(documentKeyPrefix: p)
            FavoritesTestUtilities.clearAllFavorites()
            return
        }
        let newKey = NotesManager.pdfNotesDocumentKey(
            title: title,
            favoriteDocumentId: fid,
            eli: nil,
            celex: nil
        )
        #expect(NotesManager.shared.notes(forDocumentKey: newKey).count == 1)
        #expect(NotesManager.shared.notes(forDocumentKey: oldKey).isEmpty)

        NotesTestHelpers.removeNotes(documentKeyPrefix: p)
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
    }
}
