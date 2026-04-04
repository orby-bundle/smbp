//
//  ResultsDUMP_View.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI

struct ResultsDUMP_View: View {
    let searchResults: [Act]
    let isLoadingMore: Bool
    let hasMoreResults: Bool
    let onLoadMore: () async -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
            Text("Wyniki wyszukiwania")
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
            
            if searchResults.isEmpty {
                NoSearchResultsMessage()
            } else {
                if horizontalSizeClass == .regular {
                    // iPad: 2-column grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(searchResults) { act in
                            ActRowView(act: act)
                                .onAppear {
                                    if act.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
                                        Task { await onLoadMore() }
                                    }
                                }
                        }
                    }
                } else {
                    // iPhone: full-width stack to avoid narrow single tiles
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { act in
                            ActRowView(act: act)
                                .onAppear {
                                    if act.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
                                        Task { await onLoadMore() }
                                    }
                                }
                        }
                    }
                }
                
                // Loading indicator for more results
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(horizontalSizeClass == .regular ? 1.0 : 0.8)
                        Text("Ładuję jeszcze...")
                            .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(horizontalSizeClass == .regular ? 16 : 12)
                    .transition(.opacity.combined(with: .scale))
                }
                
                // End of results indicator
                if !hasMoreResults && searchResults.count > 0 {
                    HStack {
                        Spacer()
                        Text("Koniec listy")
                            .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(horizontalSizeClass == .regular ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
    }
}

// MARK: - Results Display
struct ActRowView: View {
    let act: Act
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var markdownAvailableInBucket: Bool?
    
    // Helper function to check if a date string is in the future
    private func isFutureDate(_ dateString: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Try parsing with time first (format: "yyyy-MM-dd HH:mm")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = dateFormatter.date(from: dateString) {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let comparisonDate = calendar.startOfDay(for: date)
            return comparisonDate > today
        }
        
        // Try parsing date only (format: "yyyy-MM-dd")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else {
            return false
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let comparisonDate = calendar.startOfDay(for: date)
        
        return comparisonDate > today
    }
    
    @ViewBuilder
    private var pdfPreviewNavigationDestination: some View {
        if markdownAvailableInBucket == true {
            MDViewer(title: act.title ?? act.displayAddress, eli: act.ELI)
        } else {
            UnifiedPDFViewer(act: act)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            Text(act.title ?? act.displayAddress)
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(act.displayAddress)
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            
            if let announcementDate = act.announcementDate {
                Text("Wydany: \(announcementDate)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let promulgation = act.promulgation {
                Text("Ogłoszony: \(promulgation)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let entryIntoForce = act.entryIntoForce {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isFutureDate(entryIntoForce) ? Color.orange : Color.green)
                        .frame(width: horizontalSizeClass == .regular ? 8 : 6, height: horizontalSizeClass == .regular ? 8 : 6)
                    Text("Wejście w życie: \(entryIntoForce)")
                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let status = act.status {
                Text("Status: \(status)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 6 : 4) {
              //  Text("ELI: \(act.ELI)")
                //    .font(.caption2)
                //    .foregroundColor(.secondary)
                //    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    if let type = act.type {
                        Label(type, systemImage: "doc.text")
                            .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Inline PDF preview: top half of the first page.
                VStack(spacing: 0) {
                    NavigationLink(destination: pdfPreviewNavigationDestination) {
                        PDFPreviewTile(cacheKey: "act_\(act.ELI)", openText: "") {
                            try await APIService.shared.getActText(eli: act.ELI, format: .pdf)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack(spacing: 12) {
                        Spacer()
                        
                        NavigationLink(destination: UnifiedPDFViewer(act: act)) {
                            Text("PDF")
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if markdownAvailableInBucket == true {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            NavigationLink(destination: MDViewer(title: act.title ?? act.displayAddress, eli: act.ELI)) {
                                Text("Czytać")
                                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 12)
                    .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
        .shadow(color: .black.opacity(0.08), radius: horizontalSizeClass == .regular ? 3 : 2, x: 0, y: 1)
        .onAppear {
            guard markdownAvailableInBucket == nil else { return }
            Task {
                let exists = await FirebaseManager.shared.markdownExistsInStorage(for: act.ELI)
                await MainActor.run { markdownAvailableInBucket = exists }
            }
        }
    }
}

#Preview {
    ResultsDUMP_View(
        searchResults: [],
        isLoadingMore: false,
        hasMoreResults: true,
        onLoadMore: {}
    )
}
