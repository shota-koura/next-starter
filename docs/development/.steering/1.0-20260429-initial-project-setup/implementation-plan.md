# 初回準備PR 実装計画

## 方針

初回準備PRは、以降の Python 実装を始めるための土台だけを作る。動作仕様や外部 API の不確実性を解消するコードは次PR以降へ送る。

## 変更対象

- 削除:
  - Next.js / React / Tailwind / Jest / Playwright テンプレート関連。
  - `backend/` 配下の FastAPI テンプレート関連。
- 追加:
  - `voice_typer/__init__.py`
  - `voice_typer/__main__.py`
  - `voice_typer/main.py`
  - `tests/test_smoke.py`
  - `pyproject.toml`
  - `requirements.txt`
  - `requirements-dev.txt`
  - `.python-version`
- 更新:
  - `.github/workflows/ci.yml`
  - `.gitignore`
  - `README.md`

## CI

GitHub Actions は `ubuntu-latest` で Python 3.12 をセットアップし、開発依存をインストールして以下を実行する。

- `ruff check .`
- `ruff format --check .`
- `black --check .`
- `mypy voice_typer tests`
- `pytest`

Windows smoke や PyInstaller build smoke は、実装対象ができた後の別作業で追加する。

## 検証

ローカルで CI と同等のコマンドを実行する。環境に Python 3.12 がない場合は、その制約を明記する。
