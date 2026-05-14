import Foundation
import FoundationModels

@Generable(description: "A usage for one part of speech")
struct GenerableUsage {
    @Guide(description: "One of: noun, verb, adjective, adverb, preposition, conjunction, pronoun, interjection, phrasal_verb, idiom")
    var kind: String

    @Guide(description: "Short English definition, plain text only, no special characters")
    var definitionTarget: String

    @Guide(description: "Short native language definition, plain text only")
    var definitionAux: String

    @Guide(description: "Example sentences", .count(2))
    var examples: [GenerableExample]
}
