import Testing
@testable import PiUI

struct TranscriptPresentationTests {
    @Test func assistantFragmentsShareOneLabelUntilTheNextUser() {
        let messages = [
            TranscriptMessage(id: "u1", role: "You", text: "First"),
            TranscriptMessage(id: "a1", role: "Assistant", text: "One"),
            TranscriptMessage(id: "a2", role: "Assistant", text: "Two"),
            TranscriptMessage(id: "u2", role: "You", text: "Next"),
            TranscriptMessage(id: "a3", role: "Assistant", text: "Three"),
        ]

        #expect(TranscriptPresentation.labels(for: messages) == ["You", "π", nil, "You", "π"])
    }

    @Test func otherMessageRolesRemainVisibleWithoutRestartingTheResponse() {
        let messages = [
            TranscriptMessage(id: "a1", role: "Assistant", text: "One"),
            TranscriptMessage(id: "x", role: "Custom", text: "Notice"),
            TranscriptMessage(id: "a2", role: "Assistant", text: "Two"),
        ]

        #expect(TranscriptPresentation.labels(for: messages) == ["π", "Custom", nil])
    }
}
