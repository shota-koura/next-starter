---
name: requirements-quality-gate
description: >-
  ユーザーが指定した 1 個以上の steering ディレクトリ内の requirements.md または requirement.md を、
  AGENTS.md・README.md・steering.md・必要に応じて関連する implementation-plan.md / tasklist.md / 永続ドキュメントと照合し、
  後続の implementation-plan 生成・tasklist 生成・実装の前に品質ゲートとしてレビューする skill。
  使う場面: requirements の考慮漏れ、曖昧さ、依存関係不足、受け入れ条件不足を upstream で潰したいとき。
  使わない場面: 実装計画や tasklist を直接作りたいとき、コードレビューや実装修正が目的のとき、対象 requirements が特定されていないとき。
---

# requirements-quality-gate

## この skill の役割

この skill の仕事は、対象作業の `requirements.md` または `requirement.md` をレビューし、
後続の `implementation-plan.md` 生成、`tasklist.md` 生成、実装に悪影響が出るポイントを upstream で洗い出すことです。

この skill は、requirements を downstream の品質ゲートとして扱います。  
単なるレビューコメントを返すだけでなく、

- 後続に進めるかの判定
- 修正すべき事項の stable ID 付き提示
- 人間判断が必要な曖昧点の質問化
- 必要なら、ユーザーが指定した ID だけを反映する支援

までを扱います。

## 動作モード

### 1. 初回レビュー モード

デフォルトです。  
対象 requirements を読み、品質ゲートとしてレビュー結果を返します。  
このモードでは、原則としてファイルは直接更新しません。

### 2. RR 反映 モード

ユーザーが次のように明示した場合のみ実行します。

- `RR-001 と RR-003 を修正`
- `RR-002 を requirements に反映`

このモードでは、ユーザーが指定した `RR-*` だけを requirements に反映し、
その後に簡潔な再レビューを行います。

### 3. RQ 回答 モード

ユーザーが次のように明示した場合のみ実行します。

- `RQ-001 は A 方針`
- `RQ-002 は Supabase Edge Functions を使う`
- `RQ-003 は今回は scope 外`

このモードでは、ユーザーの回答を受け付けて整理しますが、**requirements ファイルは更新しません**。  
回答だけでは品質ゲートは解除されません。  
回答内容が `scope` / `constraint` / `acceptance` / `dependency` に関わる場合、反映待ちのまま downstream を止めます。

### 4. RQ 反映 モード

ユーザーが次のように明示した場合のみ実行します。

- `RQ-001 の回答を requirements に反映`
- `RQ-002 は A 方針で反映`
- `RQ-003 を本文に追記`

このモードでは、ユーザーが指定した `RQ-*` の回答を requirements に反映し、
その後に簡潔な再レビューを行います。

重要:

- 指定されていない ID は反映しない
- ファイル更新は、ユーザーが明示的に反映を求めた場合のみ行う
- 書き込みできない環境では、差し替え案や追記案を返す

## 入力

必須:

- レビュー対象の `requirements.md` または `requirement.md` のパス
- 複数レビューする場合は、そのファイルパス一覧
- または、対象 steering ディレクトリの一覧

任意:

- 対象ディレクトリの `implementation-plan.md`
- 対象ディレクトリの `tasklist.md`
- `docs/development/.steering/steering.md`
- リポジトリの `README.md`
- 近傍の `AGENTS.md`
- 近傍の `AGENTS.override.md`
- 関連する永続ドキュメント
- `steering.md` で依存関係または着手条件として明示された他作業ディレクトリの `requirements.md` / `tasklist.md`

## 出力

初回レビュー モードでは、返答内にレビュー結果を返します。  
原則として、ファイルは直接更新しません。

RR 反映 モード / RQ 反映 モードでは、ユーザーが指定した ID のみを対象に requirements を更新し、
更新結果と残件を返します。

RQ 回答 モードでは、質問への回答内容を整理し、反映待ちであることを明示します。

## 参照ソースの優先順位

### 1. repo ルール・運用ルールの判定順

repo ルールや agent 向け指示の判定には、次の優先順位を使う。

1. 対象ファイルに最も近い `AGENTS.override.md`
2. 対象ファイルに最も近い `AGENTS.md`
3. 上位ディレクトリに向かって辿った `AGENTS.override.md` / `AGENTS.md`
4. ルートの `AGENTS.md`
5. この skill の instructions
6. 永続ドキュメント
7. `README.md`
8. `steering.md`
9. 関連作業の `requirements.md` / `implementation-plan.md` / `tasklist.md`

