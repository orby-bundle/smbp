import Foundation
import Combine

// MARK: - User Defaults Keys

enum DefaultsKeys {
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let hasSeenSearchHelp = "hasSeenSearchHelp"
#if DEBUG
    static let forceShowSearchHelp = "forceShowSearchHelp"
#endif
}

extension UserDefaults {
    var hasSeenOnboarding: Bool {
        get { bool(forKey: DefaultsKeys.hasSeenOnboarding) }
        set { set(newValue, forKey: DefaultsKeys.hasSeenOnboarding) }
    }

    var hasSeenSearchHelp: Bool {
        get { bool(forKey: DefaultsKeys.hasSeenSearchHelp) }
        set { set(newValue, forKey: DefaultsKeys.hasSeenSearchHelp) }
    }

#if DEBUG
    var forceShowSearchHelp: Bool {
        get { bool(forKey: DefaultsKeys.forceShowSearchHelp) }
        set { set(newValue, forKey: DefaultsKeys.forceShowSearchHelp) }
    }
#endif
}

final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    @Published var shouldShowOnboarding: Bool
    @Published var shouldShowSearchHelp: Bool
#if DEBUG
    @Published var forceShowSearchHelp: Bool {
        didSet {
            defaults.forceShowSearchHelp = forceShowSearchHelp
        }
    }
#endif

    private var cancellables = Set<AnyCancellable>()
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hasSeen = defaults.hasSeenOnboarding
#if DEBUG
        self.forceShowSearchHelp = defaults.forceShowSearchHelp
#endif
        let hasSeenSearchHelp = defaults.hasSeenSearchHelp
        #if DEBUG
        self.shouldShowOnboarding = false
        #else
        self.shouldShowOnboarding = !hasSeen
        #endif

        if hasSeen && !hasSeenSearchHelp {
            self.shouldShowSearchHelp = true
        } else {
            self.shouldShowSearchHelp = false
        }
#if DEBUG
        if forceShowSearchHelp {
            self.shouldShowSearchHelp = true
        }
#endif

        $shouldShowOnboarding
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                if newValue == false {
                    self.defaults.hasSeenOnboarding = true
                    self.updateSearchHelpVisibilityAfterOnboarding()
                }
            }
            .store(in: &cancellables)
    }

    func markOnboardingSeen() {
        shouldShowOnboarding = false
    }

    func resetOnboarding() {
        defaults.hasSeenOnboarding = false
        shouldShowOnboarding = true
    }

    func markSearchHelpSeen() {
        defaults.hasSeenSearchHelp = true
        shouldShowSearchHelp = false
#if DEBUG
        forceShowSearchHelp = false
#endif
    }

    func resetSearchHelp() {
        defaults.hasSeenSearchHelp = false
        shouldShowSearchHelp = true
#if DEBUG
        forceShowSearchHelp = true
#endif
    }

    private func updateSearchHelpVisibilityAfterOnboarding() {
#if DEBUG
        if forceShowSearchHelp {
            shouldShowSearchHelp = true
            return
        }
#endif
        if !defaults.hasSeenSearchHelp {
            shouldShowSearchHelp = true
        }
    }
}


