import Foundation

/// 例文のみオンデバイス生成する場合のプロンプト。
enum VocabularyWordExampleDraftPrompt {
    static func systemInstructions() -> String {
        [
            "You output only example English sentences for vocabulary study.",
            "Never use markdown, asterisks, brackets, or any special formatting.",
            "Do not write definitions, IPA, or part-of-speech explanations.",
            "kind in each group must match exactly the requested part of speech label.",
            "Each example must be one natural English sentence using the headword appropriately.",
            "Respond with structured data only as instructed.",
        ].joined(separator: " ")
    }

    static func userPrompt(headword: String, usageKinds: [VocabularyKind]) -> String {
        let kinds = usageKinds.map(\.rawValue).joined(separator: ", ")
        return "Headword: \(headword)\nUsage kinds in order: \(kinds)"
    }
}
