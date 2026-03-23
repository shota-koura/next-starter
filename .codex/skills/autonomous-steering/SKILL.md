---
name: autonomous-steering
description: steering.md と各 steering ディレクトリの requirements.md（推奨）または requirement.md を入口に、autonomous-orchestrator sub-agent と既存 skill 群を使って evidence-based に自律実行を進める opt-in skill
---

# autonomous-steering

## 目的

- `docs/development/.steering/steering.md` と各 steering ディレクトリ内の `requirements.md`（推奨）または `requirement.md` を入口に、既存 skill 群を end-to-end で束ねる。
- 通常フローでは人間確認で停止する `requirements-quality-gate`、`coderabbit-pre-review`、`change-review` などの結果を、`autonomous-orchestrator` が evidence-based に裁定する。
- 明示的に opt-in された作業だけ、routine な承認待ちを省略して進める。

## いつ使うか

- steering と各作業の `requirements.md`（推奨）または `requirement.md` が既に存在し、Codex に自律的に開発を進めさせたいとき。
- 既存 skill を個別に呼ぶのではなく、ready な steering task を 1 本選んで最後まで進めたいとき。
- review findings や requirements の軽微な修正も、repo 影響・一次情報・契約リスクを見たうえで自律裁定したいとき。

## 使わない場面

- steering が未整備で、何を実装すべきか自体が決まっていないとき。
- auth / middleware / migration / deploy / dependency 更新など、guarded 領域の変更が中心の作業。
- 複数 steering task を同時に進める必要があり、write scope の分離ができないとき。

## この skill の役割

- この skill は薄い entrypoint であり、判断の本体は `.codex/agents/autonomous-orchestrator.toml` に委譲する。
- 既存 skill の責務は維持し、順序と停止条件の扱いだけを自律化する。
- 実際の書き込みは親エージェントまたは 1 つの bounded writer sub-agent が行い、evidence 収集 lane は read-only に保つ。

## 前提

- `docs/development/.steering/steering.md` が存在すること。
- 対象 steering ディレクトリに `requirements.md` または `requirement.md` が存在すること。
- `autonomous-orchestrator` と、少なくとも `codex-reviewer`、`planning-reviewer`、`code-mapper` が利用可能であること。
- `coderabbit-pre-review` を使う場合は `coderabbit` CLI が認証済みであること。
- opt-in の自律実行であっても、guarded 領域に触れた場合は停止する。

## 入力

任意:

- `AUTO_STEERING_DIR`: 対象 steering ディレクトリを明示したい場合
- `AUTO_TASK_ID`: `steering.md` 上の作業 ID を明示したい場合

未指定時:

- `autonomous-orchestrator` が `steering.md` を読み、現在ブランチ上の `doing` を優先し、次に依存解決済みの `todo` / `doing` を 1 件だけ選ぶ。

## 実行原則

- user-facing mode は 1 本のみとし、内部では evidence lane を必要時に並列起動する。
- evidence lane は severity ごとではなく、観点ごとに分ける。
- finding の裁定は次の 3 値のみを使う:
  - `AUTO_FIX`
  - `AUTO_DEFER`
  - `STOP`
- どの時点でも write owner は 1 つだけにする。
- 自律判断は steering ディレクトリ内の `autonomous-run.md` に append-only で記録する。

## 標準フロー

1. `steering.md` と対象 `requirements.md`（推奨）または `requirement.md` を特定する。
2. `autonomous-orchestrator` を起動し、ready な task と現在 stage を確定する。
3. requirements 整備:
   - `requirements-quality-gate` を実行する
   - `RR-*` と解決可能な `RQ-*` は evidence を取ったうえで自律反映してよい
   - acceptance / scope / contract を変える曖昧さが残る場合は `STOP`
4. planning 整備:
   - 必要なら `implementation-plan-generator`
   - 必要なら `tasklist-generator`
5. 実装前調査:
   - `dedupe`
   - 必要に応じて `bug-investigation`、`api-add-design`、`api-modify-design`、`llm-change-design`
6. 実装:
   - 親エージェント、または 1 つの bounded writer sub-agent が実装する
7. 開発中検証:
   - `verify-fast`
8. review と evidence merge:
   - `coderabbit-pre-review` と `change-review` を実行する
   - findings が出たら、必要な evidence lane を並列で収集する
   - `autonomous-orchestrator` が `AUTO_FIX` / `AUTO_DEFER` / `STOP` を裁定する
   - `AUTO_FIX` だけを最小差分で修正し、review を再実行する
9. 完了前処理:
   - `document-update`
   - `precommit`
   - `verify-full`
   - `commit`
   - `pr-review-merge`

## evidence lane の選び方

最小セット:

- `planning-reviewer`: requirements / plan / tasklist と受け入れ条件の整合
- `code-mapper`: repo 影響範囲と owning path
- `codex-reviewer`: correctness / regression / test / security

必要時のみ追加:

- `docs-researcher`: 公式仕様やバージョン差異の確認が必要
- `api-designer`: API 契約や migration path が論点
- `llm-architect`: prompt / retrieval / eval / structured output が論点
- `cloud-architect`: runtime / secret / deploy / infra が論点

詳細な判断基準は `references/autonomy-policy.md` を参照する。

## hard stop 条件

以下に触れた場合、自律実行でも停止する。

- `.github/**`
- `.coderabbit.yaml` / `.coderabbit.yml`
- `.env*`
- `package.json` / lockfile / `pyproject.toml` / `requirements*.txt` など依存管理
- auth / authorization / middleware / access control
- destructive な public route / API 変更
- DB migration / backfill / irreversible data change
- secret handling / production runtime / deploy / rollback
- evidence lane 同士の結論が衝突し、安全な裁定ができない場合

## 出力

- 選ばれた steering task
- 実行した stage
- 使った skill / sub-agent
- finding ごとの decision
- 修正した内容、見送った内容、停止理由
- `autonomous-run.md` に追記した要約

## 完了条件

- 1 つの steering task について、実行可否が `AUTO_FIX` / `AUTO_DEFER` / `STOP` の根拠付きで説明できる。
- 自律実行を続行した場合、必要な verify / review / PR 収束まで到達している。
- 停止した場合も、停止理由と再開条件が steering ディレクトリに残っている。
