# 機能一覧

[← README に戻る](../README.md)

前提の学習サイクルは [実現したい学習サイクル](learning-cycle.md) を参照。会話の詳細フローは [Conversation フロー](flow-conversation.md) を参照。学習ログの画面遷移・表示方針は [学習ログ 機能フロー](flow-learning-log.md) を参照。

---

## 機能（大枠）

**ログ**（学習記録の閲覧）と、ボキャブラリーブック中心の**インプット**と、**アウトプット**（初版は**会話**を中心に実装。<strong>クイズ</strong>は後フェーズで追加予定）。あわせて**設定**ほか**その他**（**アカウント**・プラン・外観・規約・レビュー誘導など）を用意する。

### ログ

（※純粋な Markdown の表はセル結合不可のため、必要に応じて HTML の表を使用。）

<table>
<thead>
<tr>
<th align="left">大分類</th>
<th align="left">中分類</th>
<th align="left">小分類</th>
<th align="left">内容</th>
<th align="left">備考</th>
</tr>
</thead>
<tbody>
<tr>
<td>学習ログ（履歴）</td>
<td>—</td>
<td>—</td>
<td>学習の<strong>記録を振り返る</strong>ための画面。<strong>カレンダー</strong>を表示し、<strong>学習を行った日</strong>の日付を<strong>色付け・ハイライトなど視覚的に区別</strong>できるようにする。<br><br>- <strong>日付をタップ</strong>：その<strong>日付に紐づく記録</strong>を表示する。<br>- <strong>その日の一覧</strong>：その日に行った<strong>会話セッション</strong>を一覧で表示する（<strong>1セッション＝1スレッド</strong>など、会話フロー側の単位と整合させる。会話のデータ構造は <a href="flow-conversation.md">flow-conversation.md</a>、ログ上の遷移・「その日」の扱いは <a href="flow-learning-log.md">flow-learning-log.md</a>）。<br>- <strong>セッションをタップ</strong>：当該セッション内の<strong>会話（発言の並び）</strong>を一覧で表示する。<strong>AI からのフィードバック・指摘・提案なども、セッション内で行われた範囲はすべて閲覧できる</strong>ようにする（ユーザー発話と AI 応答・フィードバックの<strong>対応関係</strong>が追える表示を想定）。<br><br><strong>空き日・セッションなし日</strong>の扱いや、<strong>タイムゾーン</strong>（「その日」の区切り）は実装で確定する。</td>
<td>アウトプット（会話）で蓄積したセッション・フィードバックを<strong>日付単位</strong>で辿る想定（データモデルは実装で確定）。</td>
</tr>
</tbody>
</table>

### インプット

（※純粋な Markdown の表はセル結合不可のため、**大分類**の縦結合には HTML の `rowspan` を使用。）

<table>
<thead>
<tr>
<th align="left">大分類</th>
<th align="left">中分類</th>
<th align="left">小分類</th>
<th align="left">内容</th>
<th align="left">備考</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="4">単語一覧</td>
<td>一覧機能</td>
<td>—</td>
<td>エントリを<strong>リスト表示</strong>し、詳細へ辿れる。<br><br>- <strong>見出し語</strong>：学習言語ごとの表記（例：英単語・ハングル・スペイン語など）<br>- <strong>定義（2本）</strong>：学習言語版と母国語版、<strong>表示切替</strong>で補助<br>- <strong>発音</strong>：言語に応じた表記（例：英語・スペイン語は <strong>IPA</strong>、韓国語は <strong>ローマ字／発音ガイド</strong> など。詳細は実装で確定）<br>- <strong>例文</strong>：複数、目安<strong>最大5つ</strong></td>
<td><strong>エントリの持ち方</strong>：単一テーブル（<strong>分割なし</strong>）。<br><br><strong>Kind（enum）</strong>：Verb / Adjective / Adverb / Noun / Phrasing / Interjection（<strong>コード上の綴りは実装で確定</strong>）。</td>
</tr>
<tr>
<td>ブックマーク</td>
<td>—</td>
<td><strong>フォルダ</strong>で整理。（<strong>複数フォルダ</strong>）（<strong>Instagram の Saved</strong> に近いイメージ）</td>
<td>—</td>
</tr>
<tr>
<td>タグ付け</td>
<td>—</td>
<td>エントリにタグ。（<strong>エントリ単位</strong>）（<strong>プリセット</strong>と<strong>ユーザー定義</strong>）</td>
<td>—</td>
</tr>
<tr>
<td>リスニング（読み上げ）</td>
<td>—</td>
<td>読み上げでインプット。（<strong>対象</strong>：単語・意味・例文）（<strong>読む範囲</strong>：単語のみ／単語と例文など）（<strong>スピード</strong>可変）</td>
<td>—</td>
</tr>
</tbody>
</table>

### アウトプット

（※大分類の縦結合のため HTML 表を使用。）

