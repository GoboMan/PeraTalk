import Foundation
import Supabase

/// Supabase Edge Function `vertex-chat` を叩く LLMClient 実装（非ストリーミング）。
/// `chat` のみ Vertex に投げ、`generateFeedback` / `generateCandidates` は当面スタブを返す。
final class VertexChatEdgeFunctionLLMClient: LLMClient {
    private let functions: FunctionsClient
    private let functionName: String

    init(functions: FunctionsClient, functionName: String = "vertex-chat") {
        self.functions = functions
        self.functionName = functionName
    }

    func chat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        let body = RequestBody(
            request_id: UUID().uuidString,
            messages: messages.map { WireMessage(role: $0.role, text: $0.text) },
            persona_prompt: personaPrompt,
            theme_description: themeDescription
        )
        let response: VertexChatResponse = try await functions.invoke(
            functionName,
            options: FunctionInvokeOptions(body: body)
        )
        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func generateFeedback(utterances: [ChatMessage], mode: String) async throws -> FeedbackResult {
        _ = utterances
        _ = mode
        return FeedbackResult(
            grammarStrength: nil,
            grammarWeakness: nil,
            vocabularyStrength: nil,
            vocabularyWeakness: nil,
            rawText: ""
        )
    }

    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        _ = utterances
        return []
    }

    private struct WireMessage: Encodable {
        let role: String
        let text: String
    }

    private struct RequestBody: Encodable {
        let request_id: String
        let messages: [WireMessage]
        let persona_prompt: String?
        let theme_description: String?
    }

    private struct VertexChatResponse: Decodable {
        let type: String?
        let request_id: String?
        let text: String
    }
}
