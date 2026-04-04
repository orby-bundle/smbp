import SwiftUI
import UIKit

struct OnboardingCarouselView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    let onFinish: (() -> Void)?

    @StateObject private var appleSignInCoordinator = SignInWithAppleCoordinator()

    @State private var currentIndex = 0
    @State private var animationTrigger = 0
    @State private var didFinish = false
    @State private var showingSignInErrorAlert = false

    @State private var showSuccessOverlay = false
    @State private var successOverlayScale: CGFloat = 0.92
    @State private var successOverlayOpacity: Double = 0.0

    private let steps = OnboardingStep.defaultSteps

    var body: some View {
        GeometryReader { fullProxy in
            let width = max(1, fullProxy.size.width)

            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 16) {
                    TabView(selection: $currentIndex) {
                        ForEach(steps.indices, id: \.self) { index in
                            OnboardingStepPage(
                                step: steps[index],
                                pageIndex: index,
                                currentIndex: currentIndex,
                                width: width,
                                animationTrigger: animationTrigger,
                                appleSignInCoordinator: appleSignInCoordinator,
                                authManager: authManager,
                                onPrimaryAction: primaryAction(for: index),
                                onSecondaryAction: finishOnboarding
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.snappy(duration: 0.35), value: currentIndex)

                    VStack(spacing: 14) {
                        progressDots
                        bottomActions
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }

                if showSuccessOverlay {
                    successOverlay
                        .transition(.opacity)
                }
            }
        }
        .task {
            // Trigger initial appear animations for the first visible page.
            animationTrigger &+= 1
        }
        .onChange(of: currentIndex) { _, _ in
            animationTrigger &+= 1
        }
        .onChange(of: appleSignInCoordinator.errorMessage) { _, newValue in
            if newValue != nil {
                showingSignInErrorAlert = true
            }
        }
        .onChange(of: authManager.hasAppleIDLinked) { _, hasAppleIDLinked in
            guard hasAppleIDLinked else { return }
            playSuccessAndFinish()
        }
        .alert("Błąd logowania", isPresented: $showingSignInErrorAlert) {
            Button("OK") { }
        } message: {
            Text(appleSignInCoordinator.errorMessage ?? "Wystąpił nieoczekiwany błąd")
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { idx in
                Capsule(style: .continuous)
                    .fill(idx == currentIndex ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: idx == currentIndex ? 22 : 8, height: 8)
                    .animation(.snappy(duration: 0.25), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Postęp przewodnika")
        .accessibilityValue("\(currentIndex + 1) z \(steps.count)")
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            if currentIndex == steps.count - 1 {
                Button(action: finishOnboarding) {
                    Text("Nie teraz")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .foregroundStyle(.primary)
                .accessibilityLabel("Pomiń logowanie")
            } else {
                Button(action: finishOnboarding) {
                    Text("Pomiń")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .foregroundStyle(.primary)
                .accessibilityLabel("Pomiń przewodnik")

                Button(action: goToNextPage) {
                    Text("Dalej")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Dalej")
                .accessibilityHint("Przejdź do następnego kroku")
            }
        }
        .frame(maxWidth: 520)
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)

                Text("Zalogowano")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .scaleEffect(successOverlayScale)
            .opacity(successOverlayOpacity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Zalogowano")
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                successOverlayScale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                successOverlayOpacity = 1.0
            }
        }
    }

    private func primaryAction(for index: Int) -> (() -> Void)? {
        guard index == steps.count - 1 else { return nil }
        if authManager.hasAppleIDLinked {
            return finishOnboarding
        }
        return appleSignInCoordinator.triggerSignIn
    }

    private func goToNextPage() {
        guard currentIndex < steps.count - 1 else { return }
        currentIndex += 1
    }

    private func playSuccessAndFinish() {
        guard !didFinish else { return }

        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)

        showSuccessOverlay = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        guard !didFinish else { return }
        didFinish = true
        onFinish?()
        dismiss()
    }
}

// MARK: - Step model

private struct OnboardingStep: Identifiable {
    enum Kind {
        case welcome
        case feature
        case signIn
    }

    let id = UUID()
    let kind: Kind
    let systemImage: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

private extension OnboardingStep {
    static let defaultSteps: [OnboardingStep] = [
        OnboardingStep(
            kind: .welcome,
            systemImage: "",
            title: "Witamy w SM Baza Prawa",
            subtitle: "Dziękujemy za zaufanie!",
            gradient: []
        ),
        OnboardingStep(
            kind: .feature,
            systemImage: "building.columns.fill",
            title: "Aktualne prawo w kilka sekund",
            subtitle: "Akty polskie i unijne, orzeczenia sądowe oraz procesy legislacyjne w jednym miejscu - szybko i wygodnie.",
            gradient: [Color.blue, Color.cyan]
        ),
        OnboardingStep(
            kind: .feature,
            systemImage: "bell.circle.fill",
            title: "Ulubione akty i personalizowane alerty",
            subtitle: "Zapisuj i udostępniaj ważne akty, otrzymuj powiadomienia o nowych dokumentach według ustawionych kryteriów.",
            gradient: [Color.indigo, Color.purple]
        ),
        OnboardingStep(
            kind: .feature,
            systemImage: "lock.circle.fill",
            title: "Pełna prywatność i bezpieczeństwo",
            subtitle: "Dane są przechowywane lokalnie na urządzeniu i nie są udostępniane żadnym serwisom.",
            gradient: [Color.orange, Color.pink]
        ),
        OnboardingStep(
            kind: .feature,
            systemImage: "sparkles",
            title: "Pełna baza prawa zawsze pod ręką",
            subtitle: "Dostęp do wszystkich akt w jednym miejscu oraz automatyczne zawiadomienia o interesujących Cię tematach.",
            gradient: [Color.blue, Color.indigo]
        ),
        OnboardingStep(
            kind: .signIn,
            systemImage: "person.crop.circle.badge.checkmark",
            title: "Synchronizacja przez Apple ID",
            subtitle: "Zaloguj się, aby móc otrzymywać powiadomienia o swoich alertach. Możesz też zrobić to później w Ustawieniach.",
            gradient: [Color.green, Color.teal]
        )
    ]
}

// MARK: - Page

private struct OnboardingStepPage: View {
    let step: OnboardingStep
    let pageIndex: Int
    let currentIndex: Int
    let width: CGFloat
    let animationTrigger: Int

    let appleSignInCoordinator: SignInWithAppleCoordinator
    let authManager: AuthenticationManager

    let onPrimaryAction: (() -> Void)?
    let onSecondaryAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var localAnimationTick = 0

    private var isActive: Bool { pageIndex == currentIndex }
    private var shouldUseScrollLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        GeometryReader { proxy in
            let minX = proxy.frame(in: .global).minX
            let progress = min(max(minX / width, -1), 1)
            let pageScale = 1 - (abs(progress) * 0.05)
            let pageOpacity = 1 - (abs(progress) * 0.25)
            let contentParallaxX = reduceMotion ? 0 : (-progress * 14)

            ZStack(alignment: .bottom) {
                if step.kind == .welcome {
                    Color.white.ignoresSafeArea()
                } else {
                    OnboardingBackground(gradient: step.gradient, trigger: animationTrigger)
                        .opacity(0.95)
                        .ignoresSafeArea()
                }

                Group {
                    if shouldUseScrollLayout {
                        ScrollView(showsIndicators: false) {
                            contentStack(progress: progress)
                                .padding(.top, 26)
                                .padding(.bottom, 44)
                        }
                    } else {
                        VStack {
                            Spacer(minLength: 14)
                            contentStack(progress: progress)
                            Spacer(minLength: 10)
                        }
                    }
                }
                .offset(x: contentParallaxX)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .scaleEffect(pageScale)
            .opacity(pageOpacity)
        }
        .onAppear {
            // Important: some pages are created only when navigated to via buttons.
            // Trigger the appear animation when the page becomes visible.
            if isActive {
                localAnimationTick &+= 1
            }
        }
        .onChange(of: currentIndex) { _, _ in
            if isActive {
                localAnimationTick &+= 1
            }
        }
    }

    @ViewBuilder
    private func contentStack(progress: CGFloat) -> some View {
        if step.kind == .welcome {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 18) {
                    appIconMark
                    animatedTextBlock
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 18) {
                hero(progress: progress)
                    .padding(.top, 18)

                animatedTextBlock
                    .padding(.horizontal, 22)

                if step.kind == .signIn {
                    signInSection
                        .padding(.top, 10)
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private var animatedTextBlock: some View {
        let active = isActive
        let base = VStack(spacing: step.kind == .welcome ? 12 : 10) {
            Text(step.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            Text(step.subtitle)
                .font(.system(step.kind == .welcome ? .title3 : .body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(step.kind == .welcome ? 1 : 2)
                .fixedSize(horizontal: false, vertical: true)
        }

        if reduceMotion {
            base
        } else {
            base
                .keyframeAnimator(
                    initialValue: TextAppearValues(),
                    trigger: "\(localAnimationTick)-\(active)-text"
                ) { content, value in
                    content
                        .opacity(active ? value.opacity : 0.0)
                        .offset(y: active ? value.y : 0)
                        .blur(radius: active ? value.blur : 0)
                } keyframes: { _ in
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(0.0, duration: 0.0)
                        CubicKeyframe(1.0, duration: 0.55)
                    }
                    KeyframeTrack(\.y) {
                        CubicKeyframe(10, duration: 0.0)
                        CubicKeyframe(0, duration: 0.55)
                    }
                    KeyframeTrack(\.blur) {
                        CubicKeyframe(6, duration: 0.0)
                        CubicKeyframe(0, duration: 0.55)
                    }
                }
        }
    }

    @ViewBuilder
    private func hero(progress: CGFloat) -> some View {
        let parallaxX = reduceMotion ? 0 : (-progress * 32)
        let active = isActive

        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: step.gradient.map { $0.opacity(0.35) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 0)

            if reduceMotion {
                Image(systemName: step.systemImage)
                    .font(.system(size: 62, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.white.opacity(0.35))
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
            } else {
                Image(systemName: step.systemImage)
                    .font(.system(size: 62, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.white.opacity(0.35))
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
                    .keyframeAnimator(
                        initialValue: HeroValues(),
                        trigger: "\(localAnimationTick)-\(active)"
                    ) { content, value in
                        content
                            .scaleEffect(value.scale)
                            .rotationEffect(.degrees(value.rotation))
                            .offset(y: value.y)
                            .opacity(value.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.0, duration: 0.05)
                            SpringKeyframe(active ? 1.06 : 1.0, duration: 0.5, spring: .bouncy)
                            SpringKeyframe(1.0, duration: 0.35, spring: .snappy)
                        }
                        KeyframeTrack(\.rotation) {
                            CubicKeyframe(0, duration: 0.0)
                            CubicKeyframe(active ? 2.5 : 0.0, duration: 0.35)
                            CubicKeyframe(0, duration: 0.35)
                        }
                        KeyframeTrack(\.y) {
                            CubicKeyframe(0, duration: 0.0)
                            CubicKeyframe(active ? -6 : 0, duration: 0.35)
                            CubicKeyframe(0, duration: 0.35)
                        }
                        KeyframeTrack(\.opacity) {
                            CubicKeyframe(1.0, duration: 0.0)
                            CubicKeyframe(1.0, duration: 0.8)
                        }
                    }
            }
        }
        .offset(x: parallaxX)
        .accessibilityHidden(true)
    }

    private var appIconMark: some View {
        Image("SMBPGradient")
            .resizable()
            .scaledToFill()
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
        .accessibilityLabel("Ikona aplikacji")
    }

    @ViewBuilder
    private var signInSection: some View {
        VStack(spacing: 12) {
            if authManager.hasAppleIDLinked {
                Button(action: onPrimaryAction ?? onSecondaryAction) {
                    Text("Kontynuuj")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Kontynuuj")
            } else {
                appleSignInCoordinator.signInWithAppleButton
                    .accessibilityLabel("Zaloguj się przez Apple ID")
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Logowanie jest opcjonalne - możesz je pominąć.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 520)
    }
}

private struct HeroValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
    var y: CGFloat = 0.0
    var opacity: Double = 1.0
}

private struct TextAppearValues {
    var opacity: Double = 0.0
    var y: CGFloat = 10.0
    var blur: CGFloat = 6.0
}

// MARK: - Background

private struct OnboardingBackground: View {
    let gradient: [Color]
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let base = ZStack {
            LinearGradient(
                colors: gradient.map { $0.opacity(0.22) } + [Color(.systemBackground).opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            orb(
                size: 240,
                colors: gradient,
                x: -90,
                y: -140,
                blur: 34,
                phaseOffset: 0
            )

            orb(
                size: 180,
                colors: gradient.reversed(),
                x: 120,
                y: -40,
                blur: 32,
                phaseOffset: 1
            )

            orb(
                size: 220,
                colors: gradient,
                x: 60,
                y: 220,
                blur: 40,
                phaseOffset: 2
            )
        }

        if reduceMotion {
            base
        } else {
            base
                .keyframeAnimator(initialValue: OrbValues(), trigger: trigger) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .rotationEffect(.degrees(value.rotation))
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.0, duration: 0.0)
                        CubicKeyframe(1.02, duration: 0.9)
                        CubicKeyframe(1.0, duration: 0.9)
                    }
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(0, duration: 0.0)
                        CubicKeyframe(2.0, duration: 0.9)
                        CubicKeyframe(0, duration: 0.9)
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
                .keyframeAnimator(initialValue: OrbItemValues(), trigger: "\(trigger)-\(phaseOffset)") { content, value in
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
                        CubicKeyframe(1.05, duration: 0.8)
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

private struct OrbValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
}

private struct OrbItemValues {
    var x: CGFloat = 0.0
    var y: CGFloat = 0.0
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}
