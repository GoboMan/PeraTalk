import Foundation

/// ストリーミング済みデルタを話しやすい断片へまとめる。句読点＋下限文字数目安（会話ストリーム壁打ち計画のチャンキング節）。
///
/// 「適切」を優先するため、`...` と括弧未完は溜め、句読点で切る。
enum ConversationUtteranceTTSChunker: Sendable {
    struct State: Equatable {
        /// モデル側から確定済みとして受領済みテキスト（デルタの連結）。
        var finalizedText = ""
        /// `finalizedText` のうち読み終えずに残っている先頭側（次のフラッシュまで）。
        var pendingRemainderText = ""

        mutating func reset() {
            finalizedText = ""
            pendingRemainderText = ""
        }
    }

    /// モデルからの増分デルタ。句読点に達するとここでもセグメントを返しうる（forceFlush は使わない）。
    static func feed(state: inout State, delta: String) -> [String] {
        state.finalizedText += delta
        state.pendingRemainderText += delta
        return extractSpeakableSegments(state: &state, forceFlush: false)
    }

    /// ストリーム完了後に残りを吐き出す。
    static func drainTail(state: inout State) -> [String] {
        extractSpeakableSegments(state: &state, forceFlush: true)
    }

    private static let minCharsBeforeWeakBreak = 18
    private static let minCharsBeforeStrongBreak = 12
    private static let maxPendingWithoutBreak = 220

    private static func extractSpeakableSegments(state: inout State, forceFlush: Bool) -> [String] {
        var segments: [String] = []
        var work = state.pendingRemainderText

        while !work.isEmpty {
            if let (segment, rest) = trySplitSegment(from: work, forceFlush: forceFlush) {
                let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    segments.append(trimmed)
                }
                work = rest
            } else {
                break
            }
        }

        if forceFlush && !work.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(work.trimmingCharacters(in: .whitespacesAndNewlines))
            work = ""
        }

        state.pendingRemainderText = work
        return segments
    }

    private static func trySplitSegment(from pending: String, forceFlush: Bool) -> (String, String)? {
        if pending.isEmpty { return nil }

        if pending.count >= maxPendingWithoutBreak {
            let idx = pending.index(pending.startIndex, offsetBy: maxPendingWithoutBreak)
            let head = String(pending[..<idx])
            let rest = String(pending[idx...])
            return (breakAtLastWordBoundary(head), rest)
        }

        let strongSet = CharacterSet(charactersIn: ".?!。？！")
        if let bounds = punctuationSplitRange(in: pending, matching: strongSet,
                                                minLeadLength: minCharsBeforeStrongBreak) {
            let headRange = bounds.headRange
            let restStart = bounds.restStartIndex
            let head = String(pending[headRange])
            let rest = String(pending[restStart...])
            return (head.trimmingCharacters(in: .whitespacesAndNewlines),
                    rest.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let weakSet = CharacterSet(charactersIn: ",;:、")
        if let bounds = punctuationSplitRange(in: pending, matching: weakSet,
                                                minLeadLength: minCharsBeforeWeakBreak) {
            let head = String(pending[bounds.headRange])
            let rest = String(pending[bounds.restStartIndex...])
            return (head.trimmingCharacters(in: .whitespacesAndNewlines),
                    rest.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // 改行は弱い締め（短文なら許容）
        if let nl = pending.firstIndex(of: "\n"), pending[..<nl].count >= minCharsBeforeWeakBreak {
            let head = pending[..<nl]
            let after = pending[pending.index(after: nl)...]
            return (String(head).trimmingCharacters(in: .whitespaces),
                    String(after).trimmingCharacters(in: .whitespaces))
        }

        if forceFlush {
            return (pending, "")
        }

        return nil
    }

    private struct Bounds {
        var headRange: Range<String.Index>
        var restStartIndex: String.Index
    }

    private static func punctuationSplitRange(
        in pending: String,
        matching punctuation: CharacterSet,
        minLeadLength: Int
    ) -> Bounds? {
        var index = pending.startIndex
        while index < pending.endIndex {
            let ch = pending[index]
            if ch.unicodeScalars.allSatisfy({ punctuation.contains($0) }) {
                let lead = pending.distance(from: pending.startIndex, to: index)
                if lead >= minLeadLength {
                    let afterMark = pending.index(after: index)
                    let headRange = pending.startIndex..<afterMark
                    let restStart = afterMark
                    return Bounds(headRange: headRange, restStartIndex: restStart)
                }
            }
            index = pending.index(after: index)
        }
        return nil
    }

    private static func breakAtLastWordBoundary(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        guard let idx = trimmed.lastIndex(of: " ") else { return trimmed }
        let slice = trimmed[..<idx]
        guard slice.count > 24 else { return trimmed }
        return String(slice).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
