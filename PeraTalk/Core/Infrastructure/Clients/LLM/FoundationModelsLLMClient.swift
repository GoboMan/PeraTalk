import Foundation
import FoundationModels

private enum FoundationModelsGuards {
    static let maxResponseCharacters = 4_096
    static let maxBackgroundUtterances = 6
}

struct FoundationModelsLLMClient: LLMClient, Sendable {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func chat(messages: [ChatMessage], personaPrompt: String?, themeDescription: String?) async throws -> String {
        let session = LanguageModelSession(instructions: Self.buildInstructions(
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        ))
        let prompt = Self.buildPrompt(from: messages)
        let response = try await session.respond(to: prompt)
        return String(response.content.prefix(FoundationModelsGuards.maxResponseCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func generateFeedback(utterances: [ChatMessage], mode: String) async throws -> FeedbackResult {
        FeedbackResult(
            grammarStrength: nil,
            grammarWeakness: nil,
            vocabularyStrength: nil,
            vocabularyWeakness: nil,
            rawText: ""
        )
    }

    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        []
    }

    private static func buildInstructions(personaPrompt: String?, themeDescription: String?) -> String {
        var parts = [
            "You are an English conversation partner for a Japanese learner. "
                + "Respond naturally in 1-3 concise English sentences.",
            "Output ONLY your spoken reply. No role labels, no prefixes, no meta commentary. "
                + "Never echo or repeat prior dialogue. One reply only, then stop.",
            "End every reply with a question to the learner.",
        ]
        if let personaPrompt { parts.append(personaPrompt) }
        if let themeDescription { parts.append("Topic: \(themeDescription)") }
        return parts.joined(separator: "\n")
    }

    private static func buildPrompt(from messages: [ChatMessage]) -> String {
        guard let latest = messages.last else {
            return "Greet the learner with one short friendly English sentence ending with a question."
        }

        let priorSlice = messages.dropLast()
        let windowedPrior = priorSlice.suffix(FoundationModelsGuards.maxBackgroundUtterances)

        var lines: [String] = []
        if !windowedPrior.isEmpty {
            lines.append("[Prior context - do not repeat these lines:]")
            for msg in windowedPrior {
                let text = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let tag = msg.role.lowercased() == "user" ? "L" : "P"
                lines.append("\(tag): \(text)")
            }
            lines.append("")
        }

        if latest.role.lowercased() == "user" {
            lines.append("Learner: \(latest.text)")
        }
        lines.append("Reply naturally in English. End with a question.")
        return lines.joined(separator: "\n")
    }
}

