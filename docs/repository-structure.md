# Repository structure

- Depth: `5`

```text
.
├── .coderabbit.yaml
├── .codex
│   ├── config.toml
│   └── skills
│       ├── branch-create
│       │   └── SKILL.md
│       ├── commit
│       │   └── SKILL.md
│       ├── dedupe
│       │   └── SKILL.md
│       ├── document-update
│       │   └── SKILL.md
│       ├── mcp-chrome-devtools-perf
│       │   └── SKILL.md
│       ├── mcp-context7-docs
│       │   └── SKILL.md
│       ├── mcp-playwright-debug
│       │   └── SKILL.md
│       ├── mcp-serena-refactor
│       │   └── SKILL.md
│       ├── pr-fix-loop
│       │   ├── SKILL.md
│       │   └── scripts
│       │       └── pr-fix-loop.sh
│       ├── pr-flow
│       │   ├── SKILL.md
│       │   └── scripts
│       │       └── pr-flow.sh
│       ├── precommit
│       │   └── SKILL.md
│       ├── repo-setup
│       │   └── SKILL.md
│       ├── setup-tailwind-frontend
│       │   └── SKILL.md
│       ├── verify-fast
│       │   └── SKILL.md
│       └── verify-full
│           └── SKILL.md
├── .github
│   ├── rulesets
│   │   └── protect-main.json
│   └── workflows
│       └── ci.yml
├── .gitignore
├── .husky
│   ├── _
│   │   ├── .gitignore
│   │   ├── applypatch-msg
│   │   ├── commit-msg
│   │   ├── h
│   │   ├── husky.sh
│   │   ├── post-applypatch
│   │   ├── post-checkout
│   │   ├── post-commit
│   │   ├── post-merge
│   │   ├── post-rewrite
│   │   ├── pre-applypatch
│   │   ├── pre-auto-gc
│   │   ├── pre-commit
│   │   ├── pre-merge-commit
│   │   ├── pre-push
│   │   ├── pre-rebase
│   │   └── prepare-commit-msg
│   └── pre-commit
├── .prettierignore
├── .prettierrc
├── .specstory
│   ├── .project.json
│   ├── .what-is-this.md
│   └── history
│       ├── 2026-01-04_07-12Z-bashスクリプトの和訳.md
│       ├── 2026-01-17_06-14Z-pr-フロー-skill-の-p0-処理設計.md
│       └── 2026-01-24_03-05Z-スクリプト出力先ディレクトリ変更.md
├── .vscode
│   └── settings.json
├── AGENTS.md
├── README.md
├── __tests__
│   └── button.test.tsx
├── app
│   ├── favicon.ico
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
├── backend
│   ├── Makefile
│   ├── __init__.py
│   ├── app.py
│   ├── pyproject.toml
│   ├── pyrightconfig.json
│   ├── requirements-dev.txt
│   ├── requirements.txt
│   └── tests
│       └── test_smoke.py
├── components
│   └── ui
│       ├── button.tsx
│       ├── card.tsx
│       ├── dialog.tsx
│       ├── input.tsx
│       ├── label.tsx
│       ├── sonner.tsx
│       └── textarea.tsx
├── components.json
├── docs
│   ├── architecture.md
│   ├── context
│   │   └── test_context_20260124_120747.md
│   ├── development-guidelines.md
│   ├── functional-design.md
│   ├── glossary.md
│   ├── product-requirements.md
│   └── repository-structure.md
├── e2e
│   └── health.spec.ts
├── eslint.config.mjs
├── jest.config.js
├── jest.setup.ts
├── lib
│   └── utils.ts
├── next-env.d.ts
├── next.config.ts
├── package-lock.json
├── package.json
├── playwright.config.ts
├── postcss.config.mjs
├── public
│   ├── file.svg
│   ├── globe.svg
│   ├── next.svg
│   ├── vercel.svg
│   └── window.svg
├── scripts
│   ├── codex-setup.sh
│   ├── context.sh
│   ├── pr.sh
│   └── tree.sh
└── tsconfig.json

39 directories, 99 files
```
