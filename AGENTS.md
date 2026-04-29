# AGENTS.md

## 概要

このファイルは `voice-typer` リポジトリ全体に適用する agent 向け恒久ルールです。

実装、レビュー、ドキュメント更新、テスト追加を行う場合は、本ファイルと `docs/development/permanent/` 配下の永続ドキュメントを一次ソースとして扱います。

`voice-typer` は、ElevenLabs Scribe v2 Realtime API を使って Windows 上の任意のアプリへ日本語音声入力を行う常駐アプリです。認識途中のテキストはオーバーレイへリアルタイム表示し、アクティブアプリへの入力は確定セグメント単位で行います。

## 適用範囲と優先順位

このファイルはリポジトリ全体に適用します。

優先順位は以下の通りです。

1. 変更対象ディレクトリ直下または上位階層の `AGENTS.override.md`
2. 変更対象ディレクトリ直下または上位階層の `AGENTS.md`
3. ルートの `AGENTS.md`
4. `docs/development/permanent/` 配下の永続ドキュメント
5. その他の README、メモ、実装中ドキュメント

同一トピックで文書間に矛盾がある場合は、実装前に永続ドキュメントを修正してからコードを変更します。

## 言語と表記

- 原則として日本語で記述します。
- コード、コマンド、ファイルパス、設定キー、API パラメータ、ログキー、例外名は英数字の原文を維持します。
- UI 文字列は日本語を基本とします。
- コード中の識別子は英語を使います。
- 文書では装飾目的の絵文字やアイコン文字を使いません。

## プロジェクト固定方針

- 対象 OS は Windows 11 x64 です。macOS、Linux、モバイル OS は対象外です。
- 初期実装の実装言語は Python 3.12.x に固定します。
- `.python-version`、CI matrix、PyInstaller build 環境、README の開発手順は Python 3.12.x に揃えます。
- Python 3.11 は将来互換候補、Python 3.13 以上は依存ライブラリと PyInstaller の対応確認後の候補として扱います。
- 配布形態は PyInstaller による単一 exe、必要に応じて Inno Setup によるインストーラです。
- 使用 API は ElevenLabs Scribe v2 Realtime API です。
- 使用モデルは `scribe_v2_realtime` を基本とします。
- 認識言語は日本語専用です。
- `language_code` の既定値は `jpn` です。API 側の仕様変更や検証結果に応じて設定で変更可能にします。
- オフライン認識は対象外です。
- アクティブアプリへの入力は、確定セグメントをクリップボードへ入れて `Ctrl+V` を送る方式を MVP の基本とします。
- `SendInput` は best effort として扱います。貼付に失敗した場合でもクラッシュせず、認識済みテキストをクリップボードに残してユーザーへ通知します。

## 外部仕様確認

ElevenLabs API、Win32 API、依存ライブラリの仕様は変わり得るため、実装または文書更新時は一次情報を確認します。

最低限確認すべき一次情報:

- ElevenLabs Realtime Speech to Text API reference: `https://elevenlabs.io/docs/api-reference/speech-to-text/v-1-speech-to-text-realtime`
- ElevenLabs Realtime event reference: `https://elevenlabs.io/docs/eleven-api/guides/how-to/speech-to-text/realtime/event-reference`
- ElevenLabs transcripts and commit strategies: `https://elevenlabs.io/docs/eleven-api/guides/how-to/speech-to-text/realtime/transcripts-and-commit-strategies`
- Microsoft SendInput documentation: `https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput`
- Microsoft RegisterHotKey documentation: `https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey`
- Microsoft clipboard documentation: `https://learn.microsoft.com/en-us/windows/win32/dataxchg/using-the-clipboard`
- Microsoft DPAPI documentation: `https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata`

外部仕様をコードに反映する場合は、可能な限り API contract test を追加します。

## ElevenLabs Realtime API 実装ルール

