import XCTest
import SwiftUI
@testable import Baza_Prawna

final class AppAppearanceTests: XCTestCase {
    func testTitles() {
        XCTAssertEqual(AppAppearance.system.title, "System")
        XCTAssertEqual(AppAppearance.light.title, "Jasny")
        XCTAssertEqual(AppAppearance.dark.title, "Ciemny")
    }

    func testColorSchemeMapping() {
        XCTAssertNil(AppAppearance.system.colorScheme)
        XCTAssertEqual(AppAppearance.light.colorScheme, .light)
        XCTAssertEqual(AppAppearance.dark.colorScheme, .dark)
    }

    func testRawValueParsingFallsBackToSystem() {
        let raw = "not-a-real-mode"
        let appearance = AppAppearance(rawValue: raw) ?? .system
        XCTAssertEqual(appearance, .system)
    }
}