同一階層では `AGENTS.override.md` を `AGENTS.md` より優先する。  
`README.md` は人間向けの入口と概要であり、agent 向け一次ソースではない。  
requirements の内容が repo ルールと衝突する場合は、requirements を正しい前提として扱わず、finding にする。

### 2. 現在タスクの意図と状態の参照順

現在タスクの意図や状態の把握には、次の順で参照する。

1. 対象 `requirements.md` または `requirement.md`
2. 同一ディレクトリの `implementation-plan.md` と `tasklist.md`
3. `docs/development/.steering/steering.md`
4. relevant な永続ドキュメント
5. `steering.md` で依存関係または着手条件が明示された他作業のドキュメント
6. `README.md`

重要:

- 現在の requirements はレビュー対象であり、repo ルールの一次ソースではない
- 他作業の tasklist や requirements は、`steering.md` で関係が明示されている場合のみ参照してよい
- 番号の前後やディレクトリの見た目上の近さだけで、他作業を参照してはならない

## 停止条件

この skill は品質ゲートです。  
次のいずれかが残っている限り、**`implementation-plan-generator` と `tasklist-generator` に進めてはならない**。

- 未解決の `RR-*` が 1 件でもある
- 未回答の `RQ-*` が 1 件でもある
- 回答済みだが未反映の `RQ-*` が 1 件でもある
- ユーザー承認待ちの論点が 1 件でもある

重要:

- `RQ-*` への回答だけでは品質ゲートは解除されない
- `RQ-*` の回答が requirements に反映されるまで、またはユーザーが明示的に「反映不要でよい」と要求し、その扱いが repo ルールと両立すると確認できるまで、gate は open のままとする
- unresolved な `RR-*` / `RQ-*` が残っている状態で downstream へ進む提案はしない
- `後続ブロック: いいえ` は補助情報であり、未解決のまま gate を通してよい意味ではない

## 基本方針

- 必ず日本語で書く
- `requirements.md` を一次ソースとして扱う
- 他ドキュメントは補助ソースとして扱う
- 他作業の `tasklist.md` や `requirements.md` は、`steering.md` 上で依存関係または着手条件が明示されている場合のみ参照してよい
- 番号の前後やディレクトリの見た目上の近さだけで、他作業を参照してはならない
- 他作業の task や要件を、そのまま現在の requirements に持ち込んではならない
- 追加指摘は、現在の requirements、repo ルール、依存関係、外部仕様のいずれかに根拠がある場合のみ行う
- 文体や言い換えだけの指摘は出さない
- `implementation-plan.md` や `tasklist.md` で自然に補完できるものまで、requirements の欠陥扱いしない
- repo ルールや skill の既定動作から **機械的に補完できるだけ** の docs update / validation / 実行手順は、原則として finding にしない
- ただし、その欠落により `scope` / `constraint` / `acceptance` / `dependency` の解釈が揺れ、downstream の生成や実装が不安定になる場合は finding にする
- `scope` / `constraint` / `acceptance` / `dependency` を変える論点だけを質問として切り出す
- `要改善・修正点` と `確認したい事項` を混ぜない
- downstream に進めない条件がある場合は、必ず明示的に差し戻す
- 初回は review-first、更新はユーザー指定 ID のみ
- `根拠` には必ず `path:line` または `path:start-end` を入れる
- 正確な行番号が未取得なら、返答前に必ず取得する

## この skill が見るべき観点

最低限、次をレビューする:

- 作業目的が明確か
- scope が明確か
- out of scope が明確か
- 制約が明確か
- 受け入れ条件が十分か
- 依存関係や着手条件が明確か
- repo ルールや AGENTS.md に反していないか
- README / 永続ドキュメント / steering と矛盾していないか
- implementation-plan-generator に必要な情報が揃っているか
- tasklist-generator に必要な情報が揃っているか
- 実装前に external docs や既存 repo 調査が必要な論点が明示されているか
- 現在の requirements のままだと downstream で詰まりそうな未決事項が残っていないか

追加の判定ルール:

- repo ルールから deterministic に補完できるだけなら finding にしない
- requirements の不足により downstream の plan / tasklist / 実装が不安定になる場合のみ finding にする
- docs update や validation の不足を指摘する場合も、それが repo の定型作業なのか、requirements の不足なのかを分けて考える

## 実行手順

### 1. 対象 requirements を確定する

- 入力がファイルパスなら、そのファイルを対象とする
- 入力が steering ディレクトリなら、その中の `requirements.md` または `requirement.md` を探す
- 複数ある場合は、対象一覧を明示してからレビューを始める

