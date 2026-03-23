---
name: tasklist-generator
description: >-
  requirements.md または requirement.md を読み、同じディレクトリの tasklist.md を
  着手順ベース・1タスク1行・phaseタグ付きで生成または更新する skill。
  使う場面: 要件はあるが tasklist が未整備、または tasklist を repo 構造・一次情報・文書整合に合わせて再構成したいとき。
  使わない場面: 単なる進捗更新だけをしたいとき、コードレビューが目的のとき、implementation-plan.md 単独作成が目的のとき、
  対象 requirements ファイルが曖昧なとき。
---

# tasklist-generator

## この skill の役割

この skill の仕事は、対象作業の要求定義を読み、実装可能な `tasklist.md` を作ることです。  
`tasklist.md` の生成・更新に集中し、それ以外のドキュメントやコードは原則として直接変更しません。  
README や `implementation-plan.md` の更新が必要なら、実施そのものではなく `tasklist.md` にタスクとして記載します。

## 入力

必須:

- 対象の `requirements.md` または `requirement.md` のパス

任意:

- 同じディレクトリの `implementation-plan.md`
- `docs/development/.steering/steering.md`
- リポジトリの `README.md`
- 近傍の `AGENTS.md`
- 関連する永続ドキュメント

## 出力

- 対象 requirements ファイルと同じディレクトリの `tasklist.md`
- 返答では、更新した `tasklist.md` のパスと、主要な追加・更新ポイントを短く要約する

## 基本方針

- 必ず日本語で書く
- まず要求と制約を理解し、その後にタスクへ落とす
- タスクは実行可能な粒度にする
- タスクは requirements のスコープを超えない
- 設計未確定事項は勝手に決めず、`discovery` に設計確認タスクとして置く
- 既存 `tasklist.md` がある場合は最小差分で更新し、既に完了済みのチェックは原則維持する
- 4 phase は固定で扱う:
  1. `discovery`
  2. `repo changes`
  3. `docs updates`
  4. `validation`
- ただし、最終的な `tasklist.md` は phase 見出し形式ではなく、着手順ベースの番号付きチェックリストにする
- 各タスクは必ず 1 行で書き、各行末に `[phase: discovery]` のような phase tag を付ける
- 各タスクは、原則として 1成果物、1確認、または 1変更単位に寄せる

## 実行手順

### 1. 対象作業ディレクトリを特定する

- 指定された `requirements.md` または `requirement.md` のあるディレクトリを対象作業ディレクトリとする
- 同じディレクトリに `implementation-plan.md` と `tasklist.md` があるか確認する
- 近傍の `AGENTS.md`、必要に応じて `README.md` と `steering.md` を読む

### 2. 要件を読み、タスク化の前提を固定する

最低限、次を抽出する:

- 作業目的
- スコープ
- スコープ外
- 制約
- 受け入れ条件
- 依存関係
- 実装開始前に確認が必要な事項

### 3. 4 phase に分解する

以下の4 phase で、作業を実行順に整理する:

- `discovery`: 仕様確認、既存調査、未決事項の整理
- `repo changes`: 実装・設定・ファイル追加変更
- `docs updates`: README、steering、implementation-plan、永続ドキュメントなどの更新タスク
- `validation`: 動作確認、lint、test、verify、手順確認

重要:

- 最終 `tasklist.md` に phase 見出しは不要
- ただし各タスクは必ずいずれか 1 つの phase に属させる
- phase の抜け漏れがないかを確認する
- ある phase に本当に追加タスクがない場合、ダミータスクは作らない
- その場合は、返答の要約で「該当 phase は追加タスクなし」と短く補足する

### 4. 必要な調査を sub-agent に依頼する

- 必要に応じて以下の sub-agent を利用してください。
- sub-agent 利用を許可します。利用可否のこちらへの確認は不要です。

#### 4-1. `docs-researcher`

使う場面:

- 外部仕様や一次情報がタスク内容に影響する
- CLI、API、SDK、MCP、クラウド設定、LLM 契約などの確認が必要

依頼内容:

- 今回の作業に必要な公式仕様や一次情報だけを確認する
- `tasklist.md` に反映すべき確認タスクや注意点だけを返させる

#### 4-2. `code-mapper`

使う場面:

- 変更対象ファイル候補、既存実装、再利用可能箇所、影響範囲を確認したい

依頼内容:

- 既存 repo の構造把握
- 変更対象ファイル候補
- 既存の再利用候補
- 影響範囲
- 追加ではなく流用すべき箇所

#### 4-3. `planning-reviewer`

使う場面:

