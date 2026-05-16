import Foundation

/// ルート認証ゲートが分岐に使う表示フェーズ。
/// JWT の自前パースはせず、AuthService のミラー結果から導出する。
enum AuthGatePhase: Equatable {
    case loading
    case signedOut
    case signedIn
}
