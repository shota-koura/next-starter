#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

RUN_BACKEND="${RUN_BACKEND:-auto}"
RUN_E2E="${RUN_E2E:-0}"

git status -sb
git diff --name-only

npm run fix
npm run format:check
npm run lint
npm run test:ci

if [[ "$RUN_BACKEND" == "auto" ]]; then
  if git diff --name-only | grep -Eq '^(backend/|pyproject\.toml$|requirements.*\.txt$)'; then
    RUN_BACKEND="1"
  else
    RUN_BACKEND="0"
  fi
fi

if [[ "$RUN_BACKEND" == "1" ]]; then
  if [[ -f backend/Makefile ]] && command -v make >/dev/null 2>&1; then
    (
      cd backend
      make ruff-fix
      make ruff-format
      make pyright
      make pytest
    )
  else
    (
      cd backend
      if [[ ! -d ".venv" ]]; then
        python3 -m venv .venv
      fi

      if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        . .venv/bin/activate
        ACTIVATED=1
      else
        ACTIVATED=0
      fi

      python -m pip install -U pip
      pip install -r requirements-dev.txt
      ruff check --fix .
      ruff format .
      pyright
      python -m pytest

      if [[ "$ACTIVATED" == "1" ]]; then
        deactivate
      fi
    )
  fi
else
  echo "[SKIP] Backend checks (RUN_BACKEND=$RUN_BACKEND)"
fi

if [[ "$RUN_E2E" == "1" ]]; then
  npm run e2e
else
  echo "[SKIP] E2E (set RUN_E2E=1 to run)"
fi
