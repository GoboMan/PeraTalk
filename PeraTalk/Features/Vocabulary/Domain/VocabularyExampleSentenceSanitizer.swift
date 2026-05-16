import Foundation

/// オンデバイスモデル出力に混じる記号だけを除去（表示用）。
enum VocabularyExampleSentenceSanitizer {
    /// `"**word**"` のような Markdown 見出し強調だけを除去（本文は変更しない）。
    static func strippingMarkdownBoldStars(_ sentence: String) -> String {
        sentence
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
