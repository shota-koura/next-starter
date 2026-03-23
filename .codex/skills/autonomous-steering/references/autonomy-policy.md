# autonomy-policy

## 決定クラス

- `AUTO_FIX`
  - 根拠が十分
  - 変更範囲が局所または bounded
  - local verify で閉じられる
  - guarded 領域に触れない

- `AUTO_DEFER`
  - 今回の acceptance criteria を満たすうえで blocking ではない
  - defer 理由を具体的に残せる
  - 後続作業への切り出しが可能

- `STOP`
  - evidence が衝突する
  - requirements / contract / auth / migration / rollout に重大な曖昧さが残る
  - live 環境が必要
  - guarded 領域に触れる

## evidence lane と主な用途

- `planning-reviewer`
  - requirements、implementation-plan、tasklist の不整合
- `code-mapper`
  - 変更箇所、所有境界、影響範囲
- `codex-reviewer`
  - correctness、regression、security、test coverage
- `docs-researcher`
  - 公式仕様、version-specific behavior
- `api-designer`
  - request/response、互換性、migration path
- `llm-architect`
  - workflow、eval、cost/latency tradeoff
- `cloud-architect`
  - runtime、secret、deploy、operational boundary

## run log の最低項目

- 日時
- 対象 steering dir
- 現在 stage
- evidence lane
- issue id
- decision
- reason
- next action

## write owner ルール

- 判定 lane は read-only にする
- 同時に複数 writer を動かさない
- writer を使った場合、親エージェントが verify と統合を担当する
