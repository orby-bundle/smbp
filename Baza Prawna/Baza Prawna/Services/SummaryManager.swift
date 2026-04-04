
//
//  SummaryManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import FoundationModels
import NaturalLanguage
import Combine

// MARK: - Summary Manager
class SummaryManager: ObservableObject {
    static let shared = SummaryManager()
    
    // MARK: - Batch Processing State
    @Published var currentBatchIndex = 0
    @Published var totalBatches = 0
    @Published var hasMoreBatches = false
    
    private var textBatches: [String] = []
    
    private init() {}
    
    // MARK: - Generate Summary (English Only)
    func generateSummary(from content: String, documentIdentifier: String? = nil) async throws -> String {
        // Clean the HTML content to plain text
        let cleanText = extractPlainText(from: content)
        
        // Check if content is substantial enough for summarization
        guard cleanText.count > 100 else {
            throw SummaryError.contentTooShort
        }
        
        // Create cache key based on document identifier or content hash
        let cacheManager = CacheManager.shared
        let cacheKey: String
        
        if let docId = documentIdentifier, !docId.isEmpty {
            // Use document identifier (CELEX, ELI, case signature, etc.)
            cacheKey = "summary_en_\(docId)"
        } else {
            // Fallback to content hash
            let contentHash = String(cleanText.hash)
            cacheKey = "summary_en_content_\(contentHash)"
        }
        
        // Check cache first
        if let cachedSummary = cacheManager.string(forKey: cacheKey, category: .summary) {
            print("📦 Using cached summary for document: \(documentIdentifier ?? "content_hash")")
            return cachedSummary
        }
        
        // Check token count and create batches if needed
        let tokenCount = countTokens(in: cleanText)
        print("🔍 Total document tokens: \(tokenCount)")
        
        // Reset previous state
        resetBatchState()
        
        // Create batches if content is too large
        let batches = createBatches(from: cleanText, maxTokensPerBatch: 1500) //experiment with 1500 tokens
        textBatches = batches
        totalBatches = batches.count
        currentBatchIndex = 0
        hasMoreBatches = batches.count > 1
        
        guard let firstBatch = batches.first else {
            throw SummaryError.invalidContent
        }
        
        print("📝 Processing first batch with \(countTokens(in: firstBatch)) tokens")
        
        // Check iOS version availability for Foundation Models
        guard #available(iOS 26.0, *) else {
            throw SummaryError.appleIntelligenceNotAvailable
        }
        
        // Create language model session
        let session = LanguageModelSession()
        
        // Create a focused prompt for English legal document summarization
        let prompt: String
        if totalBatches > 1 {
            prompt = """
            Provide a concise and grounded summary of the following part of a legal document written in English.
            This is part \(currentBatchIndex + 1) of \(totalBatches) parts.
            Keep the summary clear, structured, and informative. Avoid numbered lists.
            Do not miss anything important.
            Focus on the key points and provisions in this section. Go straight to the point wit hout any introduction like "in this section" or "in this part".
            Content to summarize (part of the document):
            \(firstBatch)
            """
        } else {
            prompt = """
            Provide a concise and grounded summary of the below legal document written in English.
            Keep the summary clear, structured, and informative. 
            Do not miss any important information.
            Do not provide the title or the type of the document.
            Document content:
            \(firstBatch)
            """
        }
        
