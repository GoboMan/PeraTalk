import Foundation

/// 単語帳用オンデバイス構造化生成のポート。戻り値は `WordDraft` に限定する。
/// 別用途（アプリ内 Q&A など）が増えたときは **別 protocol** を定義し、実装クラスが複数プロトコルに conform する形で拡張する。
protocol OnDeviceWordDraftClient {
    var isAvailable: Bool { get }

    /// システム指示とユーザメッセージだけを渡し、オンデバイスモデルの構造化応答を `WordDraft` に機械的にマップする。
    /// プロンプトの組み立てや出力のビジネス正規化は呼び出し側（例: `VocabularyService`）の責務。
    func respond(systemInstructions: String, userPrompt: String) async throws -> WordDraft
}
