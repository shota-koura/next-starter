---
name: mcp-serena-refactor
description: MCPの serena を使って、シンボル参照を追跡しながら安全にリファクタ（rename/置換/参照確認）する
---

## 目的

- “検索置換の事故” を避け、シンボル単位で安全にリファクタする。
- 影響範囲を把握し、差分を最小化する。

## いつ使うか

- 関数/クラス/変数の rename が必要なとき。
- 参照箇所が多い変更（型変更、引数追加など）をするとき。
- “どこから呼ばれているか” を正確に洗い出したいとき。

## 推奨フロー

1. `activate_project` で対象リポジトリをアクティブ化する
2. `find_symbol` / `get_symbols_overview` で対象シンボルを特定する
3. `find_referencing_symbols` で参照元を確認し、変更の影響範囲を把握する
4. 変更内容に応じて:
   - rename: `rename_symbol`
   - 本体置換: `replace_symbol_body`
   - 周辺の追記: `insert_before_symbol` / `insert_after_symbol`
5. `search_for_pattern` で置き忘れや不整合がないか確認する
6. `$verify-fast` → `$verify-full` で回帰がないか確認する

## 運用ルール

- まず “影響範囲の把握” をしてから変更する（いきなりrenameしない）。
- 大規模renameは避け、必要なら分割する。
- メモリ機能（read/write_memory）を使う場合:
  - 秘密情報は保存しない
  - プロジェクト固有の決め事（API契約、命名規則など）に限定する

## 完了条件

- 参照切れがない（typecheck/lint/test が通る）
- 無関係差分が増えていない
