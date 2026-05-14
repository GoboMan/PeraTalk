import Foundation

struct VocabularyAddFormUsageLine: Sendable {
    var kind: VocabularyKind
    var ipa: String
    var definitionAux: String
    var definitionTarget: String
    /// 例文に嵌める代表的英語綴り（空でも保存時／生成時は親見出しにフォールバック可）。
    var studyHeadword: String
    var examples: [VocabularyAddFormExampleLine]
}
