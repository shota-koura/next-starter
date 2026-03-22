---
name: change-review
description: ローカル差分に対して、codex-reviewer sub-agent を使って正しさ・回帰・テスト不足・契約破壊・セキュリティの観点で事前レビューし、親エージェントが結果を正規化して提示する
---

## 目的

- PR 前や push 前に、ローカル差分のリスクを先に洗う。
- style 指摘ではなく、ユーザー影響や運用影響のある問題を優先する。
- `codex-reviewer` sub-agent を必ず使い、親エージェントはその結果を回収して統一フォーマットで提示する。
- finding がある場合は修正へ進まず、番号付き一覧を提示してユーザーが対応番号を選ぶまで停止する。

## いつ使うか

- 実装後にローカル差分を一度点検したいとき。
- `$pr-flow` の前に、主要な懸念を減らしたいとき。
- `coderabbit-pre-review` の結果に加えて、Codex reviewer のレビューもローカルで入れたいとき。
- 大きめの変更で見落としが不安なとき。
- `coderabbit` CLI を使わず、人間または Codex の観点で差分を点検したいとき。

## 観点

- 回帰
- テスト不足
- 契約破壊
- セキュリティ

## 手順

1. `git status -sb` と `git diff --stat` でレビュー対象を把握する
2. 変更の主経路を短く要約する
3. `codex-reviewer` sub-agent を起動し、上記 4 観点でレビューさせる
4. 親エージェントが `codex-reviewer` の結果を回収し、重複や表現揺れを整理する
5. finding を統一フォーマットへ正規化して提示する
6. finding が 1 件でもあれば修正へ進まず、ユーザーに「対応する番号」を確認して停止する
7. 指示された番号だけを修正し、必要なら再度この skill を実行する

## `coderabbit-pre-review` との違い

- `coderabbit-pre-review` は CodeRabbit CLI を使った事前レビュー。
- この skill は `codex-reviewer` sub-agent を使った Codex 観点のローカル差分レビュー。
- 通常は `coderabbit-pre-review` の後に使い、CLI と `codex-reviewer` の観点を並べて確認する。

## Subagent 利用方針

- この skill は `codex-reviewer` sub-agent の実行を前提にする。
- `codex-reviewer` が利用できない環境では停止し、「この運用では codex-reviewer が必要」と明示する。
- 親エージェントは `codex-reviewer` の結果を回収して要約・正規化するが、ユーザー指示前に修正実装へ進まない。

## 出力

- 対象差分の短い要約
- `codex-reviewer` の結果を正規化した finding 一覧
- 追加で必要な検証
- finding が無い場合は、その旨と残る未確認点

提示形式は `coderabbit-pre-review` と揃えて、次を使う。

```text
- No.:
- ソース: codex-reviewer
- 懸念レベル: P0|P1|P2
- レビュータイトル:
- レビュー内容:
- 参照:
- 解釈:
- 対応方針: 対応推奨|条件付き対応|見送り可
```

finding がある場合の締め方は次を基準にする。

```text
- 対応する番号を指定してください。
- 指定された番号だけを修正します。
```

finding が無い場合の出力は次を基準にする。

```text
Codex reviewer の結果を整理しました。

- finding はありませんでした。
- 残る未確認点:
  - 追加の実機確認が必要か
  - CI 外の運用導線に影響がないか
```

## 完了条件

- `codex-reviewer` sub-agent の結果を親エージェントが回収できている。
- finding がある場合、影響と根拠が説明できる。
- finding が無い場合も、残るリスクと未確認点を短く述べられる。
