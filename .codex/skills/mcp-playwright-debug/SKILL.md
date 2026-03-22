---
name: mcp-playwright-debug
description: MCPの playwright を使ってUIの再現、スクリーンショット、console/networkログを収集し、原因切り分けに使う
---

## 目的

- UI バグ/回帰/表示崩れを、再現手順と証拠（スクショ・ログ）付きで切り分ける。
- 修正後の再現テストにも使う。
- 調査、実装、レビューを 1 つの skill に混ぜず、UI デバッグの入口として使う。

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
5. 関連コード経路が曖昧なら、影響範囲を絞る
6. 原因仮説を整理する
7. 修正後、同じ手順で再実行し、改善したことを確認する

## Subagent 利用方針

- sub-agent 利用が明示的に許可されている場合のみ、次を推奨する。
- 関連コード経路が曖昧なら `code-mapper` を使い、UI 操作から API・状態更新までの owning path を絞る。
- 原因が未確定なら `debugger` を使い、console/network の証拠とコード経路を突き合わせて仮説を絞る。
- 修正が UI/API 跨ぎになる場合のみ `fullstack-developer` を使う。
- sub-agent を使わない場合も、同じ順序で親エージェントが進める。

## 収集するもの（最小）

- スクリーンショット（崩れ/エラーが見える状態）
- console error/warn の要点
- network の失敗（status、該当API、エラー内容の要点）

## 注意

- ログに秘密情報が含まれないようにする（Authorization header 等）。
- 収集した情報は要点だけを出し、全文貼り付けは避ける。
- `debugger` を先頭固定にしない。証拠収集の後、必要なら経路把握を挟んでから原因究明に入る。
- 対話的な再現や証拠収集は MCP を優先してよい。修正後の決定的な再実行や trace 保存は `playwright` CLI / `npx playwright` を併用してよい。
