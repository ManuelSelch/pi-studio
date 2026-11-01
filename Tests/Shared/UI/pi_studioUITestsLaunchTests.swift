//
//  pi_studioUITestsLaunchTests.swift
//  pi-studioUITests
//
//  Created by Manuel Selch on 20.10.26.
//

import XCTest

final class pi_studioUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        #if os(macOS)
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launch()
        #if os(macOS)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "Expected workspace window")
        XCTAssertTrue(app.buttons["settingsButton"].firstMatch.waitForExistence(timeout: 5), "Expected workspace controls")
        #endif

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
