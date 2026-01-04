import { defineConfig, globalIgnores } from 'eslint/config';
import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTs from 'eslint-config-next/typescript';
import prettier from 'eslint-config-prettier/flat';

export default defineConfig([
  ...nextVitals,
  ...nextTs,

  // Prettierと競合する整形系ルールを無効化（Nextの後ろ）
  prettier,

  // Ignore
  globalIgnores(['.next/**', 'out/**', 'build/**', 'next-env.d.ts']),
]);
