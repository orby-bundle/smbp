//
//  Baza_PrawnaApp.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import SafariServices
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck
import Combine
import StoreKit
import PostHog

@main
struct Baza_PrawnaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif
        
        FirebaseApp.configure()
        
        // Ensure the user always has a valid auth token for Firebase Storage
        AuthenticationManager.shared.signInAnonymouslyIfNeeded()
        
        // Initialize subscription system
        Task {
            await SubscriptionManager.shared.loadProducts()
            await SubscriptionManager.shared.updateSubscriptionStatus()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Check subscription status when app returns from background
                    Task {
                        await subscriptionManager.checkSubscriptionStatusWhenNeeded()
                    }
                    // Record app open for review tracking
                    ReviewManager.shared.recordAppOpen()
                }
        }
        
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let entersReaderIfAvailable: Bool
    
    init(url: URL, entersReaderIfAvailable: Bool = true) {
        self.url = url
        self.entersReaderIfAvailable = entersReaderIfAvailable
    }
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = entersReaderIfAvailable
        
        return SFSafariViewController(url: url, configuration: config)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Firebase
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    setupFirebase()
    
// MARK: - PostHog
    let configuration = PostHogConfig(
        apiKey: "REDACTED_POSTHOG_API_KEY",
        host: "https://eu.i.posthog.com"
       
    )
     configuration.captureScreenViews = false
     configuration.sessionReplay = true 
     configuration.sessionReplayConfig.screenshotMode = true 
     configuration.sessionReplayConfig.maskAllTextInputs = true // Keeps user data private
      PostHogSDK.shared.setup(configuration)
    
    return true
  }
}

