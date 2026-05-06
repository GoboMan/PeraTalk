import SwiftUI

struct LogSessionScreen: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("SCR-LOG-SESSION")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("セッション詳細画面")
                .font(.title)

            VStack(alignment: .leading, spacing: 12) {
                Text("・発話の並び（読み取り専用）")
                Text("・総括フィードバック表示")
                Text("  - 文法の強み / 弱み")
                Text("  - 語彙力の強み / 弱み")
                Text("・ボキャブラリ候補（再生成可）")
                Text("・単語帳への再ジャンプ（任意）")
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
