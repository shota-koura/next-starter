---
name: change-review
description: ローカル差分に対して、正しさ・回帰・テスト不足・契約破壊・セキュリティの観点で事前レビューし、sub-agent 利用が許可されていれば reviewer を使う
---

## 目的

- PR 前や push 前に、ローカル差分のリスクを先に洗う。
- style 指摘ではなく、ユーザー影響や運用影響のある問題を優先する。
- sub-agent 利用が許可されている場合は `reviewer` を使い、許可されていない場合も同じ観点で親エージェントがレビューする。

## いつ使うか

- 実装後にローカル差分を一度点検したいとき。
- `$pr-flow` の前に、主要な懸念を減らしたいとき。
- `coderabbit-pre-review` の結果に加えて、Codex 観点のレビューもローカルで入れたいとき。
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
3. sub-agent 利用が許可されている場合は `reviewer` を使い、許可されていない場合は親エージェントが同じ観点でレビューする
4. 上記 4 観点で blocking issue を先に洗う
5. 必要なら追加テストや追加確認だけを提案する

## `coderabbit-pre-review` との違い

- `coderabbit-pre-review` は CodeRabbit CLI を使った事前レビュー。
- この skill は Codex 観点のローカル差分レビュー。
- 通常は `coderabbit-pre-review` の後に使い、CLI と reviewer の観点を並べて確認する。

## Subagent 利用方針

- sub-agent 利用が明示的に許可されている場合のみ、`reviewer` を使う。
- sub-agent を使わない場合も、同じ 4 観点で親エージェントがレビューする。
- この skill はレビュー専用であり、修正実装までは含めない。

## 出力

- 対象差分の短い要約
- 重大度順の finding 一覧
- 追加で必要な検証
- finding が無い場合は、その旨と残る未確認点

## 完了条件

- finding がある場合、影響と根拠が説明できる。
- finding が無い場合も、残るリスクと未確認点を短く述べられる。
