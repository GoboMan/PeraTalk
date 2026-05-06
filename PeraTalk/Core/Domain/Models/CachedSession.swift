import Foundation
import SwiftData

@Model
final class CachedSession {
    @Attribute(.unique) var remoteId: UUID
    var mode: String
    var personaId: UUID?
    var themeId: UUID?
    var startedAt: Date
    var endedAt: Date?
    var language: String
    var remoteSummaryId: UUID?
    var dirty: Bool
    var tombstone: Bool
    var remoteUpdatedAt: Date?
    var cachedAt: Date
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CachedUtterance.session)
    var utterances: [CachedUtterance]

    @Relationship(deleteRule: .cascade, inverse: \CachedSessionFeedback.session)
    var feedback: CachedSessionFeedback?

    init(
        remoteId: UUID = UUID(),
        mode: String,
        personaId: UUID? = nil,
        themeId: UUID? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        language: String = "en",
        dirty: Bool = true,
        tombstone: Bool = false
    ) {
        self.remoteId = remoteId
        self.mode = mode
        self.personaId = personaId
        self.themeId = themeId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.language = language
        self.remoteSummaryId = nil
        self.dirty = dirty
        self.tombstone = tombstone
        self.remoteUpdatedAt = nil
        self.cachedAt = Date()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.utterances = []
        self.feedback = nil
    }
}
