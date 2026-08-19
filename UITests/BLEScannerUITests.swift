// A UI test that drives the real app and asserts it read the served device.
//
// The app process is the one BleTether injects into. The test injects it through the
// app's launchEnvironment, using the dylib and fixture paths CI passes in. Those come
// in with a TEST_RUNNER_ prefix, which is how xcodebuild forwards environment to a UI
// test runner (the prefix may or may not be stripped, so read both). Then it waits for
// the status label to report the battery value the fixture recorded.
import XCTest

final class BLEScannerUITests: XCTestCase {

    private func env(_ name: String) -> String? {
        let e = ProcessInfo.processInfo.environment
        return [e[name], e["TEST_RUNNER_" + name]].compactMap { $0 }
            .first { !$0.isEmpty }
    }

    func testReadsBatteryFromServedDevice() {
        let app = XCUIApplication()
        if let dylib = env("BLETETHER_DYLIB") {
            app.launchEnvironment["DYLD_INSERT_LIBRARIES"] = dylib
        }
        if let fixture = env("BLETETHER_FIXTURE_PATH") {
            app.launchEnvironment["BLETETHER_FIXTURE"] = fixture
        }
        app.launch()

        // The status label walks Scanning… → Connecting… → Discovering… → Battery: N%.
        let battery = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Battery: 100'")).firstMatch
        let ok = battery.waitForExistence(timeout: 30)
        if !ok {
            let labels = app.staticTexts.allElementsBoundByIndex.map { $0.label }
            NSLog("BLETETHER_UITEST on-screen labels: %@", labels.description)
        }
        XCTAssertTrue(
            ok, "expected the app to read Battery: 100% from the served device")
    }
}
