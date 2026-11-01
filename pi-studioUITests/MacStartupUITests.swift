import XCTest

#if os(macOS)
/// A fresh launch and settings-preserving relaunch must both expose a usable workspace.
final class MacStartupUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testLaunchAndRelaunchPresentWorkspace() {
        let app = PiUIDriver.launch(for: self)
        app.session.shouldBeDisconnected()
        app.settings.open()
        app.settings.cancel()
        app.settings.shouldBeClosed()

        app.relaunch()

        app.session.shouldBeDisconnected()
        app.settings.open()
        app.settings.cancel()
        app.settings.shouldBeClosed()
    }
}
#endif
