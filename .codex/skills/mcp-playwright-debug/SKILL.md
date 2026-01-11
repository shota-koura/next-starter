---
name: mcp-playwright-debug
description: MCPの playwright を使ってUIの再現、スクリーンショット、console/networkログを収集し、原因切り分けに使う
---

## 目的

- UI バグ/回帰/表示崩れを、再現手順と証拠（スクショ・ログ）付きで切り分ける。
- 修正後の再現テストにも使う。

## いつ使うか

- UI の挙動が想定と違う、または再現が難しいとき。
- console error / network error が疑わしいとき。
- PR にスクショを添付したいとき。

## 前提

- 対象環境（例: `npm run dev`）が起動していること。
- 既定URLの例:
  - Frontend: `http://localhost:3000`
  - Backend: `http://localhost:8000`

## 実行手順（例）

1. 新規タブ/ページを開く → 対象URLへ遷移
2. 再現手順を最小ステップで実行（クリック、入力など）
3. `browser_take_screenshot` / `browser_snapshot` で証拠を残す
4. `browser_console_messages` と `browser_network_requests` を取得して要点を整理する
5. 修正後、同じ手順で再実行し、改善したことを確認する

## 収集するもの（最小）

- スクリーンショット（崩れ/エラーが見える状態）
- console error/warn の要点
- network の失敗（status、該当API、エラー内容の要点）

## 注意

- ログに秘密情報が含まれないようにする（Authorization header 等）。
- 収集した情報は要点だけを出し、全文貼り付けは避ける。
