import Foundation

struct WipeLocalDataUseCase {
    func execute() async throws {
        // TODO: 全 Cached* を ModelContext から削除し、次回起動時にサーバーから再 pull
    }
}
