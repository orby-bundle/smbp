//
//  FavoriteModelsTests.swift
//  Baza PrawnaTests
//
//  Created for testing FavoriteFolder and FavoriteDocument models
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct FavoriteModelsTests {
    
    // MARK: - FavoriteFolder Model Tests
    
    @Test("FavoriteFolder initialization with all parameters")
    func testFavoriteFolderInitWithAllParameters() async throws {
        let id = UUID().uuidString
        let name = "Test Folder"
        let dateCreated = Date()
        let color = "#FF0000"
        
        let folder = FavoriteFolder(
            id: id,
            name: name,
            dateCreated: dateCreated,
            color: color
        )
        
        #expect(folder.id == id)
        #expect(folder.name == name)
        #expect(folder.dateCreated == dateCreated)
        #expect(folder.color == color)
    }
    
    @Test("FavoriteFolder initialization with defaults")
    func testFavoriteFolderInitWithDefaults() async throws {
        let name = "Test Folder"
        let folder = FavoriteFolder(name: name)
        
        #expect(folder.name == name)
        #expect(folder.color == "#007AFF") // Default color
        #expect(!folder.id.isEmpty)
    }
    
    @Test("FavoriteFolder Codable encoding")
    func testFavoriteFolderEncoding() async throws {
        let folder = FavoriteFolder(
            id: "test-id",
            name: "Test Folder",
            dateCreated: Date(timeIntervalSince1970: 1000000),
            color: "#FF0000"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(folder)
        
        #expect(!data.isEmpty)
    }
    
    @Test("FavoriteFolder Codable decoding")
    func testFavoriteFolderDecoding() async throws {
        let originalFolder = FavoriteFolder(
            id: "test-id",
            name: "Test Folder",
            dateCreated: Date(timeIntervalSince1970: 1000000),
            color: "#FF0000"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalFolder)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedFolder = try decoder.decode(FavoriteFolder.self, from: data)
        
        #expect(decodedFolder.id == originalFolder.id)
        #expect(decodedFolder.name == originalFolder.name)
        #expect(decodedFolder.color == originalFolder.color)
        // Date comparison with tolerance
        #expect(abs(decodedFolder.dateCreated.timeIntervalSince1970 - originalFolder.dateCreated.timeIntervalSince1970) < 1.0)
    }
    
    @Test("FavoriteFolder Identifiable conformance")
    func testFavoriteFolderIdentifiable() async throws {
        let folder = FavoriteFolder(name: "Test Folder")
        
        // Verify it conforms to Identifiable
        let id: String = folder.id
        #expect(!id.isEmpty)
    }
    
    @Test("FavoriteFolder round-trip encoding/decoding")
    func testFavoriteFolderRoundTrip() async throws {
        let originalFolder = FavoriteFolder(
            id: UUID().uuidString,
            name: "Test Folder",
            dateCreated: Date(),
            color: "#00FF00"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalFolder)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedFolder = try decoder.decode(FavoriteFolder.self, from: data)
        
        #expect(decodedFolder.id == originalFolder.id)
        #expect(decodedFolder.name == originalFolder.name)
        #expect(decodedFolder.color == originalFolder.color)
    }
    
    // MARK: - FavoriteDocument Model Tests
    
    @Test("FavoriteDocument initialization with all parameters")
    func testFavoriteDocumentInitWithAllParameters() async throws {
        let id = UUID().uuidString
        let title = "Test Document"
        let dateAdded = Date()
        let fileName = "test.pdf"
        let folderId = UUID().uuidString
        
        let document = FavoriteDocument(
            id: id,
            title: title,
            dateAdded: dateAdded,
            fileName: fileName,
            folderId: folderId
        )
        
        #expect(document.id == id)
        #expect(document.title == title)
        #expect(document.dateAdded == dateAdded)
        #expect(document.fileName == fileName)
        #expect(document.folderId == folderId)
    }
    
    @Test("FavoriteDocument initialization with defaults")
    func testFavoriteDocumentInitWithDefaults() async throws {
        let title = "Test Document"
        let fileName = "test.pdf"
        let document = FavoriteDocument(title: title, fileName: fileName)
        
        #expect(document.title == title)
        #expect(document.fileName == fileName)
        #expect(document.folderId == nil) // Default is nil (root)
        #expect(!document.id.isEmpty)
    }
    
    @Test("FavoriteDocument Codable encoding")
    func testFavoriteDocumentEncoding() async throws {
        let document = FavoriteDocument(
            id: "test-id",
            title: "Test Document",
            dateAdded: Date(timeIntervalSince1970: 1000000),
            fileName: "test.pdf",
            folderId: "folder-id"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        
        #expect(!data.isEmpty)
    }
    
    @Test("FavoriteDocument Codable decoding")
    func testFavoriteDocumentDecoding() async throws {
        let originalDocument = FavoriteDocument(
            id: "test-id",
            title: "Test Document",
            dateAdded: Date(timeIntervalSince1970: 1000000),
            fileName: "test.pdf",
            folderId: "folder-id"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalDocument)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedDocument = try decoder.decode(FavoriteDocument.self, from: data)
        
        #expect(decodedDocument.id == originalDocument.id)
        #expect(decodedDocument.title == originalDocument.title)
        #expect(decodedDocument.fileName == originalDocument.fileName)
        #expect(decodedDocument.folderId == originalDocument.folderId)
        // Date comparison with tolerance
        #expect(abs(decodedDocument.dateAdded.timeIntervalSince1970 - originalDocument.dateAdded.timeIntervalSince1970) < 1.0)
    }
    
    @Test("FavoriteDocument Identifiable conformance")
    func testFavoriteDocumentIdentifiable() async throws {
        let document = FavoriteDocument(title: "Test", fileName: "test.pdf")
        
        // Verify it conforms to Identifiable
        let id: String = document.id
        #expect(!id.isEmpty)
    }
    
    @Test("FavoriteDocument with nil folderId (root document)")
    func testFavoriteDocumentWithNilFolderId() async throws {
        let document = FavoriteDocument(
            title: "Root Document",
            fileName: "root.pdf",
            folderId: nil
        )
        
        #expect(document.folderId == nil)
        #expect(document.title == "Root Document")
    }
    
    @Test("FavoriteDocument with folderId")
    func testFavoriteDocumentWithFolderId() async throws {
        let folderId = UUID().uuidString
        let document = FavoriteDocument(
            title: "Folder Document",
            fileName: "folder.pdf",
            folderId: folderId
        )
        
        #expect(document.folderId == folderId)
        #expect(document.title == "Folder Document")
    }
    
    @Test("FavoriteDocument round-trip encoding/decoding")
    func testFavoriteDocumentRoundTrip() async throws {
        let originalDocument = FavoriteDocument(
            id: UUID().uuidString,
            title: "Test Document",
            dateAdded: Date(),
            fileName: "test.pdf",
            folderId: UUID().uuidString
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalDocument)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedDocument = try decoder.decode(FavoriteDocument.self, from: data)
        
        #expect(decodedDocument.id == originalDocument.id)
        #expect(decodedDocument.title == originalDocument.title)
        #expect(decodedDocument.fileName == originalDocument.fileName)
        #expect(decodedDocument.folderId == originalDocument.folderId)
    }
    
    @Test("FavoriteDocument round-trip with nil folderId")
    func testFavoriteDocumentRoundTripWithNilFolderId() async throws {
        let originalDocument = FavoriteDocument(
            id: UUID().uuidString,
            title: "Root Document",
            dateAdded: Date(),
            fileName: "root.pdf",
            folderId: nil
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalDocument)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedDocument = try decoder.decode(FavoriteDocument.self, from: data)
        
        #expect(decodedDocument.id == originalDocument.id)
        #expect(decodedDocument.title == originalDocument.title)
        #expect(decodedDocument.folderId == nil)
    }
    
    @Test("FavoriteDocument array encoding/decoding")
    func testFavoriteDocumentArrayEncoding() async throws {
        let documents = [
            FavoriteDocument(title: "Doc 1", fileName: "doc1.pdf"),
            FavoriteDocument(title: "Doc 2", fileName: "doc2.pdf", folderId: "folder-id"),
            FavoriteDocument(title: "Doc 3", fileName: "doc3.pdf", folderId: nil)
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(documents)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedDocuments = try decoder.decode([FavoriteDocument].self, from: data)
        
        #expect(decodedDocuments.count == 3)
        #expect(decodedDocuments[0].title == "Doc 1")
        #expect(decodedDocuments[1].folderId == "folder-id")
        #expect(decodedDocuments[2].folderId == nil)
    }
    
    @Test("FavoriteFolder array encoding/decoding")
    func testFavoriteFolderArrayEncoding() async throws {
        let folders = [
            FavoriteFolder(name: "Folder 1", color: "#FF0000"),
            FavoriteFolder(name: "Folder 2", color: "#00FF00"),
            FavoriteFolder(name: "Folder 3", color: "#0000FF")
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(folders)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedFolders = try decoder.decode([FavoriteFolder].self, from: data)
        
        #expect(decodedFolders.count == 3)
        #expect(decodedFolders[0].name == "Folder 1")
        #expect(decodedFolders[1].color == "#00FF00")
        #expect(decodedFolders[2].name == "Folder 3")
    }
}

