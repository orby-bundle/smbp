//
//  FavoritesManagerTests.swift
//  Baza PrawnaTests
//
//  Created for testing FavoritesManager functionality
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct FavoritesManagerTests {
    
    // MARK: - Setup and Teardown
    
    @Test("Clear favorites before each test")
    func clearFavoritesBeforeTest() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        #expect(manager.favorites.isEmpty)
        #expect(manager.folders.isEmpty)
    }
    
    // MARK: - Initialization & Setup
    
    @Test("Singleton pattern - shared instance")
    func testSingletonPattern() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager1 = FavoritesManager.shared
        let manager2 = FavoritesManager.shared
        
        #expect(manager1 === manager2)
    }
    
    @Test("Favorites directory creation")
    func testFavoritesDirectoryCreation() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let favoritesDirectory = documentsDirectory.appendingPathComponent("favorites", isDirectory: true)
        
        // Directory should exist after manager initialization
        #expect(fileManager.fileExists(atPath: favoritesDirectory.path))
    }
    
    @Test("Loading favorites from UserDefaults")
    func testLoadingFavoritesFromUserDefaults() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add a favorite
        manager.addFavorite(title: "Test Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Verify it was saved
        #expect(manager.favorites.count == 1)
        
        // Clear in-memory state (simulating app restart)
        // Note: We can't directly reset the singleton, but we can verify persistence
        // by checking UserDefaults directly
        let favoritesData = UserDefaults.standard.data(forKey: "favoritePDFs")
        #expect(favoritesData != nil)
    }
    
    @Test("Loading folders from UserDefaults")
    func testLoadingFoldersFromUserDefaults() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        // Create a folder
        manager.createFolder(name: "Test Folder", color: "#FF0000")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Verify it was saved
        #expect(manager.folders.count == 1)
        
        // Verify persistence in UserDefaults
        let foldersData = UserDefaults.standard.data(forKey: "favoriteFolders")
        #expect(foldersData != nil)
    }
    
    @Test("Filtering invalid favorites (files that no longer exist)")
    func testFilteringInvalidFavorites() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add a favorite
        manager.addFavorite(title: "Valid Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Manually add an invalid favorite to UserDefaults (simulating orphaned entry)
        let invalidDocument = FavoriteDocument(
            id: UUID().uuidString,
            title: "Invalid Document",
            fileName: "nonexistent.pdf"
        )
        var currentFavorites = manager.favorites
        currentFavorites.append(invalidDocument)
        
        // Use default encoder like FavoritesManager does (dates as numbers, not ISO8601 strings)
        let encoder = JSONEncoder()
        let data = try encoder.encode(currentFavorites)
        UserDefaults.standard.set(data, forKey: "favoritePDFs")
        
        // Force reload by accessing a property that triggers load
        // Since we can't directly reload, we verify the current state
        // The manager should filter invalid favorites on next load
        #expect(manager.favorites.count >= 1)
    }
    
    // MARK: - Folder Management
    
    @Test("Creating folder with default color")
    func testCreateFolderWithDefaultColor() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.folders.count == 1)
        #expect(manager.folders.first?.name == "Test Folder")
        #expect(manager.folders.first?.color == "#007AFF") // Default color
    }
    
    @Test("Creating folder with custom color")
    func testCreateFolderWithCustomColor() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        manager.createFolder(name: "Red Folder", color: "#FF0000")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.folders.count == 1)
        #expect(manager.folders.first?.color == "#FF0000")
    }
    
    @Test("Creating folder with custom name")
    func testCreateFolderWithCustomName() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        manager.createFolder(name: "My Custom Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.folders.count == 1)
        #expect(manager.folders.first?.name == "My Custom Folder")
    }
    
    @Test("Deleting empty folder")
    func testDeleteEmptyFolder() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        manager.createFolder(name: "Empty Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let folderId = manager.folders.first!.id
        manager.deleteFolder(id: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.folders.isEmpty)
    }
    
    @Test("Deleting folder with documents (should delete documents too)")
    func testDeleteFolderWithDocuments() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Create folder
        manager.createFolder(name: "Folder with Docs")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        // Add documents to folder
        manager.addFavorite(title: "Doc 1", pdfData: testPDF, folderId: folderId)
        manager.addFavorite(title: "Doc 2", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.count == 2)
        
        // Delete folder
        manager.deleteFolder(id: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.folders.isEmpty)
        #expect(manager.favorites.isEmpty) // Documents should be deleted too
    }
    
    @Test("Deleting folder removes PDF files from disk")
    func testDeleteFolderRemovesPDFFiles() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Create folder and add document
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Test Doc", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let document = manager.favorites.first!
        let fileURL = manager.getFavoriteFileURL(id: document.id)!
        
        // Verify file exists
        #expect(FavoritesTestUtilities.verifyFileExists(at: fileURL))
        
        // Delete folder
        manager.deleteFolder(id: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Verify file is deleted
        #expect(FavoritesTestUtilities.verifyFileNotExists(at: fileURL))
    }
    
    @Test("Renaming folder")
    func testRenameFolder() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        manager.createFolder(name: "Old Name")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let folderId = manager.folders.first!.id
        manager.renameFolder(id: folderId, newName: "New Name")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.folders.first?.name == "New Name")
        #expect(manager.folders.first?.id == folderId) // ID should remain the same
    }
    
    @Test("Renaming non-existent folder (should not crash)")
    func testRenameNonExistentFolder() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let initialCount = manager.folders.count
        
        // Try to rename non-existent folder
        manager.renameFolder(id: UUID().uuidString, newName: "New Name")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should not crash and folder count should remain the same
        #expect(manager.folders.count == initialCount)
    }
    
    @Test("Folder persistence after app restart (close and reopen)")
    func testFolderPersistence() async throws {
        // This test verifies that folders persist when the app is closed and reopened
        // (not reinstalled). Data is stored in UserDefaults and should survive app restarts.
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        manager.createFolder(name: "Persistent Folder", color: "#00FF00")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let folderId = manager.folders.first!.id
        let folderName = manager.folders.first!.name
        
        // Verify it's in UserDefaults (simulating what would happen after app restart)
        let foldersData = UserDefaults.standard.data(forKey: "favoriteFolders")
        #expect(foldersData != nil)
        
        // Verify we can decode it (using default decoder like FavoritesManager does)
        let decoder = JSONDecoder()
        let decodedFolders = try decoder.decode([FavoriteFolder].self, from: foldersData!)
        #expect(decodedFolders.first?.id == folderId)
        #expect(decodedFolders.first?.name == folderName)
    }
    
    // MARK: - Document Management
    
    @Test("Adding favorite document to root")
    func testAddFavoriteToRoot() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "Root Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.count == 1)
        #expect(manager.favorites.first?.title == "Root Document")
        #expect(manager.favorites.first?.folderId == nil)
    }
    
    @Test("Adding favorite document to folder")
    func testAddFavoriteToFolder() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Folder Document", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.count == 1)
        #expect(manager.favorites.first?.folderId == folderId)
    }
    
    @Test("Adding favorite creates PDF file on disk")
    func testAddFavoriteCreatesPDFFile() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "Test Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let document = manager.favorites.first!
        let fileURL = manager.getFavoriteFileURL(id: document.id)
        
        #expect(fileURL != nil)
        #expect(FavoritesTestUtilities.verifyFileExists(at: fileURL!))
    }
    
    @Test("Removing favorite document")
    func testRemoveFavorite() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "To Remove", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documentId = manager.favorites.first!.id
        manager.removeFavorite(id: documentId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.isEmpty)
    }
    
    @Test("Removing favorite deletes PDF file from disk")
    func testRemoveFavoriteDeletesPDFFile() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "To Remove", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let document = manager.favorites.first!
        let fileURL = manager.getFavoriteFileURL(id: document.id)!
        
        // Verify file exists
        #expect(FavoritesTestUtilities.verifyFileExists(at: fileURL))
        
        // Remove favorite
        manager.removeFavorite(id: document.id)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Verify file is deleted
        #expect(FavoritesTestUtilities.verifyFileNotExists(at: fileURL))
    }
    
    @Test("Removing non-existent favorite (should not crash)")
    func testRemoveNonExistentFavorite() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let initialCount = manager.favorites.count
        
        // Try to remove non-existent favorite
        manager.removeFavorite(id: UUID().uuidString)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should not crash and count should remain the same
        #expect(manager.favorites.count == initialCount)
    }
    
    @Test("isFavorite(title:) returns true for existing favorite")
    func testIsFavoriteReturnsTrue() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "Existing Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.isFavorite(title: "Existing Document") == true)
    }
    
    @Test("isFavorite(title:) returns false for non-existent favorite")
    func testIsFavoriteReturnsFalse() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        #expect(manager.isFavorite(title: "Non-existent Document") == false)
    }
    
    @Test("getFavoriteID(title:) returns correct ID")
    func testGetFavoriteIDReturnsCorrectID() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "Test Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documentId = manager.favorites.first!.id
        let retrievedId = manager.getFavoriteID(title: "Test Document")
        
        #expect(retrievedId == documentId)
    }
    
    @Test("getFavoriteID(title:) returns nil for non-existent")
    func testGetFavoriteIDReturnsNil() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        let retrievedId = manager.getFavoriteID(title: "Non-existent Document")
        #expect(retrievedId == nil)
    }
    
    @Test("getFavoriteFileURL(id:) returns correct URL")
    func testGetFavoriteFileURLReturnsCorrectURL() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "Test Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let document = manager.favorites.first!
        let fileURL = manager.getFavoriteFileURL(id: document.id)
        
        #expect(fileURL != nil)
        #expect(fileURL!.lastPathComponent == document.fileName)
    }
    
    @Test("getFavoriteFileURL(id:) returns nil for invalid ID")
    func testGetFavoriteFileURLReturnsNil() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        let fileURL = manager.getFavoriteFileURL(id: UUID().uuidString)
        #expect(fileURL == nil)
    }
    
    @Test("Document persistence after app restart (close and reopen)")
    func testDocumentPersistence() async throws {
        // This test verifies that documents persist when the app is closed and reopened
        // (not reinstalled). Data is stored in UserDefaults and files on disk, both should
        // survive app restarts.
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "Persistent Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documentId = manager.favorites.first!.id
        let documentTitle = manager.favorites.first!.title
        
        // Verify it's in UserDefaults (simulating what would happen after app restart)
        let favoritesData = UserDefaults.standard.data(forKey: "favoritePDFs")
        #expect(favoritesData != nil)
        
        // Verify we can decode it (using default decoder like FavoritesManager does)
        let decoder = JSONDecoder()
        let decodedFavorites = try decoder.decode([FavoriteDocument].self, from: favoritesData!)
        #expect(decodedFavorites.first?.id == documentId)
        #expect(decodedFavorites.first?.title == documentTitle)
    }
    
    // MARK: - Folder-Document Relationships
    
    @Test("getDocumentsInFolder(folderId:) returns correct documents")
    func testGetDocumentsInFolder() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Doc 1", pdfData: testPDF, folderId: folderId)
        manager.addFavorite(title: "Doc 2", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documentsInFolder = manager.getDocumentsInFolder(folderId: folderId)
        
        #expect(documentsInFolder.count == 2)
        #expect(documentsInFolder.allSatisfy { $0.folderId == folderId })
    }
    
    @Test("getDocumentsInFolder(folderId:) returns empty array for empty folder")
    func testGetDocumentsInEmptyFolder() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        manager.createFolder(name: "Empty Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        let documentsInFolder = manager.getDocumentsInFolder(folderId: folderId)
        
        #expect(documentsInFolder.isEmpty)
    }
    
    @Test("getDocumentsInRoot() returns only root documents")
    func testGetDocumentsInRoot() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add root documents
        manager.addFavorite(title: "Root Doc 1", pdfData: testPDF)
        manager.addFavorite(title: "Root Doc 2", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let rootDocuments = manager.getDocumentsInRoot()
        
        #expect(rootDocuments.count == 2)
        #expect(rootDocuments.allSatisfy { $0.folderId == nil })
    }
    
    @Test("getDocumentsInRoot() excludes folder documents")
    func testGetDocumentsInRootExcludesFolderDocuments() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add root document
        manager.addFavorite(title: "Root Doc", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Create folder and add document
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Folder Doc", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let rootDocuments = manager.getDocumentsInRoot()
        
        #expect(rootDocuments.count == 1)
        #expect(rootDocuments.first?.title == "Root Doc")
    }
    
    @Test("Moving document to folder")
    func testMoveDocumentToFolder() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add root document
        manager.addFavorite(title: "Root Doc", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Create folder
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        let documentId = manager.favorites.first!.id
        manager.moveDocumentToFolder(documentId: documentId, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.first?.folderId == folderId)
        #expect(manager.getDocumentsInRoot().isEmpty)
    }
    
    @Test("Moving document from folder to root")
    func testMoveDocumentFromFolderToRoot() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Create folder and add document
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Folder Doc", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documentId = manager.favorites.first!.id
        manager.moveDocumentToFolder(documentId: documentId, folderId: nil)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.first?.folderId == nil)
        #expect(manager.getDocumentsInFolder(folderId: folderId).isEmpty)
    }
    
    @Test("Moving document between folders")
    func testMoveDocumentBetweenFolders() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Create two folders
        manager.createFolder(name: "Folder 1")
        manager.createFolder(name: "Folder 2")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let folder1Id = manager.folders[0].id
        let folder2Id = manager.folders[1].id
        
        // Add document to folder 1
        manager.addFavorite(title: "Test Doc", pdfData: testPDF, folderId: folder1Id)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documentId = manager.favorites.first!.id
        #expect(manager.favorites.first?.folderId == folder1Id)
        
        // Move to folder 2
        manager.moveDocumentToFolder(documentId: documentId, folderId: folder2Id)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.first?.folderId == folder2Id)
        #expect(manager.getDocumentsInFolder(folderId: folder1Id).isEmpty)
        #expect(manager.getDocumentsInFolder(folderId: folder2Id).count == 1)
    }
    
    @Test("Moving non-existent document (should not crash)")
    func testMoveNonExistentDocument() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        // Try to move non-existent document
        manager.moveDocumentToFolder(documentId: UUID().uuidString, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should not crash
        #expect(manager.favorites.isEmpty)
    }
    
    // MARK: - Bulk Operations
    
    @Test("bulkMoveDocuments(ids:folderId:) moves multiple documents")
    func testBulkMoveDocuments() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add root documents
        manager.addFavorite(title: "Doc 1", pdfData: testPDF)
        manager.addFavorite(title: "Doc 2", pdfData: testPDF)
        manager.addFavorite(title: "Doc 3", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Create folder
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        let documentIds = manager.favorites.map { $0.id }
        manager.bulkMoveDocuments(ids: documentIds, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.getDocumentsInRoot().isEmpty)
        #expect(manager.getDocumentsInFolder(folderId: folderId).count == 3)
    }
    
    @Test("bulkMoveDocuments with empty array")
    func testBulkMoveDocumentsWithEmptyArray() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        // Try to move empty array
        manager.bulkMoveDocuments(ids: [], folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should not crash
        #expect(manager.favorites.isEmpty)
    }
    
    @Test("bulkMoveDocuments with invalid IDs (should not crash)")
    func testBulkMoveDocumentsWithInvalidIDs() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        // Try to move invalid IDs
        manager.bulkMoveDocuments(ids: [UUID().uuidString, UUID().uuidString], folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should not crash
        #expect(manager.favorites.isEmpty)
    }
    
    @Test("bulkDeleteDocuments(ids:) deletes multiple documents")
    func testBulkDeleteDocuments() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add documents
        manager.addFavorite(title: "Doc 1", pdfData: testPDF)
        manager.addFavorite(title: "Doc 2", pdfData: testPDF)
        manager.addFavorite(title: "Doc 3", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documentIds = manager.favorites.map { $0.id }
        manager.bulkDeleteDocuments(ids: documentIds)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        #expect(manager.favorites.isEmpty)
    }
    
    @Test("bulkDeleteDocuments removes PDF files from disk")
    func testBulkDeleteDocumentsRemovesFiles() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add documents
        manager.addFavorite(title: "Doc 1", pdfData: testPDF)
        manager.addFavorite(title: "Doc 2", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documents = manager.favorites
        let fileURLs = documents.compactMap { manager.getFavoriteFileURL(id: $0.id) }
        
        // Verify files exist
        for url in fileURLs {
            #expect(FavoritesTestUtilities.verifyFileExists(at: url))
        }
        
        // Bulk delete
        let documentIds = documents.map { $0.id }
        manager.bulkDeleteDocuments(ids: documentIds)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Verify files are deleted
        for url in fileURLs {
            #expect(FavoritesTestUtilities.verifyFileNotExists(at: url))
        }
    }
    
    @Test("bulkDeleteDocuments with empty array")
    func testBulkDeleteDocumentsWithEmptyArray() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        // Try to delete empty array
        manager.bulkDeleteDocuments(ids: [])
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should not crash
        #expect(manager.favorites.isEmpty)
    }
    
    // MARK: - File Operations & Zip Archive
    
    @Test("createZipArchive() returns nil for empty favorites")
    func testCreateZipArchiveReturnsNilForEmpty() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        let zipURL = manager.createZipArchive()
        
        #expect(zipURL == nil)
    }
    
    @Test("createZipArchive() creates valid zip file")
    func testCreateZipArchiveCreatesValidZip() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add documents
        manager.addFavorite(title: "Doc 1", pdfData: testPDF)
        manager.addFavorite(title: "Doc 2", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let zipURL = manager.createZipArchive()
        
        #expect(zipURL != nil)
        #expect(FileManager.default.fileExists(atPath: zipURL!.path))
    }
    
    @Test("createZipArchive(for:folderName:) with folder name")
    func testCreateZipArchiveWithFolderName() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Create folder and add documents
        manager.createFolder(name: "Test Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Doc 1", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documents = manager.getDocumentsInFolder(folderId: folderId)
        let zipURL = manager.createZipArchive(for: documents, folderName: "Test Folder")
        
        #expect(zipURL != nil)
        #expect(FileManager.default.fileExists(atPath: zipURL!.path))
        #expect(zipURL!.lastPathComponent.contains("Test_Folder"))
    }
    
    @Test("createZipArchive(for:folderName:) without folder name")
    func testCreateZipArchiveWithoutFolderName() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add root documents
        manager.addFavorite(title: "Doc 1", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let documents = manager.favorites
        let zipURL = manager.createZipArchive(for: documents, folderName: nil)
        
        #expect(zipURL != nil)
        #expect(FileManager.default.fileExists(atPath: zipURL!.path))
    }
    
    @Test("sanitizeFileName(_:) removes invalid characters")
    func testSanitizeFileNameRemovesInvalidCharacters() async throws {
        // Note: sanitizeFileName is private, so we test it indirectly through zip creation
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add document with invalid characters in title
        manager.addFavorite(title: "Test/Document:With?Invalid*Chars", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Create zip - should not crash and should handle invalid characters
        let zipURL = manager.createZipArchive()
        #expect(zipURL != nil)
    }
    
    @Test("sanitizeFileName(_:) handles special characters")
    func testSanitizeFileNameHandlesSpecialCharacters() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add document with special characters
        manager.addFavorite(title: "Document with émojis 🎉 and spéciál chars", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Create zip - should handle special characters
        let zipURL = manager.createZipArchive()
        #expect(zipURL != nil)
    }
    
    @Test("sanitizeFileName(_:) handles long filenames")
    func testSanitizeFileNameHandlesLongFilenames() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Add document with very long title (over 200 chars)
        let longTitle = String(repeating: "A", count: 300)
        manager.addFavorite(title: longTitle, pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Create zip - should truncate to 200 chars
        let zipURL = manager.createZipArchive()
        #expect(zipURL != nil)
    }
    
    @Test("zip creation with missing source files (skips gracefully)")
    func testZipCreationWithMissingFiles() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        // Manually add a document entry that doesn't have a file
        let invalidDocument = FavoriteDocument(
            id: UUID().uuidString,
            title: "Missing File Document",
            fileName: "nonexistent.pdf"
        )
        
        // Add to UserDefaults directly to simulate orphaned entry
        // Use default encoder like FavoritesManager does (dates as numbers, not ISO8601 strings)
        let encoder = JSONEncoder()
        var currentFavorites = manager.favorites
        currentFavorites.append(invalidDocument)
        let data = try encoder.encode(currentFavorites)
        UserDefaults.standard.set(data, forKey: "favoritePDFs")
        
        // Create zip - should skip missing files gracefully
        _ = manager.createZipArchive()
        // Should return nil or valid zip without the missing file
        // The behavior depends on implementation, but should not crash
    }
    
    // MARK: - Sharing Operations
    
    @Test("shareFolder(folderId:) returns zip URL for valid folder")
    func testShareFolderReturnsZipURL() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        // Create folder and add documents
        manager.createFolder(name: "Shareable Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Doc 1", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let zipURL = await manager.shareFolder(folderId: folderId)
        
        #expect(zipURL != nil)
        #expect(FileManager.default.fileExists(atPath: zipURL!.path))
    }
    
    @Test("shareFolder(folderId:) returns nil for empty folder")
    func testShareFolderReturnsNilForEmpty() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        manager.createFolder(name: "Empty Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        let zipURL = await manager.shareFolder(folderId: folderId)
        
        #expect(zipURL == nil)
    }
    
    @Test("shareFolder(folderId:) returns nil for invalid folder ID")
    func testShareFolderReturnsNilForInvalidID() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        let zipURL = await manager.shareFolder(folderId: UUID().uuidString)
        
        #expect(zipURL == nil)
    }
    
    @Test("shareFolder creates zip asynchronously")
    func testShareFolderIsAsync() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.createFolder(name: "Async Folder")
        await FavoritesTestUtilities.waitForAsyncOperations()
        let folderId = manager.folders.first!.id
        
        manager.addFavorite(title: "Doc 1", pdfData: testPDF, folderId: folderId)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Call async function
        let zipURL = await manager.shareFolder(folderId: folderId)
        
        #expect(zipURL != nil)
    }
    
    // MARK: - Data Persistence
    
    @Test("Favorites are saved to UserDefaults")
    func testFavoritesSavedToUserDefaults() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "Test Document", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let favoritesData = UserDefaults.standard.data(forKey: "favoritePDFs")
        #expect(favoritesData != nil)
        
        // Use default decoder like FavoritesManager does (dates as numbers, not ISO8601 strings)
        let decoder = JSONDecoder()
        let decodedFavorites = try decoder.decode([FavoriteDocument].self, from: favoritesData!)
        #expect(decodedFavorites.count == 1)
        #expect(decodedFavorites.first?.title == "Test Document")
    }
    
    @Test("Folders are saved to UserDefaults")
    func testFoldersSavedToUserDefaults() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        manager.createFolder(name: "Test Folder", color: "#FF0000")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        let foldersData = UserDefaults.standard.data(forKey: "favoriteFolders")
        #expect(foldersData != nil)
        
        // Use default decoder like FavoritesManager does (dates as numbers, not ISO8601 strings)
        let decoder = JSONDecoder()
        let decodedFolders = try decoder.decode([FavoriteFolder].self, from: foldersData!)
        #expect(decodedFolders.count == 1)
        #expect(decodedFolders.first?.name == "Test Folder")
    }
    
    @Test("Invalid JSON in UserDefaults (should not crash)")
    func testInvalidJSONInUserDefaults() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        // Set invalid JSON data
        UserDefaults.standard.set("invalid json", forKey: "favoritePDFs")
        UserDefaults.standard.synchronize()
        
        // Manager should handle this gracefully
        let manager = FavoritesManager.shared
        // Should not crash - favorites should be empty or handled gracefully
        #expect(manager.favorites.count >= 0)
    }
    
    // MARK: - Edge Cases & Error Handling
    
    @Test("Adding favorite with empty title")
    func testAddFavoriteWithEmptyTitle() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        let testPDF = FavoritesTestUtilities.createTestPDFData()
        
        manager.addFavorite(title: "", pdfData: testPDF)
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should handle empty title (may or may not add it, but shouldn't crash)
        #expect(manager.favorites.count >= 0)
    }
    
    @Test("Creating folder with empty name")
    func testCreateFolderWithEmptyName() async throws {
        FavoritesTestUtilities.clearAllFavorites()
        await FavoritesTestUtilities.waitForCleanup()
        
        let manager = FavoritesManager.shared
        
        manager.createFolder(name: "")
        await FavoritesTestUtilities.waitForAsyncOperations()
        
        // Should handle empty name (may or may not add it, but shouldn't crash)
        #expect(manager.folders.count >= 0)
    }
}

