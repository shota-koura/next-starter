---
name: precommit
description: commit 前の整形・整合チェックとセルフレビュー、tree 更新を実施する
---

## 目的

- commit 前に、Python 3.12 構成の整形・静的チェック・テストを実施する。
- `docs/development/permanent/repository-structure.md` を最新化して、リポジトリ構造ドキュメントの陳腐化を防ぐ。

## いつ使うか

- commit する直前。
- docs / skills など、差分が Markdown 中心でも commit する前。
- PR 作成前。

## 前提

- 作業ブランチにいる。`main` / `master` に直接 commit しない。
- Python 3.12.x を使う。
- `bash scripts/tree.sh` が利用する `tree` コマンドが環境に存在する。

## 1コマンド実行

```bash
bash .codex/skills/precommit/scripts/precommit.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/precommit/scripts/precommit.ps1
```

## 手順

### 0) 状態確認

```bash
git status -sb
git diff --name-only
```

想定外のファイルや秘密情報が混ざっていないことを確認する。

### 1) Python 検証

```bash
bash .codex/skills/verify-full/scripts/verify-full.sh
```

### 2) リポジトリ構造ドキュメントの更新

```bash
bash scripts/tree.sh
```

### 3) tree 更新後の再検証

```bash
bash .codex/skills/verify-full/scripts/verify-full.sh
```

### 4) 差分の最終確認

```bash
git status -sb
git diff --stat
```

## 完了条件

- `verify-full` が成功している。
- `bash scripts/tree.sh` により `docs/development/permanent/repository-structure.md` が最新化されている。
- 差分が意図通りで、次に commit へ進める状態になっている。
