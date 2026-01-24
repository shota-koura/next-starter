---
name: precommit
description: commit 前の整形・整合チェックとセルフレビュー、tree 更新を実施する
---

## 目的

- commit 前に、整形・静的チェックを一連で実施して差分品質を上げる。
- `docs/repository-structure.md` を最新化して、リポジトリ構造ドキュメントの陳腐化を防ぐ（毎回実行）。

## いつ使うか

- commit する直前（原則）。
- docs / skills など、差分が Markdown 中心でも commit する前。
- PR 作成前（commit を積む運用でも、最低 1 回は実施する）。

## 前提

- 作業ブランチにいる（`main` / `master` に直接 commit しない）。
- Node 依存が揃っている（`npm install` 済み）。
- `bash scripts/tree.sh` が利用する `tree` コマンドが環境に存在する。

## 1コマンド実行（推奨）

次を実行する。

```bash
bash .codex/skills/precommit/scripts/precommit.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/precommit/scripts/precommit.ps1
```

- スクリプトが本ファイルの手順をまとめて実行する。

## 手順

### 0) 状態確認

```bash
git status -sb
git diff --name-only
```

- 想定外のファイルが混ざっていないか確認する。
- 秘密情報（トークン、鍵、内部URL 等）が差分に入っていないことを確認する。

### 1) リポジトリ標準の precommit 実行

```bash
npm run precommit
```

- 失敗した場合は、指摘内容を解消して再実行する。
- ここで自動整形が走る場合があるため、実行後に差分を再確認する。

### 2) リポジトリ構造ドキュメントの更新（毎回）

`docs/repository-structure.md` は生成物として扱い、手動編集しない。

```bash
bash scripts/tree.sh
```

- 深さを変える場合:

```bash
bash scripts/tree.sh 5
```

### 3) tree 更新後の整形（推奨）

tree 更新で Markdown が更新された場合に備えて再実行する。

```bash
npm run precommit
```

### 4) 差分の最終確認

```bash
git status -sb
git diff --stat
```

- 意図した差分のみになっていることを確認する。

### 5) commit 実行

commit は `$commit` を使う（`verify-full` を必須実行したうえで add/commit/push を行う）。

- 事前に `COMMIT_MSG` を設定する（必須）:

```bash
export COMMIT_MSG='feat(frontend): タスク作成フォームを追加'
```

- 実行:

```text
$commit
```

## 完了条件

- `npm run precommit` が成功している。
- `bash scripts/tree.sh` により `docs/repository-structure.md` が最新化されている。
- 差分が意図通りで、次に `$commit` へ進める状態になっている。
