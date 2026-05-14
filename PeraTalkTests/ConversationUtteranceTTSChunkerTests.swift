import XCTest
@testable import PeraTalk

final class ConversationUtteranceTTSChunkerTests: XCTestCase {
    func testStrongPunctuationSplitsWhenLeadLengthMet() {
        var state = ConversationUtteranceTTSChunker.State()
        let body = String(repeating: "a", count: 20) + ". More"
        let chunks = ConversationUtteranceTTSChunker.feed(state: &state, delta: body)
        XCTAssertEqual(chunks.first, String(repeating: "a", count: 20) + ".")
        let tail = ConversationUtteranceTTSChunker.drainTail(state: &state)
        XCTAssertEqual(tail.first, "More")
    }

    func testWeakCommaAfterMinimumLengthSplits() {
        var state = ConversationUtteranceTTSChunker.State()
        let lead = String(repeating: "b", count: 20)
        let out = ConversationUtteranceTTSChunker.feed(state: &state, delta: "\(lead), ")
        XCTAssertEqual(out.first?.trimmingCharacters(in: .whitespaces), "\(lead),")
        XCTAssertFalse(out.isEmpty)
    }

    func testStreamVersusChatStubParity() async throws {
        let stub = StubLLMClient()
        let messages = [ChatMessage(role: "user", text: "Hi")]

        let pooled = try await stub.chat(messages: messages, personaPrompt: nil, themeDescription: nil)
        var streamed = ""
        for try await d in stub.chatStreaming(messages: messages, personaPrompt: nil, themeDescription: nil) {
            streamed += d
        }

        XCTAssertEqual(pooled, streamed)
    }
}
