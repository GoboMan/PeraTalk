import Foundation
import SwiftData

/// 会話セッションおよび発話の SwiftData アクセス。
@MainActor
struct SwiftDataSessionRepository: SessionRepository {
    let context: ModelContext

    func fetchAll() async throws -> [CachedSession] {
        try context.fetch(FetchDescriptor<CachedSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
    }

    func fetchByDate(_ date: Date) async throws -> [CachedSession] {
        try context.fetch(FetchDescriptor<CachedSession>())
    }

    func fetchById(remoteId: UUID) async throws -> CachedSession? {
        var d = FetchDescriptor<CachedSession>(predicate: #Predicate { $0.remoteId == remoteId })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func save(_ session: CachedSession) async throws {
        if session.modelContext == nil {
            context.insert(session)
        }
        try context.save()
    }

    func appendUtterance(to session: CachedSession, role: String, text: String, occurredAt: Date) async throws {
        let indices = session.utterances.map(\.sequenceIndex)
        let next = (indices.max() ?? -1) + 1
        let utt = CachedUtterance(role: role, text: text, occurredAt: occurredAt, sequenceIndex: next)
        utt.session = session
        context.insert(utt)
        try context.save()
    }

    func markDeleted(_ session: CachedSession) async throws {
        session.tombstone = true
        try context.save()
    }
}
