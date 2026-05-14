import Foundation

protocol SyncClient {
    func pushPendingChanges() async throws
    func pullAll() async throws
    func pull(category: SyncCategory) async throws
}
