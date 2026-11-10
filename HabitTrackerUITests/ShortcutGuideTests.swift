import XCTest

final class ShortcutGuideTests: XCTestCase {
    @MainActor func testRepeatableGuideExplainsOneOccurrenceWithoutLogging() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-test-store"]
        app.launch()
        app.buttons["Add activity"].tap()
        app.textFields["Activity name"].tap()
        app.textFields["Activity name"].typeText("Walk")
        app.buttons["Save activity"].tap()
        let open = app.buttons["Open Walk"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        for _ in 0..<2 {
            app.buttons["Home Screen shortcut"].tap()
            XCTAssertTrue(app.staticTexts["Set up a shortcut for Walk"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "One tap records one occurrence")).firstMatch.exists)
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.staticTexts["0 of 1 completions"].exists)
    }
}
