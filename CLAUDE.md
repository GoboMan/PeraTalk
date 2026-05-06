# PeraTalk iOS — AI コーディング規約（必読）

このファイルは **PeraTalk の Swift / SwiftUI コードを変更するときの強制ルール** である。作業を始める前にここを読み、**詳細・背景・例外の扱いは SSOT** である次を必要に応じて参照すること。

- `PeraTalk/docs/アーキテクチャ/アプリケーションアーキテクチャ-iOS.md`

ルールと矛盾する実装を提案・追加しない。既存コードがルールと食い違う場合は、ユーザーに確認せずに「ルールへ寄せるリファクタ」と「例外のまま」のどちらかを勝手に広げない。違反しそうなときは **その旨を明示** し、最小差分で済む案を優先する。

---

## 1. アーキテクチャと依存の向き（実用クリーンアーキテクチャ）

| 層 | 責務 |
|----|------|
| **Presentation** | SwiftUI。表示に必要な状態の購読と操作の入口。**副作用の主導はここで完結させない。** |
| **Application（UseCase）** | 1 操作＝1 ユースケースの手順。**Service のみ**を依存として Orchestration。**テストの主戦場。** |
| **Application（Service）** | **複数の Client／Repository** を束ね、アプリ固有の読み書き・外部 API・プロンプト組み立てなどをまとめる（`protocol` + `Live*`／`Stub*`）。UseCase から見える **I/O の窓口**。 |
| **Domain** | 純粋な値・不変条件・小さな変換。 |
| **Infrastructure** | SwiftData `@Model`、Supabase、LLM、Apple Intelligence、TTS 等の **具体実装**（`Core/Infrastructure/Clients/` など）。 |

**依存の向き**

- `Presentation → Application → Domain` は内側へ向かう。
- `Infrastructure` は **Application が定義する `protocol`（Port）** を実装する。
- **具象の結線**（どの実装がどの `protocol` を満たすか、`ModelContainer` の注入など）は **`App` エントリまたは専用 Factory に集中**。View / UseCase が **グローバルシングルトンに直接依存**しない。

---

## 2. SwiftUI・画面状態（アーキテクチャ文書 3.1 に準拠）

- 画面ごとに **`@Observable` クラス 1 つ**に、**表示に必要な値を集約**する（`FooScreenModel` など既存パターンに合わせる）。
- **ユーザー操作**は原則 **`@Observable` 上のメソッド 1 本**に集約するイメージで設計する。入口が View や子 View に散らばらないようにする。
- 深い子 View に `Binding` とロジックを大量に渡さない。子 View は **表示と局所的な入力**に留め、**ビジネス手順は `@Observable` → UseCase** に寄せる。

---

## 3. UseCase・Service と I/O（アーキテクチャ文書 3.2）

次の **依存チェーンを必ず守る**（下位から上位へ呼び出さない）。

**`View → ScreenModel（@Observable）→ UseCase → Service → Client / Repository`**

- **ScreenModel** は **UseCase** のみを保持する（`LLMClient`・`VocabularyRepository` などの Client／Repository を直接保持しない）。
- **UseCase** は **Service** の `protocol` にだけ依存する（Client／Repository を直接受け取らない）。認証など既存の **`AuthService`** のように「すでに Service である Port」だけを受け取る場合も同様に **UseCase → Service** の一段でよい。
- **Service** が **複数の Client／Repository** を組み合わせてアプリ向けの手順を実行する。具象の Client／Repository 実装は **Infrastructure／Feature の Repositories** に置く。
- **オンデバイス生成**は用途別 **Client**（例：`OnDeviceWordDraftClient`）が **システム指示とユーザメッセージを渡し、構造化応答を `WordDraft` 等へ機械マップするまで**にとどめる。**プロンプト組み立て・出力のビジネス正規化**は **該当 Feature の Service**（例：`VocabularyWordDraftPrompt` と `LiveVocabularyService`）に寄せる。
- **具象の結線**（どの `Live*`／`Stub*` が注入されるか）は原則 **`App`・Factory・または `ScreenModel.live(...)` のようなコンポジション用ファクトリ** に寄せる。View 内で UseCase を都度 `init(repository:)` するのは避ける。