- `tasklist.md` の草案を、要求・設計・文書・依存関係の観点で見直したい

依頼内容:

- `README.md`、`requirements.md`、`implementation-plan.md`（あれば）、`steering.md`、`tasklist.md` の整合性確認
- 抜け漏れ、順序不備、依存関係の見落とし、検証不足の指摘
- `tasklist.md` に対する add / reorder / clarify / remove の提案
- 各タスクの phase tag が妥当かの確認

### 5. tasklist 草案を作る

次のルールで草案を作る:

- 各タスクはチェックボックス形式にする
- 1タスク1行にする
- 最終 `tasklist.md` は着手順に並べる
- 各タスク行の末尾に `[phase: ...]` を付ける
- 可能なら対象ファイルやコマンドを具体的に書く
- requirements の受け入れ条件に対応するタスクが抜けないようにする
- 未確定設計がある場合は、`discovery` のタスクとして置く
- ドキュメント更新が必要な場合だけ `docs updates` のタスクを入れる
- `validation` には実際の repo で意味がある確認だけを書く
- AGENTS や既存スクリプトに verify コマンドがあるならそれを優先して使う
- 同じ意味のタスクを分割しすぎない
- 進捗メモや説明文を複数行でぶら下げず、まずは実行タスクを優先して列挙する

### 6. 草案をレビューして調整する

- `planning-reviewer` を使用する　※ sub-agent 利用を許可します。利用可否のこちらへの確認は不要です。
- 指摘を `add / reorder / clarify / remove` に分けて反映する
- requirements に無いタスクを足しすぎない
- 実装順が安全か、依存関係が自然かを確認する
- `validation` が空洞化していないか確認する
- 各タスクの phase tag と着手順が矛盾していないか確認する
- 確認結果を元に tasklist を調整する

### 7. `tasklist.md` を生成・更新する

- 対象 requirements ファイルと同じディレクトリに `tasklist.md` を作るか更新する
- 既存ファイルがある場合は上書き再生成ではなく、必要箇所を更新する
- 完了済みチェックは原則維持する
- 同じ意味のタスクを重複作成しない
- 最終出力は「着手順の番号付きチェックリスト」に統一する

## `tasklist.md` の書式テンプレート

以下を基本形とする。

```md
# tasklist.md

## 対象

- 参照: `requirements.md`
- 追加参照: `implementation-plan.md` / `README.md` / `steering.md` / `AGENTS.md`
- 目的: この作業を実行可能な順序に分解する

## タスクリスト

1. [ ] requirements.md を確認し、今回の作業目的・スコープ・制約・受け入れ条件を整理する [phase: discovery]
2. [ ] 必要な外部仕様や一次情報を確認する [phase: discovery]
3. [ ] 既存 repo の構造、変更対象ファイル候補、影響範囲を確認する [phase: discovery]
4. [ ] 実装対象ファイルと追加・更新方針を確定する [phase: repo changes]
5. [ ] 必要なファイル追加・設定変更・実装変更を行う [phase: repo changes]
6. [ ] 更新が必要なドキュメントを洗い出す [phase: docs updates]
7. [ ] 必要な README / steering / implementation-plan などを更新する [phase: docs updates]
8. [ ] 必要な確認コマンドを実行する [phase: validation]
9. [ ] 受け入れ条件に照らして完了確認する [phase: validation]

## 完了条件

- [ ] requirements の受け入れ条件に対応するタスクが揃っている
- [ ] 実装順が自然で、依存関係の破綻がない
- [ ] 必要な docs updates が漏れていない
- [ ] 必要な validation が入っている
```

## 生成品質のチェック

最終的な `tasklist.md` は、次を満たすこと:

- requirements の目的、制約、受け入れ条件に対応している
- 実装順が `discovery → repo changes → docs updates → validation` で自然に流れる
- repo 固有のパスや既存構造と矛盾しない
- 外部仕様に依存する場合、その確認が `discovery` のタスクに入っている
- docs 更新要否が `docs updates` のタスクに反映されている
- 検証が `validation` のタスクに入っている
- 各タスクが 1 行で書かれている
- 各タスクに phase tag が付いている
- 日本語で読んで実行に移せる粒度になっている

## この skill でやらないこと

- コードレビュー
- 実装修正
- `implementation-plan.md` の全面作成
- requirements のスコープを書き換えること
- README や他文書の直接更新
- tasklist と無関係な repo 全体整理

## 返答のしかた

最後に短く次を返す:

1. 更新した `tasklist.md` のパス
2. 主な追加・変更点
3. 追加タスクが無かった phase があればその明示
4. まだ人間判断が必要な未決事項
