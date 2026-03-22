---
name: mcp-serena-refactor
description: MCPの serena を使って、シンボル参照を追跡しながら安全にリファクタ（rename/置換/参照確認）する
---

## 目的

- “検索置換の事故” を避け、シンボル単位で安全にリファクタする。
- 影響範囲を把握し、差分を最小化する。
- 振る舞いを変えずに構造改善する作業を標準化する。

## いつ使うか

- 関数/クラス/変数の rename が必要なとき。
- 参照箇所が多い変更（型変更、引数追加など）をするとき。
- “どこから呼ばれているか” を正確に洗い出したいとき。
- 仕様変更ではなく、構造改善や命名整理をしたいとき。

## 推奨フロー

1. まず影響範囲と owning path を把握する
2. `activate_project` で対象リポジトリをアクティブ化する
3. `find_symbol` / `get_symbols_overview` で対象シンボルを特定する
4. `find_referencing_symbols` で参照元を確認し、変更の影響範囲を把握する
5. 変更内容に応じて:
   - rename: `rename_symbol`
   - 本体置換: `replace_symbol_body`
   - 周辺の追記: `insert_before_symbol` / `insert_after_symbol`
6. `search_for_pattern` で置き忘れや不整合がないか確認する
7. `$verify-fast` → `$verify-full` で回帰がないか確認する

## Subagent 利用方針

- sub-agent 利用が明示的に許可されている場合のみ、次を推奨する。
- 変更経路や所有境界が曖昧なら `code-mapper` を先に使う。
- 構造改善そのものは `refactoring-specialist` を使う。
- 変更後の回帰リスク確認には `reviewer` を使う。
- 新機能追加や仕様変更が主目的なら、この skill ではなく別 skill を使う。

## 運用ルール

- まず “影響範囲の把握” をしてから変更する（いきなりrenameしない）。
- 大規模renameは避け、必要なら分割する。
- 振る舞い非変更が前提。仕様変更や新機能追加を混ぜない。
- メモリ機能（read/write_memory）を使う場合:
  - 秘密情報は保存しない
  - プロジェクト固有の決め事（API契約、命名規則など）に限定する

## 完了条件

- 参照切れがない（typecheck/lint/test が通る）
- 無関係差分が増えていない
