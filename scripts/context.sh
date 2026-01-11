#!/usr/bin/env bash
set -euo pipefail

# Bundle files (and optionally stdin) into a single Markdown file for LLM context sharing.
# Supports recursive directory inputs.
#
# Output:
#   context/<name>_<YYYYMMDD_HHMMSS>.md
#
# Usage:
#   bash scripts/context.sh [options] <path1|-> <path2> ...
#
# Examples:
#   bash scripts/context.sh -n pr_review AGENTS.md README.md
#   bash scripts/context.sh -n skills --include-hidden .codex/skills/branch-create
#   bash scripts/context.sh --raw docs/ app/ lib/
#   cat notes.txt | bash scripts/context.sh -n notes - AGENTS.md

OUT_DIR="context"
NAME="context"
RAW="0"
INCLUDE_HIDDEN="0"

usage() {
  cat <<'USAGE'
Usage:
  context.sh [options] <path1|-> <path2> ...

Options:
  -n, --name <name>        Output file base name (default: context)
  --raw                    Do not wrap file contents in code fences
  --include-hidden         Include dotfiles and dot-directories when expanding directories
  -h, --help               Show help

Notes:
  - "-" means read from STDIN and include it as a section.
  - Directory inputs are expanded recursively into files (stable, sorted order).
  - Some directories are excluded by default: node_modules, .next, dist, build, .git, .ruff_cache, .pytest_cache, .swc, .turbo

Examples:
  bash scripts/context.sh -n pr_review AGENTS.md README.md
  bash scripts/context.sh -n skills --include-hidden .codex/skills/branch-create
  bash scripts/context.sh app lib
  cat notes.txt | bash scripts/context.sh -n notes - AGENTS.md
USAGE
}

lang_for() {
  local f="$1"
  case "$f" in
    *.ts) echo "ts" ;;
    *.tsx) echo "tsx" ;;
    *.js) echo "js" ;;
    *.mjs) echo "js" ;;
    *.cjs) echo "js" ;;
    *.json) echo "json" ;;
    *.yml|*.yaml) echo "yaml" ;;
    *.toml) echo "toml" ;;
    *.md) echo "md" ;;
    *.py) echo "py" ;;
    *.sh) echo "bash" ;;
    *.css) echo "css" ;;
    *.html) echo "html" ;;
    *.sql) echo "sql" ;;
    *) echo "" ;;
  esac
}

# Exclude patterns for find (directories)
default_excludes=(
  ".git"
  "node_modules"
  ".next"
  "dist"
  "build"
  ".ruff_cache"
  ".pytest_cache"
  ".swc"
  ".turbo"
)

paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      NAME="${2:-}"
      if [[ -z "$NAME" ]]; then
        echo "Error: --name requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    --raw)
      RAW="1"
      shift
      ;;
    --include-hidden)
      INCLUDE_HIDDEN="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      paths+=("$1")
      shift
      ;;
  esac
done

while [[ $# -gt 0 ]]; do
  paths+=("$1")
  shift
done

if [[ ${#paths[@]} -eq 0 ]]; then
  echo "Error: no input paths" >&2
  usage
  exit 2
fi

mkdir -p "$OUT_DIR"

ts="$(date +%Y%m%d_%H%M%S)"
out_path="${OUT_DIR%/}/${NAME}_${ts}.md"

{
  echo "<!-- generated_by: scripts/context.sh -->"
  echo "<!-- generated_at: ${ts} -->"
  echo "<!-- cwd: $(pwd) -->"
  echo
} > "$out_path"

append_section_raw() {
  local title="$1"
  local cmd="$2"
  echo "# ${title}" >> "$out_path"
  echo >> "$out_path"
  eval "$cmd" >> "$out_path"
  echo >> "$out_path"
  echo >> "$out_path"
}

append_section_fenced() {
  local title="$1"
  local lang="$2"
  local cmd="$3"
  echo "# ${title}" >> "$out_path"
  echo >> "$out_path"
  if [[ -n "$lang" ]]; then
    echo '```'"$lang" >> "$out_path"
  else
    echo '```' >> "$out_path"
  fi
  eval "$cmd" >> "$out_path"
  echo >> "$out_path"
  echo '```' >> "$out_path"
  echo >> "$out_path"
}

# Expand a directory into files (stable order)
expand_dir() {
  local d="$1"

  local prune_expr=()
  for ex in "${default_excludes[@]}"; do
    prune_expr+=(-path "*/${ex}/*" -o -path "*/${ex}")
    prune_expr+=(-o)
  done
  # remove trailing -o if present
  if [[ ${#prune_expr[@]} -gt 0 ]]; then
    unset 'prune_expr[${#prune_expr[@]}-1]'
  fi

  # Hidden handling: if not including hidden, prune any path with "/."
  if [[ "$INCLUDE_HIDDEN" == "0" ]]; then
    find "$d" \
      \( "${prune_expr[@]}" -o -path '*/.*' \) -prune -o \
      -type f -print \
      | LC_ALL=C sort
  else
    find "$d" \
      \( "${prune_expr[@]}" \) -prune -o \
      -type f -print \
      | LC_ALL=C sort
  fi
}

# Collect final file list in the exact order of arguments:
# - stdin sections appear in-place
# - for a file arg: include it
# - for a dir arg: expand to sorted files and include them at that point
for p in "${paths[@]}"; do
  if [[ "$p" == "-" ]]; then
    title="STDIN"
    if [[ "$RAW" == "1" ]]; then
      append_section_raw "$title" "cat"
    else
      append_section_fenced "$title" "" "cat"
    fi
    continue
  fi

  if [[ -f "$p" ]]; then
    title="$p"
    if [[ "$RAW" == "1" ]]; then
      append_section_raw "$title" "cat \"${p}\""
    else
      lang="$(lang_for "$p")"
      append_section_fenced "$title" "$lang" "cat \"${p}\""
    fi
    continue
  fi

  if [[ -d "$p" ]]; then
    while IFS= read -r f; do
      title="$f"
      if [[ "$RAW" == "1" ]]; then
        append_section_raw "$title" "cat \"${f}\""
      else
        lang="$(lang_for "$f")"
        append_section_fenced "$title" "$lang" "cat \"${f}\""
      fi
    done < <(expand_dir "$p")
    continue
  fi

  echo "Error: path not found: $p" >&2
  exit 1
done

echo "$out_path"
