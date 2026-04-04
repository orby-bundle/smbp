//
//  SettingsView.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import AuthenticationServices
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var appleSignInCoordinator = SignInWithAppleCoordinator()
    @State private var showingErrorAlert = false
    @State private var showingAccountSheet = false
    @State private var showingLogoutAlert = false
    @State private var showingPrivacySheet = false
    @ObservedObject private var appStateManager = AppStateManager.shared
    @Environment(\.openURL) private var openURL
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isRegularWidth {
                    // iPad layout - use Grid for better space utilization
                    Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 24) {
                        GridRow {
                            accountSection
                            subscriptionSection
                        }
                        
                        GridRow {
                            legalSection
                        }
                        
                        #if DEBUG
                        GridRow {
                            debugSection
                        }
                        #endif
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 20 : 16)
                } else {
                    // iPhone layout - vertical stack
                    VStack(spacing: 24) {
                        // Account Section
                        accountSection
                        
                        // Subscription Section
                        subscriptionSection
                        
                        // Legal Section
                        legalSection
                        
                        // Debug Section (only in debug builds)
                        #if DEBUG
                        debugSection
                        #endif
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 20 : 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Błąd logowania", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(appleSignInCoordinator.errorMessage ?? "Wystąpił nieoczekiwany błąd")
        }
        .alert("UWAGA!", isPresented: $showingLogoutAlert) {
            Button("Anuluj", role: .cancel) { }
            Button("Wyloguj", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Wylogowanie uniemożliwia sprawdzanie alertów w tle.")
        }
        .onChange(of: appleSignInCoordinator.errorMessage) { _, newValue in
            if newValue != nil {
                showingErrorAlert = true
            }
        }
        .sheet(isPresented: $showingAccountSheet) {
            AccountSheetView(showingLogoutAlert: $showingLogoutAlert)
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showingPrivacySheet) {
            if let privacyURL = URL(string: "https://baza-prawna.pl/polityka-prywatnosci.html") {
                SafariView(url: privacyURL, entersReaderIfAvailable: true)
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Konto")
                    .font(isRegularWidth ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, isRegularWidth ? 20 : 16)
            
            // Account Card
            VStack(spacing: 0) {
                // Account Info - Tappable for authenticated users
                if authManager.isAuthenticated {
                    Button(action: {
                        showingAccountSheet = true
                    }) {
                        HStack(spacing: isRegularWidth ? 20 : 16) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(authManager.hasAppleIDLinked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    .frame(width: isRegularWidth ? 70 : 60, height: isRegularWidth ? 70 : 60)
                                
                                Image(systemName: authManager.hasAppleIDLinked ? "person.circle.fill" : "person.circle")
                                    .font(isRegularWidth ? .largeTitle : .title)
                                    .foregroundColor(authManager.hasAppleIDLinked ? .blue : .secondary)
                            }
                            
                            // User Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authStatusText)
                                    .font(isRegularWidth ? .title3 : .headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let email = authManager.userEmail {
                                    Text(email)
                                        .font(isRegularWidth ? .body : .subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                            }
                            
                            Spacer()
                            
                            // Status Indicator and Chevron
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(authManager.hasAppleIDLinked ? .green : .orange)
                                        .frame(width: 8, height: 8)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, isRegularWidth ? 24 : 20)
                        .padding(.vertical, isRegularWidth ? 20 : 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    HStack(spacing: isRegularWidth ? 20 : 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: isRegularWidth ? 70 : 60, height: isRegularWidth ? 70 : 60)
                            
                            Image(systemName: "person.circle")
                                .font(isRegularWidth ? .largeTitle : .title)
                                .foregroundColor(.secondary)
                        }
                        
                        // User Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authStatusText)
                                .font(isRegularWidth ? .title3 : .headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 20 : 16)
                }
                
                // Divider
                if !authManager.isAuthenticated {
                    Divider()
                        .padding(.horizontal, isRegularWidth ? 24 : 20)
                }
                
                // Actions
                if !authManager.isAuthenticated {
                    VStack(spacing: 12) {
                        appleSignInCoordinator.signInWithAppleButton
                        
                        Text("Zaloguj się, aby alerty były sprawdzane w tle, a urządzenie pokazywało powiadomienia o nowych wynikach")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 16 : 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Subskrypcja")
                    .font(isRegularWidth ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, isRegularWidth ? 20 : 16)
            
            // Subscription Card
            SubscriptionStatusView()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
        }
    }
    
    // MARK: - Debug Section
    #if DEBUG
    private var debugSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug")
                    .font(isRegularWidth ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, isRegularWidth ? 20 : 16)
            
            // Debug Card
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { appStateManager.forceShowSearchHelp },
                    set: { newValue in
                        if newValue {
                            appStateManager.resetSearchHelp()
                        } else {
                            appStateManager.markSearchHelpSeen()
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("Show visual aids")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, isRegularWidth ? 24 : 20)
                .padding(.vertical, isRegularWidth ? 16 : 12)
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                Divider()
                    .padding(.horizontal, isRegularWidth ? 24 : 20)

                Button(action: {
                    authManager.resetAuthentication()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.red)
                        Text("Reset Authentication")
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 16 : 12)
                }
                
                Divider()
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                
                Button(action: {
                    Task {
                        await SubscriptionManager.shared.resetToInitialState()
                    }
                }) {
                    HStack {
                        Image(systemName: "crown")
                            .font(.title3)
                            .foregroundColor(.red)
                        Text("Reset Subscription Status")
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 16 : 12)
                }

            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            
            // Footer
            Text("Tylko w trybie deweloperskim")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    #endif
    
    // MARK: - Computed Properties
    
    private var authStatusText: String {
        if !authManager.isAuthenticated {
            return "Niezalogowany"
        } else if authManager.hasAppleIDLinked {
            return "Zalogowany przez Apple ID"
        } else {
            return "Zalogowany"
        }
    }
    
    // MARK: - Private Methods
}

// MARK: - Legal Section
private extension SettingsView {
    var legalSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dodatkowe informacje")
                    .font(isRegularWidth ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, isRegularWidth ? 20 : 16)
            
            VStack(spacing: 0) {
                NavigationLink {
                    UserHelpView()
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Text("Opis funkcjonalności aplikacji")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 16 : 12)
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .padding(.horizontal, isRegularWidth ? 24 : 20)

                Button(action: {
                    showingPrivacySheet = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Text("Polityka prywatności")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 16 : 12)
                }

                Divider()
                    .padding(.horizontal, isRegularWidth ? 24 : 20)

                Button(action: {
                    // Open Mail app with prefilled recipient and subject
                    if let url = URL(string: "mailto:bazaprawna.pl@gmail.com?subject=Powiadomienie%20z%20aplikacji") {
                        openURL(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Text("Napisz do nas")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 16 : 12)
                }

                Divider()
                    .padding(.horizontal, isRegularWidth ? 24 : 20)

                Button(action: {
                    appStateManager.resetOnboarding()
                }) {
                    HStack {
                        Image(systemName: "map")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Text("Pokaż przewodnik")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 16 : 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
}

// MARK: - Privacy Policy Markdown Sheet
struct PrivacyPolicyMarkdownView: View {
    let fileName: String
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var markdownText: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let attributed = try? AttributedString(markdown: markdownText) {
                    Text(attributed)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                } else {
                    Text(markdownText.isEmpty ? "Nie udało się wczytać dokumentu." : markdownText)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zamknij") { dismiss() }
                }
            }
            .onAppear(perform: loadMarkdown)
        }
    }
    
    private func loadMarkdown() {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "md"),
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            markdownText = text
        } else {
            markdownText = "Nie znaleziono pliku \(fileName).md w pakiecie aplikacji. Upewnij się, że plik jest dodany do zasobów celu aplikacji."
        }
    }
}

// MARK: - Subscription Status View
struct SubscriptionStatusView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Subscription Info - Tappable for premium users
            if subscriptionManager.isPremium {
                Button(action: {
                    openManageSubscriptions()
                }) {
                    HStack(spacing: isRegularWidth ? 20 : 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.1))
                                .frame(width: isRegularWidth ? 70 : 60, height: isRegularWidth ? 70 : 60)
                            
                            Image(systemName: "crown.fill")
                                .font(isRegularWidth ? .largeTitle : .title)
                                .foregroundColor(.yellow)
                        }
                        
                        // Status Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscriptionStatusText)
                                .font(isRegularWidth ? .title2 : .title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Pełny dostęp do wszystkich funkcji")
                                .font(isRegularWidth ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Status Indicator and Chevron
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                    .padding(.vertical, isRegularWidth ? 20 : 16)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                HStack(spacing: isRegularWidth ? 20 : 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: isRegularWidth ? 70 : 60, height: isRegularWidth ? 70 : 60)
                        
                        Image(systemName: "nosign")
                            .font(isRegularWidth ? .largeTitle : .title)
                            .foregroundColor(.secondary)
                    }
                    
                    // Status Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionStatusText)
                            .font(isRegularWidth ? .title2 : .title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Ograniczony dostęp")
                            .font(isRegularWidth ? .body : .subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, isRegularWidth ? 24 : 20)
                .padding(.vertical, isRegularWidth ? 20 : 16)
            }
            
            // Actions
            if !subscriptionManager.isPremium {
                Divider()
                    .padding(.horizontal, isRegularWidth ? 24 : 20)
                
                VStack(spacing: 0) {
                    Button(action: {
                        PaywallManager.shared.presentPaywall()
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                            Text("Rozpocznij Premium")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, isRegularWidth ? 24 : 20)
                        .padding(.vertical, isRegularWidth ? 16 : 12)
                    }
                    
                    Divider()
                        .padding(.horizontal, isRegularWidth ? 24 : 20)
                    
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }) {
                        HStack {
                            
                            Text("Przywróć zakupy")
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, isRegularWidth ? 24 : 20)
                        .padding(.vertical, isRegularWidth ? 16 : 12)
                    }
                }
            }
        }
    }
    
    private var subscriptionStatusText: String {
        if subscriptionManager.isPremium {
            return "Premium"
        } else {
            return "Brak subskrypcji"
        }
    }
    
    private func openManageSubscriptions() {
        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    print("No window scene available")
                    return
                }
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                print("Failed to show manage subscriptions: \(error)")
            }
        }
    }
}

