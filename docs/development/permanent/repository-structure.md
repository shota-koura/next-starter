# Repository structure

- Depth: `5`

```text
.
├── .coderabbit.yaml
├── .codex
│   ├── agents
│   │   ├── api-designer.toml
│   │   ├── backend-developer.toml
│   │   ├── cloud-architect.toml
│   │   ├── code-mapper.toml
│   │   ├── codex-reviewer.toml
│   │   ├── debugger.toml
│   │   ├── docs-researcher.toml
│   │   ├── fullstack-developer.toml
│   │   ├── llm-architect.toml
│   │   ├── multi-agent-coordinator.toml
│   │   ├── planning-reviewer.toml
│   │   ├── refactoring-specialist.toml
│   │   └── workflow-orchestrator.toml
│   ├── config.toml
│   └── skills
│       ├── api-add-design
│       │   └── SKILL.md
│       ├── api-modify-design
│       │   └── SKILL.md
│       ├── branch-create
│       │   └── SKILL.md
│       ├── bug-investigation
│       │   └── SKILL.md
│       ├── change-review
│       │   └── SKILL.md
│       ├── coderabbit-pre-review
│       │   ├── SKILL.md
│       │   └── scripts
│       │       ├── coderabbit-pre-review.ps1
│       │       └── coderabbit-pre-review.sh
│       ├── commit
│       │   ├── SKILL.md
│       │   └── scripts
│       │       ├── commit.ps1
│       │       └── commit.sh
│       ├── dedupe
│       │   └── SKILL.md
│       ├── document-update
│       │   └── SKILL.md
│       ├── implementation-plan-generator
│       │   └── SKILL.md
│       ├── llm-change-design
│       │   └── SKILL.md
│       ├── mcp-chrome-devtools-perf
│       │   └── SKILL.md
│       ├── mcp-playwright-debug
│       │   └── SKILL.md
│       ├── mcp-serena-refactor
│       │   └── SKILL.md
│       ├── pr-flow
│       │   └── SKILL.md
│       ├── pr-review-merge
│       │   └── SKILL.md
│       ├── precommit
│       │   ├── SKILL.md
│       │   └── scripts
│       │       ├── precommit.ps1
│       │       └── precommit.sh
│       ├── repo-setup
│       │   ├── SKILL.md
│       │   └── scripts
│       │       ├── repo-setup.ps1
│       │       └── repo-setup.sh
│       ├── setup-tailwind-frontend
│       │   └── SKILL.md
│       ├── skills-retro
│       │   └── SKILL.md
│       ├── supabase-cli-workflow
│       │   └── SKILL.md
│       ├── tasklist-generator
│       │   └── SKILL.md
│       ├── vercel-cli-workflow
│       │   └── SKILL.md
│       ├── verify-fast
│       │   ├── SKILL.md
│       │   └── scripts
│       │       ├── verify-fast.ps1
│       │       └── verify-fast.sh
│       └── verify-full
│           ├── SKILL.md
│           └── scripts
│               ├── verify-full.ps1
│               └── verify-full.sh
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
│   └── history
│       ├── 2026-01-04_07-12Z-bashスクリプトの和訳.md
│       ├── 2026-01-17_06-14Z-pr-フロー-skill-の-p0-処理設計.md
│       ├── 2026-01-24_03-05Z-スクリプト出力先ディレクトリ変更.md
│       └── 2026-02-01_04-44Z-@agents-md-ディレクトリ命名規則.md
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
│   ├── business
│   │   ├── .gitkeep
│   │   ├── 01_Internal_workspace
│   │   │   ├── .gitkeep
│   │   │   ├── Meeting
│   │   │   │   ├── .gitkeep
│   │   │   │   ├── External
│   │   │   │   └── Internal
│   │   │   └── Member folder
│   │   │       ├── .gitkeep
│   │   │       ├── Eriko
│   │   │       └── Shota
│   │   ├── 02_Business reports
│   │   │   └── .gitkeep
│   │   ├── 03_Shared_data_from tA to Client
│   │   │   └── .gitkeep
│   │   ├── 04_Shared_data_from Client to tA
│   │   │   └── .gitkeep
│   │   ├── 05_Contracts
│   │   │   └── .gitkeep
│   │   └── 06_Deliverables
│   │       └── .gitkeep
│   └── development
│       ├── .steering
│       │   └── .gitkeep
│       ├── context
│       │   └── test_context_20260124_120747.md
│       ├── permanent
│       │   ├── architecture.md
│       │   ├── development-guidelines.md
│       │   ├── functional-design.md
│       │   ├── glossary.md
│       │   ├── product-requirements.md
│       │   └── repository-structure.md
│       └── recomend-skills
│           └── .gitkeep
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

71 directories, 143 files
```
