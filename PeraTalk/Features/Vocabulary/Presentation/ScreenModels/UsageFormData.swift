import Foundation

struct UsageFormData: Identifiable {
    let id = UUID()
    var kind: VocabularyKind
    var ipa: String = ""
    var definitionAux: String = ""
    var definitionTarget: String = ""
    /// 空なら親 `headword` とみなして保存／例文 AI に渡す。
    var studyHeadword: String = ""
    var examples: [ExampleFormData] = [ExampleFormData()]
}
