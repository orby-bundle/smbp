//
//  NotesManager.swift
//  Baza Prawna
//

import Foundation
import Combine

// MARK: - Text quote anchor (Web Annotation style)

struct TextQuoteAnchor: Codable, Equatable {
    var exact: String
    var prefix: String
    var suffix: String
    var headingId: String?
}

// MARK: - Document note

struct DocumentNote: Identifiable, Codable, Equatable {
    var id: String
    var documentKey: String
    var createdAt: Date
    var noteText: String
    var tags: [String]
    var anchor: TextQuoteAnchor

    init(
        id: String = UUID().uuidString,
        documentKey: String,
        createdAt: Date = Date(),
        noteText: String,
        tags: [String] = [],
        anchor: TextQuoteAnchor
    ) {
        self.id = id
        self.documentKey = documentKey
        self.createdAt = createdAt
        self.noteText = noteText
        self.tags = tags
        self.anchor = anchor
    }
}

// MARK: - NotesManager

@MainActor
final class NotesManager: ObservableObject {
    static let shared = NotesManager()

    @Published private(set) var notes: [DocumentNote] = []

    private let fileManager = FileManager.default
    private let fileURL: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("BazaPrawna", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("document_notes.json", isDirectory: false)
        loadFromDisk()
    }

    // MARK: - Document key helpers

    static func documentKey(eli: String) -> String {
        "eli:\(eli)"
    }

    static func documentKey(fileURL: URL) -> String {
        "file:\(fileURL.path)"
    }

    static func documentKey(bundleResourceName: String) -> String {
        "bundle:\(bundleResourceName)"
    }

    static func documentKey(favoriteId: String) -> String {
        "favorite:\(favoriteId)"
    }

    /// Single source of truth for which storage key notes use (favorite id, ELI, file path, or bundle).
    static func effectiveDocumentKey(
        title: String,
        favoriteDocumentId: String?,
        eli: String?,
        markdownURL: URL?,
        bundleResourceName: String?,
        isFavorited: Bool,
        favoritesManager: FavoritesManager
    ) -> String {
        if let favoriteDocumentId {
            return documentKey(favoriteId: favoriteDocumentId)
        }
        if eli != nil, isFavorited, let fid = favoritesManager.getFavoriteID(title: title) {
            return documentKey(favoriteId: fid)
        }
        if let eli {
            return documentKey(eli: eli)
        }
        if let url = markdownURL {
            return documentKey(fileURL: url)
        }
        if let name = bundleResourceName {
            return documentKey(bundleResourceName: name)
        }
        return "unknown"
    }

    // MARK: - Act markdown loading (shared by MD viewer, favorites star, note auto-save)

    enum ActMarkdownError: Error {
        case noDocumentSource
    }

    /// Raw markdown bytes (file read, or ELI cache / download). Returns nil on failure for ELI network path.
    nonisolated static func loadMarkdownData(markdownURL: URL?, eli: String?) async -> Data? {
        if let url = markdownURL {
            return try? Data(contentsOf: url)
        }
        guard let eli else { return nil }
        let cacheKey = "md_\(eli)"
        if let cachedData = await CacheManager.shared.data(forKey: cacheKey, category: .persistentMD) {
            return cachedData
        }
        do {
            let url = try await FirebaseManager.shared.getMarkdownDownloadURL(for: eli)
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            try? await CacheManager.shared.storeData(data, forKey: cacheKey, category: .persistentMD)
            return data
        } catch {
            return nil
        }
    }

    /// UTF-8 markdown for rendering (throws if there is no file/ELI source, or on I/O / HTTP errors).
    nonisolated static func loadMarkdownString(markdownURL: URL?, eli: String?) async throws -> String {
        if let url = markdownURL {
            return try String(contentsOf: url, encoding: .utf8)
        }
        guard let eli else {
            throw ActMarkdownError.noDocumentSource
        }
        let cacheKey = "md_\(eli)"
        if let cachedData = await CacheManager.shared.data(forKey: cacheKey, category: .persistentMD),
           let decoded = String(data: cachedData, encoding: .utf8) {
            return decoded
        }
        let url = try await FirebaseManager.shared.getMarkdownDownloadURL(for: eli)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        try? await CacheManager.shared.storeData(data, forKey: cacheKey, category: .persistentMD)
        return decoded
    }

    // MARK: - Queries

    func notes(forDocumentKey key: String) -> [DocumentNote] {
        notes.filter { $0.documentKey == key }.sorted { $0.createdAt > $1.createdAt }
    }

    func note(id: String) -> DocumentNote? {
        notes.first { $0.id == id }
    }

    // MARK: - Mutations

    func add(_ note: DocumentNote) {
        var next = notes
        next.append(note)
        persist(next)
    }

    func update(_ note: DocumentNote) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var next = notes
        next[idx] = note
        persist(next)
    }

    func remove(id: String) {
        var next = notes
        next.removeAll { $0.id == id }
        persist(next)
    }

    /// Moves all notes from one document key to another (e.g. after favoriting an ELI-sourced act).
    func migrateNotes(from oldKey: String, to newKey: String) {
        guard oldKey != newKey else { return }
        var next = notes
        var changed = false
        for i in next.indices where next[i].documentKey == oldKey {
            next[i].documentKey = newKey
            changed = true
        }
        if changed {
            persist(next)
        }
    }

    // MARK: - Private

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DocumentNote].self, from: data) else {
            return
        }
        notes = decoded
    }

    private func persist(_ all: [DocumentNote]) {
        do {
            let data = try JSONEncoder().encode(all)
            try data.write(to: fileURL, options: .atomic)
            notes = all
        } catch {
            notes = all
        }
    }

    // MARK: - Favorites sync (after saving a note)

    /// Ensures the markdown file is in Moje akty when the user adds a note, and migrates note keys from `eli:` to `favorite:` when applicable.
    /// - Returns: Whether the document is now listed as a favorite (for the star button).
    func ensureActInFavoritesAndMigrateNotesIfNeeded(
        title: String,
        eli: String?,
        markdownURL: URL?,
        favoritesManager: FavoritesManager
    ) async -> Bool {
        if favoritesManager.isFavorite(title: title) {
            migrateEliNotesToFavoriteIfNeeded(eli: eli, title: title, favoritesManager: favoritesManager)
            return true
        }
        guard let data = await Self.loadMarkdownData(markdownURL: markdownURL, eli: eli) else {
            return false
        }
        favoritesManager.addFavorite(title: title, pdfData: data, fileExtension: "md")
        migrateEliNotesToFavoriteIfNeeded(eli: eli, title: title, favoritesManager: favoritesManager)
        return true
    }

    private func migrateEliNotesToFavoriteIfNeeded(
        eli: String?,
        title: String,
        favoritesManager: FavoritesManager
    ) {
        guard let eli else { return }
        guard let fid = favoritesManager.getFavoriteID(title: title) else { return }
        migrateNotes(from: Self.documentKey(eli: eli), to: Self.documentKey(favoriteId: fid))
    }
}
