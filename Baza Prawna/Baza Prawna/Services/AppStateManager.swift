import Foundation
import Combine

// MARK: - User Defaults Keys

enum DefaultsKeys {
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let hasSeenSearchHelp = "hasSeenSearchHelp"
    static let hasSeenMDNavigationHelp = "hasSeenMDNavigationHelp"
#if DEBUG
    static let forceShowSearchHelp = "forceShowSearchHelp"
    static let forceShowMDNavigationHelp = "forceShowMDNavigationHelp"
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

    var hasSeenMDNavigationHelp: Bool {
        get { bool(forKey: DefaultsKeys.hasSeenMDNavigationHelp) }
        set { set(newValue, forKey: DefaultsKeys.hasSeenMDNavigationHelp) }
    }

#if DEBUG
    var forceShowSearchHelp: Bool {
        get { bool(forKey: DefaultsKeys.forceShowSearchHelp) }
        set { set(newValue, forKey: DefaultsKeys.forceShowSearchHelp) }
    }

    var forceShowMDNavigationHelp: Bool {
        get { bool(forKey: DefaultsKeys.forceShowMDNavigationHelp) }
        set { set(newValue, forKey: DefaultsKeys.forceShowMDNavigationHelp) }
    }
#endif
}

final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    @Published var shouldShowOnboarding: Bool
    @Published var shouldShowSearchHelp: Bool
    @Published var shouldShowMDNavigationHelp: Bool
#if DEBUG
    @Published var forceShowSearchHelp: Bool {
        didSet {
            defaults.forceShowSearchHelp = forceShowSearchHelp
        }
    }

    @Published var forceShowMDNavigationHelp: Bool {
        didSet {
            defaults.forceShowMDNavigationHelp = forceShowMDNavigationHelp
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
        let hasSeenMDNavigationHelp = defaults.hasSeenMDNavigationHelp
#if DEBUG
        self.forceShowMDNavigationHelp = defaults.forceShowMDNavigationHelp
#endif
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
        if hasSeen && !hasSeenMDNavigationHelp {
            self.shouldShowMDNavigationHelp = true
        } else {
            self.shouldShowMDNavigationHelp = false
        }
#if DEBUG
        if forceShowSearchHelp {
            self.shouldShowSearchHelp = true
        }
        if forceShowMDNavigationHelp {
            self.shouldShowMDNavigationHelp = true
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

    func markMDNavigationHelpSeen() {
        defaults.hasSeenMDNavigationHelp = true
        shouldShowMDNavigationHelp = false
#if DEBUG
        forceShowMDNavigationHelp = false
#endif
    }

    func resetMDNavigationHelp() {
        defaults.hasSeenMDNavigationHelp = false
        shouldShowMDNavigationHelp = true
#if DEBUG
        forceShowMDNavigationHelp = true
#endif
    }

    private func updateSearchHelpVisibilityAfterOnboarding() {
#if DEBUG
        if forceShowSearchHelp {
            shouldShowSearchHelp = true
        } else if !defaults.hasSeenSearchHelp {
            shouldShowSearchHelp = true
        }
#else
        if !defaults.hasSeenSearchHelp {
            shouldShowSearchHelp = true
        }
#endif

#if DEBUG
        if forceShowMDNavigationHelp {
            shouldShowMDNavigationHelp = true
        } else if !defaults.hasSeenMDNavigationHelp {
            shouldShowMDNavigationHelp = true
        }
#else
        if !defaults.hasSeenMDNavigationHelp {
            shouldShowMDNavigationHelp = true
        }
#endif
    }
}


