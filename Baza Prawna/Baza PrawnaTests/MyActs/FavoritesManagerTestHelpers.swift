//
//  FavoritesManagerTestHelpers.swift
//  Baza PrawnaTests
//
//  Created for testing FavoritesManager functionality
//

import Foundation
@testable import Baza_Prawna

// MARK: - Test Errors

enum FavoritesTestError: Error {
    case favoriteNotFound
    case folderNotFound
    case invalidState
    case fileOperationFailed
}

// MARK: - Test UserDefaults Management

class FavoritesTestUserDefaults {
    static let suiteName = "com.bazaprawna.favoritestests"
    private let userDefaults: UserDefaults
    
    init() {
        // Use a test suite to avoid interfering with app data
        if let testDefaults = UserDefaults(suiteName: Self.suiteName) {
            self.userDefaults = testDefaults
        } else {
            // Fallback to standard if suite creation fails
            self.userDefaults = UserDefaults.standard
        }
        clearAll()
    }
    
    func clearAll() {
        // Clear all test keys
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        userDefaults.synchronize()
    }
    
    var instance: UserDefaults {
        return userDefaults
    }
}

// MARK: - Test File Management

class FavoritesTestFileManager {
    private let fileManager = FileManager.default
    private let tempDirectory: URL
    
    init() throws {
        // Create a temporary directory for test files
        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("FavoritesTests_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)
        self.tempDirectory = testDir
    }
    
    func cleanup() {
        try? fileManager.removeItem(at: tempDirectory)
    }
    
    var directory: URL {
        return tempDirectory
    }
    
    func createTestPDFData() -> Data {
        // Create minimal valid PDF data for testing
        // This is a minimal PDF structure
        let pdfContent = """
        %PDF-1.4
        1 0 obj
        <<
        /Type /Catalog
        /Pages 2 0 R
        >>
        endobj
        2 0 obj
        <<
        /Type /Pages
        /Kids [3 0 R]
        /Count 1
        >>
        endobj
        3 0 obj
        <<
        /Type /Page
        /Parent 2 0 R
        /MediaBox [0 0 612 792]
        /Contents 4 0 R
        /Resources <<
        /Font <<
        /F1 5 0 R
        >>
        >>
        >>
        endobj
        4 0 obj
        <<
        /Length 44
        >>
        stream
        BT
        /F1 12 Tf
        100 700 Td
        (Test PDF) Tj
        ET
        endstream
        endobj
        5 0 obj
        <<
        /Type /Font
        /Subtype /Type1
        /BaseFont /Helvetica
        >>
        endobj
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000306 00000 n
        0000000440 00000 n
        trailer
        <<
        /Size 6
        /Root 1 0 R
        >>
        startxref
        527
        %%EOF
        """
        return pdfContent.data(using: .utf8) ?? Data()
    }
    
    func createTestFile(at url: URL, data: Data) throws {
        try data.write(to: url)
    }
    
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    func removeFile(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

// MARK: - Favorites Test Factory

struct FavoritesTestFactory {
    
    /// Creates a test FavoriteFolder with default values
    static func createFolder(
        id: String = UUID().uuidString,
        name: String = "Test Folder",
        dateCreated: Date = Date(),
        color: String = "#007AFF"
    ) -> FavoriteFolder {
        return FavoriteFolder(
            id: id,
            name: name,
            dateCreated: dateCreated,
            color: color
        )
    }
    
    /// Creates a test FavoriteDocument with default values
    static func createDocument(
        id: String = UUID().uuidString,
        title: String = "Test Document",
        dateAdded: Date = Date(),
        fileName: String? = nil,
        folderId: String? = nil
    ) -> FavoriteDocument {
        let file = fileName ?? "\(id).pdf"
        return FavoriteDocument(
            id: id,
            title: title,
            dateAdded: dateAdded,
            fileName: file,
            folderId: folderId
        )
    }
    
    /// Creates multiple test folders
    static func createFolders(count: Int) -> [FavoriteFolder] {
        return (0..<count).map { index in
            createFolder(name: "Test Folder \(index + 1)")
        }
    }
    
    /// Creates multiple test documents
    static func createDocuments(count: Int, folderId: String? = nil) -> [FavoriteDocument] {
        return (0..<count).map { index in
            createDocument(title: "Test Document \(index + 1)", folderId: folderId)
        }
    }
}

// MARK: - Test Utilities

struct FavoritesTestUtilities {
    
    /// Clears all favorites and folders from FavoritesManager (for test cleanup)
    @MainActor
    static func clearAllFavorites() {
        let manager = FavoritesManager.shared
        
        // Clear in-memory arrays by deleting through public API
        // We'll delete all folders first (which will delete their documents)
        let folderIds = manager.folders.map { $0.id }
        for folderId in folderIds {
            manager.deleteFolder(id: folderId)
        }
        
        // Delete remaining root documents
        let rootDocumentIds = manager.favorites.map { $0.id }
        for documentId in rootDocumentIds {
            manager.removeFavorite(id: documentId)
        }
        
        // Clear UserDefaults to ensure clean state
        UserDefaults.standard.removeObject(forKey: "favoritePDFs")
        UserDefaults.standard.removeObject(forKey: "favoriteFolders")
        UserDefaults.standard.synchronize()
    }
    
    /// Clears favorites directory files (for test cleanup)
    static func clearFavoritesDirectory() throws {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let favoritesDirectory = documentsDirectory.appendingPathComponent("favorites", isDirectory: true)
        
        if fileManager.fileExists(atPath: favoritesDirectory.path) {
            let contents = try fileManager.contentsOfDirectory(at: favoritesDirectory, includingPropertiesForKeys: nil)
            for file in contents {
                try fileManager.removeItem(at: file)
            }
        }
    }
    
    /// Waits for async operations to complete (for testing)
    static func wait(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    /// Waits for FavoritesManager async operations to complete
    @MainActor
    static func waitForAsyncOperations() async {
        // Small delay to let Tasks complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    /// Waits longer for cleanup operations to complete
    @MainActor
    static func waitForCleanup() async {
        // Longer delay for cleanup operations
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    /// Creates test PDF data
    static func createTestPDFData() -> Data {
        let pdfContent = """
        %PDF-1.4
        1 0 obj
        <<
        /Type /Catalog
        /Pages 2 0 R
        >>
        endobj
        2 0 obj
        <<
        /Type /Pages
        /Kids [3 0 R]
        /Count 1
        >>
        endobj
        3 0 obj
        <<
        /Type /Page
        /Parent 2 0 R
        /MediaBox [0 0 612 792]
        /Contents 4 0 R
        /Resources <<
        /Font <<
        /F1 5 0 R
        >>
        >>
        >>
        endobj
        4 0 obj
        <<
        /Length 44
        >>
        stream
        BT
        /F1 12 Tf
        100 700 Td
        (Test PDF) Tj
        ET
        endstream
        endobj
        5 0 obj
        <<
        /Type /Font
        /Subtype /Type1
        /BaseFont /Helvetica
        >>
        endobj
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000306 00000 n
        0000000440 00000 n
        trailer
        <<
        /Size 6
        /Root 1 0 R
        >>
        startxref
        527
        %%EOF
        """
        return pdfContent.data(using: .utf8) ?? Data()
    }
    
    /// Verifies that a file exists at the given URL
    static func verifyFileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Verifies that a file does not exist at the given URL
    static func verifyFileNotExists(at url: URL) -> Bool {
        return !FileManager.default.fileExists(atPath: url.path)
    }
}

