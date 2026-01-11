---
name: dedupe
description: 既存実装の見落としによる重複（関数/型/スキーマ/ユーティリティ）を防ぐために、repository-structure参照とrg検索で統合方針を決める
---

## 目的

- 既存実装の見落としによる「同じような関数/型/スキーマ/ユーティリティの増殖」を防ぐ。
- 追加前に ripgrep (`rg`) で横断検索し、追記/統合を優先する。
- 作業着手前に `docs/repository-structure.md` を参照して配置候補を把握し、重複探索の精度を上げる。

## いつ使うか

- 新しい関数/型/スキーマ/コンポーネント/ユーティリティを追加する前（必須）。
- 「どこに置くべきか」「既に似たものがありそう」と感じたとき。
- 新規ファイル/ディレクトリを作る前（配置ミス＆重複を避ける）。

## 前提

- `rg` が利用できること（`rg --version`）。
- リポジトリ root で実行する。
- `docs/repository-structure.md` が存在し、必要に応じて `bash scripts/tree.sh` で更新できること。
  - `tree` は `scripts/codex-setup.sh` により利用可能になっている想定。

## 入力

- 追加しようとしている「概念名」「関数名」「型名」「スキーマ名」「コンポーネント名」などのキーワード。
- 迷う場合は 2〜3 個に絞る（例: `Invoice`, `invoice`, `Billing` のような言い換えは増やさず、既存で使われている語を優先）。

## 実行手順

### 0) リポジトリ構造の参照（必須）

作業開始前に `docs/repository-structure.md` を参照して、置き場所の当たりを付ける。

```bash
sed -n '1,200p' docs/repository-structure.md
```

構造変更（新規/移動/改名/削除）を伴う作業のときは、最初に更新してから参照してよい（同じならdiffは出ない）。

```bash
bash scripts/tree.sh
git diff -- docs/repository-structure.md
```

### 1) 追加前の探索（必須）

まず “完全一致に近い” 文字列で探す（型名/関数名/コンポーネント名は大小区別が効くのでそのまま入れる）。

- 全体検索:

```bash
rg -n "Keyword" .
```

- TypeScript/TSXに絞る:

```bash
rg -n -S "Keyword" -g'*.ts' -g'*.tsx'
```

- Pythonに絞る:

```bash
rg -n -S "keyword" -g'*.py'
```

- export / 型 / interface を探すヒント:

```bash
rg -n -S "export (type|interface|class|function) Keyword" -g'*.ts' -g'*.tsx'
rg -n -S "type Keyword\\b|interface Keyword\\b|class Keyword\\b|function Keyword\\b" -g'*.ts' -g'*.tsx'
```

- Zodスキーマ想定のヒント:

```bash
rg -n -S "KeywordSchema\\b" -g'*.ts' -g'*.tsx'
rg -n -S "z\\.object\\(" -g'*.ts' -g'*.tsx'
```

- ファイル名も探す（`rg` は中身検索なので別途）:

```bash
find . -type f -iname '*keyword*'
```

### 2) 結果の分類（方針決定）

- 既に同等機能がある:
  - 新規作成しない。既存を拡張（追記）する。
  - 呼び出し側を既存へ寄せる（統合）。

- 近いが少し違うものがある:
  - 命名を揃えて統合できるかを優先検討する。
  - 統合できない場合は、責務の境界を明確化し、名前で区別できるようにする（例: `parseXxx` と `formatXxx` のように役割で分ける）。

- 何も見つからない:
  - 新規作成してよいが、命名規則（AGENTS.md）に従い、検索で再発見できる名前にする。

### 3) 新規作成時のチェックリスト（必須）

- 名前:
  - 既存コードで使われている語彙を踏襲する（言い換えを作らない）。
  - 主要な export 名とファイル名を対応させる（探しやすくする）。

- 配置:
  - 手順0で参照した `docs/repository-structure.md` に沿って、既存の“置き場”へ入れる（新しい置き場を増やさない）。
  - 既存の配置規約に従う（例: 共通utilは `lib/`、UIは `components/`、backendは `backend/` 配下）。
  - `fix/` `tmp/` `backup/` のような退避ディレクトリを作らない。

- 参照更新:
  - 既存の重複候補があるなら、呼び出し側を更新して置き換える（片方を放置しない）。

### 4) 構造変更が発生した場合の同期（必須: 新規/移動/改名/削除）

以下に該当する場合は、必ず `docs/repository-structure.md` を更新する。

- 新しいファイル/ディレクトリを追加した
- ファイル/ディレクトリを移動・リネームした
- ファイル/ディレクトリを削除した

```bash
bash scripts/tree.sh
git diff -- docs/repository-structure.md
```

PR前に `$pr-flow` 側でも構造変更検知・同期を行う（最終的にPRへ必ず含める）。

### 5) 実装後の検証（必須）

- 変更規模に応じて:
  - 速い検証: `$verify-fast`
  - PR前/完了前: `$verify-full`

## 完了条件

- `docs/repository-structure.md` を参照した上で、既存探索の証跡（どのキーワードで探したか）が説明できる。
- 重複を増やさずに要件を満たした。
- 検証コマンドが成功している。
- 構造変更（追加/移動/改名/削除）がある場合、`docs/repository-structure.md` が更新されPRに含まれている。
