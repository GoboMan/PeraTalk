import SwiftUI

struct LogDayScreen: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("SCR-LOG-DAY")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("日付詳細画面")
                .font(.title)

            VStack(alignment: .leading, spacing: 12) {
                Text("・その日のセッション一覧（時系列）")
                Text("・モード表示（Self / AI 自由 / AI テーマ）")
                Text("・ペルソナ名表示")
                Text("・セッションタップ → セッション詳細へ")
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
