//
//  ButtonAlert.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import AuthenticationServices

// MARK: - Alert Button
struct AlertButton: View {
    let onFrequencySelected: (AlertFrequency) -> Void
    let premiumCheck: (() -> Bool)?
    @State private var isPressed = false
    @State private var showingFrequencyDialog = false
    @State private var showingNotificationDisabledAlert = false
    @State private var showingLoginAlert = false
    @State private var showingSignInErrorAlert = false
    @State private var showingSuccessAnimation = false
    @State private var successScale: CGFloat = 0.0
    @State private var successOpacity: Double = 0.0
    @StateObject private var appleSignInCoordinator = SignInWithAppleCoordinator()
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(onFrequencySelected: @escaping (AlertFrequency) -> Void, premiumCheck: (() -> Bool)? = nil) {
        self.onFrequencySelected = onFrequencySelected
        self.premiumCheck = premiumCheck
    }
    
    var body: some View {
        Button(action: {
            Haptics.impact(.medium)
            checkNotificationPermission()
        }) {
            ZStack {
                HStack(spacing: horizontalSizeClass == .regular ? 12 : 8) {
                    Image(systemName: showingSuccessAnimation ? "star.fill" : "bell.fill")
                        .font(.system(size: horizontalSizeClass == .regular ? 20 : 16, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(showingSuccessAnimation ? 1.2 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showingSuccessAnimation)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
                .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: showingSuccessAnimation ? 
                            [Color.green, Color.green.opacity(0.8)] : 
                            [Color.orange, Color.orange.opacity(0.8)]
                        ),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(horizontalSizeClass == .regular ? 16 : 12)
                .overlay(
                    RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 16 : 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: horizontalSizeClass == .regular ? 2 : 1.5)
                )
                .shadow(color: showingSuccessAnimation ? 
                    Color.green.opacity(0.3) : 
                    Color.orange.opacity(0.3), 
                    radius: horizontalSizeClass == .regular ? 12 : 8, 
                    x: 0, 
                    y: horizontalSizeClass == .regular ? 6 : 4
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
                .animation(.easeInOut(duration: 0.3), value: showingSuccessAnimation)
                
                // Success checkmark overlay
                if showingSuccessAnimation {
                    Image(systemName: "star.fill")
                        .font(.system(size: horizontalSizeClass == .regular ? 24 : 20, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(successScale)
                        .opacity(successOpacity)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: successScale)
                        .animation(.easeInOut(duration: 0.3), value: successOpacity)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .confirmationDialog(
            horizontalSizeClass == .regular ? 
                "Sprawdzanie nowych wyników wg obecnych parametrów wyszukiwania" : 
                "Sprawdzanie nowych",
            isPresented: $showingFrequencyDialog,
            titleVisibility: .visible
        ) {
            Button("Codziennie") {
                handleFrequencySelection(.daily)
            }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
            Button("Co tydzień") {
                handleFrequencySelection(.weekly)
            }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
            Button("Co miesiąc") {
                handleFrequencySelection(.monthly)
            }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
            Button("Anuluj", role: .cancel) { }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
        }
        .alert("Powiadomienia wyłączone", isPresented: $showingNotificationDisabledAlert) {
            Button("Ustawienia") {
                openAppSettings()
            }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
            Button("Anuluj", role: .cancel) { }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
        } message: {
            Text(horizontalSizeClass == .regular ? 
                "Alerty nie będą działać bez pozwolonych powiadomień. Włącz je w Ustawieniach, aby dowiedzieć się o nowych dokumentach." :
                "Włącz powiadomienia w Ustawieniach, aby otrzymywać alerty.")
                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
        }
        .alert("Alert został zapisany", isPresented: $showingLoginAlert) {
            Button("Nie chcę teraz", role: .cancel) { }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
            Button("Zaloguj się przez Apple ID") {
                appleSignInCoordinator.triggerSignIn()
            }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
        } message: {
            Text(horizontalSizeClass == .regular ? 
                "Zaloguj się, aby móc dostawać powiadomienia o nowych wynikach." :
                "Zaloguj się, aby otrzymywać powiadomienia.")
                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
        }
        .alert("Błąd logowania", isPresented: $showingSignInErrorAlert) {
            Button("OK") { }
            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
        } message: {
            Text(appleSignInCoordinator.errorMessage ?? "Wystąpił nieoczekiwany błąd")
                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
        }
        .onChange(of: appleSignInCoordinator.errorMessage) { _, newValue in
            if newValue != nil {
                showingSignInErrorAlert = true
            }
        }
        .accessibilityLabel("Alert")
        .accessibilityHint("Set up search alerts")
    }
    
    private func checkNotificationPermission() {
        // Check premium access first
        if let premiumCheck = premiumCheck, !premiumCheck() {
            PaywallManager.shared.presentPaywall(onSuccess: {
                // Re-run permission flow after premium is granted
                checkNotificationPermission()
            })
            return
        }
        // Check notification permission and request permission if needed
        Task {
            let status = await NotificationManager.shared.checkNotificationPermission()
            if status == .notDetermined {
                let granted = await NotificationManager.shared.requestNotificationPermission()
                await MainActor.run {
                    if granted {
                        showingFrequencyDialog = true
                    } else {
                        showingNotificationDisabledAlert = true
                    }
                }
            } else if status == .authorized {
                await MainActor.run {
                    showingFrequencyDialog = true
                }
            } else {
                await MainActor.run {
                    showingNotificationDisabledAlert = true
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func handleFrequencySelection(_ frequency: AlertFrequency) {
        // Save the alert first
        onFrequencySelected(frequency)
        
        // Show success animation
        showSuccessAnimation()
        
        // Check if user is not logged in with Apple ID
        if !AuthenticationManager.shared.hasAppleIDLinked {
            showingLoginAlert = true
        }
    }
    
    private func showSuccessAnimation() {
        // Trigger success animation
        showingSuccessAnimation = true
        
        // Animate the checkmark appearance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            successScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            successOpacity = 1.0
        }
        
        // Add haptic feedback for success
        Haptics.notification(.success)
        
        // Reset animation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                successOpacity = 0.0
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                successScale = 0.0
            }
            
            // Reset the button state after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingSuccessAnimation = false
            }
        }
    }
}
