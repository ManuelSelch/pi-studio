import XCTest

@MainActor
final class WorkspaceHomeUITests: XCTestCase {
    func testLaunchConnectsAndShowsHomeWithoutOpeningASession() {
        let app = PiUIDriver.launch(for: self, automaticallyConnect: true)

        app.projects.shouldShowHome()
    }
}
