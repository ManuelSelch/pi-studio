import XCTest

#if os(iOS)
/// Slice 3 on iPhone: open sessions are switched through the overview sheet, with no tab strip.
final class PhoneSessionOverviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testOverviewSwitchesSessionsDiscardsDraftAndClosesTheLastView() {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.overview.shouldNotRenderATabStrip()

        // Two sessions: a saved conversation and a session in another project.
        app.projects.openSavedQuickChat()
        app.chat.enterDraft("Draft for the saved one")
        app.projects.back()
        app.projects.openRunningSession()
        app.session.statusShouldBe("Generating…")

        app.overview.open()
        app.overview.shouldShow("Saved quick chat")
        app.overview.shouldShow("Pocket navigation")
        app.overview.rowsShouldBeFullHeight("Saved quick chat")
        app.overview.statusShouldSay("Pocket navigation", "Running")

        // Drafts are composer-local and switching sessions discards them.
        app.overview.select("Saved quick chat")
        app.chat.draftShouldBe("")

        // Leaving the conversation for the projects keeps both sessions open.
        app.overview.open()
        app.overview.returnToProjects()
        app.projects.shouldBeBrowsing()
        app.overview.open()
        app.overview.shouldShow("Saved quick chat")
        app.overview.dismiss()

        // Closing one view keeps the other; closing the last leaves a deliberate empty overview.
        app.overview.open()
        app.overview.closeRow("Pocket navigation")
        app.overview.shouldNotShow("Pocket navigation")
        app.overview.shouldShow("Saved quick chat")
        app.overview.closeRow("Saved quick chat")
        app.overview.shouldBeEmpty()
        app.overview.startNewSession()
        app.chat.draftShouldBe("")

        app.overview.open()
        app.overview.shouldShow("New chat")
        app.overview.dismiss()
        app.projects.recordAppearance("iPhone sessions overview")
    }
}
#endif
