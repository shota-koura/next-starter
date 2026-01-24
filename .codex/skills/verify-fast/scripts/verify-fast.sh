#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

RUN_FRONTEND="${RUN_FRONTEND:-auto}"
RUN_BACKEND="${RUN_BACKEND:-auto}"
RUN_TEST="${RUN_TEST:-0}"
RUN_PYTEST="${RUN_PYTEST:-0}"

git status -sb
git diff --name-only

CHANGED="$(git diff --name-only || true)"

if [[ "$RUN_FRONTEND" == "auto" ]]; then
  if echo "$CHANGED" | grep -Eq '^(app/|components/|lib/|__tests__/|e2e/)'; then
    RUN_FRONTEND="1"
  else
    RUN_FRONTEND="0"
  fi
fi

if [[ "$RUN_BACKEND" == "auto" ]]; then
  if echo "$CHANGED" | grep -Eq '^(backend/|pyproject\.toml$|requirements.*\.txt$)'; then
    RUN_BACKEND="1"
  else
    RUN_BACKEND="0"
  fi
fi

if [[ "$RUN_FRONTEND" == "1" ]]; then
  npm run format:check
  npm run lint
  if [[ "$RUN_TEST" == "1" ]]; then
    npm run test:ci
  else
    echo "[SKIP] Frontend tests (set RUN_TEST=1 to run)"
  fi
else
  echo "[SKIP] Frontend checks (RUN_FRONTEND=$RUN_FRONTEND)"
fi

if [[ "$RUN_BACKEND" == "1" ]]; then
  if [[ -f backend/Makefile ]] && command -v make >/dev/null 2>&1; then
    (
      cd backend
      make ruff-format-check
      make ruff-check
      if [[ "$RUN_PYTEST" == "1" ]]; then
        make pytest
      else
        echo "[SKIP] Backend tests (set RUN_PYTEST=1 to run)"
      fi
    )
  else
    (
      cd backend
      if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        if [[ -d ".venv" ]]; then
          . .venv/bin/activate
          ACTIVATED=1
        else
          echo "[ERROR] backend/.venv not found. Create venv before backend checks."
          exit 1
        fi
      else
        ACTIVATED=0
      fi

      ruff format --check .
      ruff check .
      if [[ "$RUN_PYTEST" == "1" ]]; then
        python -m pytest
      else
        echo "[SKIP] Backend tests (set RUN_PYTEST=1 to run)"
      fi

      if [[ "$ACTIVATED" == "1" ]]; then
        deactivate
      fi
    )
  fi
else
  echo "[SKIP] Backend checks (RUN_BACKEND=$RUN_BACKEND)"
fi
