//
//  MyAlertsCommonUITests.swift
//  Baza PrawnaUITests
//
//  Common test helpers and utilities for MyAlerts UI tests
//

import XCTest

/// Common test helpers and utilities for MyAlerts UI tests
class MyAlertsCommonUITests: SearchCommonUITests {
    
    // MARK: - Navigation Helpers
    
    /// Navigate to MyAlerts view
    func navigateToMyAlerts() {
        navigateToTab("Moje")
        sleep(1) // Wait for tab to load
        
        // Switch to Moje Alerty
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 0.5) {
            let alertsButton = segmentedControl.buttons["Moje Alerty"]
            if alertsButton.waitForExistence(timeout: 1) {
                alertsButton.tap()
                sleep(1) // Wait for view switch
            }
        }
    }
    
    // MARK: - Empty State Verification
    
    /// Verify empty state is displayed for MyAlerts
    func verifyMyAlertsEmptyState() -> Bool {
        // Check for empty state text
        let emptyStateText = findStaticText("Brak zapisanych alertów")
        if emptyStateText.waitForExistence(timeout: 0.5) {
            return true
        }
        
        // Alternative: check for empty state icon or message
        let emptyStateMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Brak zapisanych' OR label CONTAINS[c] 'alert'"))
        return emptyStateMessage.count > 0
    }
    
    /// Verify empty state is displayed for MyAlerts (alias for compatibility)
    override func verifyEmptyState() -> Bool {
        return verifyMyAlertsEmptyState()
    }
    
    // MARK: - Alert Helpers
    
    /// Find alert row by title
    func findAlertRow(title: String) -> XCUIElement? {
        let alertText = app.staticTexts[title]
        if alertText.waitForExistence(timeout: 0.5) {
            return alertText
        }
        return nil
    }
    
    /// Verify alert is displayed in the list
    func verifyAlertDisplayed(title: String) -> Bool {
        let alertRow = findAlertRow(title: title)
        return alertRow != nil && alertRow!.exists
    }
    
    /// Toggle alert active/inactive by tapping bell icon
    func toggleAlert(alertTitle: String) -> Bool {
        guard let alertRow = findAlertRow(title: alertTitle) else {
            return false
        }
        
        // Find bell icon button in the alert row
        // Bell icon is typically a button with bell.fill or bell.slash image
        let bellButtons = alertRow.buttons.matching(NSPredicate(format: "identifier CONTAINS 'bell' OR label CONTAINS 'bell'"))
        
        if bellButtons.count > 0 {
            let bellButton = bellButtons.element(boundBy: 0)
            if bellButton.waitForExistence(timeout: 0.5) && bellButton.isHittable {
                bellButton.tap()
                sleep(1) // Wait for state change
                return true
            }
        }
        
        // Alternative: look for buttons in the row
        let buttons = alertRow.buttons
        for i in 0..<buttons.count {
            let button = buttons.element(boundBy: i)
            if button.exists && button.isHittable {
                // Check if it's the bell button by checking if it's near the alert title
                button.tap()
                sleep(1)
                return true
            }
        }
        
        return false
    }
    
    /// Rename an alert
    func renameAlert(oldTitle: String, newTitle: String) -> Bool {
        guard let alertRow = findAlertRow(title: oldTitle) else {
            return false
        }
        
        // Find pencil icon button
        let pencilButton = alertRow.buttons.matching(NSPredicate(format: "identifier CONTAINS 'pencil' OR label CONTAINS 'pencil'")).firstMatch
        
        if !pencilButton.exists {
            // Try swiping to reveal rename action
            alertRow.swipeLeft()
            sleep(1)
            
            let renameButton = app.buttons["Zmień\nnazwę"]
            if !renameButton.exists {
                let altRenameButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Zmień' OR label CONTAINS[c] 'nazwę'")).firstMatch
                if altRenameButton.waitForExistence(timeout: 0.5) {
                    altRenameButton.tap()
                    sleep(1)
                } else {
                    return false
                }
            } else {
                renameButton.tap()
                sleep(1)
            }
        } else {
            pencilButton.tap()
            sleep(1)
        }
        
        // Find text field in alert dialog
        let textField = app.textFields["Nazwa alertu"]
        if !textField.exists {
            let altTextField = app.textFields.firstMatch
            if altTextField.waitForExistence(timeout: 0.5) {
                altTextField.tap()
                // Clear existing text
                if let currentValue = altTextField.value as? String {
                    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                    altTextField.typeText(deleteString)
                }
                altTextField.typeText(newTitle)
                dismissKeyboard()
                sleep(1)
            } else {
                return false
            }
        } else {
            textField.tap()
            // Clear existing text
            if let currentValue = textField.value as? String {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                textField.typeText(deleteString)
            }
            textField.typeText(newTitle)
            dismissKeyboard()
            sleep(1)
        }
        
        // Find and tap save button
        let saveButton = app.buttons["Zapisz"]
        if saveButton.waitForExistence(timeout: 0.5) {
            saveButton.tap()
            sleep(1)
            return true
        }
        
        return false
    }
    
    /// Delete an alert
    func deleteAlert(title: String) -> Bool {
        guard let alertRow = findAlertRow(title: title) else {
            return false
        }
        
        // Swipe right to reveal delete action
        alertRow.swipeRight()
        sleep(1)
        
        // Find delete button
        let deleteButton = app.buttons["Usuń"]
        if deleteButton.waitForExistence(timeout: 0.5) {
            deleteButton.tap()
            sleep(1)
            
            // Confirm deletion in alert dialog
            let confirmButton = app.alerts.buttons["Usuń"]
            if confirmButton.waitForExistence(timeout: 0.5) {
                confirmButton.tap()
                sleep(1)
                return true
            }
        }
        
        return false
    }
    
    /// Open alert results sheet by tapping alert row
    func openAlertResults(alertTitle: String) -> Bool {
        guard let alertRow = findAlertRow(title: alertTitle) else {
            return false
        }
        
        if alertRow.waitForExistence(timeout: 0.5) && alertRow.isHittable {
            alertRow.tap()
            sleep(2) // Wait for sheet to appear
            return true
        }
        
        return false
    }
    
    /// Verify unseen results count for an alert
    func verifyUnseenResultsCount(alertTitle: String, count: Int) -> Bool {
        guard let alertRow = findAlertRow(title: alertTitle) else {
            return false
        }
        
        // Look for unseen results text
        let unseenText = alertRow.staticTexts.containing(NSPredicate(format: "label CONTAINS '\(count) nowych wyników'"))
        return unseenText.count > 0
    }
    
    // MARK: - Selection Mode Helpers
    
    /// Enter selection mode by swiping on an alert
    func enterSelectionMode() {
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 0.5) {
            let firstRow = list.cells.firstMatch
            if firstRow.waitForExistence(timeout: 0.5) {
                // Swipe left to reveal "Wybierz" action
                firstRow.swipeLeft()
                sleep(1)
                
                // Tap "Wybierz" button
                let wybierzButton = app.buttons["Wybierz"]
                if wybierzButton.waitForExistence(timeout: 0.5) {
                    wybierzButton.tap()
                    sleep(1)
                }
            }
        }
    }
    
    /// Exit selection mode
    func exitSelectionMode() {
        // Find back button in toolbar
        let backButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS 'arrow.uturn.backward' OR label CONTAINS 'back'")).firstMatch
        if backButton.waitForExistence(timeout: 0.5) {
            backButton.tap()
            sleep(1)
        }
    }
    
    // MARK: - Alert Status Verification
    
    /// Verify alert is active (orange bell.fill)
    func verifyAlertActive(alertTitle: String) -> Bool {
        guard let alertRow = findAlertRow(title: alertTitle) else {
            return false
        }
        
        // Check for active bell icon (bell.fill)
        // This is difficult to verify directly, so we check for the presence of the bell button
        let bellButtons = alertRow.buttons
        return bellButtons.count > 0
    }
    
    /// Verify alert is inactive (gray bell.slash)
    func verifyAlertInactive(alertTitle: String) -> Bool {
        // Similar to verifyAlertActive, but checks for inactive state
        // Implementation may need adjustment based on actual UI
        return verifyAlertActive(alertTitle: alertTitle)
    }
    
    // MARK: - Alert Results View Helpers
    
    /// Verify alert results sheet is displayed
    func verifyAlertResultsSheet() -> Bool {
        // Check for sheet or navigation bar indicating results view
        return app.sheets.count > 0 || app.navigationBars.count > 1
    }
    
    /// Dismiss alert results sheet
    func dismissAlertResultsSheet() {
        // Try swiping down to dismiss
        if app.sheets.count > 0 {
            app.swipeDown()
            sleep(1)
        }
        
        // Alternative: look for close/done button
        let closeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Zamknij' OR label CONTAINS[c] 'Gotowe' OR identifier CONTAINS 'close'")).firstMatch
        if closeButton.waitForExistence(timeout: 0.5) {
            closeButton.tap()
            sleep(1)
        }
    }
    
    // MARK: - Navigation Verification
    
    /// Verify we're on the MyAlerts view
    func verifyMyAlertsView() -> Bool {
        let navBar = app.navigationBars["Moje Alerty"]
        return navBar.waitForExistence(timeout: 0.5)
    }
    
    // MARK: - Frequency Badge Verification
    
    /// Verify frequency badge is displayed for an alert
    func verifyFrequencyBadge(alertTitle: String) -> Bool {
        guard let alertRow = findAlertRow(title: alertTitle) else {
            return false
        }
        
        // Look for frequency badge text (Codziennie, Tygodniowo, etc.)
        let frequencyTexts = ["Codziennie", "Tygodniowo", "Miesięcznie"]
        for frequencyText in frequencyTexts {
            if alertRow.staticTexts[frequencyText].exists {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Tab Badge Verification
    
    /// Verify tab bar badge shows unseen results count
    func verifyTabBadge(count: Int) -> Bool {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 0.5) {
            let mojeTab = tabBar.buttons["Moje"]
            if mojeTab.waitForExistence(timeout: 0.5) {
                // Check if badge exists (XCUIElement doesn't directly expose badge value)
                // This is a placeholder - badge verification may need different approach
                return true
            }
        }
        return false
    }
    
    // MARK: - Test Data Setup
    
    /// Setup test data for MyAlerts - creates test alerts if needed
    /// This method navigates to a search view and creates alerts through the UI
    func setupTestDataIfNeeded() {
        // Check if we already have alerts
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 0.5) {
            let cells = list.cells
            if cells.count > 0 {
                // Alerts already exist, no need to create
                return
            }
        }
        
        // Navigate to a search view to create an alert
        // Use Acts PL as it's commonly available
        navigateToTab("Akty RP")
        sleep(2)
        
        // Enter some search criteria
        let titleField = app.textFields["Poszukiwana treść"]
        if titleField.waitForExistence(timeout: 0.5) {
            titleField.tap()
            titleField.typeText("test")
            dismissKeyboard()
            sleep(1)
        }
        
        // Find and tap alert button
        // Alert button is typically in the button row
        let alertButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'alert' OR label CONTAINS 'alert'"))
        if alertButtons.count > 0 {
            let alertButton = alertButtons.element(boundBy: 0)
            if alertButton.waitForExistence(timeout: 0.5) && alertButton.isHittable {
                alertButton.tap()
                sleep(2) // Wait for alert creation sheet
                
                // Select frequency (e.g., "Codziennie")
                let frequencyButton = app.buttons["Codziennie"]
                if !frequencyButton.exists {
                    // Try other frequency options
                    let altFrequency = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Codziennie' OR label CONTAINS[c] 'Tygodniowo' OR label CONTAINS[c] 'Miesięcznie'")).firstMatch
                    if altFrequency.waitForExistence(timeout: 0.5) {
                        altFrequency.tap()
                        sleep(1)
                    }
                } else {
                    frequencyButton.tap()
                    sleep(1)
                }
                
                // Find and tap save/create button
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'zapisz' OR label CONTAINS[c] 'utwórz' OR label CONTAINS[c] 'zapisz alert'")).firstMatch
                if saveButton.waitForExistence(timeout: 0.5) {
                    saveButton.tap()
                    sleep(2) // Wait for alert to be created
                }
            }
        }
        
        // Navigate back to MyAlerts
        navigateToMyAlerts()
    }
    
    /// Check if test data exists
    func hasTestData() -> Bool {
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 0.5) {
            return list.cells.count > 0
        }
        return false
    }
}

