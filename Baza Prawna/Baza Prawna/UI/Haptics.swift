import UIKit

enum Haptics {
    private static let enabledKey = "hapticsEnabled"

    static var isEnabled: Bool {
        // Default ON unless user explicitly disabled.
        guard UserDefaults.standard.object(forKey: enabledKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selectionChanged() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

