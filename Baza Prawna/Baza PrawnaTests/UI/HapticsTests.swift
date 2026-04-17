import XCTest
@testable import Baza_Prawna

final class HapticsTests: XCTestCase {
    private let key = "hapticsEnabled"
    private var originalObject: Any?

    override func setUp() {
        super.setUp()
        originalObject = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        if let originalObject {
            UserDefaults.standard.set(originalObject, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func testIsEnabledDefaultsToTrueWhenUnset() {
        XCTAssertNil(UserDefaults.standard.object(forKey: key))
        XCTAssertTrue(Haptics.isEnabled)
    }

    func testIsEnabledFalseWhenStoredFalse() {
        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(Haptics.isEnabled)
    }

    func testIsEnabledTrueWhenStoredTrue() {
        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(Haptics.isEnabled)
    }

    func testHapticsCallsNoopWhenDisabled() {
        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(Haptics.isEnabled)

        // Should not crash / throw.
        Haptics.impact(.light)
        Haptics.notification(.success)
        Haptics.selectionChanged()
    }
}