<table>
<thead>
<tr>
<th align="left">大分類</th>
<th align="left">中分類</th>
<th align="left">小分類</th>
<th align="left">内容</th>
<th align="left">備考</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="5">Conversation（会話）</td>
<td>Self</td>
<td>—</td>
<td>学習言語を<strong>一人で話す</strong>モード。（<strong>ペラペラ</strong>・相手のターンなし）</td>
<td rowspan="5"><strong>前提</strong>：<strong>実現したい学習サイクル</strong>（アウトプット→フィードバック→インプット）を<strong>会話の形で回す</strong>（<a href="learning-cycle.md">learning-cycle.md</a> の Mermaid と対応）。<br><br><strong>フィードバック</strong>：文の<strong>正しい／正しくない</strong>／<strong>雰囲気・文脈</strong>に合わない<strong>言い回し</strong>への<strong>替え</strong>／<strong>単語の提案</strong>。<br><br><strong>インプット</strong>：<strong>スレッド</strong>で蓄積／<strong>フィードバック</strong>も同じスレッドに残す／<strong>発言</strong>と<strong>フィードバック</strong>を見返す／<strong>同じスレッド</strong>または<strong>新規スレッド</strong>で続行。（<strong>両モード共通</strong>とする。）</td>
</tr>
<tr>
<td rowspan="2">AI</td>
<td>自由テーマ</td>
<td><strong>AI</strong>と<strong>往復</strong>して会話。身につけた<strong>単語・表現</strong>で文を組み立てる。場面を<strong>特に絞らない</strong>。</td>
</tr>
<tr>
<td>テーマあり</td>
<td>同上の会話形式で<strong>テーマを指定</strong>。例：旅行・ビジネス・スポーツなどの<strong>プリセット</strong>。あわせて<strong>カスタムテーマ</strong>（自分で定義）を含める。</td>
</tr>
<tr>
<td>Self／AI 共通</td>
<td>—</td>
<td><strong>セッション終了後のボキャブラリ候補</strong>（深掘り）。<strong>1セッション＝スレッド</strong>単位で、会話から得られた<strong>新出の語・おすすめ表現</strong>などを抽出し、<strong>ボキャブラリーブック／単語一覧に載せられる形のドラフト候補</strong>まで自動生成する。<strong>AI 会話</strong>では往復テキスト（ユーザ発話＋AI）を主なソースとする。<strong>Self</strong>では独白だけから無理に語彙を「新出」認定しない前提とし、<strong>文法・言い回しのフィードバック</strong>（AI）に現れた単語・表現をソースに候補化する。<br><br><strong>直登録しない</strong>：候補は一度まとめて提示し、ユーザーが<strong>必要なものだけを選んで</strong>単語一覧へ追加する<strong>ワンクッション</strong>を挟む。</td>
</tr>
<tr>
<td>PDF出力</td>
<td>—</td>
<td>その日の<strong>会話スクリプト</strong>と、AI の<strong>指摘・フィードバック</strong>を<strong>PDF</strong>で書き出す。</td>
</tr>
<tr>
<td>クイズ</td>
<td>—</td>
<td>—</td>
<td>ボキャブラリーブックなどを素材にした<strong>クイズ形式のアウトプット</strong>を想定。仕様・UI は<strong>未定</strong>。</td>
<td><strong>ファーストフェーズでは実装しない</strong>。リリース後に段階的に追加する。</td>
</tr>
</tbody>
</table>

### その他（設定・法務・レビュー）

ログ／インプット／アウトプット以外に、**設定画面**を中心として次を実装する想定（ファーストフェーズに含める）。

| 項目 | 内容 | 備考 |
|------|------|------|
| **アカウント（登録／編集）** | **サインアップ**、**ログイン**、**ログアウト**、および**プロフィール等の編集**（表示名・連絡先など。**載せる項目は実装で確定**）。初回利用時のセットアップを含む。 | 認証方式（例：Sign in with Apple、メール）は別途決定。クラウド同期やバックアップの有無とも設計を揃える。 |
| **プラン** | **無料／有料（サブスク）**の確認と、**課金・復元**への導線（StoreKit）。 | 料金ラインは [収益・サブスク案](monetization.md) と一致させる。 |
| **テーマ／外観** | **テーマカラー**（例：アクセント色）や、**ライト／ダーク**に追従するなど表示の好み。 | 具体的なプリセット数は実装で確定。 |
| **ローカル LLM** | **既定モデル**（同梱または最小取得：**Gemma 3** の最軽量帯を想定）の利用。**追加モデル**（例：**Qwen**）の**オンデマンド・ダウンロード**。**現在使うモデルの選択**と、**会話セッション途中を含む切替**（文脈・終了後処理の扱いは [Conversation フロー](flow-conversation.md) を参照）。 | 型番・量子化・配布元は [ローカル LLM の選定](local-llm.md) 。端末ストレージ・削除（アンインストール時のキャッシュ整理）は実装で確定。 |
| **利用規約** | アプリ内または Safari で**利用規約**を表示。 | 文言・ホスティングはリリース前に確定。 |
| **プライバシーポリシー** | 同上で**プライバシーポリシー**を表示。 | 広告・分析を入れる場合は必須に近い。 |
| **レビュー** | **App Store レビュー**への導線を二段構えにする。（1）**適切なタイミング**でシステムのレビュー依頼（`requestReview` 等）。（2）**設定からいつでも**「評価する」でストアレビュー画面またはストアの該当ページを開ける。 | 依頼の頻度はガイドラインと UX を踏まえて制御。設定経路で常に用意し、実装コストも低めに載せられるようにする。 |
