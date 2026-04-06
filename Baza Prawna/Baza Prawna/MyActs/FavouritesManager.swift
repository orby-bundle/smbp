//
//  FavoritesManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - FavoriteFolder Model
struct FavoriteFolder: Identifiable, Codable {
    let id: String
    let name: String
    let dateCreated: Date
    let color: String // Store color as hex string
    
    init(id: String = UUID().uuidString, name: String, dateCreated: Date = Date(), color: String = "#007AFF") {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
        self.color = color
    }
}

// MARK: - FavoriteDocument Model
struct FavoriteDocument: Identifiable, Codable {
    let id: String
    let title: String
    let dateAdded: Date
    let fileName: String // stored in Documents/favorites/
    let folderId: String? // nil for root folder
    let fileType: String? // "pdf", "md", etc. — nil defaults to "pdf" for backward compatibility
    
    var resolvedFileType: String {
        fileType ?? "pdf"
    }
    
    init(id: String = UUID().uuidString, title: String, dateAdded: Date = Date(), fileName: String, folderId: String? = nil, fileType: String? = nil) {
        self.id = id
        self.title = title
        self.dateAdded = dateAdded
        self.fileName = fileName
        self.folderId = folderId
        self.fileType = fileType
    }
}

// MARK: - FavoritesManager
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published private(set) var favorites: [FavoriteDocument] = []
    @Published private(set) var folders: [FavoriteFolder] = []
    
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let favoritesDirectory: URL
    private let favoritesKey = "favoritePDFs"
    private let foldersKey = "favoriteFolders"
    
    private init() {
        // Set up favorites directory
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.favoritesDirectory = documentsDirectory.appendingPathComponent("favorites", isDirectory: true)
        
        // Create favorites directory if it doesn't exist
        createFavoritesDirectoryIfNeeded()
        
        // Load existing favorites and folders
        loadFavorites()
        loadFolders()
    }
    
    // MARK: - Public Methods
    
    // MARK: - Folder Management
    
    func createFolder(name: String, color: String = "#007AFF") {
        let folder = FavoriteFolder(name: name, color: color)
        folders.append(folder)
        saveFolders()
    }
    
    func deleteFolder(id: String) {
        // Get all documents in this folder before deletion
        let documentsInFolder = favorites.filter { $0.folderId == id }
        
        // Delete the actual PDF files from disk
        for document in documentsInFolder {
            let fileURL = favoritesDirectory.appendingPathComponent(document.fileName)
            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                // Handle error silently
            }
        }
        
        // Remove documents from favorites list
        favorites.removeAll { $0.folderId == id }
        
        // Remove the folder
        folders.removeAll { $0.id == id }
        saveFolders()
        saveFavorites()
    }
    
    func renameFolder(id: String, newName: String) {
        if let index = folders.firstIndex(where: { $0.id == id }) {
            let folder = folders[index]
            folders[index] = FavoriteFolder(
                id: folder.id,
                name: newName,
                dateCreated: folder.dateCreated,
                color: folder.color
            )
            saveFolders()
        }
    }
    
    func moveDocumentToFolder(documentId: String, folderId: String?) {
        if let index = favorites.firstIndex(where: { $0.id == documentId }) {
            let favorite = favorites[index]
            favorites[index] = FavoriteDocument(
                id: favorite.id,
                title: favorite.title,
                dateAdded: favorite.dateAdded,
                fileName: favorite.fileName,
                folderId: folderId,
                fileType: favorite.fileType
            )
            saveFavorites()
        }
    }
    
    func getDocumentsInFolder(folderId: String?) -> [FavoriteDocument] {
        favorites
            .filter { $0.folderId == folderId }
            .sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func getDocumentsInRoot() -> [FavoriteDocument] {
        favorites
            .filter { $0.folderId == nil }
            .sorted { $0.dateAdded > $1.dateAdded }
    }
    
    // MARK: - Document Management
    
    func addFavorite(title: String, pdfData: Data, folderId: String? = nil, fileExtension: String = "pdf") {
        let favoriteID = UUID().uuidString
        let fileName = "\(favoriteID).\(fileExtension)"
        let fileURL = favoritesDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            
            let favorite = FavoriteDocument(
                id: favoriteID,
                title: title,
                fileName: fileName,
                folderId: folderId,
                fileType: fileExtension
            )
            
            favorites.append(favorite)
            saveFavorites()
            Self.playFavoriteAddedHaptic()
            
        } catch {
            // Handle error silently
        }
    }
    
    private static func playFavoriteAddedHaptic() {
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    func removeFavorite(id: String) {
        // Find the favorite
        guard let index = favorites.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        let favorite = favorites[index]
        let fileURL = favoritesDirectory.appendingPathComponent(favorite.fileName)
        
        // Remove file from disk
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            // Handle error silently
        }
        
        // Remove from favorites list
        favorites.remove(at: index)
        saveFavorites()
    }
    
    /// Favorites are distinct per title **and** format (e.g. same act can have both `.md` and `.pdf`).
    func isFavorite(title: String, fileExtension: String) -> Bool {
        favorites.contains {
            $0.title == title && Self.normalizedFileType($0.resolvedFileType) == Self.normalizedFileType(fileExtension)
        }
    }

    func getFavoriteID(title: String, fileExtension: String) -> String? {
        favorites.first {
            $0.title == title && Self.normalizedFileType($0.resolvedFileType) == Self.normalizedFileType(fileExtension)
        }?.id
    }

    private static func normalizedFileType(_ ext: String) -> String {
        var t = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.hasPrefix(".") { t.removeFirst() }
        return t.isEmpty ? "pdf" : t
    }
    
    func getFavoriteFileURL(id: String) -> URL? {
        guard let favorite = favorites.first(where: { $0.id == id }) else {
            return nil
        }
        return favoritesDirectory.appendingPathComponent(favorite.fileName)
    }
    
    func createZipArchive() -> URL? {
        return createZipArchive(for: favorites)
    }
    
    func createZipArchive(for documents: [FavoriteDocument], folderName: String? = nil) -> URL? {
        // Check if there are any documents to archive
        guard !documents.isEmpty else {
            return nil
        }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        
        // Create filename with current date in yyyy-mm-dd format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let baseName = folderName != nil ? "SMBP_\(sanitizeFileName(folderName!))_\(dateString)" : "SMBP_Moje_akty_\(dateString)"
        let destinationURL = tempDirectory.appendingPathComponent("\(baseName).zip")
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Create a temporary directory with the proper name for the zip contents
            let zipFolderName = folderName != nil ? "SMBP_\(sanitizeFileName(folderName!))_\(dateString)" : "SMBP_Moje_akty_\(dateString)"
            let tempWorkingDirectory = tempDirectory.appendingPathComponent(zipFolderName)
            try FileManager.default.createDirectory(at: tempWorkingDirectory, withIntermediateDirectories: true)
            
            var filesCopied = 0
            
            // Copy files with proper names and folder structure
            for favorite in documents {
                let sourceFileURL = favoritesDirectory.appendingPathComponent(favorite.fileName)
                let sanitizedTitle = sanitizeFileName(favorite.title)
                
                // Check if source file exists
                guard FileManager.default.fileExists(atPath: sourceFileURL.path) else {
                    continue
                }
                
                let ext = favorite.resolvedFileType
                let destinationPath: String
                if let folderId = favorite.folderId,
                   let folder = folders.first(where: { $0.id == folderId }) {
                    let sanitizedFolderName = sanitizeFileName(folder.name)
                    destinationPath = "\(sanitizedFolderName)/\(sanitizedTitle).\(ext)"
                } else {
                    destinationPath = "\(sanitizedTitle).\(ext)"
                }
                
                let destinationFileURL = tempWorkingDirectory.appendingPathComponent(destinationPath)
                
                // Create parent directory if it doesn't exist (for folder structure)
                let parentDirectory = destinationFileURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: parentDirectory.path) {
                    try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
                }
                
                try FileManager.default.copyItem(at: sourceFileURL, to: destinationFileURL)
                filesCopied += 1
            }
            
            // Check if any files were copied
            guard filesCopied > 0 else {
                try? FileManager.default.removeItem(at: tempWorkingDirectory)
                return nil
            }
            
            // Create zip using NSFileCoordinator
            let fileCoordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            var zipURL: URL?
            
            fileCoordinator.coordinate(readingItemAt: tempWorkingDirectory, options: [.forUploading], error: &coordinatorError) { tempZipURL in
                do {
                    try FileManager.default.copyItem(at: tempZipURL, to: destinationURL)
                    zipURL = destinationURL
                } catch {
                    // Handle error silently
                }
            }
            
            // Clean up temporary directory
            try? FileManager.default.removeItem(at: tempWorkingDirectory)
            
            if let _ = coordinatorError {
                return nil
            }
            
            return zipURL
            
        } catch {
            return nil
        }
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        // Normalize the string to handle international characters properly
        let normalized = fileName.precomposedStringWithCanonicalMapping
        
        // Define characters that are not allowed in filenames
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:;=+&#'!~`,. ")
        
        // Replace invalid characters with underscores
        var sanitized = normalized.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        // Remove multiple consecutive underscores
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        
        // Remove leading/trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        // Remove any remaining control characters
        sanitized = sanitized.trimmingCharacters(in: .controlCharacters)
        
        // Ensure the filename is not empty
        if sanitized.isEmpty {
            sanitized = "document"
        }
        
        // Limit filename length to avoid filesystem issues
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }
        
        // Ensure it doesn't start with a dot (hidden files)
        if sanitized.hasPrefix(".") {
            sanitized = "document_" + sanitized
        }
        
        return sanitized
    }
    
    // MARK: - Private Methods
    
    private func createFavoritesDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: favoritesDirectory.path) {
            do {
                try fileManager.createDirectory(at: favoritesDirectory, withIntermediateDirectories: true)
            } catch {
                // Handle error silently
            }
        }
    }
    
    private func loadFavorites() {
        guard let data = userDefaults.data(forKey: favoritesKey),
              let decodedFavorites = try? JSONDecoder().decode([FavoriteDocument].self, from: data) else {
            return
        }
        
        // Filter out favorites whose files no longer exist
        let validFavorites = decodedFavorites.filter { favorite in
            let fileURL = favoritesDirectory.appendingPathComponent(favorite.fileName)
            return fileManager.fileExists(atPath: fileURL.path)
        }
        
        favorites = validFavorites
    }
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            userDefaults.set(data, forKey: favoritesKey)
        } catch {
            // Handle error silently
        }
    }
    
    private func loadFolders() {
        guard let data = userDefaults.data(forKey: foldersKey),
              let decodedFolders = try? JSONDecoder().decode([FavoriteFolder].self, from: data) else {
            return
        }
        folders = decodedFolders
    }
    
    private func saveFolders() {
        do {
            let data = try JSONEncoder().encode(folders)
            userDefaults.set(data, forKey: foldersKey)
        } catch {
            // Handle error silently
        }
    }
    
    // MARK: - Sharing Methods
    
    func shareFolder(folderId: String) async -> URL? {
        let documentsInFolder = getDocumentsInFolder(folderId: folderId)
        guard let folder = folders.first(where: { $0.id == folderId }) else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.createZipArchive(for: documentsInFolder, folderName: folder.name)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Bulk Operations
    
    func bulkMoveDocuments(ids: [String], folderId: String?) {
        for id in ids {
            moveDocumentToFolder(documentId: id, folderId: folderId)
        }
    }
    
    func bulkDeleteDocuments(ids: [String]) {
        for id in ids {
            removeFavorite(id: id)
        }
    }
}
