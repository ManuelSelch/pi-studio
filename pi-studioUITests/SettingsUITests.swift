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
        app.session.shouldBeDisconnected()
        app.relaunch()
        app.settings.open()
        app.settings.endpointShouldBe("wss://example.com:9443/custom")
        app.settings.cancel()
    }

    @MainActor func testSavingWhileConnectedLeavesTheSessionUntouched() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.session.statusShouldBe("Ready")
        app.settings.open()
        app.settings.enterEndpoint("ws://next.example/ws")
        app.settings.save()
        app.settings.shouldBeClosed()
        app.session.statusShouldBe("Ready")
        app.settings.open()
        app.settings.endpointShouldBe("ws://next.example/ws")
        app.settings.cancel()
    }
}