---

## 4. 新機能の増やし方（アーキテクチャ文書 3.3）

新機能は原則次の繰り返しパターンで増やす。

- **State**（`@Observable` が保持する表示用状態）
- **View**
- **UseCase** は **`FooUseCase.swift` にその型だけを置く（1 ファイル 1 UseCase を必須）**。複数の UseCase を `*UseCases.swift` にまとめない。
- **Service**（複数 Client／Repository を束ねる `protocol` + `Live*`／`Stub*`）
- **Client / Repository**（I/O の `protocol` + 具象実装）

**「ここだけ View が DB を直接触る」** のような例外は **最小限**。増やす場合は SSOT ドキュメントまたは ADR に理由を残す前提で、ユーザー指示があるときのみ検討する。

横断 concern（同期フック、認証セッションなど）は **`Core/` や `App/` の 1 か所** に寄せ、Feature の UseCase から **`protocol` で呼ぶ**。

---

## 5. ファイル粒度（アーキテクチャ文書 3.4）

- **1 ファイル 1 責務**。
- **UseCase は必ず 1 ファイル 1 型**とする。ファイル名は **型名と一致**（例：`GenerateVocabularyAddFormDraftUseCase.swift`）。`*UseCases.swift` に複数の UseCase をまとめない。
- **200〜400 行を上限の目安**。超える場合は **UseCase 以外の単位**で型の抽出・Repository／Service 分離を検討し、単一ファイルの肥大化を増やさない。

---

## 6. 境界の型と命名 — Port（アーキテクチャ文書 3.5）

- 境界には **役割が名前から分かる `protocol`** を置く（例：`ConversationService`、`VocabularyRepository`、`LLMClient`）。
  **オンデバイス AI** は用途ごとにポートを分ける（例：単語ドラフトは `OnDeviceWordDraftClient`。別用途は別 protocol を追加し実装を共有）。
- 新規は既存 Feature 配下の **`Services/`・`Repositories/`・`UseCases/`** および `Core/Infrastructure` の置き場所・命名に **合わせる**。

---

## 7. テスト（アーキテクチャ文書 3.6）

- **UI テストより先に**、`UseCase + モック（protocol のフェイク）` で **手順と分岐**をテストする方針と整合させる。
- 純粋なマッパ（API JSON → ドメイン型など）も同様に優先度が高い。

---

## 8. 意図的にやらないこと（現時点・アーキテクチャ文書 7）

次を **無理に採用しない**（SSOT の方針に逆らう拡張を提案しない）。

- 全ドメインをフレームワークゼロに固執した二重化の即時導入。
- テストや第 2 実装の見通しがない **過剰な `protocol` 増殖**。

---

## 9. 変更時の自己チェック（毎回）

実装・リファクタ前に以下を満たすか確認する。

1. 変更したコードは **どの層か** を言語化できる（Presentation / UseCase / Service / Domain / Infrastructure）。
2. UseCase に **具象 I/O 型** が漏れていない（**UseCase は Service のみ**を見ている）。
3. 新しい「画面操作の入口」が **散在していない**（`@Observable` に寄っている）。
4. **UseCase が 1 ファイル 1 型**になっている。`*UseCases.swift` のような集合ファイルを増やしていない。
5. ファイルが **責務過多・行数過多** になっていない。
6. SSOT で参照されるデータ意味論は **Repository／Service／UseCase 内部**で吸収し、View にドメインの例外をべた書きしていない。

---

## 10. 関連ドキュメント（意味論・インフラ）

アーキテクチャ SSOT以外の正は必要に応じて次を参照（実装の「どこに書くか」は本章より上を優先）。

- LLM・キー・オンデバイス分担: `PeraTalk/docs/アーキテクチャ/LLM-API方針.md`（存在する場合）
- SwiftData・`Cached*`・同期: `PeraTalk/docs/アーキテクチャ/データベース設計-クライアント.md`（存在する場合）
