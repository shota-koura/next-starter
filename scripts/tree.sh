#!/usr/bin/env bash
set -euo pipefail

OUT="docs/repository-structure.md"
DEFAULT_DEPTH="5"
DEPTH="${1:-$DEFAULT_DEPTH}"

mkdir -p "$(dirname "$OUT")"

# Common excludes for repo tree output (generated/large dirs)
EXCLUDES='.git|node_modules|.next|dist|build|.venv|__pycache__|.pytest_cache|.ruff_cache|coverage|.turbo|.swc|.mypy_cache|.idea'

{
  echo "# Repository structure"
  echo
  echo "- Depth: \`${DEPTH}\`"
  echo
  echo '```text'
  tree -a -L "$DEPTH" -I "$EXCLUDES"
  echo '```'
} > "$OUT"

echo "$OUT"