### 2. コンテキストを読む

最低限、次を確認する:

- 対象 requirements
- 近傍の `AGENTS.override.md`
- 近傍の `AGENTS.md`
- `README.md` があれば relevant section
- `docs/development/.steering/steering.md` があれば、依存関係・着手条件・関連作業
- 対象ディレクトリの `implementation-plan.md` / `tasklist.md` があれば現在状態
- relevant な永続ドキュメント

### 3. 関連作業を限定して特定する

- `steering.md` を読み、現在作業の依存先・着手条件・並列関係を確認する
- 他作業の `requirements.md` / `tasklist.md` を読むのは、`steering.md` で関係が明示されている場合のみ
- 関連作業を参照する目的は、スコープの拡張ではなく次の確認に限定する:
  - 依存関係の抜け漏れ
  - 役割分担の衝突
  - task の前提条件不足
  - 受け入れ条件の接続不足

### 4. 必要な調査を sub-agent に依頼する

- 必要に応じて以下の sub-agent を利用してください
- sub-agent 利用を許可します。利用可否のこちらへの確認は不要です
- sub-agent は自動では起動しない前提で、必要な場合のみ明示的に依頼してください
- 原則として read-only 系 sub-agent を使う
- `backend-developer`、`fullstack-developer`、`refactoring-specialist` などの workspace-write 系は通常使わない

#### 4-1. `planning-reviewer`

使う場面:

- requirements 自体の抜け漏れ、依存関係、順序、検証不足を俯瞰したい
- 複数 requirements 間の整合や衝突を見たい

依頼内容:

- 現在の requirements が downstream の implementation-plan / tasklist / 実装に耐えるか
- `AGENTS.md`、`README.md`、`steering.md`、関連 doc との整合
- `add / reorder / clarify / remove` の観点で指摘

#### 4-2. `docs-researcher`

使う場面:

- requirements の中に、CLI、API、SDK、LLM、クラウド、フレームワーク仕様に依存する前提がある
- documented fact と単なる想定を切り分けたい

依頼内容:

- requirements の前提となっている外部仕様や一次情報を確認する
- requirements に追記すべき documented constraint / caveat / default を返させる

#### 4-3. `code-mapper`

使う場面:

- requirements が repo 構造や既存実装に自然に乗るか確認したい
- 既存ファイル、責務境界、命名ルール、再利用候補とのズレを見たい

依頼内容:

- 対象作業の owning path
- 変更対象候補
- 再利用すべき箇所
- requirements に足りない repo-side constraints
- repo ルールとぶつかる要求の有無

#### 4-4. `api-designer`

使う場面:

- requirements が API / Edge Function / request-response / schema / compatibility を含む
- downstream の implementation-plan 作成前に contract ambiguity を減らしたい

依頼内容:

- contract として requirements に足りない点
- validation / error model / compatibility / migration 観点で追加すべき事項

#### 4-5. `llm-architect`

使う場面:

- requirements が prompt / structured output / retrieval / eval / latency / cost を含む
- downstream の implementation-plan で LLM workflow 設計が必要

依頼内容:

- requirements に不足している LLM system design 観点
- 追記すべき eval / failure handling / schema / cost-latency 制約

#### 4-6. `cloud-architect`

使う場面:

- requirements が secrets / storage / runtime / networking / deploy / reliability を含む

依頼内容:

- requirements に不足している operational constraint
- exposure / secret handling / rollback / live validation の前提

### 5. 初回レビューを行う

ファイルごとに、次の観点で review する:

- 目的は明確か
- scope / out of scope は分かれているか
- 受け入れ条件は downstream task に落とせる粒度か
- repo ルールに照らして必要な docs update や validation が抜けていないか
- external dependency があるのに仕様確認タスクが必要と分かるようになっているか
- implementation-plan が必要な作業なのに、その判断材料が不足していないか
- tasklist 生成時に ambiguous になりそうな記述がないか
- 他作業との境界が曖昧で、scope leakage が起きそうでないか
- hidden dependency や sequencing risk がないか

重要:

- repo ルールから自動補完できるだけなら finding にしない
- requirements 不足で downstream が不安定になる場合のみ finding にする

### 6. 複数 files の場合は cross-file review を行う

複数の requirements をレビューする場合は、個別レビューのあとに cross-file review を行う。

見る観点:

- 重複スコープ
- 依存関係の非対称
- 前提条件の片側欠落
- 同じ機能に対する表現差
- 受け入れ条件の穴
- task ownership の衝突
- docs update / validation の責務分担漏れ