- WebSocket 接続先は `wss://api.elevenlabs.io/v1/speech-to-text/realtime` です。
- `model_id`、`audio_format`、`language_code`、`commit_strategy`、`vad_silence_threshold_secs`、`vad_threshold`、`min_speech_duration_ms`、`min_silence_duration_ms`、`no_verbatim`、`include_timestamps`、`include_language_detection`、`enable_logging`、`keyterms` は WebSocket の query parameter として渡します。
- 接続後に独自のセッション初期化 JSON を送ってはいけません。
- ElevenLabs Realtime API の接続URL、query parameter、既知イベント名は公式ドキュメントを一次ソースとします。
- raw WebSocket payload のうち、manual commit、エラー payload 詳細、`session_started.config` の実フィールドは `scripts/manual_realtime_smoke.py` で実API確認後、`tests/contract/fixtures/` に固定します。
- `transcriber.py` の本実装は、manual smoke で得た contract fixture を一次ソースとして実装します。文書を写しただけの contract test を一次ソースにしてはいけません。
- デスクトップアプリの MVP では `xi-api-key` ヘッダで認証します。
- ブラウザやクライアントサイド JavaScript から直接接続する実装は対象外です。
- API キーをログに出してはいけません。
- API キーを平文で設定ファイルに保存してはいけません。Windows DPAPI を使ってユーザー単位で暗号化保存します。
- VAD による自動 commit を使う場合は query parameter として `commit_strategy=vad` を指定します。
- `vad_commit_strategy=true` をクライアント送信パラメータとして使ってはいけません。
- `session_started.config` に `vad_commit_strategy` というサーバ側表示名が返る場合がありますが、接続時の指定名とは区別します。

音声チャンクは以下の形式を基本とします。

```json
{
  "message_type": "input_audio_chunk",
  "audio_base_64": "<base64 encoded PCM>",
  "sample_rate": 16000,
  "commit": false
}
```

停止時または補助 commit 時のみ、最後の音声チャンクで `commit: true` を指定します。

`previous_text` は再接続後などの文脈補助に限定し、最初の音声チャンクにのみ付与します。通常の全チャンクに付与してはいけません。

処理対象の受信イベント:

- `session_started`
- `partial_transcript`
- `committed_transcript`
- `committed_transcript_with_timestamps`
- error 系イベント

`speech_started` を前提にした実装をしてはいけません。無音タイムアウトの主判定はローカル音声活動検出で行います。

Realtime API の error type ごとにリトライ可否を分けます。

- `auth_error`、`quota_exceeded`、`unaccepted_terms` は自動リトライしません。
- `rate_limited`、`resource_exhausted` はバックオフして再試行します。
- `queue_overflow`、`chunk_size_exceeded`、`input_error` は実装不備の可能性が高いため、原因をログに残してセッションを停止します。
- `commit_throttled` は manual commit 頻度を下げます。
- `session_time_limit_exceeded` は新規セッション開始または停止をユーザーに案内します。
- `insufficient_audio_activity` は無音扱いで安全に終了します。
- `transcriber_error` は原因、error code、request/session 識別子など本文を含まない詳細をログに残し、既定では自動リトライせずセッションを停止します。payload が既知の一時的障害に分類できる場合のみ、回数上限付きでバックオフ再試行してよいです。
- generic error type の `error` は、本文、音声、APIキーを除いた payload 詳細をログに残し、既定では自動リトライしません。payload が既知の recoverable subtype に対応付けられる場合のみ、その subtype の方針に従います。

## 録音実装ルール

- MVP では待機中にマイクを開きません。待機中のネットワーク接続も行いません。
- ホットキー押下前の音声を取得する真のプリロールは MVP では実装しません。
- ホットキー押下後、録音開始と WebSocket 接続を並行して開始します。
- WebSocket の `session_started` を受信するまでの音声はローカルキューに保持し、接続完了後に順次送信します。
- このキューを `connect_buffer` と呼びます。`preroll` と呼んではいけません。
- 録音 callback では PCM bytes の受け取り、RMS 計算用の軽量処理、固定長 queue への投入のみ行います。
- callback 内で WebSocket 送信、base64 encode、重いリサンプリング、ファイル I/O、ロック待ちが長い処理をしてはいけません。
- 無音タイムアウトはサーバイベントではなくローカル VAD で管理します。
- 100ms チャンクごとに RMS を計算します。
- `local_vad_threshold` を超えたチャンクを音声活動ありとみなします。
- 最後の音声活動から `silence_timeout_sec` が経過した場合、セッションを停止します。
- partial や committed の受信は補助的な活動として扱えますが、主判定にはしません。
- API 送信音声は 16kHz、16bit PCM、モノラルを基本とします。

録音初期化は以下の順序で行います。

1. 16kHz / mono / int16 でデバイスを開く。
2. 失敗した場合、デバイス既定 sample rate で開く。
3. 16kHz へリサンプリングする。
4. リサンプリングも失敗した場合はマイク利用不可として通知する。

## 状態遷移ルール

アプリ状態は中央の state machine で管理します。

必須状態:

