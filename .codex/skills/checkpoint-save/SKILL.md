---
name: checkpoint-save
description: >-
  1つの論理単位（関数・コンポーネント・ファイル群）の実装が完了したとき、次の作業単位に移る前、
  または差分が肥大化する前に、能動的に実行する。verify-fast を通して checkpoint commit/push を作る。
  軽い save point 用であり、CodeRabbit / codex-reviewer / PR 作成 / merge は行わない。
  作業完了時には使わず、`$pr-flow` を使う。
---

# Checkpoint Save

## 目的

- 開発途中の安全な区切りで、軽い save point を残す。
- `verify-fast` を通したうえで checkpoint commit/push を作り、作業切り替えや小刻みな積み上げをしやすくする。
- `coderabbit-pre-review`、`change-review`、`pr-review-merge` を呼ばず、途中保存を重くしすぎない。

## いつ使うか

- 実装途中で、論理的に 1 区切りついたとき。
- コンテキストを切り替える前に、現在の変更を branch に退避したいとき。
- 次の変更に入る前に、いったん `verify-fast` を通した checkpoint を残したいとき。

## 使わないとき

- 作業が完了し、PR 作成から merge まで進みたいとき。
- CodeRabbit / `codex-reviewer` の review を含めた最終フローに進みたいとき。
- `.github/`、依存管理ファイル、任意ディレクトリ配下を含む `.env*` など guarded file の変更を人間確認なしで push したくないとき。

作業完了時は、この skill ではなく `$pr-flow` を使う。

## 前提

- 作業ブランチ上であること。
- detached HEAD ではないこと。
- checkpoint として残したい変更が working tree にあること。
- `.codex/skills/verify-fast/scripts/verify-fast.sh` または `.ps1` が利用可能であること。

## 環境変数

- `COMMIT_MSG`（任意）
  - checkpoint commit メッセージ。未設定なら差分から自動生成する。
  - 例: `feat(frontend): タスク作成 UI の途中経過を保存`
- `PUSH`（任意）
  - `1` なら push する（デフォルト `1`）。
  - `0` なら commit のみ行う。
- `REMOTE`（任意）
  - push 先 remote（デフォルト `origin`）。
- `ALLOW_GUARDED_FILES`（任意）
  - 今回だけ許可する guarded file を exact path のカンマ区切りで指定する。
- `RUN_TEST`（任意）
  - `1` なら `verify-fast` で frontend test も実行する。
- `RUN_PYTEST`（任意）
  - `1` なら `verify-fast` で backend pytest も実行する。

## 1コマンド実行（推奨）

次を実行する。

```bash
bash .codex/skills/checkpoint-save/scripts/checkpoint-save.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/checkpoint-save/scripts/checkpoint-save.ps1
```

## ガードレール

以下に該当する変更がある場合、この skill は停止する。

- `.github/` 配下（特に `.github/workflows/`）
- `.codex/agents/`、`.codex/skills/`、`AGENTS.md`
- `.coderabbit.yaml` / `.coderabbit.yml`
- 依存管理ファイル / lock file
  - `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`
  - `pyproject.toml`, `poetry.lock`, `requirements*.txt`, `backend/requirements*.txt`
- `.env*` などの環境変数ファイル
  - root 直下だけでなく、`backend/.env` や `app/.env.local` のようなネスト配下も含む

checkpoint を軽く保つため、上記変更は自動で押し流さない。
また、detached HEAD では停止し、remote 退避に失敗する状態で commit/push を進めない。

## 手順

1. `git status -sb` で差分を確認する
2. `verify-fast` を実行する
3. guarded file の有無を検査する
4. `COMMIT_MSG` 未設定時は差分から checkpoint 向けメッセージを自動生成する
5. `git add -A` → `git commit` → `git push` を行う
6. 作業完了時はこの skill を再実行せず、`$pr-flow` に進む

## 完了条件

- `verify-fast` が成功している。
- guarded file の無確認 push が起きていない。
- `git commit` が成功している。
- `PUSH=1` の場合、`git push` が成功している。
