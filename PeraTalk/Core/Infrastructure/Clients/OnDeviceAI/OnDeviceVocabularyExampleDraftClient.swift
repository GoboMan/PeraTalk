import Foundation

/// レマ結線時など、**例文だけ**をオンデバイス生成する用途のポート（全文 `WordDraft` とは別 protocol）。
protocol OnDeviceVocabularyExampleDraftClient {
    var isAvailable: Bool { get }

    func respond(systemInstructions: String, userPrompt: String) async throws -> WordExampleDraft
}
