#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

git status -sb
git diff --name-only

npm run precommit

bash scripts/tree.sh

npm run precommit

git status -sb
git diff --stat
