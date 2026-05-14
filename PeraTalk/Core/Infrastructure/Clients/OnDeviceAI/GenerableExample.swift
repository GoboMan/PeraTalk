import Foundation
import FoundationModels

@Generable(description: "Example sentence")
struct GenerableExample {
    @Guide(
        description: "Natural English sentence: plain prose only — never asterisks for bold (**), never Markdown.",
    )
    var sentenceTarget: String
}
