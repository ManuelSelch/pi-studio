import XCTest

@MainActor
final class WorkspaceHomeUITests: XCTestCase {
    func testLaunchConnectsAndShowsHomeWithoutOpeningASession() {
        let app = PiUIDriver.launch(for: self, automaticallyConnect: true)

        app.projects.shouldShowHome()
    }

    func testFailedLaunchConnectionStaysOnHomeAndCanBeRetried() {
        let app = PiUIDriver.launch(for: self, automaticallyConnect: true, failFirstConnection: true)

        app.projects.shouldShowHome()
        app.projects.shouldShowHomeConnectionError()
        app.projects.retryHomeConnection()
    }
}
