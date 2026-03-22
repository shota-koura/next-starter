---
name: api-add-design
description: 新規 API 追加の前に、外部仕様確認、契約設計、実装方針整理を行う
---

## 目的

- 新しい API を、既存クライアントや将来拡張を意識した契約として設計する。
- 実装前に request/response、validation、error model を固める。

## いつ使うか

- 新しい endpoint や mutation を追加するとき。
- 外部 API 連携や SDK ラッパーの新規導入前に契約を決めたいとき。

## 手順

1. 必要なら一次情報で仕様や制約を確認する
2. 追加する API の利用者、責務境界、入出力を整理する
3. success/failure の canonical response を決める
4. validation、auth、idempotency、pagination など必要な契約要素を確認する
5. 実装方針と review 観点を短くまとめる

## Subagent 利用方針

- sub-agent 利用が明示的に許可されている場合のみ、次を推奨する。
- 仕様確認が必要なら `docs-researcher` を使う。
- 契約設計には `api-designer` を使う。
- 実装に進む場合、バックエンド局所の追加は `backend-developer` を使う。
- 実装後のリスク確認には `reviewer` を使う。

## 出力

- 追加する API の目的
- request/response 概要
- error/validation 方針
- 実装に進む前の未決事項

## 完了条件

- 契約の主要要素が文章で説明できる。
- 実装前に決めるべき未解決点が明確になっている。
