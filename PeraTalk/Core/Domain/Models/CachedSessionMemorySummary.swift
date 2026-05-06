import Foundation
import SwiftData

@Model
final class CachedSessionMemorySummary {
    @Attribute(.unique) var remoteId: UUID
    var sessionRemoteId: UUID
    var personaId: UUID
    var themeId: UUID?
    var mode: String
    var occurredAt: Date
    var endedAt: Date?
    var topicsJSON: String?
    var factsJSON: String?
    var phrasesJSON: String?
    var openThreadsJSON: String?
    var remoteCreatedAt: Date
    var cachedAt: Date

    init(
        remoteId: UUID = UUID(),
        sessionRemoteId: UUID,
        personaId: UUID,
        mode: String,
        occurredAt: Date
    ) {
        self.remoteId = remoteId
        self.sessionRemoteId = sessionRemoteId
        self.personaId = personaId
        self.themeId = nil
        self.mode = mode
        self.occurredAt = occurredAt
        self.endedAt = nil
        self.topicsJSON = nil
        self.factsJSON = nil
        self.phrasesJSON = nil
        self.openThreadsJSON = nil
        self.remoteCreatedAt = Date()
        self.cachedAt = Date()
    }
}
