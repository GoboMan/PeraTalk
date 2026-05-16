import Foundation

protocol TTSClient {
    /// 初回発話前のモデル読み込みなどを先に済ませる（失敗しても呼び元は継続してよい）。
    func warmUp() async throws

    func speak(
        text: String,
        locale: String,
        gender: String?
    ) async

    /// ストリーミング応答の断片をキューへ積む（バージインはスコープ外・ターン間の連続再生用）。
    func enqueueFragment(_ text: String, locale: String, gender: String?) async

    /// バッファに残った短い尾部を再生キューへ送る。
    func flushPendingSpeech(locale: String, gender: String?) async

    /// キューを捨て、現在の発話を止める（キャンセル／新ターン開始時）。
    func cancelQueuedSpeech()

    func stop()

    var isSpeaking: Bool { get }
}
