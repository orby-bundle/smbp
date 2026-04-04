//
//  SettingsCommonUITests.swift
//  Baza PrawnaUITests
//
//  Common test helpers and utilities for Settings UI tests
//

import XCTest

/// Common test helpers and utilities for Settings UI tests
class SettingsCommonUITests: SearchCommonUITests {
    
    // MARK: - Navigation Helpers
    
    /// Navigate to Settings tab
    func navigateToSettings() {
        navigateToTab("Ustawienia")
        sleep(1) // Wait for tab to load
    }
    
    /// Verify we're on the Settings view
    func verifySettingsView() -> Bool {
        let navBar = app.navigationBars["Ustawienia"]
        return navBar.waitForExistence(timeout: 0.5)
    }
    
    // MARK: - Section Verification Helpers
    
    /// Verify account section exists
    func verifyAccountSection() -> Bool {
        let accountHeader = app.staticTexts["Konto"]
        return accountHeader.waitForExistence(timeout: 0.5)
    }
    
    /// Verify subscription section exists
    func verifySubscriptionSection() -> Bool {
        let subscriptionHeader = app.staticTexts["Subskrypcja"]
        return subscriptionHeader.waitForExistence(timeout: 0.5)
    }
    
    /// Verify legal section exists
    func verifyLegalSection() -> Bool {
        let legalHeader = app.staticTexts["Dodatkowe informacje"]
        return legalHeader.waitForExistence(timeout: 0.5)
    }
    
    // MARK: - Account Section Helpers
    
    /// Verify unauthenticated state in account section
    func verifyUnauthenticatedState() -> Bool {
        let notLoggedInText = app.staticTexts["Nie zalogowany"]
        return notLoggedInText.waitForExistence(timeout: 0.5)
    }
    
    /// Find Sign in with Apple button
    func findSignInWithAppleButton() -> XCUIElement? {
        // Sign in with Apple button is typically a button with specific identifier
        let signInButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'SignInWithApple' OR label CONTAINS 'Zaloguj'")).firstMatch
        if signInButton.waitForExistence(timeout: 0.5) {
            return signInButton
        }
        return nil
    }
    
    // MARK: - Subscription Section Helpers
    
    /// Verify non-premium state
    func verifyNonPremiumState() -> Bool {
        let noSubscriptionText = app.staticTexts["Brak subskrypcji"]
        return noSubscriptionText.waitForExistence(timeout: 0.5)
    }
    
    /// Verify premium state
    func verifyPremiumState() -> Bool {
        let premiumText = app.staticTexts["Premium"]
        return premiumText.waitForExistence(timeout: 0.5)
    }
    
    /// Find "Rozpocznij Premium" button
    func findStartPremiumButton() -> XCUIElement? {
        let button = app.buttons["Rozpocznij Premium"]
        if button.waitForExistence(timeout: 0.5) {
            return button
        }
        return nil
    }
    
    /// Find "Przywróć zakupy" button
    func findRestorePurchasesButton() -> XCUIElement? {
        let button = app.buttons["Przywróć zakupy"]
        if button.waitForExistence(timeout: 0.5) {
            return button
        }
        return nil
    }
    
    // MARK: - Legal Section Helpers
    
    /// Find "Opis funkcjonalności aplikacji" button
    func findAppDescriptionButton() -> XCUIElement? {
        let button = app.buttons["Opis funkcjonalności aplikacji"]
        if button.waitForExistence(timeout: 0.5) {
            return button
        }
        return nil
    }
    
    /// Find "Polityka prywatności" button
    func findPrivacyPolicyButton() -> XCUIElement? {
        let button = app.buttons["Polityka prywatności"]
        if button.waitForExistence(timeout: 0.5) {
            return button
        }
        return nil
    }
    
    /// Find "Napisz do nas" button
    func findContactUsButton() -> XCUIElement? {
        let button = app.buttons["Napisz do nas"]
        if button.waitForExistence(timeout: 0.5) {
            return button
        }
        return nil
    }
    
    /// Find "Pokaż przewodnik" button
    func findShowGuideButton() -> XCUIElement? {
        let button = app.buttons["Pokaż przewodnik"]
        if button.waitForExistence(timeout: 0.5) {
            return button
        }
        return nil
    }
    
    // MARK: - Account Sheet Helpers
    
    /// Open account sheet by tapping account card (if authenticated)
    func openAccountSheet() -> Bool {
        // Account card is typically tappable when authenticated
        // Look for the account section and tap it
        let accountSection = app.staticTexts["Konto"]
        if accountSection.waitForExistence(timeout: 0.5) {
            // Try to find a tappable element in the account section
            // The account card might be a button or have a chevron
            let chevron = app.images.matching(NSPredicate(format: "identifier CONTAINS 'chevron.right'")).firstMatch
            if chevron.waitForExistence(timeout: 0.5) {
                chevron.tap()
                sleep(1)
                return verifyAccountSheet()
            }
        }
        return false
    }
    
    /// Verify account sheet is displayed
    func verifyAccountSheet() -> Bool {
        let sheetTitle = app.navigationBars["Konto"]
        return sheetTitle.waitForExistence(timeout: 0.5)
    }
    
    /// Dismiss account sheet
    func dismissAccountSheet() {
        let closeButton = app.buttons["Zamknij"]
        if closeButton.waitForExistence(timeout: 0.5) {
            closeButton.tap()
            sleep(1)
        } else {
            // Try swiping down to dismiss
            app.swipeDown()
            sleep(1)
        }
    }
    
    // MARK: - Layout Helpers
    
    /// Check if device is iPad (regular width)
    func isIPad() -> Bool {
        // Check for grid layout elements (iPad uses Grid)
        // This is a simple heuristic
        return app.scrollViews.firstMatch.exists && app.otherElements.count > 10
    }
    
    /// Check if device is iPhone (compact width)
    func isIPhone() -> Bool {
        // Check for list layout (iPhone uses VStack)
        return app.tables.firstMatch.exists || app.scrollViews.firstMatch.exists
    }
    
    // MARK: - Alert Helpers
    
    /// Verify logout confirmation alert appears
    func verifyLogoutAlert() -> Bool {
        let alert = app.alerts["UWAGA!"]
        if alert.waitForExistence(timeout: 0.5) {
            return true
        }
        return false
    }
    
    /// Cancel logout alert
    func cancelLogout() {
        let cancelButton = app.alerts.buttons["Anuluj"]
        if cancelButton.waitForExistence(timeout: 0.5) {
            cancelButton.tap()
            sleep(1)
        }
    }
    
    /// Verify delete account confirmation alert appears
    func verifyDeleteAccountAlert() -> Bool {
        let alert = app.alerts["Czy na pewno chcesz usunąć konto?"]
        if alert.waitForExistence(timeout: 0.5) {
            return true
        }
        return false
    }
    
    /// Cancel delete account alert
    func cancelDeleteAccount() {
        let cancelButton = app.alerts.buttons["Anuluj"]
        if cancelButton.waitForExistence(timeout: 0.5) {
            cancelButton.tap()
            sleep(1)
        }
    }
    
    // MARK: - Static Text Helpers
    
    /// Find static text by label
    override func findStaticText(_ label: String) -> XCUIElement {
        return app.staticTexts[label]
    }
}

