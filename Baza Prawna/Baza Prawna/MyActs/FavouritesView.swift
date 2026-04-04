//
//  FavouritesView.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import UIKit

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var shareURL: URL?
    @State private var showingShareSheet = false
    @State private var isPreparingArchive = false
    @State private var showingNewFolderSheet = false
    @State private var selectedFolder: FavoriteFolder?
    @State private var isRenameAlertPresented = false
    @State private var folderToRename: FavoriteFolder?
    @State private var newFolderName: String = ""
    
    // Selection mode state
    @State private var selectedDocumentIds: Set<String> = []
    @State private var isSelectionMode: Bool = false
    @State private var showingBulkDeleteConfirmation = false
    @State private var showingBulkMoveSheet = false
    @State private var pendingDeleteDocumentIds: Set<String> = []
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationStack {
            if favoritesManager.favorites.isEmpty && favoritesManager.folders.isEmpty {
                // Empty state
                VStack(spacing: isRegularWidth ? 32 : 20) {
                    Image(systemName: "star")
                    .font(.system(size: isRegularWidth ? 80 : 60))
                    .foregroundColor(.yellow)
                    
                    Text("Dodawaj tu akty")
                        .font(isRegularWidth ? .largeTitle : .title)
                        .fontWeight(.bold)
                    
                    Text("naciskając na gwiazdkę w widoku akty")
                        .font(isRegularWidth ? .title3 : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, isRegularWidth ? 40 : 20)
                    
                    Spacer()
                }
                .padding(isRegularWidth ? 40 : 20)
                .navigationTitle("Moje akty")
                .navigationBarTitleDisplayMode(.large)
            } else {
                // List of folders and favorites
                if isRegularWidth {
                    // iPad layout - use ScrollView with adaptive grid
                    ScrollView {
                        LazyVStack(spacing: isRegularWidth ? 24 : 16) {
                            // Folders section
                            if !favoritesManager.folders.isEmpty {
                                VStack(alignment: .leading, spacing: isRegularWidth ? 16 : 12) {
                                    HStack {
                                        Text("Teczki")
                                            .font(isRegularWidth ? .title2 : .headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, isRegularWidth ? 24 : 16)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: isRegularWidth ? 16 : 12), count: isRegularWidth ? 2 : 1), spacing: isRegularWidth ? 16 : 12) {
                                        ForEach(favoritesManager.folders) { folder in
                                            NavigationLink(destination: FolderDetailView(folder: folder)) {
                                                FolderCardView(folder: folder, isRegularWidth: isRegularWidth)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .contextMenu {
                                                Button("Zmień nazwę") {
                                                    showRenameAlert(for: folder)
                                                }
                                                Button("Usuń", role: .destructive) {
                                                    favoritesManager.deleteFolder(id: folder.id)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, isRegularWidth ? 24 : 16)
                                }
                            }
                            
                            // Root documents section
                            let rootDocuments = favoritesManager.getDocumentsInRoot()
                            if !rootDocuments.isEmpty {
                                VStack(alignment: .leading, spacing: isRegularWidth ? 16 : 12) {
                                    HStack {
                                        Text("Dokumenty")
                                            .font(isRegularWidth ? .title2 : .headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, isRegularWidth ? 24 : 16)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: isRegularWidth ? 16 : 12), count: isRegularWidth ? 2 : 1), spacing: isRegularWidth ? 16 : 12) {
                                        ForEach(rootDocuments) { favorite in
                                            DocumentCardView(
                                                favorite: favorite,
                                                currentFolderId: nil,
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
                                                },
                                                onRequestDelete: { pendingDeleteDocumentIds = [$0] }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, isRegularWidth ? 24 : 16)
                                }
                            }
                        }
                        .padding(.vertical, isRegularWidth ? 20 : 16)
                    }
                    .navigationTitle("Moje akty")
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
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { showingNewFolderSheet = true }) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(isRegularWidth ? .title3 : .body)
                                }
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                if isPreparingArchive {
                                    ProgressView()
                                        .scaleEffect(isRegularWidth ? 1.0 : 0.8)
                                } else {
                                    Button(action: shareFavorites) {
                                        HStack(spacing: 4) {
                                            Text(".zip")
                                                .font(isRegularWidth ? .subheadline : .caption)
                                            Image(systemName: "square.and.arrow.up")
                                                .font(isRegularWidth ? .title3 : .body)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // iPhone layout - use List
                    List {
                        // Folders section
                        if !favoritesManager.folders.isEmpty {
                            Section("") {
                                ForEach(favoritesManager.folders) { folder in
                                    NavigationLink(destination: FolderDetailView(folder: folder)) {
                                        FolderRowView(folder: folder)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button("Zmień\nnazwę") {
                                            showRenameAlert(for: folder)
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Usuń") {
                                            favoritesManager.deleteFolder(id: folder.id)
                                        }
                                        .tint(.red)
                                    }
                                    .contextMenu {
                                        Button("Zmień nazwę") {
                                            showRenameAlert(for: folder)
                                        }
                                        Button("Usuń", role: .destructive) {
                                            favoritesManager.deleteFolder(id: folder.id)
                                        }
                                    }
                                }
                                .onDelete(perform: deleteFolders)
                            }
                        }
                        
                        // Root documents section
                        let rootDocuments = favoritesManager.getDocumentsInRoot()
                        if !rootDocuments.isEmpty {
                            Section("") {
                                ForEach(rootDocuments) { favorite in
                                    DocumentRowView(
                                        favorite: favorite,
                                        currentFolderId: nil,
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
                                        },
                                        onRequestDelete: { pendingDeleteDocumentIds = [$0] }
                                    )
                                }
                                .onDelete(perform: deleteFavorites)
                            }
                        }
                    }
                    .navigationTitle("Moje akty")
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
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { showingNewFolderSheet = true }) {
                                    Image(systemName: "folder.badge.plus")
                                }
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                if isPreparingArchive {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Button(action: shareFavorites) {
                                        Text(".zip")
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderSheet()
        }
        .modifier(ShareSheetManager(shareURL: $shareURL, showingShareSheet: $showingShareSheet))
        .alert("Zmień nazwę teczki", isPresented: $isRenameAlertPresented) {
            TextField("Nazwa teczki", text: $newFolderName)
            Button("Anuluj", role: .cancel) {
                newFolderName = ""
                folderToRename = nil
            }
            Button("Zapisz") {
                if let folder = folderToRename {
                    favoritesManager.renameFolder(id: folder.id, newName: newFolderName)
                }
                newFolderName = ""
                folderToRename = nil
            }
            .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .modifier(SelectionModeModifier(
            selectedDocumentIds: $selectedDocumentIds,
            isSelectionMode: $isSelectionMode,
            showingBulkDeleteConfirmation: $showingBulkDeleteConfirmation,
            showingBulkMoveSheet: $showingBulkMoveSheet,
            favoritesManager: favoritesManager,
            currentFolderId: nil,
            onBulkMove: { folderId in
                favoritesManager.bulkMoveDocuments(ids: Array(selectedDocumentIds), folderId: folderId)
                exitSelectionMode()
                showingBulkMoveSheet = false
            },
            onBulkDelete: {
                bulkDeleteDocuments()
            }
        ))
        .modifier(PendingDocumentDeleteAlertModifier(
            pendingDeleteDocumentIds: $pendingDeleteDocumentIds,
            onConfirmDelete: { ids in
                favoritesManager.bulkDeleteDocuments(ids: ids)
            }
        ))
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
    
    private func shareFavorites() {
        // Check if there are any favorites to share
        guard !favoritesManager.favorites.isEmpty else {
            return
        }
        
        isPreparingArchive = true
        
        Task {
            // Create the zip archive asynchronously
            guard let zipURL = await createZipArchiveAsync() else {
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
    
    private func createZipArchiveAsync() async -> URL? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.favoritesManager.createZipArchive()
                continuation.resume(returning: result)
            }
        }
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        let rootDocuments = favoritesManager.getDocumentsInRoot()
        pendingDeleteDocumentIds = Set(offsets.map { rootDocuments[$0].id })
    }
    
    private func deleteFolders(offsets: IndexSet) {
        for index in offsets {
            let folder = favoritesManager.folders[index]
            favoritesManager.deleteFolder(id: folder.id)
        }
    }
    
    private func showRenameAlert(for folder: FavoriteFolder) {
        folderToRename = folder
        newFolderName = folder.name
        isRenameAlertPresented = true
    }
}

struct FavoriteRowView: View {
    let favorite: FavoriteDocument
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DocumentTileTopBanners(favorite: favorite, isRegularWidth: false)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(favorite.title)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            
        }
        .padding(.vertical, 4)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onDismiss: (() -> Void)?
    
    init(activityItems: [Any], onDismiss: (() -> Void)? = nil) {
        self.activityItems = activityItems
        self.onDismiss = onDismiss
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Handle completion
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - FolderRowView
struct FolderRowView: View {
    let folder: FavoriteFolder
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Folder icon with color
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(Color(hex: folder.color))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                let documentCount = favoritesManager.getDocumentsInFolder(folderId: folder.id).count
                Text("\(documentCount) \(documentCount.actsPlural)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
           
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FolderCardView (for iPad grid layout)
struct FolderCardView: View {
    let folder: FavoriteFolder
    let isRegularWidth: Bool
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: isRegularWidth ? 12 : 8) {
            // Folder icon with color
            HStack {
                Image(systemName: "folder.fill")
                    .font(isRegularWidth ? .largeTitle : .title2)
                    .foregroundColor(Color(hex: folder.color))
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: isRegularWidth ? 8 : 4) {
                Text(folder.name)
                    .font(isRegularWidth ? .title3 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                let documentCount = favoritesManager.getDocumentsInFolder(folderId: folder.id).count
                Text("\(documentCount) \(documentCount.actsPlural)")
                    .font(isRegularWidth ? .subheadline : .caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(isRegularWidth ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: isRegularWidth ? 16 : 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: isRegularWidth ? 8 : 4, x: 0, y: isRegularWidth ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isRegularWidth ? 16 : 12)
                .stroke(Color(hex: folder.color).opacity(0.3), lineWidth: isRegularWidth ? 2 : 1)
        )
    }
}

// MARK: - Reusable Components

// MARK: - Share Sheet Manager
struct ShareSheetManager: ViewModifier {
    @Binding var shareURL: URL?
    @Binding var showingShareSheet: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingShareSheet) {
                if let shareURL = shareURL {
                    ShareSheet(activityItems: [shareURL]) {
                        // Cleanup when share sheet is dismissed
                        let isOutsideSandbox = !shareURL.path.contains("/Containers/Data/Application/")
                        if isOutsideSandbox {
                            shareURL.stopAccessingSecurityScopedResource()
                        }
                        self.shareURL = nil
                    }
                }
            }
    }
}

// MARK: - Document tile banners (PDF / notes on MD)

private struct DocumentTileTopBanners: View {
    let favorite: FavoriteDocument
    var isRegularWidth: Bool = false
    @ObservedObject private var notesManager = NotesManager.shared
    
    private var documentKey: String {
        NotesManager.documentKey(favoriteId: favorite.id)
    }
    
    private var hasNotes: Bool {
        favorite.resolvedFileType == "md" && !notesManager.notes(forDocumentKey: documentKey).isEmpty
    }
    
    private var showPDFBanner: Bool {
        favorite.resolvedFileType != "md"
    }
    
    var body: some View {
        Group {
            if showPDFBanner {
                tileBanner(icon: "doc.fill", text: "PDF")
            } else if hasNotes {
                tileBanner(icon: "note.text", text: "z notatkami")
            }
        }
    }
    
    private func tileBanner(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(isRegularWidth ? .caption.weight(.semibold) : .caption2.weight(.semibold))
            Text(text)
                .font(isRegularWidth ? .caption.weight(.semibold) : .caption2.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, isRegularWidth ? 10 : 8)
        .padding(.vertical, isRegularWidth ? 5 : 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemFill))
        )
    }
}

// MARK: - Document Row Component
struct DocumentRowView: View {
    let favorite: FavoriteDocument
    let currentFolderId: String?
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    let onRequestDelete: (String) -> Void
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .blue : .secondary)
                        
                        FavoriteRowView(favorite: favorite)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                NavigationLink(destination: {
                    if let fileURL = favoritesManager.getFavoriteFileURL(id: favorite.id) {
                        if favorite.resolvedFileType == "md" {
                            MDViewer(title: favorite.title, fileURL: fileURL, favoriteDocumentId: favorite.id)
                        } else {
                            UnifiedPDFViewer(
                                title: favorite.title,
                                pdfDataProvider: {
                                    try Data(contentsOf: fileURL)
                                }
                            )
                        }
                    }
                }) {
                    FavoriteRowView(favorite: favorite)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if !favoritesManager.folders.isEmpty {
                        MoveDocumentMenu(documentId: favorite.id, currentFolderId: currentFolderId)
                            .tint(.blue)
                    }
                    
                    Button("Wybierz") {
                        onSelect()
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Usuń") {
                        onRequestDelete(favorite.id)
                    }
                    .tint(.red)
                }
                .contextMenu {
                    if !favoritesManager.folders.isEmpty {
                        MoveDocumentMenu(documentId: favorite.id, currentFolderId: currentFolderId)
                    }
                    
                    Button("Wybierz") {
                        onSelect()
                    }
                    
                    Button("Usuń", role: .destructive) {
                        onRequestDelete(favorite.id)
                    }
                }
            }
        }
    }
}

