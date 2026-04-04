//
//  CommitteeSittings.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 03/11/2025.
//

import SwiftUI

// MARK: - Committee Sittings Sheet
struct CommitteeSittingsSheet: View {
    let committeeCode: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var sittings: [CommitteeSitting] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var committeeNameGenitive: String?
    
    init(committeeCode: String) {
        self.committeeCode = committeeCode
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header section with titles and alert button
                VStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("Posiedzenia")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(committeeNameGenitive ?? committeeCode)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    GeometryReader { geometry in
                        AlertButton(
                            onFrequencySelected: saveAlertForCommitteeSittings,
                            premiumCheck: { SubscriptionManager.shared.isPremium }
                        )
                        .frame(width: geometry.size.width / 3)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: horizontalSizeClass == .regular ? 60 : 50)
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
                .padding(.top, horizontalSizeClass == .regular ? 16 : 12)
                .padding(.bottom, horizontalSizeClass == .regular ? 16 : 12)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Content area
                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if sittings.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Brak posiedzeń")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(sittings) { sitting in
                                CommitteeSittingRow(sitting: sitting, horizontalSizeClass: horizontalSizeClass)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .task {
            await loadSittings()
            await loadCommitteeDetails()
        }
    }
    
    @MainActor
    private func loadSittings() async {
        isLoading = true
        errorMessage = nil
        
        // Validate committee code before making API call
        let cleanedCode = committeeCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedCode.isEmpty else {
            errorMessage = "Nieprawidłowy kod komisji."
            isLoading = false
            print("❌ DEBUG - Committee code is empty in loadSittings: '\(committeeCode)'")
            return
        }
        
        do {
            let apiService = APIService_Legis.shared
            sittings = try await apiService.getCommitteeSittings(committeeCode: cleanedCode)
            // Sort by date descending (most recent first)
            sittings.sort { sitting1, sitting2 in
                (sitting1.date ?? "") > (sitting2.date ?? "")
            }
        } catch {
            errorMessage = "Nie udało się załadować posiedzeń. Spróbuj ponownie później."
            print("Error loading committee sittings: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func loadCommitteeDetails() async {
        // Validate committee code before making API call
        let cleanedCode = committeeCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedCode.isEmpty else {
            return
        }
        
        do {
            let apiService = APIService_Legis.shared
            let details = try await apiService.getCommitteeDetails(committeeCode: cleanedCode)
            committeeNameGenitive = details.nameGenitive
        } catch {
            // If fetching details fails, we'll just use the committee code
            print("Error loading committee details: \(error)")
        }
    }
    
    private func saveAlertForCommitteeSittings(frequency: AlertFrequency) {
        let alertTitle = generateAlertTitle()
        let searchCriteria: [String: Any] = [
            "committeeCode": committeeCode
        ]
        
        let alert = SavedAlert(
            searchType: .committeeSittings,
            title: alertTitle,
            searchCriteria: searchCriteria,
            frequency: frequency
        )
        
        AlertManager.shared.saveAlert(alert)
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func generateAlertTitle() -> String {
        if let nameGenitive = committeeNameGenitive, !nameGenitive.isEmpty {
            return "Posiedzenia \(nameGenitive)"
        } else {
            return "Posiedzenia \(committeeCode)"
        }
    }
}

// MARK: - Committee Sitting Row
struct CommitteeSittingRow: View {
    let sitting: CommitteeSitting
    let horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Start DateTime
            if let startDateTime = sitting.startDateTime {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data rozpoczęcia")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(formatDateTime(startDateTime))
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            // Closed
            if let closed = sitting.closed {
                HStack(spacing: 8) {
                    Text("Typ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: closed ? "lock.fill" : "lock.open.fill")
                            .font(.body)
                            .foregroundColor(closed ? .red : .green)
                        Text(closed ? "Zamknięte" : "Otwarte")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Status
            if let status = sitting.status {
                HStack(spacing: 8) {
                    Text("Status")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(status))
                            .frame(width: 8, height: 8)
                        Text(statusText(status))
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Room
            if let room = sitting.room, !room.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Miejsce")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(room)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            // Agenda
            if let agenda = sitting.agenda, !agenda.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agenda")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(stripHTML(agenda))
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Player Link IFrame
            if let playerLinkIFrame = sitting.video?.first?.playerLinkIFrame, !playerLinkIFrame.isEmpty,
               let url = URL(string: playerLinkIFrame) {
                VStack(alignment: .leading, spacing: 4) {
                    
                    Button(action: {
                        openURL(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.body)
                            Text("Nagranie")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
        }
        .padding(.vertical, 4)
    }
    
    private func formatDateTime(_ dateTimeString: String) -> String {
        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"]
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd.MM.yyyy HH:mm"
        displayFormatter.locale = Locale(identifier: "pl_PL")
        
        for format in formats {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = Locale(identifier: "pl_PL")
            
            if let date = dateFormatter.date(from: dateTimeString) {
                return displayFormatter.string(from: date)
            }
        }
        
        return dateTimeString
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "FINISHED":
            return .red
        case "PLANNED":
            return .blue
        case "CANCELLED":
            return .gray
        default:
            return .gray
        }
    }
    
    private func statusText(_ status: String) -> String {
        switch status.uppercased() {
        case "FINISHED":
            return "Zakończone"
        case "PLANNED":
            return "Zaplanowane"
        case "CANCELLED":
            return "Anulowane"
        default:
            return status
        }
    }
    
    private func stripHTML(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

