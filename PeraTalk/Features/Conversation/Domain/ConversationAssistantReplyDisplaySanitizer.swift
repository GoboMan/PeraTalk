import Foundation

/// 会話 UI はチャット形式のため、モデルが付けがちな「アシスタント:」等の役割ラベルを表示・永続化から取り除く。
enum ConversationAssistantReplyDisplaySanitizer {
    /// 英語ラベルは大小無視。日本語はそのまま。
    private static let exactLeadingPrefixes: [String] = [
        "アシスタント:",
        "アシスタント：",
    ]

    private static let asciiCaseInsensitivePrefixes: [String] = [
        "Assistant:",
        "assistant:",
        "ASSISTANT:",
    ]

    /// 先頭の役割ラベルを最大 `maxPasses` 回まで剥がす（二重付与対策）。
    static func stripAllLeadingRoleLabels(from text: String, maxPasses: Int = 4) -> String {
        var result = text
        for _ in 0..<maxPasses {
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let peeled = peelLongestLeadingRoleLabel(from: trimmed) else { break }
            result = peeled
        }
        return result
    }

    /// 学習者への英語の質問で終わっていないとき、短文のフォロー質問で `?` を保証する（モデルトレース用）。
    static func ensuringLearnerQuestionEnglishSuffix(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return t }
        if let last = t.last, last == "?" || last == "？" { return t }
        return "\(t) What would you like to talk about next?"
    }

    /// ストリームの先頭チャンクで「Assistant:」が分割されて届く場合に備え、バッファで判定してから表示分だけ返す。
    struct StreamingLeadingLabelStripper: Sendable {
        private enum Mode: Sendable {
            case scanning
            case passthrough
        }

        /// 「Assistant:」候補のスキャンでバッファが膨らみすぎないようにする（思考中表示の滞留防止）。
        private static let maxScanningBufferCharacters = 28

        private var mode: Mode = .scanning
        private var buffer = ""

        mutating func push(_ chunk: String) -> String {
            switch mode {
            case .passthrough:
                return chunk
            case .scanning:
                buffer += chunk
                if buffer.count > Self.maxScanningBufferCharacters {
                    mode = .passthrough
                    let out = buffer
                    buffer = ""
                    return out
                }
                if let stripped = ConversationAssistantReplyDisplaySanitizer.peelLongestLeadingRoleLabel(from: buffer) {
                    mode = .passthrough
                    buffer = ""
                    return stripped
                }
                if !Self.labelPrefixStillPossible(buffer) {
                    mode = .passthrough
                    let out = buffer
                    buffer = ""
                    return out
                }
                return ""
            }
        }

        /// ストリーム終端で `scanning` のまま残ったテキストを確定表示へ回す。
        mutating func flushRemaining() -> String {
            switch mode {
            case .passthrough:
                return ""
            case .scanning:
                let out = buffer
                buffer = ""
                mode = .passthrough
                return out
            }
        }

        private static func labelPrefixStillPossible(_ raw: String) -> Bool {
            let probe = ConversationAssistantReplyDisplaySanitizer.dropLeadingWhitespace(raw)
            // 先頭が空白だけの入力は「Assistant: の手前」の可能性がある一方、空白だけが増え続けると表示が進まず「ずっと思考中」になり得る。
            if probe.isEmpty { return raw.count < 48 }
            guard probe.count <= ConversationAssistantReplyDisplaySanitizer.maxPrefixCharacterCount else { return false }
            for p in ConversationAssistantReplyDisplaySanitizer.exactLeadingPrefixes {
                if p.hasPrefix(probe) { return true }
            }
            let lowerProbe = probe.lowercased()
            for p in ConversationAssistantReplyDisplaySanitizer.asciiCaseInsensitivePrefixes {
                if p.lowercased().hasPrefix(lowerProbe) { return true }
            }
            return false
        }
    }

    /// モデル出力の先頭に付く可能性があるラベルの最大文字数（ざっくり上限）。
    private static var maxPrefixCharacterCount: Int {
        let all = exactLeadingPrefixes + asciiCaseInsensitivePrefixes
        return all.map(\.count).max() ?? 32
    }

    private static func peelLongestLeadingRoleLabel(from text: String) -> String? {
        let headStart = dropLeadingWhitespaceIndex(text)
        guard headStart < text.endIndex else { return nil }
        let tail = text[headStart...]

        for exact in exactLeadingPrefixes.sorted(by: { $0.count > $1.count }) where tail.hasPrefix(exact) {
            return trimOneLeadingWhitespace(String(tail.dropFirst(exact.count)))
        }

        let lowerTail = tail.lowercased()
        for token in asciiCaseInsensitivePrefixes.sorted(by: { $0.count > $1.count }) {
            let lowerToken = token.lowercased()
            guard lowerTail.hasPrefix(lowerToken) else { continue }
            return trimOneLeadingWhitespace(String(tail.dropFirst(token.count)))
        }

        return nil
    }

    private static func trimOneLeadingWhitespace(_ s: String) -> String {
        if let first = s.first, first.isWhitespace { return String(s.dropFirst()) }
        return s
    }

    private static func dropLeadingWhitespace(_ s: String) -> String {
        String(s[dropLeadingWhitespaceIndex(s)...])
    }

    private static func dropLeadingWhitespaceIndex(_ s: String) -> String.Index {
        var i = s.startIndex
        while i < s.endIndex {
            let ch = s[i]
            if ch.isWhitespace || ch.isNewline {
                i = s.index(after: i)
            } else {
                break
            }
        }
        return i
    }
}
