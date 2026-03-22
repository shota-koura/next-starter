---
name: vercel-cli-workflow
description: Vercel CLI を使って、project link、env pull、deploy、inspect の手順を整理して実行する
---

## 目的

- Vercel 周りの作業を CLI で再現可能にする。
- env pull や deploy 状態確認を、最小差分で進める。

## いつ使うか

- Vercel project を link したいとき。
- 環境変数を pull したいとき。
- preview / production deploy の状態を確認したいとき。

## 前提

- `vercel` CLI が使えること。
- 認証や環境変数の内容をログに出さない。

## 手順

1. `vercel --version` で CLI を確認する
2. project 未連携なら `vercel link` を使う
3. env が必要なら `vercel env pull` を使う
4. deploy が必要なら `vercel` または `vercel deploy` を使う
5. 状態確認や URL 確認には inspect 系コマンドを使う
6. 変更がコードや設定に及ぶ場合は検証に進む

## 運用ルール

- `.env` 系ファイルは commit しない。
- deploy の前に対象環境を明示する。
- CLI 出力の URL や識別子は必要最小限だけ共有する。

## 出力

- 実行した CLI コマンド
- link / env / deploy の結果要約
- 次に必要な検証や確認

## 完了条件

- 対象の Vercel workflow が CLI で再現できる。
- 環境変数や秘密情報を出さずに結果を説明できる。
