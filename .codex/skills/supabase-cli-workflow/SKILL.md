---
name: supabase-cli-workflow
description: Supabase CLI を使って、ローカル開発、project link、migration、型生成の手順を整理して実行する
---

## 目的

- Supabase 周りの作業を、Web UI ではなく CLI 中心で再現可能にする。
- ローカル開発、migration、型生成の流れを標準化する。

## いつ使うか

- ローカルで Supabase を立ち上げたいとき。
- project link や migration を扱いたいとき。
- 型生成や schema 反映をしたいとき。

## 前提

- `supabase` CLI が使えること。
- 認証や link に必要な token / project ref は、ログに出さない。

## 手順

1. `supabase --version` で CLI を確認する
2. ローカル開発なら `supabase start` / `supabase status` を使う
3. project 連携が必要なら `supabase login` と `supabase link` を使う
4. schema 変更時は migration 系コマンドを使う
5. 型生成が必要なら対象言語向けの generate コマンドを使う
6. 生成物や差分を確認し、必要なら `$verify-fast` / `$verify-full` に進む

## 運用ルール

- token や DB 接続情報を出力しない。
- migration や generated file は、差分を確認してから commit する。
- 破壊的な DB 操作は、ローカルか対象環境を明示してから行う。

## 出力

- 実行した CLI コマンド
- 生成/更新されたファイル
- 次に必要な検証

## 完了条件

- 対象の Supabase workflow が CLI で再現できる。
- 秘密情報を出さずに、差分と次工程を説明できる。
