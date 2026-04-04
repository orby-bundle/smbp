//
//  FolderViews.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI

// MARK: - FolderDetailView
struct FolderDetailView: View {
    let folder: FavoriteFolder
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var showingMoveSheet = false
    @State private var selectedDocument: FavoriteDocument?
    @State private var shareURL: URL?
    @State private var showingShareSheet = false
    @State private var isPreparingArchive = false
    
    // Selection mode state
    @State private var selectedDocumentIds: Set<String> = []
    @State private var isSelectionMode: Bool = false
    @State private var showingBulkDeleteConfirmation = false
    @State private var showingBulkMoveSheet = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var documentsInFolder: [FavoriteDocument] {
        favoritesManager.getDocumentsInFolder(folderId: folder.id)
    }
    
    var body: some View {
        if isRegularWidth {
            // iPad layout - use ScrollView with grid
            ScrollView {
                if documentsInFolder.isEmpty {
                    VStack(spacing: isRegularWidth ? 24 : 16) {
                        Image(systemName: "folder")
                            .font(.system(size: isRegularWidth ? 70 : 50))
                            .foregroundColor(Color(hex: folder.color))
                        
                        Text("Pusta teczka")
                            .font(isRegularWidth ? .largeTitle : .title2)
                            .fontWeight(.medium)
                        
                        Text("Przytrzymaj akt, aby przenieść go tutaj")
                            .font(isRegularWidth ? .title3 : .subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, isRegularWidth ? 40 : 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isRegularWidth ? 60 : 40)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: isRegularWidth ? 16 : 12), count: isRegularWidth ? 2 : 1), spacing: isRegularWidth ? 16 : 12) {
                        ForEach(documentsInFolder) { favorite in
                            DocumentCardView(
                                favorite: favorite,
                                currentFolderId: folder.id,
                                isRegularWidth: isRegularWidth,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedDocumentIds.contains(favorite.id),
                                onTap: {
                                    if isSelectionMode {
                                        toggleSelection(for: favorite)
                                    }
                                },
                                onSelect: {
                                    enterSelectionMode()
                                    selectedDocumentIds.insert(favorite.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 16)
                    .padding(.vertical, isRegularWidth ? 20 : 16)
                }
            }
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                SelectionModeToolbar(
                    isSelectionMode: $isSelectionMode,
                    selectedDocumentIds: $selectedDocumentIds,
                    showingBulkMoveSheet: $showingBulkMoveSheet,
                    showingBulkDeleteConfirmation: $showingBulkDeleteConfirmation,
                    folders: favoritesManager.folders
                )
                
                if !isSelectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if !documentsInFolder.isEmpty {
                            if isPreparingArchive {
                                ProgressView()
                                    .scaleEffect(isRegularWidth ? 1.0 : 0.8)
                            } else {
                                Button(action: shareFolder) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(isRegularWidth ? .title3 : .body)
                                }
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if !documentsInFolder.isEmpty {
                                Button("Przenieś akty na główną listę") {
                                    for document in documentsInFolder {
                                        favoritesManager.moveDocumentToFolder(documentId: document.id, folderId: nil)
                                    }
                                }
                            }
                            
                            Button("Usuń całą teczkę", role: .destructive) {
                                favoritesManager.deleteFolder(id: folder.id)
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(isRegularWidth ? .title3 : .body)
                        }
                    }
                }
            }
            .modifier(ShareSheetManager(shareURL: $shareURL, showingShareSheet: $showingShareSheet))
            .modifier(SelectionModeModifier(
                selectedDocumentIds: $selectedDocumentIds,
                isSelectionMode: $isSelectionMode,
                showingBulkDeleteConfirmation: $showingBulkDeleteConfirmation,
                showingBulkMoveSheet: $showingBulkMoveSheet,
                favoritesManager: favoritesManager,
                currentFolderId: folder.id,
                onBulkMove: { folderId in
                    favoritesManager.bulkMoveDocuments(ids: Array(selectedDocumentIds), folderId: folderId)
                    exitSelectionMode()
                    showingBulkMoveSheet = false
                },
                onBulkDelete: {
                    bulkDeleteDocuments()
                }
            ))
        } else {
            // iPhone layout - use List
            List {
                if documentsInFolder.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: folder.color))
                        
                        Text("Pusta teczka")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Przytrzymaj akt, aby przenieść go tutaj")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(documentsInFolder) { favorite in
                        DocumentRowView(
                            favorite: favorite,
                            currentFolderId: folder.id,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedDocumentIds.contains(favorite.id),
                            onTap: {
                                if isSelectionMode {
                                    toggleSelection(for: favorite)
                                }
                            },
                            onSelect: {
                                enterSelectionMode()
                                selectedDocumentIds.insert(favorite.id)
                            }
                        )
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                SelectionModeToolbar(
                    isSelectionMode: $isSelectionMode,
                    selectedDocumentIds: $selectedDocumentIds,
                    showingBulkMoveSheet: $showingBulkMoveSheet,
                    showingBulkDeleteConfirmation: $showingBulkDeleteConfirmation,
                    folders: favoritesManager.folders
                )
                
                if !isSelectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if !documentsInFolder.isEmpty {
                            if isPreparingArchive {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button(action: shareFolder) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if !documentsInFolder.isEmpty {
                                Button("Przenieś akty na główną listę") {
                                    for document in documentsInFolder {
                                        favoritesManager.moveDocumentToFolder(documentId: document.id, folderId: nil)
                                    }
                                }
                            }
                            
                            Button("Usuń całą teczkę", role: .destructive) {
                                favoritesManager.deleteFolder(id: folder.id)
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .modifier(ShareSheetManager(shareURL: $shareURL, showingShareSheet: $showingShareSheet))
            .modifier(SelectionModeModifier(
                selectedDocumentIds: $selectedDocumentIds,
                isSelectionMode: $isSelectionMode,
                showingBulkDeleteConfirmation: $showingBulkDeleteConfirmation,
                showingBulkMoveSheet: $showingBulkMoveSheet,
                favoritesManager: favoritesManager,
                currentFolderId: folder.id,
                onBulkMove: { folderId in
                    favoritesManager.bulkMoveDocuments(ids: Array(selectedDocumentIds), folderId: folderId)
                    exitSelectionMode()
                    showingBulkMoveSheet = false
                },
                onBulkDelete: {
                    bulkDeleteDocuments()
                }
            ))
        }
    }
    
    // MARK: - Selection Mode Management
    
    private func enterSelectionMode() {
        isSelectionMode = true
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedDocumentIds.removeAll()
    }
    
    private func toggleSelection(for favorite: FavoriteDocument) {
        if selectedDocumentIds.contains(favorite.id) {
            selectedDocumentIds.remove(favorite.id)
        } else {
            selectedDocumentIds.insert(favorite.id)
        }
    }
    
    private func bulkDeleteDocuments() {
        let documentIds = Array(selectedDocumentIds)
        favoritesManager.bulkDeleteDocuments(ids: documentIds)
        exitSelectionMode()
        showingBulkDeleteConfirmation = false
    }
    
    private func deleteDocuments(offsets: IndexSet) {
        for index in offsets {
            let favorite = documentsInFolder[index]
            favoritesManager.removeFavorite(id: favorite.id)
        }
    }
    
    private func shareFolder() {
        isPreparingArchive = true
        
        Task {
            // Create the zip archive asynchronously using the refactored method
            guard let zipURL = await favoritesManager.shareFolder(folderId: folder.id) else {
                await MainActor.run {
                    isPreparingArchive = false
                }
                return
            }
            
            // Check if the file is outside the app's sandbox
            let isOutsideSandbox = !zipURL.path.contains("/Containers/Data/Application/")
            
            if isOutsideSandbox {
                // Only call startAccessingSecurityScopedResource for files outside the sandbox
                guard zipURL.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        isPreparingArchive = false
                    }
                    return
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                shareURL = zipURL
                isPreparingArchive = false
                showingShareSheet = true
            }
        }
    }
}

// MARK: - NewFolderSheet
struct NewFolderSheet: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var folderName = ""
    @State private var selectedColor = "#000000"
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    private let availableColors = [
        "#000000", "#007AFF", "#FF3B30", "#34C759", 
        "#FF9500", "#AF52DE", "#5AC8FA", "#FFCC00"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Nazwa teczki") {
                    TextField("Wprowadź", text: $folderName)
                        .font(isRegularWidth ? .body : .body)
                }
                
                Section("Kolor") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isRegularWidth ? 6 : 4), spacing: isRegularWidth ? 20 : 16) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: isRegularWidth ? 50 : 40, height: isRegularWidth ? 50 : 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: isRegularWidth ? 4 : 3)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, isRegularWidth ? 12 : 8)
                }
            }
            .navigationTitle("Nowa teczka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Anuluj") {
                        dismiss()
                    }
                    .font(isRegularWidth ? .body : .body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Utwórz") {
                        favoritesManager.createFolder(name: folderName, color: selectedColor)
                        dismiss()
                    }
                    .font(isRegularWidth ? .body : .body)
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Bulk Move Folder Sheet
struct BulkMoveFolderSheet: View {
    let selectedDocumentIds: [String]
    let currentFolderId: String?
    let onMove: (String?) -> Void
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Move to root folder option
                Button(action: {
                    onMove(nil)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.forward.folder")
                            .foregroundColor(.blue)
                        Text("Na główną listę")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                
                // Move to folders (excluding current folder)
                ForEach(favoritesManager.folders.filter { $0.id != currentFolderId }) { folder in
                    Button(action: {
                        onMove(folder.id)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(Color(hex: folder.color))
                            Text(folder.name)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Przenieś do teczki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
            }
        }
    }
}

