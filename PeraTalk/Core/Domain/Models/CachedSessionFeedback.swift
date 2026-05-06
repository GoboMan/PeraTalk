import Foundation
import SwiftData

@Model
final class CachedSessionFeedback {
    @Attribute(.unique) var remoteId: UUID
    var session: CachedSession?
    var grammarStrengthText: String?
    var grammarWeaknessText: String?
    var vocabularyStrengthText: String?
    var vocabularyWeaknessText: String?
    var rawText: String?
    var generatedAt: Date
    var dirty: Bool
    var remoteUpdatedAt: Date?
    var cachedAt: Date

    init(
        remoteId: UUID = UUID(),
        generatedAt: Date = Date(),
        dirty: Bool = true
    ) {
        self.remoteId = remoteId
        self.grammarStrengthText = nil
        self.grammarWeaknessText = nil
        self.vocabularyStrengthText = nil
        self.vocabularyWeaknessText = nil
        self.rawText = nil
        self.generatedAt = generatedAt
        self.dirty = dirty
        self.remoteUpdatedAt = nil
        self.cachedAt = Date()
    }
}
