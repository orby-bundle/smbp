#if canImport(Translation)
import Translation
#endif

import Foundation
import NaturalLanguage
import Combine

// MARK: - Translation Manager
final class TranslationManager: ObservableObject {
    static let shared = TranslationManager()
    
    // MARK: - Batch Processing State
    @Published var currentBatchIndex = 0
    @Published var totalBatches = 0
    @Published var hasMoreBatches = false
    
    private var textBatches: [String] = []
    
    private init() {}
    
    /// Translates an English text into Polish using Apple's on-device TranslationSession API.
    /// - Parameter text: The English text to translate.
    /// - Returns: The translated Polish text.
    @available(iOS 26.0, *)
    func translateToPolish(text: String) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TranslationError.emptySource
        }
        
        // Create cache key based on content hash
        let cacheManager = CacheManager.shared
        let contentHash = String(trimmedText.hash)
        let cacheKey = "translation_pl_\(contentHash)"
        
        // Check cache first
        if let cachedTranslation = cacheManager.string(forKey: cacheKey, category: .translation) {
            print("📦 Using cached Polish translation for content hash: \(contentHash)")
            return cachedTranslation
        }
        
        // Check token count and create batches if needed
        let tokenCount = countTokens(in: trimmedText)
        print("🔍 Total document tokens for translation: \(tokenCount)")
        
        // Reset previous state
        resetBatchState()
        
        // Create batches if content is too large
        let batches = createBatches(from: trimmedText, maxTokensPerBatch: 1500)
        textBatches = batches
        totalBatches = batches.count
        currentBatchIndex = 0
        hasMoreBatches = batches.count > 1
        
        guard let firstBatch = batches.first else {
            throw TranslationError.invalidContent
        }
        
        print("📝 Processing first translation batch with \(countTokens(in: firstBatch)) tokens")
        
        #if canImport(Translation)
        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "pl")
        )
        let response = try await session.translate(firstBatch)
        let translation = try validateTranslation(response.targetText)
        
        // Store translation in cache
        do {
            try cacheManager.storeString(translation, forKey: cacheKey, category: .translation)
            print("💾 Cached Polish translation for content hash: \(contentHash)")
        } catch {
            print("⚠️ Failed to cache translation for content hash: \(contentHash): \(error.localizedDescription)")
        }
        
        return translation
        #else
        throw TranslationError.notSupported
        #endif
    }
    
    // MARK: - Process Next Translation Batch
    @available(iOS 26.0, *)
    func processNextTranslationBatch() async throws -> String {
        guard currentBatchIndex + 1 < textBatches.count else {
            hasMoreBatches = false
            throw TranslationError.noMoreBatches
        }
        
        currentBatchIndex += 1
        
        #if canImport(Translation)
        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "pl")
        )
        let response = try await session.translate(textBatches[currentBatchIndex])
        hasMoreBatches = currentBatchIndex + 1 < textBatches.count
        return try validateTranslation(response.targetText)
        #else
        throw TranslationError.notSupported
        #endif
    }
    
    private func validateTranslation(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationError.translationFailed("Empty translation response")
        }
        return trimmed
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
        print("📊 Created \(batches.count) translation batches:")
        for (index, batch) in batches.enumerated() {
            let batchTokenCount = countTokens(in: batch)
            print("  Translation Batch \(index + 1): \(batchTokenCount) tokens")
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

// MARK: - Translation Error
enum TranslationError: Error, LocalizedError {
    case emptySource
    case notSupported
    case translationFailed(String)
    case invalidContent
    case noMoreBatches
    
    var errorDescription: String? {
        switch self {
        case .emptySource:
            return "Brak treści do podsumowania."
        case .notSupported:
            return "Podsumowanie nie jest dostępne na tym urządzeniu." 
        case .translationFailed(let message):
            return "Nie udało się przetłumaczyć podsumowania: \(message)"
        case .invalidContent:
            return "Nieprawidłowa treść do podsumowania"
        case .noMoreBatches:
            return "Nic więcej do podsumowania"
        }
    }
}
