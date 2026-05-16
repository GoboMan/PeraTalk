import Foundation

/// マイクからの 1 ターン録音を担う Port。
/// 押下開始 → start、離した／確定 → stop で URL を返す、最小 API のみ用意する。
protocol AudioRecorderClient: Sendable {
    /// マイク権限のリクエスト・付与済み確認を行う。OS の権限ダイアログが出る場合がある。
    func requestPermission() async -> Bool

    /// 録音を開始する。既に録音中なら何もしない。
    func startRecording() async throws

    /// 録音を停止し、保存先 URL を返す。録音中でなければ throws する。
    func stopRecording() async throws -> URL

    /// 録音を中止し一時ファイルを破棄する（転写には進めない）。
    func cancelRecording() async
}
