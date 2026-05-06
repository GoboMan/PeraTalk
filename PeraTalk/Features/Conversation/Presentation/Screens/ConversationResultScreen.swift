import SwiftUI

struct ConversationResultScreen: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("SCR-CONV-RESULT")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("会話結果画面")
                .font(.title)

            VStack(alignment: .leading, spacing: 12) {
                Text("総括フィードバック:")
                Text("  ・文法の強み / 弱み")
                Text("  ・語彙力の強み / 弱み")

                Divider()

                Text("新出ボキャブラリ候補:")
                Text("  ・Kind バランス")
                Text("  ・ブックマークボタン → 単語帳へ保存")

                Divider()

                Text("「PDF 出力」ボタン（後日実装）")
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
