# next-starter

Next.js + TypeScript + Tailwind CSS の開発用スターターです。  
ESLint / Prettier / prettier-plugin-tailwindcss を組み込み、Cursor（VS Code互換）で保存時に自動整形・自動修正が効く状態を標準化しています。

## Features

- Next.js (App Router) + TypeScript
- ESLint (Next.js core-web-vitals + TypeScript)
- Prettier（保存時フォーマット）
- prettier-plugin-tailwindcss（Tailwind class の自動並び替え）
- Cursor / VS Code 向けのワークスペース設定（`.vscode/settings.json`）

## Create a new project from this template

このリポジトリを `create-next-app --example` で雛形として新規プロジェクトを作成します。

```bash
npx create-next-app@latest my-app --example "https://github.com/shota-koura/next-starter"
cd my-app
```

## Recommended first run (before development)

依存インストールとフォーマットを一度通し、以降の開発でズレが出ない状態にします。

```bash
npm install
npm run format
npm run check
npm run dev
```

- `format`: Prettier 実行（Tailwind class 並び替えもここで適用）
- `check`: `format:check` + `lint`（テンプレ側の scripts に依存）
- `dev`: 開発サーバ起動（[http://localhost:3000）](http://localhost:3000）)

## Cursor / VS Code behavior

このテンプレは `.vscode/settings.json` を含みます。

- 保存時に Prettier で整形されます
- 保存時に ESLint の autofix が可能な範囲で自動修正されます
- Tailwind class の順序は Prettier により自動で整えられます

必要な拡張機能（推奨）

- ESLint
- Prettier - Code formatter
- Tailwind CSS IntelliSense

## Verify Tailwind class sorting

`app/page.tsx` の `className="..."` の順序を崩してから、次を実行してください。
class の順序が自動的に整えば有効です。

```bash
npx prettier --write app/page.tsx
```

## Scripts

主要コマンド（詳細は package.json を参照）

```bash
npm run dev           # start dev server
npm run lint          # run eslint
npm run lint:fix      # eslint --fix
npm run format        # prettier --write .
npm run format:check  # prettier --check .
npm run check         # format:check + lint
```

## Notes

- `create-next-app --example` は新規作成時にテンプレをコピーするだけです。
  既存プロジェクトへ自動追従はしません（必要なら設定ファイルを適用してください）。
- Prettier の対象外にしたいファイルがある場合は `.prettierignore` を編集してください。
Test for Actions
