import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testValidationCancelSaveAndRelaunchPersistence() {
        let app = PiUIDriver.launch(for: self)
        app.settings.open()
        app.settings.endpointShouldBe("ws://127.0.0.1:8787/ws")
        app.settings.enterEndpoint("https://example.com")
        app.settings.save()
        app.settings.shouldShowValidationError()
        app.settings.cancel()
        app.settings.open()
        app.settings.endpointShouldBe("ws://127.0.0.1:8787/ws")
        app.settings.enterEndpoint("wss://example.com:9443/custom")
        app.settings.save()
        app.settings.shouldBeClosed()
        app.settings.sessionDetailsShouldContain("wss://example.com:9443/custom")
        app.session.shouldBeDisconnected()
        app.relaunch()
        app.settings.open()
        app.settings.endpointShouldBe("wss://example.com:9443/custom")
        app.settings.cancel()
    }

    @MainActor func testSaveLeavesConnectedSessionUntouchedUntilNextConnect() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.settings.open()
        app.settings.enterEndpoint("ws://next.example/ws")
        app.settings.save()
        app.settings.shouldBeClosed()
        app.session.statusShouldBe("Ready")
        app.settings.sessionDetailsShouldContain("ws://127.0.0.1:8787/ws")
        app.settings.sessionDetailsShouldContain("Next connection: ws://next.example/ws")
        app.session.disconnect()
        app.session.connect()
        app.settings.sessionDetailsShouldContain("ws://next.example/ws")
    }
}