- `Idle`
- `Starting`
- `Connecting`
- `Recording`
- `Reconnecting`
- `Flushing`
- `Error`
- `Exiting`

`Recording` から直接 `Idle` へ戻してはいけません。停止時は必ず `Flushing` を経由します。

`Starting` は API キー確認、録音ストリーム開始、WebSocket 接続開始を行う状態です。まだ `session_started` を受け取っておらず、録音チャンクは `connect_buffer` に投入してよいです。

`Connecting` は WebSocket handshake および `session_started` を待つ状態です。`session_started` 受信までは音声をサーバへ送信しません。接続中バッファ上限を超えた場合は、設定ポリシーに従い停止または破棄します。

`Flushing` では以下を行います。

1. 新規音声入力を止める。
2. 未送信チャンクを送信する。
3. 最終チャンクで manual commit を試みる。
4. 最終 committed を最大 `final_commit_wait_ms` 待つ。
5. 貼付キューを drain する。
6. WebSocket と recorder を閉じる。
7. `Idle` へ遷移する。

`Flushing` 中の境界条件:

- `final_commit_wait_ms` を過ぎた後に到着した `committed_transcript` は破棄します。本文はログに出さず、`late_committed_discarded` として件数のみ記録します。
- `Flushing` 中の hotkey 入力は無視し、必要に応じて「確定処理中です」と通知します。
- `Flushing` 中に WebSocket が切断された場合、再接続は試みず、受信済み committed の貼付キュー drain 後に `Idle` へ戻ります。
- `Flushing` 中にアプリ終了要求が来た場合、短い grace period の後に安全終了します。

## クリップボードと貼付

実装対象の貼付モード:

- `auto_paste_restore_text`
- `auto_paste_no_restore`
- `clipboard_only`
- `direct_unicode_input`

MVP の既定値は `auto_paste_restore_text` です。ただし、貼付失敗時は認識結果をクリップボードに残します。

- MVP では `CF_UNICODETEXT` の復元のみ保証します。非テキスト形式の完全復元を保証してはいけません。
- クリップボード復元時は `GetClipboardSequenceNumber` を使い、貼付処理中にユーザーまたは他アプリがクリップボードを変更した場合は古い内容を復元しません。
- `SendInput(Ctrl+V)` の制約を隠してはいけません。README、要求定義、受け入れ条件に明記します。

`SendInput(Ctrl+V)` は以下のケースで失敗し得ます。

- 対象アプリが管理者権限で起動している。
- UAC の secure desktop が表示されている。
- パスワード入力欄、保護された入力欄である。
- 一部ゲーム、仮想デスクトップ、リモートデスクトップ、独自入力欄である。
- 対象アプリが `Ctrl+V` を無効化または独自処理している。
- フォアグラウンドウィンドウが貼付中に変わった。

## ホットキー実装ルール

- toggle の基本実装は Win32 `RegisterHotKey` を優先します。
- Push-to-Talk は押下中とリリースを検出する必要があるため、低レベルキーフックまたは `keyboard` ライブラリを使います。
- `Ctrl+無変換` が押された場合に無変換単体の toggle が二重発火しないようにします。
- 無変換キーは日本語 IME と競合し得るため、ホットキーは設定可能にします。
- ホットキー抑止の有無は `hotkey_suppress_original_key` で設定可能にします。
- ホットキー実装は本実装前に POC で確定します。
- POC では `VK_NONCONVERT` 単独を `RegisterHotKey` で登録できるか、`Ctrl+VK_NONCONVERT` を PTT として扱えるか、Toggle と PTT 併用時に二重発火しないか、`hotkey_suppress_original_key=true` で Toggle 側も抑止できるか、IME の無変換動作と競合しないかを検証します。
- `RegisterHotKey` と低レベルフックの併用で二重発火が解消できない場合、Toggle も低レベルフックへ統一します。

## UI 実装ルール

- オーバーレイはフォーカスを奪ってはいけません。
- Win32 の `WS_EX_NOACTIVATE` と `WM_MOUSEACTIVATE` の `MA_NOACTIVATE` を使います。
- ドラッグ可能領域では常時 `WS_EX_TRANSPARENT` にしないでください。
- マルチモニタでは保存位置が画面外になる場合、最も近いモニタへクランプします。
- 待機中は小さなピル型表示とします。
- 録音中は横長バーを表示し、partial を流します。
- 確定セグメントの貼付状態、再接続中、貼付失敗、API エラーは短いステータスとして表示します。
- partial は暫定結果であり、自動貼付対象ではありません。

