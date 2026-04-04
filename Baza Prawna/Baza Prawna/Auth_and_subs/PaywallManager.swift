//
//  PaywallManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PaywallManager: ObservableObject {
    static let shared = PaywallManager()
    
    // MARK: - Published Properties
    @Published var showPaywall: Bool = false
    
    // MARK: - Private Properties
    private let subscriptionManager = SubscriptionManager.shared
    private var wasPreviouslyPremium: Bool = false
    private var onSuccess: (() -> Void)?
    
    // MARK: - Initialization
    private init() {
        // Listen to subscription status changes
        subscriptionManager.$isPremium
            .sink { [weak self] isPremium in
                guard let self = self else { return }
                
                // Track previous premium status
                self.wasPreviouslyPremium = isPremium
                
                // Auto-hide paywall if user becomes premium and continue pending flow
                if isPremium {
                    self.showPaywall = false
                    let callback = self.onSuccess
                    self.onSuccess = nil
                    callback?()
                }
                // Note: We don't automatically show paywall when subscription expires
                // The paywall will only be shown when explicitly requested via presentPaywall()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    func checkPremiumAccess() -> Bool {
        return subscriptionManager.isPremium
    }
    
    func presentPaywall(onSuccess: (() -> Void)? = nil) {
        self.onSuccess = onSuccess
        showPaywall = true
    }
    
    func dismissPaywall() {
        showPaywall = false
        // If user is premium upon dismissal, run continuation
        if subscriptionManager.isPremium {
            let callback = onSuccess
            onSuccess = nil
            callback?()
        } else {
            onSuccess = nil
        }
    }
    
    /// Force refresh subscription status and show paywall if needed
    func refreshAndCheckAccess() async {
        await subscriptionManager.checkSubscriptionStatusWhenNeeded()
    }
    
    /// Check if paywall should be shown based on current subscription status
    func shouldShowPaywall() -> Bool {
        return !subscriptionManager.isPremium
    }
}
