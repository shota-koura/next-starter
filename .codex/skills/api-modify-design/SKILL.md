---
name: api-modify-design
description: 既存 API 変更の前に、外部仕様確認、互換性整理、影響範囲把握、実装方針整理を行う
---

## 目的

- 既存 API の変更を、互換性と移行影響を見ながら安全に進める。
- 既存利用箇所を把握し、契約破壊を避ける。

## いつ使うか

- request/response shape や semantics を変更するとき。
- field の追加、削除、rename、optional/nullability 変更をするとき。
- 既存 endpoint の auth、validation、error behavior を見直すとき。

## 手順

1. 必要なら一次情報や外部制約を確認する
2. 既存 API の利用者と互換性要件を整理する
3. 既存利用箇所や依存経路を把握する
4. 変更後の契約と migration path を整理する
5. 実装方針と review 観点を短くまとめる

## Subagent 利用方針

- sub-agent 利用が明示的に許可されている場合のみ、次を推奨する。
- 仕様確認が必要なら `docs-researcher` を使う。
- 契約変更の整理には `api-designer` を使う。
- 既存利用箇所や影響経路の把握には `code-mapper` を使う。
- 実装に進む場合、バックエンド局所の変更は `backend-developer` を使う。
- 実装後のリスク確認には `codex-reviewer` を使う。

## 出力

- 変更対象 API と変更理由
- 互換性リスク
- migration path
- 影響を受ける主な利用箇所

## 完了条件

- 互換性影響と migration 方針が説明できる。
- 主要な利用箇所や downstream 影響が把握できている。
