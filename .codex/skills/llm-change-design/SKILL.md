---
name: llm-change-design
description: LLM 機能変更の前に、仕様確認、ワークフロー設計、実装影響整理を行う
---

## 目的

- prompt 変更、tool 利用、retrieval、structured output、eval 変更を、運用影響まで見て整理する。
- 設計変更だけで済むか、実装変更が必要かを切り分ける。

## いつ使うか

- LLM の応答品質、tool 利用、評価導線を見直したいとき。
- モデル変更、prompt upgrade、retrieval 変更、schema 変更を検討するとき。

## 手順

1. 必要なら一次情報でモデル機能や制約を確認する
2. 現在の LLM workflow を、入力から出力まで短く整理する
3. 主要な failure surface を洗い出す
4. 変更が設計だけで済むか、backend や frontend 実装を伴うかを切り分ける
5. eval、コスト、遅延影響を短くまとめる

## Subagent 利用方針

- sub-agent 利用を明示的に許可します。必要に応じて以下sub-agentを利用してください。
- 仕様確認が必要なら `docs-researcher` を使う。
- LLM workflow 設計には `llm-architect` を使う。
- 実装影響の経路把握には `code-mapper` を使う。
- backend 実装が必要なら `backend-developer` を使う。
- UI/API 跨ぎの変更が必要なら `fullstack-developer` を使う。
- 実装後のリスク確認には `codex-reviewer` を使う。

## 出力

- 設計だけで済むか
- backend 実装が必要か
- frontend 変更が必要か
- eval 追加が必要か
- コスト/遅延影響

## 完了条件

- 次工程が設計、backend 実装、fullstack 実装のどれか判断できる。
- quality/cost/latency の主要トレードオフが説明できる。
