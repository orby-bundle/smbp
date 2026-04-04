//
//  Results_Legis.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 03/11/2025.
//

import SwiftUI

struct ResultsLegislacjaView: View {
    let searchResults: [LegislativeProcess]
    let isLoadingMore: Bool
    let hasMoreResults: Bool
    let onLoadMore: () async -> Void
    let onELITapped: (Act) -> Void
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
                        ForEach(searchResults) { process in
                            ProcessRowView(process: process, onELITapped: onELITapped)
                            .onAppear {
                                if process.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
                                    Task { await onLoadMore() }
                                }
                            }
                        }
                    }
                } else {
                    // iPhone: full-width stack to avoid narrow single tiles
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { process in
                            ProcessRowView(process: process, onELITapped: onELITapped)
                            .onAppear {
                                if process.id == searchResults.last?.id && hasMoreResults && !isLoadingMore {
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
struct ProcessRowView: View {
    let process: LegislativeProcess
    let onELITapped: (Act) -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var isDescriptionExpanded = false
    @State private var fullProcess: LegislativeProcess?
    @State private var isLoadingDetails = false
    @State private var isLoadingELI = false
    @State private var foundELIAct: Act?
    @State private var showingCommitteeSheet = false
    @State private var selectedCommitteeCode: String = ""
    
    // Use full process if available, otherwise use initial process
    private var displayProcess: LegislativeProcess {
        fullProcess ?? process
    }
    
    // Flatten all stages recursively and filter out stages with committeeCode "Sejm"
    private var allStages: [ProcessStage] {
        guard let stages = displayProcess.stages else { return [] }
        let flattened = flattenStages(stages)
        // Filter out stages where committeeCode is "Sejm"
        return flattened.filter { stage in
            guard let committeeCode = stage.committeeCode else { return true }
            return committeeCode.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("Sejm") != .orderedSame
        }
    }
    
    private func flattenStages(_ stages: [ProcessStage]) -> [ProcessStage] {
        var result: [ProcessStage] = []
        for stage in stages {
            result.append(stage)
            if let children = stage.children {
                result.append(contentsOf: flattenStages(children))
            }
        }
        return result
    }
    
    // Check if any stage contains "Wycofano"
    private var isRejected: Bool {
        allStages.contains { stage in
            stage.stageName.localizedCaseInsensitiveContains("Wycofano")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            // Title
            Text(displayProcess.title ?? displayProcess.titleFinal ?? "Brak tytułu")
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Description with expand/collapse
            if let description = displayProcess.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(description)
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(isDescriptionExpanded ? nil : 3)
                    
                    if !isDescriptionExpanded {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDescriptionExpanded = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("więcej")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Image(systemName: "chevron.down")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
                      
            // Number
            Text("Numer druku: \(displayProcess.number)")
                .font(horizontalSizeClass == .regular ? .subheadline : .subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Passed status
            if let passed = displayProcess.passed {
                HStack {
                    if isRejected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Wycofano")
                            .font(horizontalSizeClass == .regular ? .subheadline : .subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(passed ? .green : .orange)
                        Text(passed ? "Uchwalono" : "W toku")
                            .font(horizontalSizeClass == .regular ? .subheadline : .subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show ELI when passed is true
                    if passed, let eli = displayProcess.ELI, !eli.isEmpty {
                        HStack(spacing: 4) {
                            Text("• ELI:")
                                .font(horizontalSizeClass == .regular ? .subheadline : .subheadline)
                                .foregroundColor(.secondary)
                            
                            if isLoadingELI {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else if let act = foundELIAct {
                                NavigationLink(destination: UnifiedPDFViewer(act: act)) {
                                    Text(eli)
                                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Button(action: {
                                    Task {
                                        await openELIPDF(eli: eli)
                                    }
                                }) {
                                    Text(eli)
                                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isLoadingELI)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Stages
            if !allStages.isEmpty {
                VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 8 : 6) {
                    ForEach(allStages) { stage in
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = stage.date {
                                Text(formatDate(date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack(alignment: .top) {
                                Text(stage.stageName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                if let committeeCode = stage.committeeCode, !committeeCode.isEmpty {
                                    Button(action: {
                                        // Clean and trim the committee code
                                        let cleanedCode = committeeCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                        
                                        // Validate before showing sheet
                                        guard !cleanedCode.isEmpty else {
                                            print("⚠️ DEBUG - Committee code is empty after cleaning in button action. Original: '\(committeeCode)'")
                                            return
                                        }
                                        
                                        print("✅ DEBUG - Setting selectedCommitteeCode to: '\(cleanedCode)'")
                                        selectedCommitteeCode = cleanedCode
                                        showingCommitteeSheet = true
                                    }) {
                                        Text("do komisji \(committeeCode)")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            // PDF link for stage if available
                            if hasStagePDF(stage) {
                                NavigationLink(destination: UnifiedPDFViewer(
                                    stage: stage,
                                    processTitle: displayProcess.title ?? displayProcess.titleFinal ?? displayProcess.number,
                                    term: "term\(displayProcess.term)"
                                )) {
                                    Text("Pobierz PDF")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Spacer()
                        }
                        .padding(.leading, horizontalSizeClass == .regular ? 8 : 6)
                    }
                }
            }
            
            // Document type label
            if let documentType = displayProcess.documentType {
                Label(documentType, systemImage: "doc.text")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 12 : 8)
        .shadow(color: .black.opacity(0.08), radius: horizontalSizeClass == .regular ? 3 : 2, x: 0, y: 1)
        .sheet(isPresented: $showingCommitteeSheet) {
            CommitteeSittingsSheet(committeeCode: selectedCommitteeCode)
        }
        .onChange(of: selectedCommitteeCode) { _, newValue in
            
        }
        .onChange(of: showingCommitteeSheet) { _, newValue in
            if newValue {
               
            }
        }
        .task {
            // Fetch full process details if stages are not available
            if displayProcess.stages == nil || displayProcess.stages?.isEmpty == true {
                await loadFullProcessDetails()
            }
            
            // Fetch ELI Act if available and not already fetched
            if displayProcess.passed == true,
               let eli = displayProcess.ELI,
               !eli.isEmpty,
               foundELIAct == nil,
               !isLoadingELI {
                await openELIPDF(eli: eli)
            }
        }
    }
    
    @MainActor
    private func loadFullProcessDetails() async {
        // Don't load if already loading or already loaded
        guard !isLoadingDetails && fullProcess == nil else { return }
        
        isLoadingDetails = true
        
        do {
            let apiService = APIService_Legis.shared
            let details = try await apiService.getProcessDetails(id: process.number, term: "term\(process.term)")
            fullProcess = details
        } catch {
            print("Failed to load process details: \(error)")
        }
        
        isLoadingDetails = false
    }
    
    @MainActor
    private func openELIPDF(eli: String) async {
        isLoadingELI = true
        
        // Parse ELI format: "DU/2025/1506" or "MP/2023/1261"
        let components = eli.split(separator: "/")
        guard components.count == 3 else {
            isLoadingELI = false
            return
        }
        
        let publisher = String(components[0]) // "DU" or "MP"
        guard let year = Int(String(components[1])) else {
            isLoadingELI = false
            return
        }
        guard let position = Int(String(components[2])) else {
            isLoadingELI = false
            return
        }
        
        do {
            // Search for the Act using the parsed parameters
            let apiService = APIService.shared
            let parameters = SearchParameters(
                date: nil,
                dateEffect: nil,
                dateEffectFrom: nil,
                dateEffectTo: nil,
                dateFrom: nil,
                dateTo: nil,
                exile: nil,
                inForce: nil,
                keyword: nil,
                limit: 1,
                offset: 0,
                position: position,
                pubDate: nil,
                pubDateFrom: nil,
                pubDateTo: nil,
                publisher: publisher,
                sortBy: nil,
                sortDir: nil,
                title: nil,
                type: nil,
                volume: nil,
                year: year
            )
            
            let response = try await apiService.searchActs(parameters: parameters)
            
            if let act = response.items.first {
                foundELIAct = act
                // Also notify parent for potential use
                onELITapped(act)
            }
        } catch {
            print("Failed to find Act for ELI \(eli): \(error)")
        }
        
        isLoadingELI = false
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "pl_PL")
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd.MM.yyyy"
        outputFormatter.locale = Locale(identifier: "pl_PL")
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        // If parsing fails, return original string
        return dateString
    }
    
    // Check if a stage has a PDF available (has printNumber or PDF link)
    private func hasStagePDF(_ stage: ProcessStage) -> Bool {
        // Check if stage has a printNumber
        if let printNumber = stage.printNumber, !printNumber.isEmpty {
            return true
        }
        
        // Check if stage has links that might contain PDF
        if let links = stage.links, !links.isEmpty {
            // Check if any link is a PDF (href ends with .pdf or rel contains pdf)
            return links.contains { link in
                link.href.lowercased().hasSuffix(".pdf") ||
                link.rel?.lowercased().contains("pdf") == true
            }
        }
        
        return false
    }
}

#Preview {
    ResultsLegislacjaView(
        searchResults: [],
        isLoadingMore: false,
        hasMoreResults: true,
        onLoadMore: {},
        onELITapped: { _ in }
    )
}
