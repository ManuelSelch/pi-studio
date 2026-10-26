import Testing
@testable import PiUI

struct ServerEndpointTests {
    @Test(arguments: ["", "  ", "https://example.com/ws", "ws://", "/ws", "ws:///ws",
                      "ws://user:secret@example.com/ws", "wss://example.com/ws#fragment",
                      "ws://example.com/#", "ws://exa mple.com/ws", "ws://example.com:0/ws",
                      "ws://example.com:65536/ws", "ws://example.com:abc/ws"])
    func rejectsInvalidEndpoint(_ value: String) {
        #expect(ServerEndpoint.validated(value) == nil)
    }

    @Test(arguments: ["ws://127.0.0.1:8787/ws", "wss://example.com:9443/custom?token=abc",
                      "ws://[::1]:8787/ws", "wss://example.com", "WS://example.com/ws"])
    func acceptsWebSocketEndpointWithoutChangingPath(_ value: String) {
        #expect(ServerEndpoint.validated(" \n" + value + " ") == value)
    }
}
