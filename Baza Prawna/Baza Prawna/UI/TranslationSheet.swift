//
//  SummarySheet.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI

// MARK: - Translation Sheet
struct TranslationSheet: View {
    @Binding var summaryText: String
    @Binding var isLoading: Bool
    @Binding var error: String?
    let documentTitle: String
    @ObservedObject var summaryManager: SummaryManager
    @ObservedObject var translationManager: TranslationManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingNextBatch = false
    @State private var shouldAutoContinue = true
    @State private var currentTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Document title tile
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Skrót dokumentu")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(documentTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Translation info tile
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Podsumowanie wygenerowane za pomocą AI", systemImage: "apple.intelligence")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                                   }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Translated summary tile
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Treść podsumowania")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if isLoading {
                                VStack(spacing: 16) {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(1.1)
                                        Text("Tworzenie podsumowania…")
                                            .font(.system(.body, design: .default, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                    Text("Nie zamykaj tego widoku, dopóki podsumowanie nie zostanie wygenerowane.")
                                        .font(.system(.caption, design: .default))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                            } else if let error = error {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(.body, weight: .medium))
                                    Text(userFriendlyError(error))
                                        .font(.system(.body, design: .default))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 8)
                            } else {
                                VStack(alignment: .leading, spacing: 20) {
                                    ForEach(parseSummaryText(summaryText), id: \.self) { paragraph in
                                        if paragraph.hasPrefix("1.") || paragraph.hasPrefix("2.") || paragraph.hasPrefix("3.") || paragraph.hasPrefix("4.") {
                                            // Numbered list items with enhanced formatting
                                            HStack(alignment: .top, spacing: 16) {
                                                Text(paragraph.prefix(2))
                                                    .font(.system(.body, design: .default, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                    .frame(minWidth: 24, alignment: .leading)
                                                
                                                Text(String(paragraph.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                                                    .font(.system(.body, design: .default))
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.leading)
                                                    .lineSpacing(6)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .padding(.vertical, 4)
                                        } else if paragraph.hasPrefix("•") || paragraph.hasPrefix("-") {
                                            // Bullet points with enhanced formatting
                                            HStack(alignment: .top, spacing: 16) {
                                                Text("•")
                                                    .font(.system(.body, design: .default, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .frame(minWidth: 24, alignment: .leading)
                                                
                                                Text(String(paragraph.dropFirst()).trimmingCharacters(in: .whitespaces))
                                                    .font(.system(.body, design: .default))
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.leading)
                                                    .lineSpacing(6)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .padding(.vertical, 4)
                                        } else if paragraph.contains("---") {
                                            // Section headers (like "PODSUMOWANIE KOŃCOWE")
                                            Text(paragraph)
                                                .font(.system(.headline, design: .default, weight: .bold))
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.center)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color(.systemGray5))
                                                .cornerRadius(8)
                                        } else {
                                            // Regular paragraphs with enhanced formatting
                                            Text(paragraph)
                                                .font(.system(.body, design: .default))
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.leading)
                                                .lineSpacing(8)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .padding(.vertical, 4)
                                        }
                                    }
                                }
                                
                                // Dalej button for next summary batch (translated)
                                if summaryManager.hasMoreBatches && !isLoading {
                                    Button {
                                        Task {
                                            await processNextBatch()
                                        }
                                    } label: {
                                        if isLoadingNextBatch {
                                            HStack {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                                Text("Generowanie...")
                                            }
                                        } else {
                                            Text("Dalej (\(summaryManager.currentBatchIndex + 2)/\(summaryManager.totalBatches))")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !summaryText.isEmpty && !isLoading {
                        ShareLink(item: summaryText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if !newValue {
                    checkAutoContinue()
                }
            }
            .onDisappear {
                cancelCurrentTask()
            }
        }
    }
    
    // MARK: - Helper Functions
    private func parseSummaryText(_ text: String) -> [String] {
        let paragraphs = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if paragraphs.count <= 1 {
            return text.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return paragraphs
    }
    
    // MARK: - Auto Continue Logic
    private func processNextBatch() async {
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        isLoadingNextBatch = true
        do {
            if #available(iOS 26.0, *) {
                // Get the next summary batch
                let nextSummarySegment = try await summaryManager.processNextBatch()
                
                // Check again after async operation
                guard !Task.isCancelled else { return }
                
                // Translate the new summary segment
                let translatedSegment = try await translationManager.translateToPolish(text: nextSummarySegment)
                
                // Check again after translation
                guard !Task.isCancelled else { return }
                
                // Add part header before the new segment
                let partNumber = summaryManager.currentBatchIndex + 1
                let partHeader = "\n\n--- Część \(partNumber) ---\n\n"
                summaryText += partHeader + translatedSegment
                
                // Auto-continue if enabled and there are more batches
                if shouldAutoContinue && summaryManager.hasMoreBatches {
                    // Small delay to show the new content before auto-continuing
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Check again after delay
                    guard !Task.isCancelled else { return }
                    
                    await processNextBatch()
                }
            } else {
                if !Task.isCancelled {
                    self.error = "Podsumowanie wymaga systemu iOS 26+"
                }
            }
        } catch {
            // Only update error if task wasn't cancelled
            if !Task.isCancelled {
                self.error = userFriendlyError(error.localizedDescription)
            }
        }
        isLoadingNextBatch = false
    }
    
    // Auto-trigger next batch when loading finishes and auto-continue is enabled
    private func checkAutoContinue() {
        if shouldAutoContinue && !isLoading && summaryManager.hasMoreBatches && !isLoadingNextBatch {
            currentTask = Task {
                await processNextBatch()
            }
        }
    }
    
    // Cancel ongoing tasks when view disappears
    private func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        shouldAutoContinue = false
    }

    // MARK: - Error Mapping
    private func userFriendlyError(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("model assets are unavailable") || lower.contains("apple intelligence") || lower.contains("foundation models") {
            return "Niestety nie da się uzyskać podsumowania, gdy język urządzenia to polski. Zmień go na angielski, francuski lub niemiecki"
        }
        return text
    }
}

#Preview {
    TranslationSheet(
        summaryText: .constant("""
        1. Główne cele dokumentu
        Dokument ustanawia zasady dotyczące ochrony danych osobowych w Unii Europejskiej, wzmacniając prawa obywateli oraz obowiązki administratorów danych.
        
        2. Najważniejsze obowiązki
        • Zgłaszanie naruszeń w ciągu 72 godzin
        • Zapewnienie przenoszalności danych
        • Wdrożenie mechanizmów zgody
        
        3. Daty kluczowe
        Przepisy wejdą w życie 1 stycznia 2025 r., a na wdrożenie przewidziano 12 miesięcy.
        """),
        isLoading: .constant(false),
        error: .constant(nil as String?),
        documentTitle: "Rozporządzenie UE 2024/123",
        summaryManager: SummaryManager.shared,
        translationManager: TranslationManager.shared
    )
}