// MARK: - Document Card Component (for iPad grid layout)
struct DocumentCardView: View {
    let favorite: FavoriteDocument
    let currentFolderId: String?
    let isRegularWidth: Bool
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    let onRequestDelete: (String) -> Void
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: isRegularWidth ? 12 : 8) {
                        // Selection indicator and document icon
                        HStack(alignment: .center, spacing: isRegularWidth ? 10 : 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(isRegularWidth ? .title2 : .title3)
                                .foregroundColor(isSelected ? .blue : .secondary)
                            
                            DocumentTileTopBanners(favorite: favorite, isRegularWidth: isRegularWidth)
                            
                            Spacer()
                            
                            Image(systemName: "doc.fill")
                                .font(isRegularWidth ? .largeTitle : .title2)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: isRegularWidth ? 8 : 4) {
                            Text(favorite.title)
                                .font(isRegularWidth ? .title3 : .headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                    }
                    .padding(isRegularWidth ? 20 : 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: isRegularWidth ? 16 : 12)
                            .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: isRegularWidth ? 8 : 4, x: 0, y: isRegularWidth ? 4 : 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: isRegularWidth ? 16 : 12)
                                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                NavigationLink(destination: {
                    if let fileURL = favoritesManager.getFavoriteFileURL(id: favorite.id) {
                        if favorite.resolvedFileType == "md" {
                            MDViewer(title: favorite.title, fileURL: fileURL, favoriteDocumentId: favorite.id)
                        } else {
                            UnifiedPDFViewer(
                                title: favorite.title,
                                pdfDataProvider: {
                                    try Data(contentsOf: fileURL)
                                }
                            )
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: isRegularWidth ? 12 : 8) {
                        HStack(alignment: .center, spacing: isRegularWidth ? 10 : 8) {
                            Image(systemName: favorite.resolvedFileType == "md" ? "doc.richtext" : "doc.fill")
                                .font(isRegularWidth ? .largeTitle : .title2)
                                .foregroundColor(favorite.resolvedFileType == "md" ? .purple : .blue)
                            
                            DocumentTileTopBanners(favorite: favorite, isRegularWidth: isRegularWidth)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: isRegularWidth ? 8 : 4) {
                            Text(favorite.title)
                                .font(isRegularWidth ? .title3 : .headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                    }
                    .padding(isRegularWidth ? 20 : 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: isRegularWidth ? 16 : 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: isRegularWidth ? 8 : 4, x: 0, y: isRegularWidth ? 4 : 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    if !favoritesManager.folders.isEmpty {
                        MoveDocumentMenu(documentId: favorite.id, currentFolderId: currentFolderId)
                    }
                    
                    Button("Wybierz") {
                        onSelect()
                    }
                    
                    Button("Usuń", role: .destructive) {
                        onRequestDelete(favorite.id)
                    }
                }
            }
        }
    }
}

// MARK: - Move Document Menu Component
struct MoveDocumentMenu: View {
    let documentId: String
    let currentFolderId: String?
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        Menu("Przenieś") {
            // Move to root folder option
            Button(action: {
                favoritesManager.moveDocumentToFolder(documentId: documentId, folderId: nil)
            }) {
                Label("Na główną listę", systemImage: "folder")
            }
            
            // Move to other folders (excluding current folder)
            ForEach(favoritesManager.folders.filter { $0.id != currentFolderId }) { folder in
                Button(action: {
                    favoritesManager.moveDocumentToFolder(documentId: documentId, folderId: folder.id)
                }) {
                    Label(folder.name, systemImage: "folder.fill")
                }
            }
        }
    }
}

// MARK: - Selection Mode Modifier
struct SelectionModeModifier: ViewModifier {
    @Binding var selectedDocumentIds: Set<String>
    @Binding var isSelectionMode: Bool
    @Binding var showingBulkDeleteConfirmation: Bool
    @Binding var showingBulkMoveSheet: Bool
    let favoritesManager: FavoritesManager
    let currentFolderId: String?
    let onBulkMove: (String?) -> Void
    let onBulkDelete: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Usuń", isPresented: $showingBulkDeleteConfirmation) {
                Button("Anuluj", role: .cancel) {
                    showingBulkDeleteConfirmation = false
                }
                Button("Usuń", role: .destructive) {
                    onBulkDelete()
                }
            } message: {
                Text("Czy na pewno chcesz usunąć wybrane dokumenty (\(selectedDocumentIds.count) szt.)? Stracisz również notatki w nich.")
            }
            .sheet(isPresented: $showingBulkMoveSheet) {
                BulkMoveFolderSheet(
                    selectedDocumentIds: Array(selectedDocumentIds),
                    currentFolderId: currentFolderId,
                    onMove: onBulkMove
                )
            }
            .onChange(of: selectedDocumentIds) { _, newValue in
                // Auto-exit selection mode when all items are deselected
                if newValue.isEmpty && isSelectionMode {
                    isSelectionMode = false
                    selectedDocumentIds.removeAll()
                }
            }
    }
}

