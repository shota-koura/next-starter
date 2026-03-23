---
name: implementation-plan-generator
description: >-
  requirements.md または requirement.md を読み、同じディレクトリの implementation-plan.md を
  実装方針・変更対象・影響範囲・検証方針・未決事項の観点で生成または更新する skill。
  使う場面: tasklist 作成前に今回どう作るかを整理したいとき、API/LLM/インフラ/既存構造への影響を踏まえた実装計画が必要なとき。
  使わない場面: 単なる進捗更新だけをしたいとき、コード実装そのものが目的のとき、要件がまだ曖昧で前提整理が先のとき。
---

# implementation-plan-generator

## この skill の役割

この skill の仕事は、対象作業の要求定義を読み、今回の作業用 `implementation-plan.md` を作ることです。  
`implementation-plan.md` の生成・更新に集中し、それ以外のドキュメントやコードは原則として直接変更しません。  
この skill は `implementation-plan.md` の生成・更新までを対象とします。`tasklist.md` は別途 `tasklist-generator` の責務です。

この skill は、UI設計書を作るものではありません。  
役割は、今回の作業について「どう実装するか」「どこに影響するか」「何が未決か」を整理することです。

## 入力

必須:

- 対象の `requirements.md` または `requirement.md` のパス

任意:

- 同じディレクトリの既存 `implementation-plan.md`
- `docs/development/.steering/steering.md`
- リポジトリの `README.md`
- 近傍の `AGENTS.md`
- 関連する永続ドキュメント

## 出力

- 対象 requirements ファイルと同じディレクトリの `implementation-plan.md`
- 返答では、更新した `implementation-plan.md` のパスと、主要な追加・更新ポイントを短く要約する

## 基本方針

- 必ず日本語で書く
- まず要求と制約を理解し、その後に実装方針へ落とす
- plan は requirements のスコープを超えない
- 未確定事項は勝手に決めず、`未決事項` に明示する
- 既存 `implementation-plan.md` がある場合は最小差分で更新し、既に確定済みの判断は根拠なく崩さない
- plan は「今回の変更に必要な設計判断」に集中し、一般論の長い説明にしない
- 1項目1論点を基本とし、長文の散文ではなく短い箇条書きを優先する
- 実装が小さくても、明示的にこの skill が呼ばれた場合は、簡潔でもよいので `implementation-plan.md` を生成または更新する

## 実行手順

### 1. 対象作業ディレクトリを特定する

- 指定された `requirements.md` または `requirement.md` のあるディレクトリを対象作業ディレクトリとする
- 同じディレクトリに `implementation-plan.md` と `tasklist.md` があるか確認する
- 近傍の `AGENTS.md`、必要に応じて `README.md` と `steering.md` を読む

### 2. 要件を読み、実装計画の前提を固定する

最低限、次を抽出する:

- 作業目的
- スコープ
- スコープ外
- 制約
- 受け入れ条件
- 依存関係
- 実装開始前に確認が必要な事項

### 3. 今回の plan で扱う観点を決める

requirements を読み、今回どの観点の plan が必要かを判断する。  
必要な観点だけを扱うこと。

候補:

- 既存 repo 構造と変更対象
- API / 契約 / request-response
- データ / 状態 / DB / Storage
- LLM / prompt / schema / tool / eval
- インフラ / secrets / runtime / deploy
- ドキュメント更新
- 検証方針
- 未決事項と人間判断が必要な論点

不要な観点を無理に見出し化しないこと。

### 4. 必要な調査を sub-agent に依頼する

- 必要に応じて以下の sub-agent を利用してください。
- sub-agent 利用を許可します。利用可否のこちらへの確認は不要です。
- sub-agent は自動では起動しない前提で、必要な場合のみ明示的に依頼してください。
- 役割が既に明確なので、通常は `multi-agent-coordinator` や `workflow-orchestrator` は使わなくてよいです。

#### 4-1. `docs-researcher`

使う場面:

- 外部仕様や一次情報が実装方針に影響する
- CLI、API、SDK、MCP、フレームワーク挙動、LLM API、設定値の既定動作などの確認が必要

依頼内容:

- 今回の作業に必要な公式仕様や一次情報だけを確認する
- `implementation-plan.md` に反映すべき確認結果、制約、注意点だけを返させる

#### 4-2. `code-mapper`

使う場面:

- 変更対象ファイル候補、既存実装、再利用可能箇所、影響範囲を確認したい

依頼内容:

- 既存 repo の構造把握
- 変更対象ファイル候補
- 既存の再利用候補
- 影響範囲
- 追加ではなく流用すべき箇所
- 実装境界や所有パスの把握

#### 4-3. `api-designer`

使う場面:

- API、Edge Function、入出力契約、JSON Schema、互換性、移行方針の整理が必要

依頼内容:

- 今回必要な API / function / contract の設計方針
- request / response / validation / error model の観点
- 互換性、migration、client 影響
- 実装前に固定すべき契約判断

#### 4-4. `llm-architect`

使う場面:

- prompt、tool use、retrieval、structured output、eval、latency/cost tradeoff などの整理が必要

依頼内容:

- 現在または予定している LLM workflow の要点
- 主要な failure surface
- 構造化出力、schema、tool/retrieval 契約の整理
- 実装前に固定すべき LLM 設計判断
- 検証方針や eval 観点

