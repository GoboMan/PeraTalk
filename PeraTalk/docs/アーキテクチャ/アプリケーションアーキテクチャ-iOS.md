# アプリケーションアーキテクチャ（iOS）

[← README に戻る](../../README.md)

> 本ドキュメントは **PeraTalk iOS アプリのコード構成・依存関係・テスト方針の SSOT** である。インフラや API キー、クラウド／オンデバイス LLM の役割分担は [LLM-API方針](LLM-API方針.md) を、端末ローカルスキーマと同期は [データベース設計-クライアント](データベース設計-クライアント.md) を正とする。

---

## 1. 目的とスコープ

個人開発（単一メンテナ）でも **保守・差分レビューがしやすく**、**宣言的 UI（SwiftUI）と矛盾しない**形で、かつ **AI 支援による編集が増えても破綻しにくい** コードベースにするための規約を定義する。

- **対象**：iOS クライアント（SwiftUI / SwiftData 等）。
- **含まない**：サーバー（Supabase）のデプロイ詳細（[インフラ-Supabase](インフラ-Supabase.md)、[データベース設計-サーバー](データベース設計-サーバー.md) を参照）。

---

## 2. 基本思想（実用クリーンアーキテクチャ）

[クリーンアーキテクチャ](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) の **依存のルール**（内側はフレームワークに依存しない）を採用しつつ、フル装備の層分けにはしない **実用寄り** の厚さとする。

| 層（概念） | 責務 |
|------------|------|
| **Presentation** | SwiftUI。表示に必要な状態の購読と、ユーザー操作の入口。**副作用の主導はここで完結させない。** |
| **Application（UseCase）** | アプリが提供する **1 操作＝1 ユースケース** の手順。**Service のみ**を依存として Orchestration する。**テストの主戦場。** |
| **Application（Service）** | **複数の Client／Repository** を組み合わせ、アプリ固有の読み書き・外部 API 呼び出しをまとめる層（`protocol` + `Live*`／`Stub*`）。UseCase から見える **唯一の I/O 窓口**。 |
| **Domain** | 純粋な値・不変条件・小さな変換。初期フェーズでは薄くてよい。 |
| **Infrastructure** | SwiftData `@Model`、Supabase クライアント、BFF 越しの LLM、Apple Intelligence、TTS 等の **具体実装**。 |

**依存の向き**：`Presentation → Application → Domain` は内側へ。`Infrastructure` は **Application が定義する protocol（Port）** を実装し、**コンポジションルート**（通常は `App` 起動時やファクトリ）で結線する。

---

## 3. 採用方針（今回のアーキテクチャで固定するルール）

以下は **意図的に例外を増やさない** ことを前提とする。例外が増えるほど、人間も AI も古いパターンを引用して不整合を起こしやすい。

### 3.1 画面状態とユーザー操作（宣言的 UI との相性）

- **`@Observable` の 1 クラス**に、**表示に必要な値を集約**する。
- **ユーザー操作**は、原則として **`@Observable` 上のメソッド 1 本**に集約するイメージで設計する（「この画面で起きうる操作の入口が散らばらない」状態を目指す）。
- 深い子 View に `Binding` とロジックを大量に渡さない。子 View は **表示と局所的な入力**に留め、**ビジネス手順は `@Observable` → UseCase** に寄せる。

### 3.2 UseCase・Service と I/O（依存チェーン）

次を **必ず守る**（上位レイヤーからのみ依存し、下位から上位を呼ばない）。

**`View → ScreenModel（@Observable）→ UseCase → Service → Client / Repository`**

- **ScreenModel** は **UseCase** のみを保持する（Client／Repository を直接保持しない）。
- **UseCase** は **Service** の `protocol` にのみ依存する（Client／Repository を直接注入しない）。すでに横断 concern として **`AuthService`** のような **Service** が存在する場合も、UseCase はそれを **唯一の窓口**としてよい。
- **Service** が SwiftData・ネットワーク・LLM・オンデバイス API などへの **具体的な呼び出し**を束ねる。**Repository／Client** の具象実装は Infrastructure／Feature の Repositories に置く。
- **具象の結線**は **`App` エントリ・専用 Factory・または `ScreenModel.live(...)` のようなコンポジション用ファクトリ** に寄せる（View の `body` 内で Repository を new して UseCase を組み立てない）。

### 3.3 新機能の増やし方（繰り返しパターン）

