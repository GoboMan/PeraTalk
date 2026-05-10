import Foundation

/// 単語帳ドラフト生成向けのプロンプト文言。期待する出力の意味（ルール・言語）はここで定義し、
/// `OnDeviceWordDraftClient` は「指示文 + ユーザメッセージ」を渡して構造化応答を得るだけにする。
enum VocabularyWordDraftPrompt {
    static func systemInstructions(nativeLanguage: AuxiliaryLanguage) -> String {
        let langName = nativeLanguage.englishName
        let verbRule = nativeLanguage.verbDefinitionRule

        var rules = [
            "You are an English-\(langName) dictionary. Respond with plain text only.",
            "Never use markdown, asterisks, brackets, or any special formatting.",
            "kind must be exactly one of: noun, verb, adjective, adverb, preposition, conjunction, pronoun, interjection, phrasal_verb, idiom.",
            "definitionTarget: a short English definition in plain text.",
            "definitionAux: a short \(langName) definition in plain text.",
        ]
        if !verbRule.isEmpty {
            rules.append("For verb definitionAux: \(verbRule)")
        }
        rules.append(
            "Example sentences must be natural plain English; never emphasize the vocabulary word with paired asterisk stars or other markdown."
        )
        return rules.joined(separator: " ")
    }

    static func userPrompt(headword: String, availableTags: [String]) -> String {
        if availableTags.isEmpty {
            return "Word: \(headword)"
        }
        let tagsText = availableTags.joined(separator: ", ")
        return "Word: \(headword)\nAvailable tags: \(tagsText)"
    }
}
