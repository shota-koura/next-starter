# AGENTS.md

## Language / 言語

- Respond in Japanese by default.
- Use English for code, commands, file paths, and config keys.
- If a command requires English (e.g., review comments), follow that.

# Development rules (must)

## Validation levels (fast vs full)

- Fast validation (during coding loop):
  - Run: `npm run format:check`
  - Then run: `npm run lint`
- Full validation (CI parity / before PR / before marking a task done):
  - Run: `npm run fix`
  - Then run: `npm run check`

## Definition of done (per task / PR)

- Before marking any task as "done" or proposing a PR:
  - Run: `npm run fix`
  - Then run: `npm run check`
  - If `npm run check` fails, fix the issues and rerun until it passes.
- During development, prefer the "Fast validation" commands to keep iteration quick.

## Avoid unrelated diffs (important)

- Do not introduce unrelated reformatting changes.
- Prefer minimal diffs:
  - Only modify files required for the task.
  - Avoid repo-wide formatting unless explicitly needed.
- If `npm run fix` causes a large number of changes:
  - Explain why in the PR, or
  - Split formatting-only changes into a separate PR.

## Formatting

- Formatting is done by Prettier.
- Tailwind class ordering is handled by `prettier-plugin-tailwindcss`.
- Do not manually “pretty-print”:
  - Use `npm run fix` for full auto-fix.
  - Use `npm run format` to apply Prettier formatting.

## Linting

- ESLint is the source of truth for lint rules.
- Use `npm run lint:fix` only via `npm run fix` (or when explicitly requested).

## Output (for PR proposals / review)

- When you propose a PR, include:
  - Summary of changes
  - Commands executed and their results (at least `npm run check`)
  - Notes if large formatting changes occurred
  - Screenshots for UI changes (if applicable)

# Repository Guidelines

## Project Structure & Module Organization

- `app/` contains Next.js App Router routes and shared UI (e.g., `app/page.tsx`, `app/layout.tsx`).
- `app/globals.css` holds global styles and Tailwind directives.
- `public/` stores static assets served at the site root.
- Root config files include `next.config.ts`, `tsconfig.json`, `eslint.config.mjs`, and `postcss.config.mjs`.

## Build, Test, and Development Commands

- `npm install` installs dependencies.
- `npm run dev` starts the local dev server at `http://localhost:3000`.
- `npm run build` creates a production build.
- `npm run start` serves the production build after `npm run build`.
- `npm run lint` runs ESLint across the repo.
- `npm run lint:fix` runs ESLint with auto-fixes.
- `npm run format` formats code with Prettier (includes Tailwind class sorting).
- `npm run format:check` checks formatting without writing changes.
- `npm run check` runs `format:check`, `lint`, and `build` for CI-style validation.
- `npm run fix` runs formatting and ESLint auto-fixes.

## Coding Style & Naming Conventions

- TypeScript + React; prefer `tsx` for components and route files.
- Let Prettier handle formatting; avoid manual alignment.
- Tailwind class ordering is managed by `prettier-plugin-tailwindcss`.
- Naming:
  - React components in PascalCase (`HeroBanner`)
  - Hooks as `useX`
  - Route segment folders in lowercase (App Router conventions)

## Testing Guidelines

- No test runner is configured yet.
- Use `npm run check` to catch build and lint issues before pushing.
- If adding tests:
  - Place them under `tests/` or `__tests__/`
  - Name files like `*.test.tsx` or `*.spec.tsx`

## Commit & Pull Request Guidelines

- Keep commits minimal and focused.
- Use concise, imperative commit subjects (e.g., `Add pricing section`).
- Prefer small PRs; avoid mixing refactors with feature work unless necessary.
- PRs should include:
  - Short summary
  - Testing notes (commands run)
  - Screenshots for UI changes
  - Links to relevant issues (if any)

## Configuration & Environment Tips

- Keep secrets in `.env.local` (do not commit).
- Use `.prettierignore` to exclude generated/irrelevant directories (e.g., `.next`, `node_modules`, `.specstory`).
- Verify Tailwind class sorting by running `npx prettier --write app/page.tsx` if in doubt.
