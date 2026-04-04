//
//  ReviewManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 01/02/2025.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class ReviewManager {
    static let shared = ReviewManager()
    
    private let userDefaults = UserDefaults.standard
    private let appOpenDatesKey = "ReviewAppOpenDates"
    private let mojeTabVisitCountKey = "ReviewMojeTabVisitCount"
    private let reviewRequestedKey = "ReviewRequested"
    
    private init() {
        // Initialize - no automatic check on init
    }
    
    /// Called when app becomes active to track daily opens
    func recordAppOpen() {
        let today = Calendar.current.startOfDay(for: Date())
        let storedDates = userDefaults.array(forKey: appOpenDatesKey) as? [Date] ?? []
        
        // Add today if not already recorded
        let alreadyRecorded = storedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) })
        
        if !alreadyRecorded {
            var openDates = storedDates
            openDates.append(today)
            // Keep only last 30 days to avoid bloat
            openDates = Array(openDates.suffix(30))
            userDefaults.set(openDates, forKey: appOpenDatesKey)
            
            // Check if we should request review (3 separate days)
            if openDates.count >= 3 {
                Task {
                    await checkAndRequestReview()
                }
            }
        }
    }
    
    /// Called when user visits "Moje" tab
    func recordMojeTabVisit() {
        let hasFavorites = !FavoritesManager.shared.favorites.isEmpty
        let hasAlerts = !AlertManager.shared.savedAlerts.isEmpty
        
        // Only track if there's content
        guard hasFavorites || hasAlerts else { return }
        
        let visitCount = userDefaults.integer(forKey: mojeTabVisitCountKey)
        let newCount = visitCount + 1
        userDefaults.set(newCount, forKey: mojeTabVisitCountKey)
        
        // Request review on second visit with content
        if newCount == 2 {
            Task {
                await checkAndRequestReview()
            }
        }
    }
    
    private func checkAndRequestReview() async {
        // Don't request if already requested within last 3 months
        if let lastRequestDate = userDefaults.object(forKey: reviewRequestedKey) as? Date {
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            if lastRequestDate > threeMonthsAgo {
                return
            }
        }
        
        // Request review - iOS will only show if conditions are met
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
            userDefaults.set(Date(), forKey: reviewRequestedKey)
        }
    }
}