        do {
            let response = try await session.respond(to: prompt)
            let summary = response.content
            
            // Store summary in cache
            do {
                try cacheManager.storeString(summary, forKey: cacheKey, category: .summary)
                print("💾 Cached summary for document: \(documentIdentifier ?? "content_hash")")
            } catch {
                print("⚠️ Failed to cache summary for document: \(documentIdentifier ?? "content_hash"): \(error.localizedDescription)")
            }
            
            return summary
        } catch {
            // Handle specific Foundation Models errors
            if error.localizedDescription.contains("Apple Intelligence") {
                throw SummaryError.appleIntelligenceNotAvailable
            } else {
                throw SummaryError.summarizationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Process Next Batch
    func processNextBatch() async throws -> String {
        guard currentBatchIndex + 1 < textBatches.count else {
            hasMoreBatches = false
            throw SummaryError.noMoreBatches
        }
        
        currentBatchIndex += 1
        let batchNumber = currentBatchIndex + 1
        
        // Check iOS version availability for Foundation Models
        guard #available(iOS 26.0, *) else {
            throw SummaryError.appleIntelligenceNotAvailable
        }
        
        // Create language model session
        let session = LanguageModelSession()
        
        // Create prompt for this batch
        let prompt = """
        Provide a concise and grounded summary of this part of a legal document written in English.
        This is part \(batchNumber) of \(totalBatches) parts.
        Keep the summary clear, structured, and informative. 
        Do not miss any important information.
        Focus on the key points and provisions in this section.
        Document content:
        \(textBatches[currentBatchIndex])
        """
        
        do {
            let response = try await session.respond(to: prompt)
            hasMoreBatches = currentBatchIndex + 1 < textBatches.count
            return response.content
        } catch {
            // Handle specific Foundation Models errors
            if error.localizedDescription.contains("Apple Intelligence") {
                throw SummaryError.appleIntelligenceNotAvailable
            } else {
                throw SummaryError.summarizationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - HTML Text Extraction
    private func extractPlainText(from htmlContent: String) -> String {
        var cleanText = StripBoilerplate.cleaned(html: htmlContent)
        
        // Remove remaining HTML tags
        cleanText = cleanText.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        
        // Clean up whitespace
        cleanText = cleanText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanText
    }
    
    // MARK: - Token Counting
    private func countTokens(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokenCount = 0
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            tokenCount += 1
            return true
        }
        
        return tokenCount
    }
    
    // MARK: - Batch Creation
    private func createBatches(from text: String, maxTokensPerBatch: Int) -> [String] {
        guard maxTokensPerBatch > 0 else { return [text] }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return [] }
        
        // If the text is small enough, return it as a single batch
        let totalTokens = countTokens(in: trimmedText)
        if totalTokens <= maxTokensPerBatch {
            return [trimmedText]
        }
        
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = trimmedText
        
        var batches: [String] = []
        var currentBatchTokens: [String] = []
        var tokenCount = 0
        
        tokenizer.enumerateTokens(in: trimmedText.startIndex..<trimmedText.endIndex) { tokenRange, _ in
            let token = String(trimmedText[tokenRange])
            currentBatchTokens.append(token)
            tokenCount += 1
            
            if tokenCount >= maxTokensPerBatch {
                // Create batch from accumulated tokens
                let batch = currentBatchTokens.joined(separator: " ")
                batches.append(batch)
                
                // Reset for next batch
                currentBatchTokens = []
                tokenCount = 0
            }
            return true
        }
        
        // Add the remaining tokens as the last batch
        if !currentBatchTokens.isEmpty {
            let batch = currentBatchTokens.joined(separator: " ")
            batches.append(batch)
        }
        
        // Debug: Verify token counts in each batch
        print("📊 Created \(batches.count) batches:")
        for (index, batch) in batches.enumerated() {
            let batchTokenCount = countTokens(in: batch)
            print("  Batch \(index + 1): \(batchTokenCount) tokens")
        }
        
        return batches
    }
    
    // MARK: - Reset Batch State
    func resetBatchState() {
        currentBatchIndex = 0
        totalBatches = 0
        hasMoreBatches = false
        textBatches = []
    }
    
}

// MARK: - Summary Error
enum SummaryError: Error, LocalizedError {
    case contentTooShort
    case contentTooLarge
    case appleIntelligenceNotAvailable
    case summarizationFailed(String)
    case invalidContent
    case noMoreBatches
    
    var errorDescription: String? {
        switch self {
        case .contentTooShort:
            return "Content is too short for summarization"
        case .contentTooLarge:
            return "Content is too large for summarization"
        case .appleIntelligenceNotAvailable:
            return "Apple Intelligence is not available on this device"
        case .summarizationFailed(let message):
            return "Failed to generate summary: \(message)"
        case .invalidContent:
            return "Invalid content provided for summarization"
        case .noMoreBatches:
            return "No more batches to process"
        }
    }
}
