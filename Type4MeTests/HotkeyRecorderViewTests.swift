import AppKit
import XCTest
@testable import Type4Me

final class HotkeyRecorderViewTests: XCTestCase {

    func testKeyDisplayNameIncludesFunctionModifier() {
        let modifiers = UInt64(NSEvent.ModifierFlags.function.rawValue)

        XCTAssertEqual(
            HotkeyRecorderView.keyDisplayName(keyCode: 49, modifiers: modifiers),
            "fn+Space"
        )
    }

    func testKeyDisplayNameIncludesFunctionAlongsideOtherModifiers() {
        let modifiers = UInt64((NSEvent.ModifierFlags.control.union(.function)).rawValue)

        XCTAssertEqual(
            HotkeyRecorderView.keyDisplayName(keyCode: 49, modifiers: modifiers),
            "⌃+fn+Space"
        )
    }
}
