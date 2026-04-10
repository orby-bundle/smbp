//
//  FavouritesViewTests.swift
//  Baza PrawnaTests
//
//  Smoke and data-precondition tests for FavouritesView.swift (view uses FavoritesManager.shared).
//

import Testing
@testable import Baza_Prawna
import SwiftUI
import Foundation

@MainActor
struct FavouritesViewTests {

    @Test("FavoritesView builds without crashing")
    func testFavoritesViewBuilds() {
        let view = FavoritesView()
        let mirror = Mirror(reflecting: view)
        #expect(mirror.subjectType == FavoritesView.self)
    }

    @Test("Empty favorites matches empty-state branch inputs")
    func testEmptyStateMatchesManager() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        let manager = FavoritesManager.shared
        #expect(manager.favorites.isEmpty)
        #expect(manager.folders.isEmpty)
        // FavoritesView shows star empty copy when both are empty
        let view = FavoritesView()
        _ = view
    }

    @Test("Non-empty favorites implies list branch")
    func testNonEmptyFavoritesShowsContentPath() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        let manager = FavoritesManager.shared
        manager.addFavorite(title: "Listed Doc", pdfData: FavoritesTestUtilities.createTestPDFData())
        await FavoritesTestUtilities.waitForAsyncOperations()
        #expect(!manager.favorites.isEmpty)
        let view = FavoritesView()
        _ = view
    }

    /// When the user saves a note on an act that is not yet in Moje akty, `NotesManager.ensureActInFavoritesAndMigrateNotesIfNeeded` adds the markdown file automatically (see MDViewer).
    @Test("Auto-added markdown favorite appears like any other favorite for FavoritesView data")
    func testNotedMarkdownActAppearsInFavoritesList() async throws {
        let p = "favview.auto.md."
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        NotesTestHelpers.removeNotes(documentKeyPrefix: p)

        let title = "Fav View MD \(UUID().uuidString.prefix(6))"
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(p)\(UUID().uuidString).md")
        try "# Notatka\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let ok = await NotesManager.shared.ensureActInFavoritesAndMigrateNotesIfNeeded(
            title: title,
            eli: nil,
            markdownURL: tmp,
            favoritesManager: FavoritesManager.shared
        )
        #expect(ok)

        let manager = FavoritesManager.shared
        #expect(manager.isFavorite(title: title, fileExtension: "md"))
        #expect(manager.favorites.contains { $0.title == title && $0.resolvedFileType == "md" })

        NotesTestHelpers.removeNotes(documentKeyPrefix: p)
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
    }
}