## ログとプライバシー

ローカルログに以下を保存してはいけません。

- 音声データ
- partial transcript
- committed transcript
- API キー
- クリップボードの元テキスト

保存してよい情報:

- タイムスタンプ
- 状態遷移
- duration
- error type
- レイテンシ計測値
- 音声チャンク数、queue depth などの非内容メトリクス

本アプリは音声を ElevenLabs API に送信します。この事実を README と要求定義に明記します。

ElevenLabs 側のデータ保持は同社のポリシーと契約プランに従います。Zero Retention Mode は Enterprise 向け機能として扱い、一般ユーザーで利用可能と断定してはいけません。

クリップボード経由で貼付する場合、Windows のクリップボード履歴やクラウド同期に認識テキストが残る可能性があります。このリスクを明記します。

## 設定ファイルルール

- 設定ファイルは `%APPDATA%/voice-typer/config.json` に保存します。
- API キー本体は保存しません。
- `config.json` には `has_api_key`、`api_key_storage` などの状態のみ保存します。
- 設定スキーマには `config_version` を持たせ、将来の migration を可能にします。

## テスト必須項目

unit test:

- config load/save/migration
- API query parameter builder
- audio queue overflow
- local VAD
- state machine
- paste mode
- clipboard sequence guard
- error handling
- hotkey de-duplication

API contract test:

- `commit_strategy=vad` が query parameter として生成される。
- `vad_commit_strategy` を接続パラメータとして送らない。
- keyterms が URL encode される。
- `enable_logging` の意味がローカルログ設定と混同されない。
- 受信イベント `partial_transcript`、`committed_transcript`、error 系を正しく dispatch する。

Windows smoke test:

- GitHub Actions では `windows-latest` を使う。
- 初回準備PRでは `windows-latest` で import smoke、unit test、ruff、mypy を最低限実行する。
- PyInstaller build smoke は `build/voice_typer.spec` と packaging 依存を追加する作業以降に、`build-smoke.yml` または同等の workflow で追加する。
- Linux runner のみで CI 完了としてはいけません。

## 実装順序

大きな実装は以下の順に進めます。

1. ElevenLabs Realtime API の最小 POC
2. 録音パイプライン POC
3. ホットキー POC
4. 貼付 POC
5. state machine と Flushing 実装
6. オーバーレイ、トレイ、設定 UI
7. パッケージングとインストーラ

API、録音、貼付の不確実性を解消する前に UI を作り込んではいけません。

## 禁止事項

- WebSocket 接続後に独自のセッション初期化 JSON を送ること。
- `vad_commit_strategy=true` を接続パラメータとして使うこと。
- `speech_started` イベントを存在前提で実装すること。
- 待機中にユーザーへ明示せずマイクを開くこと。
- 録音 callback 内で WebSocket 送信や重い処理を行うこと。
- API キーを平文保存すること。
- transcript や音声をローカルログへ保存すること。
- `SendInput` による貼付成功を全アプリ保証として書くこと。
- `Recording` から直接 `Idle` へ遷移すること。
- 非テキストのクリップボード形式を完全復元できると断定すること。

## 永続ドキュメント一覧

- `docs/development/permanent/product-requirements.md`
- `docs/development/permanent/functional-design.md`
- `docs/development/permanent/architecture.md`
- `docs/development/permanent/development-guidelines.md`
- `docs/development/permanent/glossary.md`
- `docs/development/permanent/repository-structure.md`

## 開発プロセス

### ステアリング要否

作業開始前に、ステアリング（`docs/development/.steering/` と requirements/implementation-plan/tasklist など）を作成するかを確認します。

ステアリング不要と判断した小規模作業では、後追いでステアリングを作成・更新しません。PR 前の `document-update` でも `docs/development/.steering/steering.md` を更新または作成しません。

### ステアリングを使う作業

- `docs/development/.steering/steering.md` を作業統括ドキュメントとして扱います。
- 作業単位は `docs/development/.steering/[作業ID]-[YYYYMMDD]-[開発タイトル]/` に作成します。
- 作業ディレクトリの基本ファイルは `requirements.md`、必要に応じて `implementation-plan.md`、`tasklist.md` です。
- `requirements.md` は作成後に確認・承認を得てから次へ進みます。
- `implementation-plan.md` を作成する場合は、その作成後に確認・承認を得ます。
- `tasklist.md` は `requirements.md` と必要なら `implementation-plan.md` を元に `tasklist-generator` で生成または更新します。
- ユーザーが明示的に `$autonomous-steering` を起動した作業では、通常の段階承認待ちを routine には挟まなくてよいです。ただし guarded 領域、重大な requirements 曖昧さ、evidence 衝突では停止します。

