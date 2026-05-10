import Foundation

/// オンデバイスで例文だけ生成するときに、モデルへ渡す用法ごとの文脈。
/// 定義（英語／学習者言語）があると同綴異義などのセンス指定に使える。
struct VocabularyExampleDraftUsageSlot: Sendable {
    var kind: VocabularyKind
    var definitionAux: String
    var definitionTarget: String
    /// 例文中に載せる英語綴り（明示）。空ならレマまたは親見出しで補う。
    var studyHeadword: String

    init(kind: VocabularyKind, definitionAux: String = "", definitionTarget: String = "", studyHeadword: String = "") {
        self.kind = kind
        self.definitionAux = definitionAux.trimmingCharacters(in: .whitespacesAndNewlines)
        self.definitionTarget = definitionTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        self.studyHeadword = studyHeadword.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
