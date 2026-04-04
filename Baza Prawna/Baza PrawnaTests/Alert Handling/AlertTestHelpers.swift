//
//  AlertTestHelpers.swift
//  Baza PrawnaTests
//
//  Created for testing alert system
//

import Foundation
@testable import Baza_Prawna

// MARK: - Test Errors

enum TestError: Error {
    case alertNotFound
    case invalidState
}

// MARK: - Test UserDefaults Management

class TestUserDefaults {
    static let suiteName = "com.bazaprawna.tests"
    private let userDefaults: UserDefaults
    
    init() {
        // Use a test suite to avoid interfering with app data
        if let testDefaults = UserDefaults(suiteName: Self.suiteName) {
            self.userDefaults = testDefaults
        } else {
            // Fallback to standard if suite creation fails
            self.userDefaults = UserDefaults.standard
        }
        clearAll()
    }
    
    func clearAll() {
        // Clear all test keys
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        userDefaults.synchronize()
    }
    
    var instance: UserDefaults {
        return userDefaults
    }
}

// MARK: - Alert Creation Helpers

struct AlertTestFactory {
    
    /// Creates a test alert for ActsPL search type
    static func createActsPLAlert(
        title: String = "Test ActsPL Alert",
        keyword: String? = nil,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        var criteria: [String: Any] = [:]
        if let keyword = keyword {
            criteria["keyword"] = keyword
        }
        
        return SavedAlert(
            id: UUID(),
            searchType: .actsPL,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for ActsEU search type
    static func createActsEUAlert(
        title: String = "Test ActsEU Alert",
        searchText: String? = nil,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        var criteria: [String: Any] = [:]
        if let searchText = searchText {
            criteria["searchText"] = searchText
        }
        criteria["selectedLanguage"] = "pol"
        criteria["selectedDocumentType"] = "all"
        
        return SavedAlert(
            id: UUID(),
            searchType: .actsEU,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for CourtPL search type
    static func createCourtPLAlert(
        title: String = "Test CourtPL Alert",
        searchText: String? = nil,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        var criteria: [String: Any] = [:]
        if let searchText = searchText {
            criteria["searchText"] = searchText
        }
        
        return SavedAlert(
            id: UUID(),
            searchType: .courtPL,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for CourtNSA search type
    static func createCourtNSAAlert(
        title: String = "Test CourtNSA Alert",
        searchText: String? = nil,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        var criteria: [String: Any] = [:]
        if let searchText = searchText {
            criteria["searchText"] = searchText
        }
        criteria["selectedOccurrence"] = "gdziekolwiek"
        criteria["withWordVariations"] = true
        
        return SavedAlert(
            id: UUID(),
            searchType: .courtNSA,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for CourtSupreme search type
    static func createCourtSupremeAlert(
        title: String = "Test CourtSupreme Alert",
        searchText: String? = nil,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        var criteria: [String: Any] = [:]
        if let searchText = searchText {
            criteria["searchText"] = searchText
        }
        
        return SavedAlert(
            id: UUID(),
            searchType: .courtSupreme,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for RPLProjects search type
    static func createRPLProjectsAlert(
        title: String = "Test RPLProjects Alert",
        titleSearch: String? = nil,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        var criteria: [String: Any] = [:]
        if let titleSearch = titleSearch {
            criteria["title"] = titleSearch
        }
        criteria["selectedType"] = "1" // Government Programme Assumptions
        
        return SavedAlert(
            id: UUID(),
            searchType: .rplProjects,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for LegisPL search type (title-based)
    static func createLegisPLTitleAlert(
        title: String = "Test LegisPL Alert",
        titleSearch: String? = nil,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        var criteria: [String: Any] = [:]
        if let titleSearch = titleSearch {
            criteria["title"] = titleSearch
        }
        
        return SavedAlert(
            id: UUID(),
            searchType: .legisPL,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for LegisPL search type (number-based)
    static func createLegisPLNumberAlert(
        title: String = "Test LegisPL Number Alert",
        number: String,
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        let criteria: [String: Any] = [
            "number": number
        ]
        
        return SavedAlert(
            id: UUID(),
            searchType: .legisPL,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates a test alert for CommitteeSittings search type
    static func createCommitteeSittingsAlert(
        title: String = "Test CommitteeSittings Alert",
        committeeCode: String = "KOM",
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date()
    ) -> SavedAlert {
        let criteria: [String: Any] = [
            "committeeCode": committeeCode
        ]
        
        return SavedAlert(
            id: UUID(),
            searchType: .committeeSittings,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
    }
    
    /// Creates an alert for any search type
    static func createAlert(
        for searchType: SearchType,
        title: String = "Test Alert",
        criteria: [String: Any] = [:],
        frequency: AlertFrequency? = .daily,
        dateCreated: Date = Date(),
        lastSearchDate: Date? = nil
    ) -> SavedAlert {
        return SavedAlert(
            id: UUID(),
            searchType: searchType,
            title: title,
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: frequency,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: lastSearchDate,
            resultCount: 0
        )
    }
}

// MARK: - Date Helpers

extension Date {
    /// Returns a date N days ago from now
    static func daysAgo(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
    
    /// Returns a date N days ago from the given date
    func daysAgo(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }
}

// MARK: - Test Utilities

struct AlertTestUtilities {
    /// Clears all alerts from AlertManager (for test cleanup)
    @MainActor
    static func clearAllAlerts() {
        let manager = AlertManager.shared
        
        // Clear UserDefaults first to prevent any reloading
        UserDefaults.standard.removeObject(forKey: "SavedAlerts")
        UserDefaults.standard.removeObject(forKey: "OfflineAlerts")
        UserDefaults.standard.removeObject(forKey: "OfflineDeletions")
        UserDefaults.standard.synchronize()
        
        // Directly clear the in-memory array - this is the most reliable way
        // We don't need to call deleteAlert() as it has async operations
        // and we're in a test context where we just want to clear everything
        manager.savedAlerts.removeAll()
    }
    
    /// Waits for async operations to complete (for testing)
    static func wait(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    /// Waits for AlertManager async operations to complete
    /// This gives Tasks time to finish their work
    @MainActor
    static func waitForAsyncOperations() async {
        // Small delay to let Tasks complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    /// Waits longer for cleanup operations to complete
    @MainActor
    static func waitForCleanup() async {
        // Longer delay for cleanup operations
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
}

