import XCTest

final class LaunchTests: XCTestCase {
    @MainActor func testLaunchesHost() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Habit Tracker"].exists)
    }
}
