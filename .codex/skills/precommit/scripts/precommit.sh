#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

bash .codex/skills/verify-full/scripts/verify-full.sh

bash scripts/tree.sh

bash .codex/skills/verify-full/scripts/verify-full.sh

git status -sb
git diff --stat
