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
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["1 of 1 completions"].waitForExistence(timeout: 10))
        app.buttons["Open Read"].tap()
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
