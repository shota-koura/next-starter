---
name: skills-retro
description: push/一区切り後に Codex セッション履歴と現行 skills を棚卸しし、追加/改修候補を docs/recomend-skills/ に提案書として出力する
metadata:
  short-description: skill提案の自動生成（提案書のみ）
---

## 目的

- Codex CLI のやり取り履歴（直近セッション）から「繰り返し発生した手順」「判断ポイント」を抽出し、
  - 新規 skill 化候補
  - 既存 skill の改修候補
    を提案として残す。
- ただし **この skill は .codex/skills 自体を変更しない（提案書出力のみ）**。

## いつ使うか

- push した直後
- PR作成前の一区切り
- 作業が一段落して「次回の自動化/標準化」を考えたいとき

## 出力先

- 既定: `docs/recomend-skills/`
- ここに「提案書Markdown」を出力する。

## 環境変数（任意）

- OUTPUT_DIR: 出力先（デフォルト `docs/recomend-skills`）
- LOOKBACK_HOURS: 履歴の対象時間（デフォルト `24`）
- MAX_PROPOSALS: 提案上限（デフォルト `5`）
- SESSION_ID: 対象セッションを明示したい場合（無ければ “このrepoの直近” を推定）
- SPLIT_FILES: `1` なら新規/改修をファイル分割（デフォルト `0`）

## ガードレール（必須）

- **履歴の生テキスト（transcript）を提案書へ貼り付けない。**
  - 提案書には “要約” と “手順/設計” のみを書く。
- APIキー/トークン/秘密情報らしき文字列が見えたら、提案書側では必ず伏字（`[REDACTED]`）にする。
- 既存 skill の改修提案はしてよいが、勝手に改修コミットはしない。
- 無関係な整形やファイル移動はしない（提案書の追加のみ）。

## 手順

### 0) repo root と出力先の確認

- `git rev-parse --show-toplevel` で repo root を取得する。
- `OUTPUT_DIR`（デフォルト `docs/recomend-skills`）を `mkdir -p` で作る。

### 1) 既存 skills の棚卸し（必須）

- `.codex/skills/**/SKILL.md` を走査し、各 skill の `name` と `description` を一覧化する。
- 以降の提案では必ずこの一覧と突き合わせ、重複（既存で代替可能）なら新規提案しない。

### 2) Codex セッション履歴の取得（ベストエフォート）

- `CODEX_HOME`（通常 `~/.codex`）配下を参照し、直近セッションを推定する。
  - 参考: `~/.codex/history.jsonl` に transcript が保存されることがある。
  - 参考: `~/.codex/sessions/` 配下にセッションが保存され、ID指定で再開できる。
- `SESSION_ID` が指定されていればそれを優先する。
- 履歴が無効化されている/読めない場合は、以下だけで提案を作る:
  - `git diff --name-only`
  - `git log -1 --oneline`
  - 実行した検証コマンド（ユーザーが覚えている範囲）を確認して要約

### 3) 履歴から “skill化候補” を抽出する観点

- 同じコマンド列やチェックリストが複数回出てきた（例: 状態確認→特定のverify→差分確認→…）
- いつも同じ判断で止まる（例: lockfileが混ざったら止める、CIログ抽出、など）
- 名前付け・配置・探索が毎回発生する（例: 新規追加前の検索、置き場判断）
- PR本文・スクショ・メトリクス作成などの “毎回やるが忘れる” 作業

### 4) 提案の生成（新規 / 改修）

- 最大 `MAX_PROPOSALS` 件までに絞る（薄い提案は出さない）。
- 新規提案は以下を含める:
  - skill名（衝突しない短い名前）
  - description（いつ使うかが分かる1文）
  - 手順（ガードレール込み）
  - 完了条件
  - 可能なら “SKILL.md 草案” をコードブロックで添付
- 改修提案は以下を含める:
  - 対象 skill
  - 望ましい変更点（最小差分）
  - その理由（履歴上の詰まり/重複/抜け）

### 5) docs/recomend-skills/ に Markdown 出力

- ファイル名: `YYYYMMDD_HHMM__skills-retro.md`
- `SPLIT_FILES=1` の場合:
  - `YYYYMMDD_HHMM__new__<skill>.md`
  - `YYYYMMDD_HHMM__update__<skill>.md`
    も併せて作る。

### 6) 変更確認

- `git status -sb` で提案書だけが増えていることを確認して終了。

## 提案書（docs/recomend-skills）のテンプレ例

提案書は “後で採用して skill に落とす” のが目的なので、最低限これがあると運用が回ります。

````md
---
date: 2026-01-24
source: skills-retro
scope: new-skill | update-skill
status: proposed
---

# 概要

- 何を標準化/自動化したいか

# 観測された繰り返し（履歴由来の要約）

- （生ログは貼らない。要約のみ）

# 提案

## 1) 新規 skill: <name>（または既存 skill: <name> の改修）

- 目的
- いつ使うか
- ガードレール
- 手順
- 完了条件

## SKILL.md 草案（新規の場合）

```md
---
name: ...
description: ...
---
```
````