// MARK: - Account Sheet View
struct AccountSheetView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @Binding var showingLogoutAlert: Bool
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Account Info
                VStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(authManager.hasAppleIDLinked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: authManager.hasAppleIDLinked ? "person.circle.fill" : "person.circle")
                            .font(.largeTitle)
                            .foregroundColor(authManager.hasAppleIDLinked ? .blue : .secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text(authStatusText)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if let email = authManager.userEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Logout / Delete Buttons
                if authManager.hasAppleIDLinked {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .font(.title3)
                                Text("Wyloguj się")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                        }

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.title3)
                                Text("Usuń konto")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Konto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if !isAuthenticated {
                    dismiss()
                }
            }
        }
        .alert("Czy na pewno chcesz usunąć konto?", isPresented: $showingDeleteAlert) {
            Button("Anuluj", role: .cancel) { }
            Button("Usuń", role: .destructive) {
                Task {
                    if let userId = authManager.userUID {
                        await FirebaseManager.shared.deleteUserData(userId: userId)
                    }
                    authManager.signOutAndDeleteAccount()
                    dismiss()
                }
            }
        } message: {
            Text("Spowoduje to trwałe usunięcie Twoich danych (w tym alertów) z naszych serwerów. \n\nTej operacji nie można cofnąć. Możesz jednak zalogować się ponownie.")
        }
    }
    
    private var authStatusText: String {
        if authManager.hasAppleIDLinked {
            return "Zalogowany przez Apple ID"
        } else {
            return "Zalogowany"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
}