### 7. 結果を返す

- ファイルごとの `要改善・修正点`
- ファイルごとの `確認したい事項`
- 複数ある場合は `複数ファイル横断の指摘`
- `進行判定`
- `次のアクション`
- `総評`

### 8. RR 反映を行う

次の条件を満たす場合のみ、requirements を更新してよい:

- ユーザーが明示的に `RR-*` を指定した
- 反映対象ファイルが明確である
- scope 拡張を伴う勝手な補完ではない
- 現在セッションで書き込み可能である  
  書き込み不可なら、差し替え案や追記案を返す

反映時のルール:

- 指定されていない `RR-*` は反映しない
- 反映後は簡潔な再レビューを行い、残件のみを返す

### 9. RQ 回答を受け付ける

次の条件を満たす場合のみ、回答受付として扱う:

- ユーザーが明示的に `RQ-*` への回答を示した
- まだ requirements へ反映するとは言っていない

回答受付時のルール:

- requirements ファイルは更新しない
- 回答内容を整理して再掲する
- 回答済みだが未反映であることを明示する
- `進行判定` は原則として保留のままにする

### 10. RQ 回答を requirements に反映する

次の条件を満たす場合のみ、requirements を更新してよい:

- ユーザーが明示的に `RQ-*` を requirements に反映すると指示した
- 反映対象ファイルが明確である
- 現在セッションで書き込み可能である  
  書き込み不可なら、差し替え案や追記案を返す

反映時のルール:

- 指定されていない `RQ-*` は反映しない
- 反映後は簡潔な再レビューを行う
- 反映済み question は未解決一覧から外す
- 反映しても新たな ambiguity が生じた場合は、新しい `RQ-*` を採番する

## `要改善・修正点` と `確認したい事項` の判定基準

### `要改善・修正点`

次に該当するものを入れる:

- scope, out of scope, constraint, acceptance, dependency が不足している
- repo ルールや既存 docs と矛盾している
- 後続 skill が安定して生成できない
- 曖昧さではなく、事実ベースで不足・矛盾・欠落と言える
- requirements 不足により downstream の生成や実装が不安定になる

### `確認したい事項`

次に該当するものを入れる:

- 複数の妥当な解釈があり、どれを採るかで scope / acceptance / implementation が変わる
- 外部仕様や product 判断が必要
- agent が勝手に決めると過剰補完になる
- 人間の承認がないと downstream の仕様が不安定になる

## 分類

各 `要改善・修正点` は、次のいずれかの分類を持たせる:

- スコープ不足（missing_scope）
- スコープ外不足（missing_out_of_scope）
- 制約不足（missing_constraint）
- 受け入れ条件不足（missing_acceptance）
- 依存関係不足（missing_dependency）
- 要件の曖昧さ（ambiguous_requirement）
- リポジトリルール不整合（repo_rule_mismatch）
- 外部前提未確認（external_assumption_unverified）
- 検証不足（validation_gap）
- ドキュメント更新不足（doc_update_gap）
- 作業間衝突（cross_task_conflict）
- 順序リスク（sequencing_risk）
- implementation-plan 先行必要（implementation_plan_needed）
- tasklist 生成阻害（tasklist_blocker）

## Stable ID のルール

- `要改善・修正点` には `RR-001` 形式の ID を付ける
- `確認したい事項` には `RQ-001` 形式の ID を付ける
- 同じ会話の中で未解決の項目は ID を維持する
- 新規に見つかった項目だけ、新しい番号を付ける
- 解消済みの ID は再利用しない
- 複数ファイルの場合も ID はグローバルに採番してよい
- 各項目には必ず対象ファイルを明記する

具体ルール:

- 文言が変わっても、本質的に同じ問題・同じ判断要求なら同じ ID を維持する
- 1件の指摘が 2 件以上に分かれた場合は、元のスコープと最も近いものに元の ID を残し、追加分に新しい ID を付ける
- split した場合は、必要なら `派生元: RR-001` または `派生元: RQ-001` を付けてよい
- 複数の指摘が 1 件に統合された場合は、最小の既存 ID を維持し、他は `統合先: RR-001` または `統合先: RQ-001` として扱ってよい
- 対象ファイルの行ずれや文言修正だけで本質が変わらない場合は、再採番しない
- ファイル名変更や見出し移動があっても、本質が同じなら同じ ID を維持する

## 進行判定

各ファイル、および必要なら全体に対して、次のいずれかを返す:

