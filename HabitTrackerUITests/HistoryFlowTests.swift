import XCTest

final class HistoryFlowTests: XCTestCase {
    @MainActor func testCreateLogRestartAndDelete() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-test-store"]
        app.launch()
        app.buttons["Add activity"].tap()
        app.textFields["Activity name"].tap()
        app.textFields["Activity name"].typeText("Read")
        app.buttons["Save activity"].tap()
        let log = app.buttons["Log Read"]
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        log.tap()
        XCTAssertTrue(app.staticTexts["1 of 1 completions"].waitForExistence(timeout: 5))
        app.buttons["Open Read"].tap()
        app.buttons["Reminders"].tap()
        let reminders = app.switches["Reminders"]
        XCTAssertEqual(reminders.value as? String, "0")
        reminders.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(reminders.value as? String, "1")
        app.buttons["Save reminder settings"].tap()
        XCTAssertTrue(app.buttons["Progress reports"].waitForExistence(timeout: 5))
        app.buttons["Progress reports"].tap()
        XCTAssertTrue(app.staticTexts["Calendar"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Edit recorded history"].tap()
        app.cells.firstMatch.tap()
        let timeToggle = app.switches["Include actual time"]
        XCTAssertEqual(timeToggle.value as? String, "1")
        // The SwiftUI accessibility frame covers the row, but its switch is at the trailing edge.
        timeToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(timeToggle.value as? String, "0")
        app.buttons["Save entry"].tap()
        XCTAssertTrue(app.staticTexts["Date only"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["1 of 1 completions"].waitForExistence(timeout: 10))
        app.buttons["Open Read"].tap()
        app.buttons["Reminders"].tap()
        XCTAssertEqual(app.switches["Reminders"].value as? String, "1")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Edit recorded history"].tap()
        XCTAssertTrue(app.staticTexts["Date only"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Delete activity"].tap()
        XCTAssertTrue(app.alerts["Delete Read?"].exists)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Read"].exists)
        app.buttons["Delete activity"].tap()
        app.alerts.buttons["Delete activity and history"].tap()
        XCTAssertTrue(app.buttons["Add activity"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Log Read"].exists)
    }
}
