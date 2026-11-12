import XCTest

final class AccessibilityFlowTests: XCTestCase {
    @MainActor func testPrimaryControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-test-store", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Add activity"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .textClipped, .dynamicType])
        app.buttons["Add activity"].tap()
        app.textFields["Activity name"].tap()
        app.textFields["Activity name"].typeText("Read")
        app.buttons["Save activity"].tap()
        XCTAssertTrue(app.buttons["Log Read"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open Read"].exists)
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .textClipped, .dynamicType])
        app.buttons["Open Read"].tap()
        XCTAssertTrue(app.buttons["Log one completion"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .textClipped, .dynamicType])
    }
}
