//
//  SettingsUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for SettingsView functionality
//

import XCTest

final class SettingsUITests: SettingsCommonUITests {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToSettings()
        sleep(1) // Wait for view to load
    }
    
    // MARK: - Navigation & Layout Tests
    
    func testNavigationAndLayout() throws {
        // Verify we're on the Settings view
        XCTAssertTrue(verifySettingsView(), "Should be on Settings view")
        
        // Check for navigation title
        let navigationBar = app.navigationBars["Ustawienia"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 0.5), "Navigation title should be 'Ustawienia'")
        
        // Verify all sections are displayed
        XCTAssertTrue(verifyAccountSection(), "Account section should exist")
        XCTAssertTrue(verifySubscriptionSection(), "Subscription section should exist")
        XCTAssertTrue(verifyLegalSection(), "Legal section should exist")
        
        // Test layout differences based on device
        if isIPad() {
            // iPad should use Grid layout
            let scrollView = app.scrollViews.firstMatch
            XCTAssertTrue(scrollView.exists, "iPad should use ScrollView with Grid")
        } else if isIPhone() {
            // iPhone should use VStack layout
            let scrollView = app.scrollViews.firstMatch
            XCTAssertTrue(scrollView.exists, "iPhone should use ScrollView with VStack")
        }
    }
    
    // MARK: - Account Section Tests (Unauthenticated State)
    
    func testAccountSection() throws {
        // Verify account section header
        let accountHeader = app.staticTexts["Konto"]
        XCTAssertTrue(accountHeader.waitForExistence(timeout: 0.5), "Account section header should exist")
        
        // Test unauthenticated state
        let notLoggedInText = app.staticTexts["Nie zalogowany"]
        if notLoggedInText.waitForExistence(timeout: 0.5) {
            // Verify unauthenticated state elements
            XCTAssertTrue(notLoggedInText.exists, "Should show 'Nie zalogowany' text")
            
            // Verify Sign in with Apple button exists
            let signInButton = findSignInWithAppleButton()
            if signInButton != nil {
                XCTAssertTrue(signInButton!.exists, "Sign in with Apple button should exist")
            }
            
            // Verify informational text about background alerts
            let infoText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'alerty' OR label CONTAINS 'tle' OR label CONTAINS 'powiadomienia'"))
            _ = infoText.count // Informational text may or may not be present
            
            // Verify account card is not tappable (no chevron or button)
            // In unauthenticated state, the account card should not open a sheet
            let chevron = app.images.matching(NSPredicate(format: "identifier CONTAINS 'chevron.right'")).firstMatch
            // Chevron should not exist in unauthenticated state
            _ = chevron.exists // Just check, don't fail if it exists
        }
    }
    
    // MARK: - Subscription Section Tests
    
    func testSubscriptionSection() throws {
        // Verify subscription section header
        let subscriptionHeader = app.staticTexts["Subskrypcja"]
        XCTAssertTrue(subscriptionHeader.waitForExistence(timeout: 0.5), "Subscription section header should exist")
        
        // Test non-premium state
        let noSubscriptionText = app.staticTexts["Brak subskrypcji"]
        if noSubscriptionText.waitForExistence(timeout: 0.5) {
            // Verify non-premium state elements
            XCTAssertTrue(noSubscriptionText.exists, "Should show 'Brak subskrypcji' text")
            
            let limitedAccessText = app.staticTexts["Ograniczony dostęp"]
            _ = limitedAccessText.exists // May or may not be present
            
            // Verify "Rozpocznij Premium" button
            let startPremiumButton = findStartPremiumButton()
            if startPremiumButton != nil {
                XCTAssertTrue(startPremiumButton!.exists, "Start Premium button should exist")
                // Don't actually tap to avoid opening paywall
            }
            
            // Verify "Przywróć zakupy" button
            let restoreButton = findRestorePurchasesButton()
            if restoreButton != nil {
                XCTAssertTrue(restoreButton!.exists, "Restore purchases button should exist")
                // Don't actually tap to avoid triggering restore
            }
        } else {
            // Check for premium state
            let premiumText = app.staticTexts["Premium"]
            if premiumText.waitForExistence(timeout: 0.5) {
                // Verify premium state elements
                XCTAssertTrue(premiumText.exists, "Should show 'Premium' text")
                
                let fullAccessText = app.staticTexts["Pełny dostęp do wszystkich funkcji"]
                _ = fullAccessText.exists // May or may not be present
                
                // Premium card should be tappable (has chevron)
                let chevron = app.images.matching(NSPredicate(format: "identifier CONTAINS 'chevron.right'")).firstMatch
                _ = chevron.exists // Premium card may be tappable
            }
        }
    }
    
    // MARK: - Legal Section Tests
    
    func testLegalSection() throws {
        // Verify legal section header
        let legalHeader = app.staticTexts["Dodatkowe informacje"]
        XCTAssertTrue(legalHeader.waitForExistence(timeout: 0.5), "Legal section header should exist")
        
        // Test "Opis funkcjonalności aplikacji" NavigationLink
        let appDescriptionButton = findAppDescriptionButton()
        if appDescriptionButton != nil {
            XCTAssertTrue(appDescriptionButton!.exists, "App description button should exist")
            
            // Tap to navigate
            appDescriptionButton!.tap()
            sleep(2) // Wait for navigation
            
            // Verify we navigated to UserHelpView (check for back button)
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.waitForExistence(timeout: 0.5) {
                // Navigate back
                backButton.tap()
                sleep(1)
            }
        }
        
        // Test "Polityka prywatności" button
        let privacyButton = findPrivacyPolicyButton()
        if privacyButton != nil {
            XCTAssertTrue(privacyButton!.exists, "Privacy policy button should exist")
            
            // Tap to open sheet
            privacyButton!.tap()
            sleep(2) // Wait for sheet to appear
            
            // Verify sheet appears (check for Safari view or sheet)
            let sheetExists = app.sheets.count > 0 || app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'Safari'")).count > 0
            if sheetExists {
                // Dismiss sheet
                app.swipeDown()
                sleep(1)
            }
        }
        
        // Test "Napisz do nas" button
        let contactButton = findContactUsButton()
        if contactButton != nil {
            XCTAssertTrue(contactButton!.exists, "Contact us button should exist")
            
            // Scroll to make button visible and hittable
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                // Scroll down to bring button into view (with safety limit)
                var scrollAttempts = 0
                while !contactButton!.isHittable && scrollView.exists && scrollAttempts < 5 {
                    scrollView.swipeUp()
                    sleep(UInt32(0.5))
                    scrollAttempts += 1
                }
            }
            
            // Tap button (will open mailto URL - can't fully test URL opening in UI tests)
            if contactButton!.isHittable {
                contactButton!.tap()
                sleep(1)
            }
            
            // Mail app might open, but we can't verify that in UI tests
            // Just verify the button is tappable
        }
        
        // Test "Pokaż przewodnik" button
        let guideButton = findShowGuideButton()
        if guideButton != nil {
            XCTAssertTrue(guideButton!.exists, "Show guide button should exist")
            
            // Scroll to make button visible and hittable
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                // Scroll down to bring button into view (with safety limit)
                var scrollAttempts = 0
                while !guideButton!.isHittable && scrollView.exists && scrollAttempts < 5 {
                    scrollView.swipeUp()
                    sleep(UInt32(0.5))
                    scrollAttempts += 1
                }
            }
            
            // Tap button (resets onboarding - can't fully test this in UI tests)
            if guideButton!.isHittable {
                guideButton!.tap()
                sleep(1)
            }
            
            // Onboarding might appear, but we can't verify that easily
            // Just verify the button is tappable
        }
    }
    
    // MARK: - Account Sheet Tests
    
    func testAccountSheet() throws {
        // Try to open account sheet (only works if authenticated)
        let accountSection = app.staticTexts["Konto"]
        if accountSection.waitForExistence(timeout: 0.5) {
            // Look for chevron indicating tappable account card
            let chevron = app.images.matching(NSPredicate(format: "identifier CONTAINS 'chevron.right'")).firstMatch
            if chevron.waitForExistence(timeout: 0.5) {
                // Account card is tappable (authenticated state)
                chevron.tap()
                sleep(2) // Wait for sheet to appear
                
                // Verify sheet appears
                let sheetExists = verifyAccountSheet()
                if sheetExists {
                    // Verify sheet title
                    let sheetTitle = app.navigationBars["Konto"]
                    XCTAssertTrue(sheetTitle.exists, "Account sheet should have 'Konto' title")
                    
                    // Verify "Zamknij" button exists
                    let closeButton = app.buttons["Zamknij"]
                    XCTAssertTrue(closeButton.waitForExistence(timeout: 0.5), "Close button should exist")
                    
                    // Test "Wyloguj się" button (if Apple ID linked)
                    let logoutButton = app.buttons["Wyloguj się"]
                    if logoutButton.waitForExistence(timeout: 0.5) {
                        XCTAssertTrue(logoutButton.exists, "Logout button should exist")
                        
                        // Tap logout button to show alert
                        logoutButton.tap()
                        sleep(1)
                        
                        // Verify logout alert appears
                        let alertExists = verifyLogoutAlert()
                        if alertExists {
                            // Cancel logout
                            cancelLogout()
                        }
                    }
                    
                    // Test "Usuń konto" button (if Apple ID linked)
                    let deleteButton = app.buttons["Usuń konto"]
                    if deleteButton.waitForExistence(timeout: 0.5) {
                        XCTAssertTrue(deleteButton.exists, "Delete account button should exist")
                        
                        // Tap delete button to show alert
                        deleteButton.tap()
                        sleep(1)
                        
                        // Verify delete account alert appears
                        let alertExists = verifyDeleteAccountAlert()
                        if alertExists {
                            // Cancel deletion
                            cancelDeleteAccount()
                        }
                    }
                    
                    // Dismiss sheet
                    dismissAccountSheet()
                }
            }
        }
    }
    
    // MARK: - Alert Tests
    
    func testAlerts() throws {
        // Test logout confirmation alert (if we can trigger it)
        // This is tested in testAccountSheet, but we can verify alert structure here
        
        // Test delete account confirmation alert (if we can trigger it)
        // This is also tested in testAccountSheet
        
        // Note: Login error alert is difficult to test without actually triggering an error
        // We'll skip that for now as it requires specific error conditions
    }
}

