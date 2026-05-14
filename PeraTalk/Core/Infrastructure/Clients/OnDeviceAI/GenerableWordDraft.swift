import Foundation
import FoundationModels

@Generable(description: "English vocabulary word analysis")
struct GenerableWordDraft {
    @Guide(description: "Usages by part of speech", .maximumCount(4))
    var usages: [GenerableUsage]

    @Guide(description: "Tag names for categorization", .maximumCount(3))
    var suggestedTags: [String]
}
