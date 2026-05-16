import Foundation

struct WordDraftUsage {
    let kind: String
    let definitionTarget: String
    let definitionAux: String?
    let ipa: String?
    let examples: [WordDraftExample]
}