// MARK: - Single / list delete confirmation (same copy as bulk delete)

struct PendingDocumentDeleteAlertModifier: ViewModifier {
    @Binding var pendingDeleteDocumentIds: Set<String>
    let onConfirmDelete: ([String]) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Usuń", isPresented: Binding(
                get: { !pendingDeleteDocumentIds.isEmpty },
                set: { if !$0 { pendingDeleteDocumentIds.removeAll() } }
            )) {
                Button("Anuluj", role: .cancel) {
                    pendingDeleteDocumentIds.removeAll()
                }
                Button("Usuń", role: .destructive) {
                    let ids = Array(pendingDeleteDocumentIds)
                    pendingDeleteDocumentIds.removeAll()
                    onConfirmDelete(ids)
                }
            } message: {
                Text("Czy na pewno chcesz usunąć wybrany dokument? Stracisz również notatki w nim.")
            }
    }
}

// MARK: - Selection Mode Toolbar
struct SelectionModeToolbar: ToolbarContent {
    @Binding var isSelectionMode: Bool
    @Binding var selectedDocumentIds: Set<String>
    @Binding var showingBulkMoveSheet: Bool
    @Binding var showingBulkDeleteConfirmation: Bool
    let folders: [FavoriteFolder]
    
    var body: some ToolbarContent {
        if isSelectionMode {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    isSelectionMode = false
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !folders.isEmpty {
                    Button {
                        showingBulkMoveSheet = true
                    } label: {
                        Image(systemName: "folder")
                            .foregroundColor(.primary)
                    }
                    .disabled(selectedDocumentIds.isEmpty)
                }
                
                Button {
                    showingBulkDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(selectedDocumentIds.isEmpty)
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Pluralization Helper
private extension Int {
    var actsPlural: String {
        if self == 1 { return "akt" }
        let lastDigit = self % 10
        let lastTwoDigits = self % 100
        if (2...4).contains(lastDigit) && !(12...14).contains(lastTwoDigits) {
            return "akty"
        }
        return "aktów"
    }
}

#Preview {
    FavoritesView()
}