### ブランチ運用

- main/master への直接 push は禁止です。
- 原則として「1 作業単位 = 1 ブランチ = 1 PR」で運用します。
- 作業着手前に対象作業のブランチを作成して checkout します。
- ブランチ名は原則としてステアリングの `[開発タイトル]` と一致させます。
- ブランチ作成手順は `$branch-create` を優先し、フォールバックとして `git switch -c <branch>` を使います。

### 差分の品質

- 無関係な差分を避けます。
- 差分はタスクに必要なファイルに限定します。
- 新しい util/型/スキーマ/共通関数を追加する前に既存実装を探索します。`$dedupe` を推奨します。
- 大量整形が必要な場合は、理由を PR に明記するか、整形のみの commit と機能変更 commit を分けます。

### 事前確認が必要な変更

以下に該当する場合は、実装前に確認を取ります。

- 本番依存の追加/削除
- UIライブラリの追加
- 大規模リファクタ、repo 全体の整形、タスクと無関係な変更の混入
- 認証/認可、middleware、アクセス制御の変更
- `.github/workflows/*`、CI の挙動、リポジトリ運用ルールの変更
- 新しい環境変数の導入、既存環境変数の意味変更
- 公開されている route / API / 外部参照されるコンポーネントの削除・リネーム
- テスト基盤の差し替えや大幅変更
- `.coderabbit.yaml` の大幅変更

### 標準コマンド

- 開発途中の save point: `$checkpoint-save`
- commit 前の標準フロー: `$precommit`
- PR を作成/更新する前の標準フロー: `$pr-flow`
- PR 作成から CI 待ち: `bash scripts/pr.sh`（無い場合は `gh`）
- リポジトリ構造ドキュメント更新: `bash scripts/tree.sh`

### 完了条件

PR を提案する前、またはタスクを完了とする前に、必ず `$verify-full` を通します。

どれかが失敗した場合は問題を修正し、成功するまで再実行します。

### commit メッセージ規約

コミットメッセージは日本語で書きます。

形式:

```text
<type>(<scope>): <日本語の要約>
```

scope が不要なら以下です。

```text
<type>: <日本語の要約>
```

例:

- `feat(backend): ヘルスチェックAPIを追加`
- `fix(frontend): モバイルでボタンが切れる問題を修正`
- `docs: ステアリング手順を更新`
- `chore: 上記以外の修正`

## skills

このリポジトリでは、長い手順・状況依存の手順は skills に分離します。

- PR前のドキュメント整合: `document-update`
- 開発途中の checkpoint commit/push: `checkpoint-save`
- プレコミット: `precommit`
- 重複検知/統合: `dedupe`
- ローカル差分の事前レビュー: `change-review`
- CodeRabbit CLI による pre-review: `coderabbit-pre-review`
- 不具合調査の入口整理: `bug-investigation`
- 新規 API 追加前の設計整理: `api-add-design`
- 既存 API 変更前の設計整理: `api-modify-design`
- LLM 機能変更前の設計整理: `llm-change-design`
- requirements 品質ゲート: `requirements-quality-gate`
- implementation-plan 生成/更新: `implementation-plan-generator`
- tasklist 生成/更新: `tasklist-generator`
- steering 入口からの opt-in 自律実行: `autonomous-steering`
- PR 提案からマージとローカル `main` 同期まで: `pr-flow`
- 初期セットアップ: `repo-setup`
- Tailwind CSS v4 の導入: `setup-tailwind-frontend`
- skills 棚卸し提案: `skills-retro`
- 速い検証: `verify-fast`
- フル検証: `verify-full`
- ブランチ作成: `branch-create`
- MCP UI再現・スクショ・ログ収集: `mcp-playwright-debug`
- MCP 安全なリファクタ: `mcp-serena-refactor`
- MCP パフォーマンス計測: `mcp-chrome-devtools-perf`
- Supabase CLI ワークフロー: `supabase-cli-workflow`
- Vercel CLI ワークフロー: `vercel-cli-workflow`

## 秘密情報・安全

- PII/秘密情報をログ・例・コメント・テストデータ・PR本文に含めません。
- トークン、API key、認証情報、内部URL などは出力しません。貼られている場合は伏せます。
- 設定に API key が含まれるものは特に注意し、コピペで漏らしません。
