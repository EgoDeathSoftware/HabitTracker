import XCTest

final class ExportFlowTests: XCTestCase {
    @MainActor func testExportAndCancelSharing() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-test-store"]
        app.launch()
        app.buttons["Add activity"].tap()
        app.textFields["Activity name"].tap()
        app.textFields["Activity name"].typeText("Read")
        app.buttons["Save activity"].tap()
        XCTAssertTrue(app.buttons["Log Read"].waitForExistence(timeout: 10))
        app.buttons["Log Read"].tap()
        app.buttons["Settings"].tap()
        app.buttons["Export history"].tap()
        app.buttons["Export CSV"].tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(app.navigationBars["Export history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Export CSV"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1 of 1 completions"].waitForExistence(timeout: 5))
    }
}