#### 4-5. `cloud-architect`

使う場面:

- compute、storage、network、runtime、secrets、可用性、運用境界が plan に影響する

依頼内容:

- 対象となる operational boundary
- 最小安全構成
- secrets / exposure / rollback / runtime dependency の注意点
- live environment でしか検証できない事項

#### 4-6. `planning-reviewer`

使う場面:

- `implementation-plan.md` の草案を、要求・文書・依存関係・検証方針の観点で見直したい

依頼内容:

- `README.md`、`requirements.md`、既存 `implementation-plan.md`、`steering.md`、`AGENTS.md` の整合性確認
- 抜け漏れ、順序不備、依存関係の見落とし、検証不足、過剰設計の指摘
- `implementation-plan.md` に対する add / reorder / clarify / remove の提案

### 5. 初稿を作る

次のルールで `implementation-plan.md` 草案を作る:

- requirements の受け入れ条件に対応する実装方針が抜けないようにする
- repo 固有の変更対象を曖昧にしない
- 外部仕様や契約に依存する部分は、確認済み事実と未確認事項を分ける
- 必要な文書更新があれば plan に含める
- 必要な検証方針を plan に含める
- 実装タスクの列挙ではなく、「どう作るか」「どこに影響するか」「何を先に固めるか」に集中する
- requirements に無い機能追加や拡張前提を勝手に足さない
- まだ決められないことは `未決事項` に残す

### 6. 初稿をレビューして調整する

- `planning-reviewer` を使用する  
  ※ sub-agent 利用を許可します。利用可否のこちらへの確認は不要です。
- 指摘を `add / reorder / clarify / remove` に分けて反映する
- requirements に無い設計を足しすぎない
- 変更対象、契約、検証、ドキュメント更新の抜け漏れがないか確認する
- 「実装計画」ではなく「仕様再説明」になっていないか確認する
- 確認結果を元に `implementation-plan.md` を調整する

### 7. `implementation-plan.md` を生成・更新する

- 対象 requirements ファイルと同じディレクトリに `implementation-plan.md` を作るか更新する
- 既存ファイルがある場合は上書き再生成ではなく、必要箇所を更新する
- 同じ意味の判断を重複記載しない
- 書式は短い見出しと箇条書きを優先し、長い散文を避ける

## `implementation-plan.md` の書式テンプレート

以下を基本形とする。  
ただし、今回の作業に不要な見出しは省略してよい。

```md
# implementation-plan.md

## 対象

- 参照: `requirements.md`
- 追加参照: `README.md` / `AGENTS.md` / `steering.md` / 既存 `implementation-plan.md`
- 目的: requirements を今回の実装方針に落とし込む

## 要件要約

- 今回の作業目的:
- スコープ:
- スコープ外:
- 制約:
- 受け入れ条件:

## 実装方針

- 今回の変更をどう実装するかの要点
- 先に確定すべき設計判断
- 既存実装を再利用する方針
- 新規追加が必要な箇所

## 変更対象

- 主な変更対象ファイル候補:
- 変更対象の責務:
- 影響範囲:
- 触らない範囲:

## 契約・仕様確認

- 外部仕様や一次情報に基づく前提
- API / function / schema / config で固定すべき事項
- 既定値や caveat
- 未確認で runtime 検証が必要な事項

## 実装詳細方針

### API / Contract

- 必要な場合のみ記載

### Data / Storage / State

- 必要な場合のみ記載

### LLM / Prompt / Schema / Eval

- 必要な場合のみ記載

### Cloud / Secrets / Runtime

- 必要な場合のみ記載

## ドキュメント更新方針

- 更新が必要なドキュメント
- 更新理由
- 更新しないドキュメント

## 検証方針

- 実装後に最低限確認すべき内容
- 実行すべきコマンドや check
- 手元で確認できること
- 環境依存で別途確認が必要なこと

## 未決事項

- 人間判断が必要な事項
- 仕様未確定事項
- 後続の tasklist 生成前に確定したいこと
```

## 生成品質のチェック

最終的な `implementation-plan.md` は、次を満たすこと:

- requirements の目的、制約、受け入れ条件に対応している
- plan が「どう実装するか」に寄っており、単なる要件再掲になっていない
- repo 固有の変更対象や影響範囲と矛盾しない
- 外部仕様に依存する場合、その確認結果または未確認事項が明記されている
- API / LLM / Cloud など relevant な観点だけが含まれている
- 不要な観点を無理に膨らませていない
- 必要な docs 更新方針が入っている
- 検証方針が入っている
- 未決事項が明確に残されている
- 日本語で読んで、そのまま `tasklist-generator` の入力に使える粒度になっている

## この skill でやらないこと

- コードレビュー
- 実装修正
- `tasklist.md` の生成・更新
- requirements のスコープを書き換えること
- README や他文書の直接更新
- tasklist と同じ粒度の実行タスク列挙
- 無関係な repo 全体整理
- 必要のない sub-agent の多重起動

## 返答のしかた

最後に短く次を返す:

1. 更新した `implementation-plan.md` のパス
2. 主な追加・変更点
3. 使用した sub-agent と、その反映先
4. まだ人間判断が必要な未決事項
