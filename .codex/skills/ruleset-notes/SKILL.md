---
name: ruleset-notes
description: GitHub Ruleset（required checks）運用の注意点と、CodeRabbitを必須チェックに入れるときのよくある詰まりどころを短くまとめる
---

## 目的

- required checks の候補が出ない等の “よくある詰まり” をすぐ解消する。

## 要点

- required checks の候補が出ない場合:
  - 対象チェックが「1回以上」実行されていない可能性が高い
  - 先に PR を作って CI / CodeRabbit を走らせてから Ruleset を設定する

- CodeRabbit を required checks にしたい場合:
  - 先に PR を作って CodeRabbit のレビュー/ステータスを発生させる
  - その後、Ruleset の `Require status checks to pass` に追加する

- CodeRabbit 側で commit status を出すには:
  - `.coderabbit.yaml` の `reviews.commit_status` が有効である必要がある（設定変更時は注意）

## 注意

- Ruleset / CI / CodeRabbit の設定変更は影響が大きいので、原則「事前確認が必要な変更」として扱う。
