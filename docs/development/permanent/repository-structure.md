# Repository structure

- Depth: `5`

```text
.
├── .coderabbit.yaml
├── .codex
│   ├── agents
│   │   ├── api-designer.toml
│   │   ├── autonomous-orchestrator.toml
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
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── api-modify-design
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── autonomous-steering
│       │   ├── SKILL.md
│       │   ├── agents
│       │   │   └── openai.yaml
│       │   └── references
│       │       └── autonomy-policy.md
│       ├── branch-create
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── bug-investigation
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── change-review
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── checkpoint-save
│       │   ├── SKILL.md
│       │   ├── agents
│       │   │   └── openai.yaml
│       │   └── scripts
│       │       ├── checkpoint-save.ps1
│       │       └── checkpoint-save.sh
│       ├── coderabbit-pre-review
│       │   ├── SKILL.md
│       │   ├── agents
│       │   │   └── openai.yaml
│       │   └── scripts
│       │       ├── coderabbit-pre-review.ps1
│       │       └── coderabbit-pre-review.sh
│       ├── commit
│       │   ├── SKILL.md
│       │   ├── agents
│       │   │   └── openai.yaml
│       │   └── scripts
│       │       ├── commit.ps1
│       │       └── commit.sh
│       ├── dedupe
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── document-update
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── implementation-plan-generator
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── llm-change-design
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── mcp-chrome-devtools-perf
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── mcp-playwright-debug
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── mcp-serena-refactor
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── pr-flow
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── pr-review-merge
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── precommit
│       │   ├── SKILL.md
│       │   ├── agents
│       │   │   └── openai.yaml
│       │   └── scripts
│       │       ├── precommit.ps1
│       │       └── precommit.sh
│       ├── repo-setup
│       │   ├── SKILL.md
│       │   ├── agents
│       │   │   └── openai.yaml
│       │   └── scripts
│       │       ├── repo-setup.ps1
│       │       └── repo-setup.sh
│       ├── requirements-quality-gate
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── setup-tailwind-frontend
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── skills-retro
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── supabase-cli-workflow
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── tasklist-generator
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── vercel-cli-workflow
│       │   ├── SKILL.md
│       │   └── agents
│       │       └── openai.yaml
│       ├── verify-fast
│       │   ├── SKILL.md
│       │   ├── agents
│       │   │   └── openai.yaml
│       │   └── scripts
│       │       ├── verify-fast.ps1
│       │       └── verify-fast.sh
│       └── verify-full
│           ├── SKILL.md
│           ├── agents
│           │   └── openai.yaml
│           └── scripts
│               ├── verify-full.ps1
│               └── verify-full.sh
├── .github
│   ├── rulesets
│   │   └── protect-main.json
│   └── workflows
│       └── ci.yml
├── .gitignore
├── .python-version
├── .vscode
│   └── settings.json
├── AGENTS.md
├── README.md
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
│       │   ├── .gitkeep
│       │   ├── 1.0-20260429-initial-project-setup
│       │   │   ├── implementation-plan.md
│       │   │   ├── requirements.md
│       │   │   └── tasklist.md
│       │   └── steering.md
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
├── pyproject.toml
├── requirements-dev.txt
├── requirements.txt
├── scripts
│   ├── codex-setup.sh
│   ├── context.sh
│   ├── pr.sh
│   └── tree.sh
├── tests
│   └── test_smoke.py
└── voice_typer
    ├── __init__.py
    ├── __main__.py
    └── main.py

95 directories, 127 files
```
