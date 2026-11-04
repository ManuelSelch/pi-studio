import Testing
@testable import PiUI

/// In-process screen scenarios. The real shell is rendered with ViewInspector and driven through
/// `WorkspaceScreenDriver`, so each scenario reads as a user journey and reports coverage.
@MainActor
@Suite(.serialized)
struct WorkspaceScreenTests {
    @Test func aFailedConnectionRecoversWhenTheUserRetriesFromHome() async throws {
        try await WorkspaceScreenDriver.run(failingFirstConnection: true) { screen in
            try await screen.launch()
            screen.homeShouldShowConnectionError()

            try await screen.retryFromHome()
            screen.homeShouldShowGreeting()
        }
    }

    @Test func theQuickSwitcherFiltersAndOpensTheChosenSession() async throws {
        try await WorkspaceScreenDriver.run { screen in
            try await screen.launch()

            try screen.quickSwitcher.type("@Fix")
            try screen.quickSwitcher.selectScope(.sessions)
            try await screen.quickSwitcher.choose("Fix the layout")

            try await screen.selectedSessionShouldBe("Fix the layout")
        }
    }
}
