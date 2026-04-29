---
name: verify-full
description: "PR前/タスク完了前のフル検証を実行する（Python: ruff/black/mypy/pytest）"
---

## 目的

- PR を提案する前、またはタスクを「完了」とする前に、CI 相当の検証を通す。
- Python 3.12.x 前提の lint、format、typecheck、test を一通り確認する。

## いつ使うか

- PR 作成前 / PR 更新前の最終確認。
- CI 失敗を直した後の最終確認。
- リファクタや依存更新など、回帰リスクがある変更を入れた後。

## 前提

- リポジトリ root で実行する。
- Python 3.12.x を使う。
- `.venv` が無い場合、スクリプトは `python3.12 -m venv` を試し、失敗した場合は `uv venv .venv --python 3.12` にフォールバックする。

## 1コマンド実行

```bash
bash .codex/skills/verify-full/scripts/verify-full.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/verify-full/scripts/verify-full.ps1
```

## 実行内容

```bash
ruff check .
ruff format --check .
black --check .
mypy voice_typer tests
pytest
python -m voice_typer
```

## 完了条件

- 上記コマンドがすべて成功している。
- 失敗した場合は原因を修正し、成功するまで再実行する。
