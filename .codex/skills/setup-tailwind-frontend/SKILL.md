---
name: setup-tailwind-frontend
description: 新しく追加された frontend（workspace/package）で Tailwind CSS v4 を使えるようにする（Vite は @tailwindcss/vite、その他は PostCSS 経由）
---

## 目的

- 新規/追加された frontend（例: `extension/` のような Vite + React、将来追加される別 frontend）で、Tailwind CSS が「書ける」かつ「ビルドで反映される」状態にする。
- リポジトリのルートに Tailwind が入っていても、frontend/package 単位で統合（Vite プラグイン or PostCSS、CSS 入口、import）が未設定だと反映されないため、パッケージ単位で揃える。

## いつ使うか

- 新しい frontend ディレクトリ（`package.json` を持つ）が増えたとき。
- 既存 frontend で「Tailwind クラスを書いても効かない」状態のとき。

## 入力（この skill 内で使う変数）

- `<pkg>`: 対象パッケージ名（例: `extension`）
- `<pkgDir>`: 対象ディレクトリ（例: `extension/`）
- `<cssEntry>`: 対象 UI が読み込むグローバル CSS（例: `src/index.css` / `src/style.css` / `src/sidepanel/styles.css` など）
- `<uiEntry>`: CSS を import しているエントリ（例: `src/main.tsx` / `src/sidepanel/main.tsx` など）

## 方針（重要）

- 差分は最小にする（UIや既存CSSの大規模置換はしない）。
- 既存の CSS は削除せず温存する（追記または import で併用する）。
- 依存追加は「対象パッケージの devDependencies」に明示的に入れる（hoisting 任せにしない）。
- Tailwind v4 前提:
  - CSS 入口は `@import "tailwindcss";` を使う。
  - v3 の `@tailwind base; @tailwind components; @tailwind utilities;` は使わない。
- 既存の設定ファイルがある場合は「追記のみ」で、無関係な変更はしない。

## 手順

### 0) 対象が「frontend package」か確認

- `<pkgDir>` 直下に `package.json` があること
- 使用ツールを確認する（例）
  - Vite: `vite.config.*` がある、または依存に `vite` がある
  - Next.js: 依存に `next` がある

### 1) 統合方式を選ぶ

- Vite の場合: 原則 `@tailwindcss/vite` を使う（推奨）。
- Vite 以外（Next.js 等）や既に PostCSS 運用が固まっている場合: `@tailwindcss/postcss` を使う。

以降、該当する手順のみ実施する。

### 2-A) Vite の場合（推奨: @tailwindcss/vite）

#### 2-A-1) 依存追加

```bash
npm -w <pkg> i -D tailwindcss @tailwindcss/vite
```

#### 2-A-2) Vite 設定にプラグインを追加

`<pkgDir>/vite.config.ts`（または `vite.config.js/mjs`）に以下を反映する。

- 既に `plugins: [...]` がある場合は、配列に `tailwindcss()` を追加する。
- 既存プラグインの順序が重要そうな場合は、基本は「既存を崩さず」追加のみ行う。

例:

```ts
import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [
    tailwindcss(),
    // 既存の plugins を維持
  ],
});
```

### 2-B) PostCSS の場合（@tailwindcss/postcss）

#### 2-B-1) 依存追加（postcss を含める）

```bash
npm -w <pkg> i -D tailwindcss @tailwindcss/postcss postcss
```

#### 2-B-2) PostCSS 設定を追加/更新

`<pkgDir>/postcss.config.mjs` が無ければ作成し、以下にする。

```js
const config = {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};

export default config;
```

既に存在する場合:

- `plugins` に `"@tailwindcss/postcss"` が入っているか確認し、無ければ追加する。
- `tailwindcss` を PostCSS プラグインとして直接指定しない（v4 では別パッケージに移動しているため）。

### 3) Tailwind の CSS 入口を用意する（既存 CSS は温存）

原則として「既に UI が import している `<cssEntry>`」を CSS 入口として使う。

#### 3-1) `<cssEntry>` の先頭に Tailwind を import（最小変更）

`<cssEntry>` の先頭に以下を追加する（既存の内容はそのまま残す）。

```css
@import 'tailwindcss';
```

補足:

- 既存 CSS を削除しない。
- 既に `@import "tailwindcss";` がある場合は追加しない。

#### 3-2) monorepo で検出が不安定な場合（必要な時のみ）

ビルド/実行のカレントディレクトリが monorepo の root になり、クラス検出が期待通りに動かない場合は、`source()` を使って基準パスを明示する。

例（CSS ファイルから見たスキャン基準を指定する）:

```css
@import 'tailwindcss' source('../..');
```

- `source("...")` のパスは `<cssEntry>` の位置に合わせて調整する。

#### 3-3) 自動検出されない場所を追加でスキャンしたい場合（必要な時のみ）

`.gitignore` 対象や `node_modules` 配下など、Tailwind が自動検出しない領域をスキャンしたい場合は `@source` を追加する。

例:

```css
@source '../shared';
@source '../node_modules/@my-company/ui-lib';
```

- これは追加登録であり、通常は不要。効かない時の手段として使う。

### 4) UI エントリで CSS が読み込まれていることを確認

`<uiEntry>` に `<cssEntry>` の import が存在することを確認する。

例:

```ts
import './index.css';
```

- 既に import されているなら変更不要。
- import が無い場合のみ、1 行追加する（既存の import 順序は崩さない）。

### 5) 最小検証

対象パッケージでビルド（または dev）を実行する。

```bash
npm -w <pkg> run build
```

必要なら dev:

```bash
npm -w <pkg> run dev
```

目視確認:

- UI 上の一箇所だけ Tailwind クラスを付与して変化を見る（デバッグ用途）。
- 追加した場合は「戻す」か「意図として残す」かを明確にする。

## 完了条件

- `<pkg>` の `npm -w <pkg> run build` が成功する。
- 対象 UI で Tailwind のユーティリティが反映される（目視で確認できる）。
- 既存 CSS や既存 UI の大規模変更が混入していない。

## トラブルシュート（よくある）

### Tailwind が効かない

- `<cssEntry>` が `<uiEntry>` から import されているか
- `<cssEntry>` に `@import "tailwindcss";` があるか
- Vite の場合:
  - `vite.config.*` に `@tailwindcss/vite` が入っているか

- PostCSS の場合:
  - `<pkgDir>/postcss.config.mjs` が存在し、`"@tailwindcss/postcss"` が入っているか

### ビルドが落ちる（PostCSS 関連のエラー）

- `tailwindcss` を PostCSS プラグインとして直接指定していないか
  - v4 は `"@tailwindcss/postcss"` を使う

- `<pkg>` の devDependencies に `postcss` が入っているか（hoisting に依存していないか）

### monorepo でクラス検出が不安定

- `@import "tailwindcss" source("...")` を使ってスキャン基準パスを明示する
- 追加で必要な場所のみ `@source` を登録する
