#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

git status -sb
git diff --name-only

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  if [[ ! -d ".venv" ]]; then
    if command -v python3.12 >/dev/null 2>&1 && python3.12 -m venv .venv; then
      :
    elif command -v uv >/dev/null 2>&1; then
      uv venv .venv --python 3.12
    else
      echo "[ERROR] Python 3.12 venv creation failed and uv is unavailable." >&2
      exit 1
    fi
  fi
  # shellcheck disable=SC1091
  . .venv/bin/activate
fi

if command -v uv >/dev/null 2>&1; then
  uv pip install --python "$(command -v python)" -r requirements-dev.txt
else
  python -m pip install -U pip
  python -m pip install -r requirements-dev.txt
fi

ruff check .
ruff format --check .
black --check .
mypy voice_typer tests
pytest
python -m voice_typer
