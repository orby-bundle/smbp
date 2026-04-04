import Foundation
import SwiftUI
#if canImport(Translation)
import Translation
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

enum SummaryAvailability: Equatable {
    case available
    case requiresIOS26
    case unsupportedDevice
}

enum TranslationReadiness: Equatable {
    case unknown
    case ready
    case needsDownload
    case unsupported
}

enum TranslationGuidance: Hashable {
    case none
    case progress(String)
    case warning(String)
}

enum ComplianceChecks {
    static func summaryAvailability(for language: EULanguage) async -> SummaryAvailability {
        guard await appleIntelligenceAvailable() else {
            return .unsupportedDevice
        }
        guard #available(iOS 26.0, *) else {
            return .requiresIOS26
        }
        return .available
    }
    
    private static func appleIntelligenceAvailable() async -> Bool {
        if #available(iOS 26.0, *) {
            return await AppleIntelligenceChecks.appleIntelligenceAvailable()
        }
        return false
    }
    
    static func summaryGuidance(for language: EULanguage, availability: SummaryAvailability) -> TranslationGuidance {
        if language == .polish || language == .english {
            switch availability {
            case .available:
                return .none
            case .requiresIOS26:
                return .warning("Podsumowanie dostępne w systemie iOS 26 lub nowszym.")
            case .unsupportedDevice:
                return .warning("Podsumowanie nie jest dostępne na tym urządzeniu.")
            }
        }
        return .none
    }
    
    static func translationReadiness(for selectedLanguage: EULanguage) async -> TranslationReadiness {
        guard selectedLanguage == .polish else {
            return .ready
        }
        return await translationReadiness(
            from: Locale.Language(identifier: "en"),
            to: Locale.Language(identifier: "pl")
        )
    }
    
    static func translationReadiness(from source: Locale.Language, to target: Locale.Language) async -> TranslationReadiness {
        #if canImport(Translation)
        if #available(iOS 26.0, *) {
            let availability = LanguageAvailability()
            let status = await availability.status(from: source, to: target)
            switch status {
            case .installed:
                return .ready
            case .supported:
                return .needsDownload
            case .unsupported:
                return .unsupported
            @unknown default:
                return .unsupported
            }
        } else {
            return .unsupported
        }
        #else
        return .unsupported
        #endif
    }
    
    static func translationGuidance(for readiness: TranslationReadiness) -> TranslationGuidance {
        switch readiness {
        case .unknown:
            return .progress("Sprawdzanie dostępności…")
        case .ready:
            return .none
        case .needsDownload:
            return .warning("Zainstaluj aplikację Translate oraz pakiety językowe angielski (US) i polski, aby uzyskać podsumowanie po polsku.")
        case .unsupported:
            let fallback = TranslationError.notSupported.errorDescription ?? "Podsumowanie w języku polskim nie jest dostępne na tym urządzeniu."
            return .warning(fallback)
        }
    }
    
    static func canShowSummaryButton(for language: EULanguage, summaryAvailability: SummaryAvailability, translationReadiness: TranslationReadiness) -> Bool {
        guard summaryAvailability == .available else { return false }
        if language == .polish {
            return translationReadiness == .ready
        }
        return true
    }
    
    static func summaryBlockingMessage(for language: EULanguage, availability: SummaryAvailability) -> String? {
        if case .warning(let message) = summaryGuidance(for: language, availability: availability) {
            return message
        }
        return nil
    }
    
    static func translationBlockingMessage(for language: EULanguage, readiness: TranslationReadiness) -> String? {
        guard language == .polish, readiness != .ready else { return nil }
        if case .warning(let message) = translationGuidance(for: readiness) {
            return message
        }
        return nil
    }
    
    static func complianceStates(for language: EULanguage) async -> (summary: SummaryAvailability, translation: TranslationReadiness) {
        let availability = await summaryAvailability(for: language)
        let readiness: TranslationReadiness
        if availability == .available {
            readiness = await translationReadiness(for: language)
        } else if language == .polish {
            readiness = .unsupported
        } else {
            readiness = .unsupported
        }
        return (availability, readiness)
    }
    
    static func guidanceMessages(for language: EULanguage, summaryAvailability: SummaryAvailability, translationReadiness: TranslationReadiness) -> [TranslationGuidance] {
        // Priority order: unsupportedDevice > requiresIOS26 > translation warning
        let summary = summaryGuidance(for: language, availability: summaryAvailability)
        
        // If we have a summary warning (unsupportedDevice or requiresIOS26), show only that
        if summary != .none {
            return [summary]
        }
        
        // Only show translation warning if no summary warnings and language is Polish
        if language == .polish {
            let translation = translationGuidance(for: translationReadiness)
            if translation != .none {
                return [translation]
            }
        }
        
        return []
    }
}

struct TranslationGuidanceBanner: View {
    let guidance: TranslationGuidance
    
    var body: some View {
        switch guidance {
        case .none:
            EmptyView()
        case .progress(let message):
            HStack(spacing: 8) {
                ProgressView()
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .warning(let message):
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

@available(iOS 26.0, *)
private enum AppleIntelligenceChecks {
    static func appleIntelligenceAvailable() async -> Bool {
        _ = LanguageModelSession()
        return true
    }
}
