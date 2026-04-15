//
//  PaywallView.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import StoreKit
import PostHog

// MARK: - Helper Functions
private func getPeriodText(for product: Product) -> String {
    // Use StoreKit's subscription period information
    if let subscription = product.subscription {
        let period = subscription.subscriptionPeriod
        switch period.unit {
        case .day:
            // Handle weekly subscriptions configured as 7 days
            if period.value == 7 {
                return "tydzień"
            }
            return period.value == 1 ? "dzień" : "dni"
        case .week:
            return period.value == 1 ? "tydzień" : "tygodni"
        case .month:
            return period.value == 1 ? "miesiąc" : "miesięcy"
        case .year:
            return period.value == 1 ? "rok" : "lat"
        @unknown default:
            return "okres"
        }
    }
    return "okres"
}

struct PaywallView: View {
    private enum ProductIds {
        static let weekly = "101010"
        static let monthly = "010101"
        static let yearly = "111111"
    }

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var paywallManager = PaywallManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isEligibleForTrial = false
    @State private var isCheckingEligibility = true
    @Environment(\.isEligibleForTrial) private var environmentTrialEligibility
    @State private var introOpacity: Double = 0
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfUse = false
    @State private var loadingTimedOut = false
    @State private var ctaPulseTick = 0
    @State private var loadingTimeoutToken = UUID()
    @State private var disclosuresExpanded = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    
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
            GeometryReader { geometry in
                ZStack {
                    PaywallAnimatedBackground(trigger: ctaPulseTick)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        if isRegularWidth {
                            // iPad layout - side-by-side content
                            HStack(alignment: .top, spacing: 40) {
                                // Left side - Hero and Benefits
                                VStack(spacing: 0) {
                                    heroSection
                                    
                                    benefitsSection
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Right side - Subscription and Purchase
                                VStack(spacing: 0) {
                                    Spacer().frame(height: 60) // Match header height
                                    
                                    subscriptionSection
                                    
                                    purchaseSection
                                    
                                    footerSection
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 40)
                        } else {
                            // iPhone layout - vertical stack
                            VStack(spacing: 0) {
                                // Header Section (moved to safe-area inset)
                                // Hero Content
                                heroSection
                                
                                // Benefits Section
                                benefitsSection
                                
                                // Subscription Options
                                subscriptionSection
                                
                                // Purchase Button
                                purchaseSection
                                
                                // Footer
                                footerSection
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .opacity(introOpacity)
                }
            }
            .navigationBarHidden(true)
        }
        .postHogScreenView("Paywall")
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .safeAreaInset(edge: .top) {
            topCloseInset
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            if let privacyURL = URL(string: "https://baza-prawna.pl/polityka-prywatnosci.html") {
                SafariView(url: privacyURL)
            }
        }
        .sheet(isPresented: $showingTermsOfUse) {
            if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                SafariView(url: termsURL)
            }
        }
        .onAppear {
            // Track Paywall Viewed
            PostHogSDK.shared.capture("Paywall Viewed")
            
            // Smooth, simple fade-in for the entire paywall content
            introOpacity = 0
            withAnimation(.easeInOut(duration: 1.5)) {
                introOpacity = 1
            }
            if selectedProduct == nil && !subscriptionManager.products.isEmpty 
            {
                // Auto-select the monthly plan
                selectedProduct = subscriptionManager.products.first { $0.id == ProductIds.monthly } ?? subscriptionManager.products.first
            }
            
            // Use environment value for previews, otherwise check eligibility
            if let environmentTrialEligibility = environmentTrialEligibility {
                isEligibleForTrial = environmentTrialEligibility
                isCheckingEligibility = false
            } else {
                // Check trial eligibility
                Task {
                    await checkTrialEligibility()
                }
            }
            
            startLoadingTimeout()
        }
        .onDisappear {
            // Reset so the fade-in runs when the paywall is shown again
            introOpacity = 0
        }
    }
    
    // MARK: - Close Button (Top Inset)
    private var topCloseInset: some View {
        HStack {
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    paywallManager.dismissPaywall()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: isRegularWidth ? 18 : 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: isRegularWidth ? 40 : 36, height: isRegularWidth ? 40 : 36)
                    .background(
                        Circle()
                            .fillAdaptiveUltraThinMaterial(reduceTransparency: accessibilityReduceTransparency)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Zamknij")
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, isRegularWidth ? 20 : 16)
        .padding(.top, isRegularWidth ? 8 : 6)
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: isRegularWidth ? 24 : 20) {
            VStack(spacing: isRegularWidth ? 20 : 16) {
                // Premium badge/icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isRegularWidth ? 80 : 64, height: isRegularWidth ? 80 : 64)
                    
                    Group {
                        if reduceMotion {
                            Image(systemName: "crown.fill")
                        } else {
                            Image(systemName: "crown.fill")
                                .symbolEffect(.bounce, value: ctaPulseTick)
                        }
                    }
                    .font(.system(size: isRegularWidth ? 36 : 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.yellow.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .padding(.bottom, isRegularWidth ? 8 : 4)
                
                Text("Dostęp Premium")
                    .font(isRegularWidth ? .system(size: 52, weight: .bold, design: .rounded) : .system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)

                if isEligibleForTrial && !isCheckingEligibility {
                    HStack(alignment: .center, spacing: isRegularWidth ? 12 : 10) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: isRegularWidth ? 32 : 26, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: isRegularWidth ? 44 : 36)

                        VStack(alignment: .leading, spacing: isRegularWidth ? 4 : 3) {
                            Text("30 dni za darmo")
                                .font(isRegularWidth ? .title2 : .title3)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("W tej chwili za nic nie płacisz")
                                .font(isRegularWidth ? .headline : .subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, isRegularWidth ? 10 : 8)
                    .padding(.horizontal, isRegularWidth ? 16 : 12)
                    .background(
                        RoundedRectangle(cornerRadius: isRegularWidth ? 14 : 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.12), Color.green.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: isRegularWidth ? 14 : 12, style: .continuous)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.12), radius: 10, x: 0, y: 4)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isEligibleForTrial)
                }
                
                Text("Uzyskaj dostęp do wszystkich funkcji")
                    .font(isRegularWidth ? .title3 : .headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(isRegularWidth ? 3 : 2)
                    .lineSpacing(4)
            }
            .padding(.horizontal, isRegularWidth ? 0 : 20)
            .padding(.top, isRegularWidth ? 40 : 32)
        }
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(spacing: isRegularWidth ? 28 : 20) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: isRegularWidth ? 16 : 12),
                    GridItem(.flexible(), spacing: isRegularWidth ? 16 : 12)
                ],
                spacing: isRegularWidth ? 16 : 12
            ) {
                FeatureTile(
                    icon: "bell.badge.fill",
                    title: "Alerty",
                    isRegularWidth: isRegularWidth
                )

                FeatureTile(
                    icon: "document.on.document.fill",
                    title: "Prawo UE",
                    isRegularWidth: isRegularWidth
                )

                FeatureTile(
                    icon: "hammer.fill",
                    title: "Orzeczenia",
                    isRegularWidth: isRegularWidth
                )

                FeatureTile(
                    icon: "scroll.fill",
                    title: "Legislacja",
                    isRegularWidth: isRegularWidth
                )
            }
            .padding(.horizontal, isRegularWidth ? 0 : 20)
            
            // Update notice
            Text("Stała aktualizacja na bieżąco!")
                .font(isRegularWidth ? .title3 : .headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, isRegularWidth ? 0 : 20)
                .padding(.top, isRegularWidth ? 24 : 20)
        }
        .padding(.top, isRegularWidth ? 48 : 36)
    }
    
    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(spacing: isRegularWidth ? 24 : 18) {
            if subscriptionManager.products.isEmpty, subscriptionManager.isLoading, !loadingTimedOut {
                VStack(spacing: isRegularWidth ? 20 : 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(isRegularWidth ? 1.4 : 1.2)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: subscriptionManager.isLoading)
                    Text("Ładowanie opcji subskrypcji...")
                        .font(isRegularWidth ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: subscriptionManager.isLoading)
                }
                .frame(height: isRegularWidth ? 140 : 120)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if !subscriptionManager.products.isEmpty {
                VStack(spacing: isRegularWidth ? 16 : 12) {
                    if let message = subscriptionManager.errorMessage {
                        Text(message)
                            .font(isRegularWidth ? .caption : .caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fillAdaptiveUltraThinMaterial(reduceTransparency: accessibilityReduceTransparency)
                            )
                            .transition(.opacity)
                    } else if subscriptionManager.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("Aktualizowanie…")
                                .font(isRegularWidth ? .caption : .caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(subscriptionManager.products.enumerated()), id: \.element.id) { index, product in
                        SubscriptionCard(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            isRecommended: product.id == ProductIds.monthly,
                            savingsPercent: yearlySavingsPercent(for: product),
                            billingSummary: billingSummary(for: product),
                            isEligibleForTrial: isEligibleForTrial,
                            isCheckingEligibility: isCheckingEligibility,
                            isPurchasing: isPurchasing,
                            isRegularWidth: isRegularWidth,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedProduct = product
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                ctaPulseTick &+= 1
                            }
                        )
                    }
                }
                .padding(.horizontal, isRegularWidth ? 0 : 20)
            } else {
                paywallErrorState
                    .padding(.horizontal, isRegularWidth ? 0 : 20)
            }
        }
        .padding(.top, isRegularWidth ? 48 : 36)
    }
    
    // MARK: - Purchase Section
    private var purchaseSection: some View {
        VStack(spacing: isRegularWidth ? 20 : 16) {
            if let selectedProduct = selectedProduct {
                VStack(spacing: isRegularWidth ? 16 : 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            isPurchasing = true
                        }
                        
                        // Track Trial Started if eligible
                        if isEligibleForTrial {
                             PostHogSDK.shared.capture("Trial Started")
                        }
                        
                        Task {
                            await purchaseProduct(selectedProduct)
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(isRegularWidth ? 1.0 : 0.9)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPurchasing)
                            } else if isCheckingEligibility {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(isRegularWidth ? 1.0 : 0.9)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isCheckingEligibility)
                            } else {
                                Text(buttonText)
                                    .font(isRegularWidth ? .title3 : .body)
                                    .fontWeight(.bold)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isRegularWidth ? 64 : 56)
                        .background(
                            Group {
                                if isPurchasing {
                                    RoundedRectangle(cornerRadius: isRegularWidth ? 18 : 16)
                                        .fill(Color.blue.opacity(0.8))
                                } else {
                                    RoundedRectangle(cornerRadius: isRegularWidth ? 18 : 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        )
                        .shadow(color: Color.blue.opacity(isPurchasing ? 0.3 : 0.4), radius: isPurchasing ? 8 : 16, x: 0, y: isPurchasing ? 4 : 8)
                        .scaleEffect(isPurchasing ? 0.98 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPurchasing)
                        .modifier(CTAPulseModifier(trigger: ctaPulseTick, enabled: !reduceMotion))
                    }
                    .disabled(isPurchasing || isCheckingEligibility)
                    .accessibilityLabel(buttonText)
                    .buttonStyle(ScaleButtonStyle())
                    
                    Text(buttonSubtext)
                        .font(isRegularWidth ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(isRegularWidth ? 3 : 2)
                        .opacity(isPurchasing ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isPurchasing)
                        .padding(.horizontal, isRegularWidth ? 8 : 4)

                    if isEligibleForTrial && !isCheckingEligibility {
                        trialTimeline(selectedProduct: selectedProduct)
                            .padding(.top, 2)
                    }
                    
                    Text("Płatność przez Apple ID. Możesz anulować w App Store.")
                        .font(isRegularWidth ? .caption : .caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)

                    DisclosureGroup("Szczegóły subskrypcji", isExpanded: $disclosuresExpanded) {
                        VStack(alignment: .leading, spacing: isRegularWidth ? 6 : 4) {
                            Text("• Płatność zostanie pobrana z konta Apple ID przy potwierdzeniu zakupu.")
                            Text("• Subskrypcja odnawia się automatycznie, chyba że zostanie anulowana co najmniej 24 godziny przed końcem bieżącego okresu. Konto zostanie obciążone opłatą za odnowienie w ciągu 24 godzin przed końcem bieżącego okresu.")
                            Text("• Zarządzaj subskrypcją i anuluj w ustawieniach aplikacji lub App Store po zakupie.")
                            if isEligibleForTrial {
                                Text("• Niewykorzystana część bezpłatnego okresu próbnego przepada po zakupie subskrypcji.")
                            }
                        }
                        .font(isRegularWidth ? .caption : .caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                    }
                    .font(isRegularWidth ? .caption : .caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, isRegularWidth ? 0 : 20)
            }
        }
        .padding(.top, isRegularWidth ? 36 : 28)
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: isRegularWidth ? 24 : 20) {
            HStack(spacing: isRegularWidth ? 32 : 24) {
                Button("Przywróć Zakupy") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .font(isRegularWidth ? .subheadline : .caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .accessibilityLabel("Przywróć poprzednie zakupy")
                
                Text("•")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(isRegularWidth ? .subheadline : .caption)
                              
                Button("Polityka Prywatności") {
                    showingPrivacyPolicy = true
                }
                .font(isRegularWidth ? .subheadline : .caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .accessibilityLabel("Zobacz politykę prywatności")

                Text("•")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(isRegularWidth ? .subheadline : .caption)

                Button("Warunki użytkowania") {
                    showingTermsOfUse = true
                }
                .font(isRegularWidth ? .subheadline : .caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .accessibilityLabel("Zobacz warunki użytkowania")
            }
        }
        .padding(.horizontal, isRegularWidth ? 0 : 20)
        .padding(.top, isRegularWidth ? 48 : 36)
        .padding(.bottom, isRegularWidth ? 50 : 40)
    }
    
    private func purchaseProduct(_ product: Product) async {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isPurchasing = true
        }
        
        do {
            _ = try await subscriptionManager.purchase(product)
            
            // Track Subscription Successful
            PostHogSDK.shared.capture("Subscription Successful", properties: [
                "product_id": product.id,
                "price": product.displayPrice,
                "currency": product.priceFormatStyle.currencyCode
            ])
            
            // Success animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                // Add success feedback here if needed
            }
            
            // Small delay for user to see success state
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            paywallManager.dismissPaywall()
        } catch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isPurchasing = false
        }
    }
    
    private func checkTrialEligibility() async {
        isCheckingEligibility = true
        
        for product in subscriptionManager.products {
            if let subscriptionInfo = product.subscription {
                // Check if user is eligible for introductory offers
                let eligibility = await subscriptionInfo.isEligibleForIntroOffer
                if eligibility {
                    await MainActor.run {
                        isEligibleForTrial = true
                        isCheckingEligibility = false
                    }
                    return
                }
            }
        }
        
        await MainActor.run {
            isEligibleForTrial = false
            isCheckingEligibility = false
        }
    }

    // MARK: - Helpers (Plans / Pricing)

    private func yearlySavingsPercent(for product: Product) -> Int? {
        guard product.id == ProductIds.yearly else { return nil }
        guard
            let monthly = subscriptionManager.products.first(where: { $0.id == ProductIds.monthly }),
            let yearly = subscriptionManager.products.first(where: { $0.id == ProductIds.yearly })
        else { return nil }

        let monthlyPrice = NSDecimalNumber(decimal: monthly.price)
        let yearlyPrice = NSDecimalNumber(decimal: yearly.price)
        let monthlyYearlyCost = monthlyPrice.multiplying(by: NSDecimalNumber(value: 12))
        guard monthlyYearlyCost.compare(NSDecimalNumber.zero) == .orderedDescending else { return nil }

        let savings = monthlyYearlyCost.subtracting(yearlyPrice)
        guard savings.compare(NSDecimalNumber.zero) == .orderedDescending else { return nil }

        let percentage = savings
            .dividing(by: monthlyYearlyCost)
            .multiplying(by: NSDecimalNumber(value: 100))

        let value = percentage.intValue
        return value > 0 ? value : nil
    }

    private func billingSummary(for product: Product) -> String? {
        switch product.id {
        case ProductIds.weekly:
            return "Płatność co tydzień"
        case ProductIds.monthly:
            return "Płatność co miesiąc"
        case ProductIds.yearly:
            if let yearly = subscriptionManager.products.first(where: { $0.id == ProductIds.yearly }) {
                let monthlyEquivalent = (NSDecimalNumber(decimal: yearly.price).dividing(by: 12)).decimalValue
                let approx = monthlyEquivalent.formatted(yearly.priceFormatStyle)
                return "Płatność raz w roku • ok. \(approx)/mies."
            }
            return "Płatność raz w roku"
        default:
            return nil
        }
    }

    // MARK: - Loading recovery

    private func startLoadingTimeout() {
        loadingTimedOut = false
        let token = UUID()
        loadingTimeoutToken = token

        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            guard loadingTimeoutToken == token else { return }

            if subscriptionManager.products.isEmpty && subscriptionManager.isLoading {
                await MainActor.run {
                    loadingTimedOut = true
                }
            }
        }
    }

    private var paywallErrorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: isRegularWidth ? 28 : 24, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(subscriptionManager.errorMessage ?? (loadingTimedOut ? "Nie udało się pobrać opcji subskrypcji." : "Brak dostępnych opcji subskrypcji."))
                .font(isRegularWidth ? .body : .subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                loadingTimedOut = false
                startLoadingTimeout()
                Task {
                    await subscriptionManager.loadProducts()
                    await checkTrialEligibility()
                }
            } label: {
                Text("Spróbuj ponownie")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: 520)
        .padding(.vertical, 12)
    }
    
    // MARK: - Computed Properties
    
    private var buttonText: String {
        if isEligibleForTrial {
            return "Rozpocznij 30-dniowy okres próbny"
        } else {
            return "Subskrybuj"
        }
    }
    
    private var buttonSubtext: String {
        guard let selectedProduct = selectedProduct else { return "" }
        
        if isEligibleForTrial {
            return "Następnie \(selectedProduct.displayPrice)/\(getPeriodText(for: selectedProduct)). Anuluj w dowolnej chwili."
        } else {
            return "\(selectedProduct.displayPrice)/\(getPeriodText(for: selectedProduct)). Anuluj w dowolnej chwili."
        }
    }

    private func trialTimeline(selectedProduct: Product) -> some View {
        HStack(spacing: 8) {
            Label("Dziś", systemImage: "checkmark.seal.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)

            Text("→")
                .foregroundStyle(.secondary.opacity(0.7))

            Text("Za 30 dni: \(selectedProduct.displayPrice)/\(getPeriodText(for: selectedProduct))")
                .foregroundStyle(.secondary)

            Text("•")
                .foregroundStyle(.secondary.opacity(0.6))

            Text("Anuluj w App Store")
                .foregroundStyle(.secondary)
        }
        .font(isRegularWidth ? .caption : .caption2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let isRegularWidth: Bool
    @State private var isHovered = false
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    
    var body: some View {
        HStack(alignment: .center, spacing: isRegularWidth ? 16 : 14) {
            // Icon with modern gradient background
            ZStack {
                RoundedRectangle(cornerRadius: isRegularWidth ? 14 : 12)
                    .fill(
                        LinearGradient(
                            colors: isHovered ? 
                                [Color.blue.opacity(0.2), Color.blue.opacity(0.12)] :
                                [Color.blue.opacity(0.12), Color.blue.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isRegularWidth ? 56 : 48, height: isRegularWidth ? 56 : 48)
                    .shadow(color: Color.blue.opacity(0.1), radius: isHovered ? 8 : 4, x: 0, y: 2)
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(isRegularWidth ? .title2 : .title3)
                    .fontWeight(.semibold)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            
            // Content
            VStack(alignment: .leading, spacing: isRegularWidth ? 6 : 4) {
                Text(title)
                    .font(isRegularWidth ? .title3 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(isRegularWidth ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Premium badge
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(isRegularWidth ? .title2 : .title3)
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .padding(isRegularWidth ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: isRegularWidth ? 18 : 16)
                .fillAdaptiveUltraThinMaterial(reduceTransparency: accessibilityReduceTransparency)
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 12 : 6, x: 0, y: 4)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isHovered = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = false
                }
            }
        }
    }
}

// MARK: - 2x2 feature tiles
struct FeatureTile: View {
    let icon: String
    let title: String
    let isRegularWidth: Bool

    @State private var isPressed = false
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency

    var body: some View {
        VStack(alignment: .center, spacing: isRegularWidth ? 12 : 10) {
            ZStack {
                RoundedRectangle(cornerRadius: isRegularWidth ? 14 : 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.14), Color.blue.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isRegularWidth ? 54 : 46, height: isRegularWidth ? 54 : 46)

                Image(systemName: icon)
                    .font(isRegularWidth ? .title2 : .title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(title)
                .font(isRegularWidth ? .headline : .subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(isRegularWidth ? 18 : 16)
        .frame(maxWidth: .infinity, minHeight: isRegularWidth ? 112 : 104, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: isRegularWidth ? 18 : 16, style: .continuous)
                .fillAdaptiveUltraThinMaterial(reduceTransparency: accessibilityReduceTransparency)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

struct SubscriptionCard: View {
    let product: Product
    let isSelected: Bool
    let isRecommended: Bool
    let savingsPercent: Int?
    let billingSummary: String?
    let isEligibleForTrial: Bool
    let isCheckingEligibility: Bool
    let isPurchasing: Bool
    let isRegularWidth: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isPurchasing)
        .accessibilityLabel("Subskrypcja \(getProductTitle(for: product)), \(product.displayPrice)")
        .accessibilityHint(isPurchasing ? "Przetwarzanie zakupu" : "Dotknij aby kupić")
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: isRegularWidth ? 14 : 10) {
            // Product title with badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(getProductTitle(for: product))
                            .font(isRegularWidth ? .title2 : .title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if let savingsPercent, savingsPercent > 0 {
                            Text("Oszczędzasz \(savingsPercent)%")
                                .font(isRegularWidth ? .caption : .caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(LinearGradient(colors: [Color.green, Color.green.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                )
                                .accessibilityLabel("Oszczędzasz \(savingsPercent) procent")
                        } else if isRecommended {
                            Text("Polecane")
                                .font(isRegularWidth ? .caption : .caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.blue.opacity(0.12))
                                )
                                .accessibilityLabel("Polecane")
                        }
                    }
                    
                    if let billingSummary {
                        Text(billingSummary)
                            .font(isRegularWidth ? .caption : .caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(isRegularWidth ? .title3 : .body)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Trial status or purchasing state
            if isPurchasing {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(isRegularWidth ? 1.0 : 0.8)
                    Text("Przetwarzanie...")
                        .font(isRegularWidth ? .subheadline : .caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            } else if !isCheckingEligibility {
                if isEligibleForTrial {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "gift.fill")
                                .font(isRegularWidth ? .title3 : .body)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Bezpłatnie przez 30 dni,")
                                .font(isRegularWidth ? .title2 : .title3)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        Text("następnie")
                            .font(isRegularWidth ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Okres próbny wygasł")
                        .font(isRegularWidth ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            
            // Price and period
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(product.displayPrice)
                    .font(isRegularWidth ? .system(size: 28, weight: .bold) : .system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("/\(getPeriodText(for: product))")
                    .font(isRegularWidth ? .title3 : .body)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
            
            // Cancel anytime text
            HStack(spacing: 6) {
                Image(systemName: "stop.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                Text("Anuluj w dowolnej chwili")
                    .font(isRegularWidth ? .subheadline : .caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(isRegularWidth ? 24 : 20)
        .background(
            RoundedRectangle(cornerRadius: isRegularWidth ? 20 : 16)
                .fill(isSelected ? 
                    LinearGradient(
                        colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isRegularWidth ? 20 : 16)
                        .stroke(
                            isSelected ? Color.blue : Color.clear,
                            lineWidth: isRegularWidth ? 2.5 : 2
                        )
                )
                .shadow(
                    color: isSelected ? Color.blue.opacity(0.2) : Color.black.opacity(0.05),
                    radius: isSelected ? 12 : 6,
                    x: 0,
                    y: isSelected ? 6 : 3
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private func getProductTitle(for product: Product) -> String {
        // Use the display name from StoreKit, fallback to a default if needed
        return product.displayName.isEmpty ? "Premium" : product.displayName
    }
    
}

#Preview {
    PaywallView()
}

#Preview("Post-Trial State") {
    PaywallViewPreview(isEligibleForTrial: false)
}

struct PaywallViewPreview: View {
    let isEligibleForTrial: Bool
    
    var body: some View {
        PaywallView()
            .environment(\.isEligibleForTrial, isEligibleForTrial)
    }
}

// Environment key to override trial eligibility in previews
private struct IsEligibleForTrialKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var isEligibleForTrial: Bool? {
        get { self[IsEligibleForTrialKey.self] }
        set { self[IsEligibleForTrialKey.self] = newValue }
    }
}

// MARK: - Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Subtle motion (onboarding-style)

private struct CTAPulseModifier: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        guard enabled else { return AnyView(content) }

        return AnyView(
            content
                .keyframeAnimator(initialValue: CTAPulseValues(), trigger: trigger) { view, value in
                    view
                        .scaleEffect(value.scale)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.0, duration: 0.0)
                        SpringKeyframe(1.02, duration: 0.25, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.25, spring: .snappy)
                    }
                }
        )
    }
}

private struct CTAPulseValues {
    var scale: CGFloat = 1.0
}

private struct PaywallAnimatedBackground: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let gradient: [Color] = [Color.blue, Color.cyan]
        let base = ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.97),
                    Color.blue.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            orb(size: 260, colors: gradient, x: -110, y: -160, blur: 38, phaseOffset: 0)
            orb(size: 200, colors: gradient.reversed(), x: 120, y: -70, blur: 36, phaseOffset: 1)
            orb(size: 240, colors: gradient, x: 80, y: 240, blur: 44, phaseOffset: 2)
        }

        if reduceMotion {
            base
        } else {
            base
                .keyframeAnimator(initialValue: PaywallBgValues(), trigger: trigger) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .rotationEffect(.degrees(value.rotation))
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.0, duration: 0.0)
                        CubicKeyframe(1.015, duration: 0.8)
                        CubicKeyframe(1.0, duration: 0.8)
                    }
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(0.0, duration: 0.0)
                        CubicKeyframe(1.2, duration: 0.8)
                        CubicKeyframe(0.0, duration: 0.8)
                    }
                }
        }
    }

    @ViewBuilder
    private func orb(
        size: CGFloat,
        colors: [Color],
        x: CGFloat,
        y: CGFloat,
        blur: CGFloat,
        phaseOffset: Int
    ) -> some View {
        let base = Circle()
            .fill(
                RadialGradient(
                    colors: [
                        colors.first?.opacity(0.55) ?? .accentColor.opacity(0.55),
                        colors.last?.opacity(0.05) ?? .accentColor.opacity(0.05)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.65
                )
            )
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: x, y: y)

        if reduceMotion {
            base
        } else {
            base
                .keyframeAnimator(initialValue: PaywallOrbValues(), trigger: "\(trigger)-\(phaseOffset)") { content, value in
                    content
                        .offset(x: value.x, y: value.y)
                        .scaleEffect(value.scale)
                        .opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.x) {
                        CubicKeyframe(0, duration: 0.0)
                        CubicKeyframe(10, duration: 0.8)
                        CubicKeyframe(-8, duration: 0.8)
                        CubicKeyframe(0, duration: 0.8)
                    }
                    KeyframeTrack(\.y) {
                        CubicKeyframe(0, duration: 0.0)
                        CubicKeyframe(-8, duration: 0.8)
                        CubicKeyframe(10, duration: 0.8)
                        CubicKeyframe(0, duration: 0.8)
                    }
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.0, duration: 0.0)
                        CubicKeyframe(1.04, duration: 0.8)
                        CubicKeyframe(0.98, duration: 0.8)
                        CubicKeyframe(1.0, duration: 0.8)
                    }
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(1.0, duration: 0.0)
                        CubicKeyframe(0.92, duration: 1.2)
                        CubicKeyframe(1.0, duration: 1.2)
                    }
                }
        }
    }
}

private struct PaywallBgValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
}

private struct PaywallOrbValues {
    var x: CGFloat = 0.0
    var y: CGFloat = 0.0
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}