- `そのまま implementation-plan へ進める`
- `そのまま tasklist へ進める`
- `implementation-plan 前に修正が必要`
- `tasklist 生成前に修正が必要`
- `未回答または未反映の確認事項があり保留`

補助判定:

- `implementation-plan 要否: 必要 / 不要 / 要判断`

判定基準:

- `未回答または未反映の確認事項があり保留` が 1 件でもある場合、全体判定は原則これを優先する
- 未解決の `RR-*` が 1 件でもある場合、downstream には進めない
- `implementation-plan` が作れないレベルの欠落は `implementation-plan 前に修正が必要`
- `implementation-plan` は作れるが `tasklist` 生成で不安定になる場合は `tasklist 生成前に修正が必要`
- 問題がなく、未解決の `RR-*` / `RQ-*` が無く、`implementation-plan 要否` が `必要` または `要判断` の場合のみ `そのまま implementation-plan へ進める`
- 問題がなく、未解決の `RR-*` / `RQ-*` が無く、`implementation-plan 要否` が `不要` の場合のみ `そのまま tasklist へ進める`
- `implementation-plan 要否` が `不要` の場合でも、未解決の `RR-*` / `RQ-*` が残っていれば downstream には進めない

## 返答フォーマット

返答は必ず次の順で出す。  
見出し名・項目名は固定すること。

### 1. `## 対象ファイル`

- 対象 requirements 一覧を列挙する

### 2. `## 要改善・修正点`

各項目は次の形式で返す:

- `RR-001`
  - `重要度:` `P0` / `P1` / `P2`
  - `分類:` 日本語名（英語コード）
  - `後続ブロック:` `はい` / `いいえ`
  - `対象:` ファイルパス
  - `問題:`
  - `根拠:` `path:line` または `path:start-end` を 1 件以上必須
  - `なぜ重要か:`
  - `推奨修正:`
  - `派生元:` 必要な場合のみ
  - `統合先:` 必要な場合のみ

問題が無い場合は、ファイルごとに `指摘なし` と書いてよい。

### 3. `## 確認したい事項`

各項目は次の形式で返す:

- `RQ-001`
  - `対象:` ファイルパス
  - `確認したい事項:`
  - `判断が必要な理由:`
  - `推奨方針:`
  - `影響:`
  - `根拠:` `path:line` または `path:start-end` を 1 件以上必須
  - `派生元:` 必要な場合のみ
  - `統合先:` 必要な場合のみ

質問が無い場合は `なし` と書く。

### 4. `## 複数ファイル横断の指摘`

複数ファイルをレビューした場合のみ出す。

各項目は次の形式で返す:

- `RR-XXX` または `RQ-XXX`
  - `対象:` 複数ファイル
  - `問題または確認したい事項:`
  - `根拠または判断が必要な理由:` `path:line` または `path:start-end` を 1 件以上必須
  - `推奨修正または推奨方針:`
  - `影響:`

単一ファイルの場合はこの見出しを省略してよい。

### 5. `## 進行判定`

- ファイルごとの判定
- 必要なら全体判定
- `implementation-plan 要否`

### 6. `## 次のアクション`

必ず次を明示する:

- 修正する `RR-*` を指定してください
- 回答する `RQ-*` を指定してください
- 回答済み `RQ-*` を requirements に反映する場合は、その ID を指定してください
- すべて解消後に再レビューを依頼してください
- unresolved な `RR-*` / `RQ-*` が残る限り downstream には進めません
- gate 解消後は、判定に従って `implementation-plan-generator` または `tasklist-generator` に進んでください

ユーザーの指定例:

- `RR-001 と RR-003 を修正`
- `RQ-002 は A 方針`
- `RQ-002 の回答を requirements に反映`
- `RR-004 を反映して再レビュー`

### 7. `## 総評`

- ファイルごとの短い総評
- 複数ファイルの場合は全体総評も付ける

## この skill でやらないこと

- コードレビュー
- 実装修正
- `implementation-plan.md` の生成
- `tasklist.md` の生成
- requirements の勝手な直接書き換え
- 関連のない steering task の横断レビュー
- 「他 tasklist にあるから」という理由だけで新規要件を作ること
- 文体や言い換えだけのレビュー
- 未指定 ID の自動反映
- unresolved な `RR-*` / `RQ-*` がある状態で downstream へ進める提案

## 返答のしかた

- 返答は上記の固定フォーマットに従う
- `## 要改善・修正点` と `## 確認したい事項` を先に出す
- `## 総評` は末尾に置く
- 余分な自由文要約は追加しない
