import XCTest

final class pi_studioUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    #if os(macOS)
    @MainActor func testMacWorkspaceConversationJourney() throws {
        let app = PiUIDriver.launch(for: self, automaticallyConnect: true)
        try app.quickSwitcher.typeOnInitiallyFocusedHomeSearch("Quick Chats")
        try app.quickSwitcher.shouldBeInline()
        try app.quickSwitcher.searchShouldContain("Quick Chats")
        try app.quickSwitcher.shouldShowResult("Quick Chats", kind: "Folders")
        try app.quickSwitcher.dismiss()
        try app.quickSwitcher.openUsingShortcut("k")
        try app.quickSwitcher.searchShouldContain("Quick Chats")
        try app.quickSwitcher.shouldShowResult("Quick Chats", kind: "Folders")
        try app.quickSwitcher.dismiss()
        try app.quickSwitcher.clickHomeSearch()
        try app.quickSwitcher.homeSearchShouldBeCollapsed()
        try app.quickSwitcher.openUsingShortcut("k")
        try app.quickSwitcher.filter("All")
        try app.quickSwitcher.selectSession("Saved quick chat")
        try app.quickSwitcher.composerShouldRegainFocus()
        app.chat.typeAtCaret("Say hello")
        app.chat.pressReturn()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, "Say hello")
        app.session.waitUntilReady()
        app.chat.replyShouldBe(1, "Hello from the demo. This reply is streaming a little at a time.")
    }
    #else
    @MainActor func testPhoneWorkspaceConversationJourney() throws {
        let app = PiUIDriver.launch(for: self, automaticallyConnect: true)
        try app.quickSwitcher.clickHomeSearch()
        try app.quickSwitcher.homeSearchShouldBeCollapsed()
        try app.quickSwitcher.typeOnHomeSearch("Quick Chats")
        try app.quickSwitcher.shouldBeInline()
        try app.quickSwitcher.searchShouldContain("Quick Chats")
        try app.quickSwitcher.shouldShowResult("Quick Chats", kind: "Folders")
        try app.quickSwitcher.selectFolder("Quick Chats")
        app.session.waitUntilReady()
        app.chat.enterDraft("Hello")
        app.chat.pressSoftwareReturn()
        app.chat.enterDraft("Pi")
        app.chat.draftShouldBe("Hello\nPi")
        app.chat.submitDraft()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, "Hello\nPi")
        app.session.waitUntilReady()
        app.chat.replyShouldBe(1, "Hello from the demo. This reply is streaming a little at a time.")
    }
    #endif
}
