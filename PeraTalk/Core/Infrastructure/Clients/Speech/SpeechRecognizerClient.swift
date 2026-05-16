import Foundation

/// 録音済みオーディオファイルを英語テキストに転写する Port。
/// 実装は WhisperKit を使うオンデバイス版が前提。
protocol SpeechRecognizerClient: Sendable {
    /// 内部の音声認識モデルを事前ロードする。未呼でも transcribe で必要に応じてロードされるが、
    /// UI 起動時にウォームアップしておくと初回のレイテンシを隠せる。
    func warmUp() async throws

    /// `audioFileURL` に書かれた音声を転写してテキストを返す。空文字を返してもよい。
    func transcribe(audioFileURL: URL) async throws -> String
}
