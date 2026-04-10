//
//  MDViewerNotesTests.swift
//  Baza PrawnaTests
//
//  Document key logic used by MDViewer (mirrors `effectiveDocumentKey` in MDViewer.swift).
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct MDViewerNotesTests {

    @Test("effectiveDocumentKey resolves starred ELI act to favorite id when title matches")
    func testEffectiveKeyFavoritedEliUsesFavoriteId() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()

        let title = "MDViewer Key Test Act"
        let eli = "DU/2024/99999"
        let mdBytes = "# Test markdown".data(using: .utf8)!

        let fm = FavoritesManager.shared
        fm.addFavorite(title: title, pdfData: mdBytes, fileExtension: "md")
        await FavoritesTestUtilities.waitForAsyncOperations()

        let fid = fm.getFavoriteID(title: title, fileExtension: "md")
        #expect(fid != nil)
        guard let fid else { return }

        let key = NotesManager.effectiveDocumentKey(
            title: title,
            favoriteDocumentId: nil,
            eli: eli,
            markdownURL: nil,
            bundleResourceName: nil,
            isFavorited: true,
            favoritesManager: fm
        )
        #expect(key == NotesManager.documentKey(favoriteId: fid))
    }

    @Test("effectiveDocumentKey uses file URL when no ELI")
    func testEffectiveKeyFileURL() {
        let fm = FavoritesManager.shared
        let url = URL(fileURLWithPath: "/tmp/mdviewer-test.md")
        let key = NotesManager.effectiveDocumentKey(
            title: "T",
            favoriteDocumentId: nil,
            eli: nil,
            markdownURL: url,
            bundleResourceName: nil,
            isFavorited: false,
            favoritesManager: fm
        )
        #expect(key == NotesManager.documentKey(fileURL: url))
    }

    @Test("effectiveDocumentKey uses bundle name when only bundle is set")
    func testEffectiveKeyBundle() {
        let fm = FavoritesManager.shared
        let key = NotesManager.effectiveDocumentKey(
            title: "T",
            favoriteDocumentId: nil,
            eli: nil,
            markdownURL: nil,
            bundleResourceName: "sample",
            isFavorited: false,
            favoritesManager: fm
        )
        #expect(key == NotesManager.documentKey(bundleResourceName: "sample"))
    }
}
