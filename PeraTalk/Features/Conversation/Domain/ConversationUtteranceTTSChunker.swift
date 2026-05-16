import Foundation

enum ConversationUtteranceTTSChunker: Sendable {
    /// 句読点で切り出すまでに必要な先頭側の最小文字数（テスト・体感の基準に合わせる）。
    private static let minimumLeadLengthBeforeBoundary = 20

    struct State: Equatable {
        var finalizedText = ""
        var pendingRemainderText = ""

        mutating func reset() {
            finalizedText = ""
            pendingRemainderText = ""
        }
    }

    static func feed(state: inout State, delta: String) -> [String] {
        guard !delta.isEmpty else { return [] }
        state.pendingRemainderText.append(contentsOf: delta)
        var emitted: [String] = []

        while !state.pendingRemainderText.isEmpty {
            let buffer = state.pendingRemainderText

            if let cut = strongPunctuationCutIndex(in: buffer) {
                let chunk = String(buffer[..<cut])
                emitted.append(chunk)
                state.finalizedText.append(chunk)
                state.pendingRemainderText = String(buffer[cut...])
                continue
            }

            if let cut = weakCommaCutIndex(in: buffer) {
                let chunk = String(buffer[..<cut])
                emitted.append(chunk)
                state.finalizedText.append(chunk)
                state.pendingRemainderText = String(buffer[cut...])
                continue
            }

            break
        }

        return emitted
    }

    static func drainTail(state: inout State) -> [String] {
        let trimmed = state.pendingRemainderText.trimmingCharacters(in: .whitespacesAndNewlines)
        state.pendingRemainderText = ""
        guard !trimmed.isEmpty else { return [] }
        state.finalizedText.append(trimmed)
        return [trimmed]
    }

    /// `.` `!` `?` の直後を切り口とする。句読点までの長さが `minimumLeadLengthBeforeBoundary` 以上のときのみ。
    private static func strongPunctuationCutIndex(in buffer: String) -> String.Index? {
        var length = 0
        for idx in buffer.indices {
            length += 1
            let ch = buffer[idx]
            guard ".!?".contains(ch), length >= minimumLeadLengthBeforeBoundary else { continue }
            return buffer.index(after: idx)
        }
        return nil
    }

    /// `,` の直後を切り口とする。コンマ手前の文字数が `minimumLeadLengthBeforeBoundary` 以上のときのみ。
    private static func weakCommaCutIndex(in buffer: String) -> String.Index? {
        for idx in buffer.indices where buffer[idx] == "," {
            let leadCount = buffer.distance(from: buffer.startIndex, to: idx)
            guard leadCount >= minimumLeadLengthBeforeBoundary else { continue }
            return buffer.index(after: idx)
        }
        return nil
    }
}
