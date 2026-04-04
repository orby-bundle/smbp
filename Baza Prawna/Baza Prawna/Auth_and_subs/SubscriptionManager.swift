//
//  SubscriptionManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var productIds: Set<String> = ["101010", "010101", "111111"] // weekly, monthly, yearly
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Initialization
    private init() {
        Task {
            await loadProducts()
            await updateSubscriptionStatus() // Check subscription status on app launch
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.sorted { $0.price < $1.price }
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func purchase(_ product: Product) async throws -> StoreKit.Transaction {
        startTransactionListener()
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return transaction
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            isLoading = false
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func updateSubscriptionStatus() async {
        var hasValidSubscription = false
        
        // Check subscription status for each product to get accurate expiration info
        for product in products {
            guard let subscription = product.subscription else { continue }
            
            do {
                let statuses = try await subscription.status
                
                for status in statuses {
                    do {
                        let transaction = try checkVerified(status.transaction)
                        
                        // Check if this is our product
                        if productIds.contains(transaction.productID) {
                            switch status.state {
                            case .subscribed:
                                hasValidSubscription = true
                                print("Active subscription found: \(product.id)")
                                break
                            case .expired, .revoked:
                                print("WARN: Expired/Revoked subscription: \(product.id)")
                                // Don't grant access
                            case .inGracePeriod, .inBillingRetryPeriod:
                                print("INFO: Subscription in grace/billing retry: \(product.id)")
                                // Don't grant access during grace periods
                            default:
                                print("WARN: Unknown subscription state: \(product.id)")
                            }
                            
                            if hasValidSubscription {
                                break
                            }
                        }
                    } catch {
                        print("ERROR: Failed to verify subscription transaction: \(error)")
                    }
                }
                
                if hasValidSubscription {
                    break
                }
            } catch {
                print("ERROR: Failed to get subscription status: \(error)")
            }
        }
        
        isPremium = hasValidSubscription
        print("INFO: Final subscription status: isPremium = \(isPremium)")
        
        // Sync to Firebase
        if let userId = AuthenticationManager.shared.userUID {
            await FirebaseManager.shared.syncSubscriptionStatus(isPremium: isPremium, userId: userId)
        }
    }
    
    func checkSubscriptionStatus() -> Bool {
        return isPremium
    }
    
    func checkTrialEligibility() async -> Bool {
        for product in products {
            if let subscriptionInfo = product.subscription {
                let eligibility = await subscriptionInfo.isEligibleForIntroOffer
                if eligibility {
                    return true
                }
            }
        }
        return false
    }
    
    /// Check subscription status when user actually needs it (e.g., accessing premium features)
    func checkSubscriptionStatusWhenNeeded() async {
        // Only check when explicitly needed - no automatic checking
        await updateSubscriptionStatus()
    }
    
    func getSubscriptionDetails() async -> String {
        var details = "=== Subscription Details ===\n"
        details += "isPremium: \(isPremium)\n"
        details += "Product IDs: \(productIds)\n\n"
        
        details += "Current Entitlements:\n"
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                details += "  - \(transaction.productID) (Active)\n"
            } catch {
                details += "  - Verification failed: \(error)\n"
            }
        }
        
        details += "\nAvailable Products:\n"
        for product in products {
            details += "  - \(product.id): \(product.displayName) (\(product.displayPrice))\n"
        }
        
        return details
    }
    
    #if DEBUG
    func resetToInitialState() async {
        isPremium = false
        
        if let userId = AuthenticationManager.shared.userUID {
            await FirebaseManager.shared.syncSubscriptionStatus(isPremium: false, userId: userId)
        }
        
        print("Subscription status reset to initial state")
    }
    #endif
    
    // MARK: - Private Methods
    
    private func startTransactionListener() {
        transactionListener = Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await MainActor.run { try self.checkVerified(result) }
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                } catch {
                    print("ERROR: Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.unverified
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Subscription Errors
enum SubscriptionError: LocalizedError {
    case userCancelled
    case pending
    case unverified
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending approval"
        case .unverified:
            return "Transaction could not be verified"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
