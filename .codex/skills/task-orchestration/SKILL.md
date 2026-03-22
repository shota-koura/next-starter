---
name: task-orchestration
description: 多段階タスクや複数 agent を伴う作業の工程設計と分担整理を行う
---

## 目的

- 大きめタスクを、発見、実装、検証、統合の段階に分けて進めやすくする。
- 依存関係や待機点を明確にし、無駄な並列化や競合を避ける。

## いつ使うか

- 3 工程以上あるタスク。
- 3 agent 以上を使いそうなタスク。
- 依存関係や統合順が曖昧なタスク。

## 運用

- この skill は implicit より explicit 実行を推奨する。
- 小さな単発修正では使わない。

## 手順

1. 目的を discovery / implementation / validation / integration に分ける
2. どこが critical path かを決める
3. 並列にできる作業と待機点を整理する
4. 各工程の完了条件を決める
5. 必要なら agent への分担案をまとめる

## Subagent 利用方針

- sub-agent 利用が明示的に許可されている場合のみ、次を推奨する。
- 工程分解には `workflow-orchestrator` を使う。
- agent ごとの ownership、依存、統合条件の整理には `multi-agent-coordinator` を使う。
- この skill 自体は段取り設計が主目的であり、個別実装は別 skill に委ねる。

## 出力

- 段階ごとの作業一覧
- critical path
- 並列化できる作業
- 待機点と統合条件

## 完了条件

- 次に何をどの順で進めるか説明できる。
- 並列化してよい範囲と、統合時の注意点が整理できている。
