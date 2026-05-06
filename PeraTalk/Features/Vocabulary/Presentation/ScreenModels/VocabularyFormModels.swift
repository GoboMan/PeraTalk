import Foundation

struct UsageFormData: Identifiable {
    let id = UUID()
    var kind: VocabularyKind
    var ipa: String = ""
    var definitionAux: String = ""
    var definitionTarget: String = ""
    var examples: [ExampleFormData] = [ExampleFormData()]
}

struct ExampleFormData: Identifiable {
    let id = UUID()
    var sentence: String = ""
}
