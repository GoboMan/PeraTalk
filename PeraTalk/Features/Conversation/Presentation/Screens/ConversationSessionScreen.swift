import SwiftUI

struct ConversationSessionScreen: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("SCR-CONV-SESSION")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("会話セッション画面")
                .font(.title)

            VStack(alignment: .leading, spacing: 12) {
                Text("・LLM ↔ ユーザーの往復ループ")
                Text("・AI 発話表示 + TTS 読み上げ")
                Text("・テキスト入力（Phase A）")
                Text("・ターン制音声入力（Phase B）")
                Text("・セッション終了ボタン → 結果画面へ")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding()
    }
}
