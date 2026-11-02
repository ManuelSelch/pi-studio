import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSavedEndpointPersistsAfterRelaunch() {
        let app = PiUIDriver.launch(for: self)
        app.settings.open()
        app.settings.enterEndpoint("wss://example.com:9443/custom")
        app.settings.save()
        app.settings.shouldBeClosed()
        app.relaunch()
        app.settings.open()
        app.settings.endpointShouldBe("wss://example.com:9443/custom")
        app.settings.cancel()
    }
}
