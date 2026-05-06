import Foundation
import SwiftData

struct SwiftDataLearningLogRepository: LearningLogRepository {
    let context: ModelContext

    func fetchSessionsInMonth(_ date: Date) async throws -> [CachedSession] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let rangeStart = interval.start
        let rangeEnd = interval.end
        let predicate = #Predicate<CachedSession> { session in
            !session.tombstone && session.startedAt >= rangeStart && session.startedAt < rangeEnd
        }
        let descriptor = FetchDescriptor<CachedSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetchSessionsByDate(_ date: Date) async throws -> [CachedSession] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let predicate = #Predicate<CachedSession> { session in
            !session.tombstone && session.startedAt >= dayStart && session.startedAt < dayEnd
        }
        let descriptor = FetchDescriptor<CachedSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetchSession(remoteId: UUID) async throws -> CachedSession? {
        let id = remoteId
        let predicate = #Predicate<CachedSession> { $0.remoteId == id && !$0.tombstone }
        let descriptor = FetchDescriptor<CachedSession>(predicate: predicate)
        return try context.fetch(descriptor).first
    }
}
