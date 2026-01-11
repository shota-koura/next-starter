---
name: branch-create
description: 新しい作業ブランチを作る（git alias feat|fix|docs|chore を優先、無ければフォールバック）
---

## 目的

- main を最新化してからブランチを切る運用を統一する。
- 1ブランチ=1PR を崩さない。

## いつ使うか

- 新しい作業を始めるとき。
- main 直作業を避けたいとき。

## 手順

### 0) working tree が clean か確認

```bash
git status -sb

```

未コミット変更がある場合は停止する（stash/commit/破棄の判断が必要）。

### 1) git alias が使えるならそれを使う（推奨）

- `git feat <slug>` -> `feat/<slug>`
- `git fix <slug>` -> `fix/<slug>`
- `git docs <slug>` -> `docs/<slug>`
- `git chore <slug>` -> `chore/<slug>`

例:

```bash
git chore agents-split

```

### 2) alias が無い場合のフォールバック

```bash
git switch main
git pull --ff-only
git switch -c "chore/<slug>"

```

## 注意

- default branch が `main` 以外のリポジトリではフォールバック手順を調整する。
- 既存ブランチ名と衝突する場合は slug を変える。
