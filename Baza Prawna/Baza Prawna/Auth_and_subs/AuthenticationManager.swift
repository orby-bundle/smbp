//
//  AuthenticationManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import FirebaseAuth
import Combine
import CryptoKit
import PostHog

final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var authError: String?
    @Published private(set) var isAppleIDLinked: Bool = false
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let mainQueue: DispatchQueue
    
    // Computed property for easy access to user UID
    var userUID: String? {
        return currentUser?.uid
    }
    
    // Check if current user is anonymous
    var isAnonymous: Bool {
        return currentUser?.isAnonymous ?? false
    }
    
    // Check if user has Apple ID linked
    var hasAppleIDLinked: Bool {
        return isAppleIDLinked
    }
    
    // Get user email if available
    var userEmail: String? {
        return currentUser?.email
    }
    
    private init() {
        self.mainQueue = DispatchQueue.main
        
        // Set up authentication state listener
        setupAuthStateListener()
        
        // No automatic authentication - users can access app without login
        // Authentication is optional and only via Apple ID
    }
    
    deinit {
        // Remove auth state listener when deallocated
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Public Methods
    
    /// Signs in anonymously if no user is currently authenticated
    func signInAnonymouslyIfNeeded() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    print("ERROR: Anonymous sign-in failed: \(error.localizedDescription)")
                } else if let user = authResult?.user {
                    print("OK: Signed in anonymously with UID: \(user.uid)")
                    Task {
                        await FirebaseManager.shared.syncUserData(uid: user.uid)
                    }
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("OK: User signed out successfully")
            
            // Reset Apple ID linked status
            mainQueue.async {
                self.isAppleIDLinked = false
            }
            
            // Reset PostHog identity
            PostHogSDK.shared.reset()
            
            // No automatic re-authentication - users can continue using app without login
        } catch {
            print("ERROR: Sign out failed: \(error.localizedDescription)")
            self.authError = error.localizedDescription
        }
    }
    
    /// Sign out and delete user account (for complete sign out)
    func signOutAndDeleteAccount() {
        guard let user = Auth.auth().currentUser else {
            print("No current user to sign out")
            return
        }
        
        // Delete the Firebase user account completely
        user.delete { [weak self] error in
            guard let self = self else { return }
            
            self.mainQueue.async {
                if let error = error {
                    print("ERROR: Failed to delete user account: \(error.localizedDescription)")
                    self.authError = error.localizedDescription
                    
                    // If deletion fails, try regular sign out as fallback
                    do {
                        try Auth.auth().signOut()
                        print("Fallback: User signed out successfully")
                        self.isAppleIDLinked = false
                    } catch {
                        print("ERROR: Fallback sign out also failed: \(error.localizedDescription)")
                        self.authError = error.localizedDescription
                    }
                } else {
                    print("OK: User account deleted successfully")
                    self.isAppleIDLinked = false
                    self.authError = nil
                }
            }
        }
    }
    
    // MARK: - Apple ID Integration
    
    /// Generate a cryptographically secure nonce for Apple Sign In
    func generateNonce() -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = 32
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    /// Hash the nonce using SHA256
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    /// Sign in with Apple ID credential
    func signInWithAppleID(credential: AuthCredential) async throws {
        do {
            let result = try await Auth.auth().signIn(with: credential)
            print("OK: Successfully signed in with Apple ID: \(result.user.uid)")
            
            // Update Apple ID linked status
            mainQueue.async {
                self.isAppleIDLinked = true
                self.authError = nil
            }
            
            // Sync user data to Firestore
            if let email = result.user.email {
                await FirebaseManager.shared.syncUserData(uid: result.user.uid, appleId: email)
                
                // Identify user in PostHog with email
                PostHogSDK.shared.identify(result.user.uid, userProperties: [
                    "email": email,
                    "is_anonymous": false
                ])
            } else {
                await FirebaseManager.shared.syncUserData(uid: result.user.uid)
                
                // Identify user in PostHog without email
                PostHogSDK.shared.identify(result.user.uid, userProperties: [
                    "is_anonymous": false
                ])
            }

            // Always refresh premium status after Apple sign-in and user sync
            await SubscriptionManager.shared.updateSubscriptionStatus()
        } catch {
            print("ERROR: Apple ID sign-in failed: \(error.localizedDescription)")
            mainQueue.async {
                self.authError = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            self.mainQueue.async {
                self.currentUser = user
                self.isAuthenticated = user != nil
                
                if let user = user {
                    if user.isAnonymous {
                        print("INFO: User is signed in anonymously with UID: \(user.uid)")
                        self.isAppleIDLinked = false
                    } else {
                        print("INFO: User is signed in with UID: \(user.uid)")
                        // Check if user has Apple ID linked by checking provider data
                        self.isAppleIDLinked = user.providerData.contains { $0.providerID == "apple.com" }
                        print("INFO: Apple ID linked: \(self.isAppleIDLinked)")
                    }
                } else {
                    print("INFO: User is signed out")
                    self.isAppleIDLinked = false
                }
                
                // Post authentication state change notification
                NotificationCenter.default.post(name: .authenticationStateChanged, object: nil)
            }
        }
    }
    
    // MARK: - Debug Methods
    
    func printAuthStatus() {
        print("🔍 Authentication Status:")
        print("   - Is Authenticated: \(isAuthenticated)")
        print("   - Is Anonymous: \(isAnonymous)")
        print("   - User UID: \(userUID ?? "nil")")
        print("   - Is Loading: \(isLoading)")
        if let error = authError {
            print("   - Error: \(error)")
        }
    }
    
    /// Debug method to reset authentication state
    /// This will sign out the current user and clear all auth state
    func resetAuthentication() {
        print("Resetting authentication...")
        
        // Sign out current user
        do {
            try Auth.auth().signOut()
            print("OK: User signed out successfully")
        } catch {
            print("ERROR: Sign out failed: \(error.localizedDescription)")
        }
        
        // Clear local state
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
            self.authError = nil
            self.isLoading = true
            self.isAppleIDLinked = false
        }
        
        // No automatic re-authentication - users can continue using app without login
    }
}

// MARK: - Extensions

extension AuthenticationManager {
    /// Convenience method to get user UID with fallback
    func getUserUID() -> String {
        return userUID ?? "unknown"
    }
    
    /// Check if user has a specific UID (useful for debugging)
    func hasUID(_ uid: String) -> Bool {
        return userUID == uid
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let authenticationStateChanged = Notification.Name("authenticationStateChanged")
}
