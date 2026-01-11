---
name: mcp-chrome-devtools-perf
description: MCPの chrome-devtools を使って、パフォーマンス計測（trace/insight）と console/network 収集を行い、改善ポイントを特定する
---

## 目的

- “体感が遅い” を、計測（trace/insight）で根拠づける。
- 修正前後で改善したことを示せる状態にする。

## いつ使うか

- 初回表示が遅い、操作が重い、レイアウトシフトがある等が疑われるとき。
- PR で「どこがボトルネックか」を短く説明したいとき。

## 実行手順（概略）

1. `new_page` → `Maps_page` で対象URLへ
2. `performance_start_trace`
3. 問題が出る操作（再現手順）を実行（click/scroll/input 等）
4. `performance_stop_trace`
5. `performance_analyze_insight` で要点を得る
6. 必要なら `get_console_message` / `list_console_messages`、`list_network_requests` を併用
7. スクショ（`take_screenshot`）も合わせて残す

## 注意

- 計測ログに秘密情報が混ざらないようにする（URLパラメータ、Authorization 等）。
- 結果は「今回の修正方針に必要な要点」だけ出す（全文貼り付けは避ける）。