- 新機能も原則 **`State`（`@Observable` が保持する表示用状態）+ `View` + `UseCase` + `Service` + `Client / Repository`（必要なら複数）** で増やす。
- **同じパターンの繰り返し**を徹底する。例外的な「ここだけ View が DB を直接触る」は **最小限** とし、増やす場合は本ドキュメントまたは ADR で理由を残す。

### 3.4 ファイル粒度

- **1 ファイル 1 責務**。**200〜400 行を上限の目安**とする（超えるなら型の抽出・Repository／Service の分離を検討）。
- **UseCase は 1 ファイルに 1 型のみ**。ファイル名は **型名と同一**（例：`LoadVocabularyAddFormForEditingUseCase.swift`）。`**UseCases.swift` に複数の UseCase をまとめない**（検索・レビュー・AI 指示のブレを防ぐ）。
- 差分レビューと **AI が読むコンテキストのサイズ**の両方に効く。

### 3.5 境界の型と命名（Port）

- 境界には **役割が名前から分かる `protocol`** を置く。例：`ConversationService`、`VocabularyRepository`、`LLMClient`、`AuthService`。オンデバイス生成は **用途別ポート**（単語ドラフトは `OnDeviceWordDraftClient`）とし、別用途は別 protocol で増やす。
- プロンプトで **「この protocol の実装を差し替え／新規を追加」** と指示しやすくする。

### 3.6 テスト

- **UI テストより先に**、`UseCase + モック（protocol のフェイク）` で **手順と分岐**を厚くテストする。
- AI や人間によるリファクタの **安全网** にする。純粋なマッパ（API JSON → ドメイン型など）も同様に優先度が高い。

---

## 4. 機能単位のフォルダ構成（推奨）

最初は **機能（Feature）単位のディレクトリ** の中に、次を並べるとコンテキストが揃い、AI に「この配下だけ」と指示しやすい。

```
FeatureConversation/
  ConversationScreen.swift              // View
  ConversationScreenModel.swift       // @Observable（UseCase のみ保持）
  UseCases/
    StartSessionUseCase.swift         // 1 ファイル 1 UseCase（型名＝ファイル名）
    SendMessageUseCase.swift
  Services/
    ConversationService.swift        // protocol + Stub / Live
  Repositories/
    SessionRepository.swift           // protocol（具象は Infrastructure などとセット）
```

横断Concern（同期の起動フック、認証セッション）は **`Core/` や `App/`** に **1 か所** に寄せ、各 Feature の UseCase から **protocol** で呼ぶ。

---

## 5. 他ドキュメントとの役割分担（参照関係）

| 内容 | 参照先 |
|------|--------|
| クラウド LLM・オンデバイス・キー管理 | [LLM-API方針](LLM-API方針.md) |
| SwiftData スキーマ・`Cached*`・同期・push 順 | [データベース設計-クライアント](データベース設計-クライアント.md) |
| サーバー側スキーマ・RLS | [データベース設計-サーバー](データベース設計-サーバー.md) |
| 会話のプロダクト仕様 | [会話](../機能/会話.md) ほか機能ドキュメント |

本書は **「コードをどこにどう書くか」** を定義する。データの意味論・Phase 1/2 の境界は上記の仕様ドキュメントに従い、**Repository／Service／UseCase の内部**で吸収する。

---

## 6. コンポジションルート

- **具象の結線**（どの `Live*`／`Stub*` がどの protocol を満たすか、`ModelContainer` の注入）は **`App` エントリや専用 Factory** に集中させる（当面、`ScreenModel.live(modelContext:)` のように **Presentation 近傍のファクトリ** に置く場合もある。その場合も **View が Repository を直接組み立てない**こと）。
- View / UseCase が **グローバルシングルトン**に直接依存しない方針とする（テスト差し替えのため）。

---

## 7. 意図的にやらないこと（現時点）

- **全ドメインをフレームワークゼロ**にすることへの固執（Swift のみの純粋層と SwiftData モデルの二重化は、痛みが出てから段階的に増やす）。
- **過剰な protocol**（テストや第 2 実装の見通しがなければ増やさない）。

---

## 8. 更新方針

- フォルダ構成の rename、依存ルールの例外追加、テスト方針の変更は **本書を更新**し、大きな転換は ADR を別途起こす。
- OS・フレームワークの推奨 API が変わった場合（例：`Observable` のベストプラクティス）は、**本章 3.1 を見直す**。
