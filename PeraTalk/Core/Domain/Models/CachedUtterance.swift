import Foundation
import SwiftData

@Model
final class CachedUtterance {
    @Attribute(.unique) var remoteId: UUID
    var session: CachedSession?
    var role: String
    var text: String
    var occurredAt: Date
    var sequenceIndex: Int
    var inputModality: String?
    var dirty: Bool
    var remoteUpdatedAt: Date?
    var createdAt: Date

    init(
        remoteId: UUID = UUID(),
        role: String,
        text: String,
        occurredAt: Date = Date(),
        sequenceIndex: Int,
        inputModality: String? = nil,
        dirty: Bool = true
    ) {
        self.remoteId = remoteId
        self.role = role
        self.text = text
        self.occurredAt = occurredAt
        self.sequenceIndex = sequenceIndex
        self.inputModality = inputModality
        self.dirty = dirty
        self.remoteUpdatedAt = nil
        self.createdAt = Date()
    }
}
