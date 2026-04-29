# 開発ガイドライン（development-guidelines.md）

最終更新: 2026-04-29

## 1. 目的

この文書は voice-typer の開発規約、実装ルール、テスト方針、CI、レビュー観点、ログ、セキュリティ、ドキュメント更新ルールを定義する。

実装者は `AGENTS.md`、`product-requirements.md`、`functional-design.md`、`architecture.md` と合わせて本書を参照する。

## 2. 基本原則

- 安全側に倒す。
- 本文とsecretをログに出さない。
- 外部API仕様を推測で実装しない。
- Windows制約を無視して「必ず貼付できる」と扱わない。
- 音声コールバックを軽く保つ。
- UIスレッドをブロックしない。
- 停止時は必ず `Flushing` を通す。
- テストできる境界に分割する。
- 仕様変更とドキュメント更新を同じ作業に含める。

## 3. Python規約

### 3.1 バージョン

- 初期実装は Python 3.12.x に固定する。
- `.python-version`、CI matrix、PyInstaller build 環境、README の開発手順を Python 3.12.x に揃える。
- Python 3.11 は将来互換候補とする。
- Python 3.13 以上は依存ライブラリとPyInstallerの対応を確認してから対象に含める。

### 3.2 フォーマット

- `black` を使う。
- 行長は100文字を基本にする。
- import順序は `ruff` に従う。

### 3.3 lint

`ruff` で以下を基本ルールにする。

- `E`, `W`: pycodestyle
- `F`: pyflakes
- `I`: import sort
- `B`: bugbear
- `UP`: pyupgrade
- `SIM`: simplify
- `RUF`: ruff固有
- `ANN`: 型ヒント。ただしテストや一部callbackでは必要に応じて緩和。

### 3.4 型ヒント

- 公開関数、公開クラス、公開メソッドに型ヒントを付ける。
- `from __future__ import annotations` を各ファイル冒頭に置く。
- `Any` は原則禁止。
- `Any` が必要な場合は、外部ライブラリ境界など理由をコメントに残す。
- `Literal`、`NewType`、`TypeAlias` を使って設定値と状態を明確化する。
- mypy は strict に近い設定を使う。
- pywin32、sounddevice、pystray、PIL など stub 不足の可能性がある import は module override で `ignore_missing_imports = true` を許容する。
- `voice_typer/windows/*` は Win32 API wrapper として境界モジュールにし、`Any` の流入をアプリ本体へ広げない。

`pyproject.toml` の mypy 方針:

```toml
[tool.mypy]
python_version = "3.12"
strict = true
warn_unused_ignores = true
warn_redundant_casts = true
disallow_any_generics = true
disallow_untyped_defs = true

[[tool.mypy.overrides]]
module = [
  "win32api.*",
  "win32con.*",
  "win32gui.*",
  "win32clipboard.*",
  "sounddevice.*",
  "pystray.*",
  "PIL.*",
]
ignore_missing_imports = true
```

例:

```python
from __future__ import annotations

from typing import Literal, TypeAlias

PasteMode: TypeAlias = Literal[
    "auto_paste_restore_text",
    "auto_paste_no_restore",
    "clipboard_only",
    "direct_unicode_input",
]


def validate_paste_mode(value: str) -> PasteMode:
    """貼付モードの設定値を検証する。"""
    allowed = {
        "auto_paste_restore_text",
        "auto_paste_no_restore",
        "clipboard_only",
        "direct_unicode_input",
    }
    if value not in allowed:
        raise ValueError(f"invalid paste_mode: {value}")
    return value  # type: ignore[return-value]
```

### 3.5 dataclass

- 設定、イベント、音声チャンク、状態遷移には `dataclass(frozen=True)` を基本とする。
- 本文を含むdataclassは `repr=False` を検討する。

例:

```python
from dataclasses import dataclass, field
from datetime import datetime


@dataclass(frozen=True)
class TranscriptSegment:
    segment_id: str
    text: str = field(repr=False)
    received_at: datetime
    sequence_no: int
```

### 3.6 Docstring

- 公開関数と公開クラスには日本語 docstring を書く。
- 形式は Google style を基本とする。
- secretや本文を例示しない。

## 4. モジュール設計ルール

### 4.0 初回準備PR

最初の作業ブランチでは、以下のみを準備PRとして独立させる。

- 既存テンプレートの frontend / backend を削除する。
- `voice_typer/` の最小パッケージ雛形を作る。
- `pyproject.toml`、ruff、black、mypy、pytest の初期設定を追加する。
- 空または最小の CI を追加する。
- 実装ロジックは入れない。

### 4.1 単一責務

| モジュール               | 禁止する責務                                     |
| ------------------------ | ------------------------------------------------ |
| `recorder.py`            | WebSocket送信、base64 encode、UI更新。           |
| `transcriber.py`         | クリップボード操作、SendInput、Tkinter直接更新。 |
| `paster.py`              | 音声処理、API接続。                              |
| `overlay.py`             | API接続、録音制御の直接実装。                    |
| `config.py`              | APIキー平文保持、Win32詳細実装。                 |
| `secure_store.py`        | config全体の読み書き。                           |
| `elevenlabs_protocol.py` | ネットワークI/O。                                |

### 4.2 Windows API分離

- Win32 API の直接呼び出しは `voice_typer/windows/` 配下に置く。
- アプリ本体はラッパー関数を呼ぶ。
- Windows API wrapper は unit test でmockできるようにする。

### 4.3 外部API分離

- ElevenLabs のURL、query parameter、message type、event type は `elevenlabs_protocol.py` に集約する。
- `transcriber.py` に文字列を散在させない。
- API仕様が変わった場合に contract test が落ちるようにする。
- raw WebSocket payload の manual commit、エラーpayload詳細、`session_started.config` の実フィールドは `scripts/manual_realtime_smoke.py` で実API確認後、`tests/contract/fixtures/` に固定する。
- `transcriber.py` の本実装は、この contract fixture を一次ソースとして実装する。
- `config.elevenlabs_enable_logging` から query parameter `enable_logging` への mapping は `elevenlabs_protocol.py` に集約する。
- contract test では query parameter 名が `enable_logging`、config キー名が `elevenlabs_enable_logging`、両者の値が一致することを検証する。

## 5. 非同期、スレッド、キュー

### 5.1 スレッド境界

- Tkinter UI はメインスレッドで更新する。
- WebSocket は asyncio event loop 専用スレッドで扱う。
- sounddevice callback はPortAudio callback threadで動く。
- 貼付は専用ワーカースレッドで直列化する。

### 5.2 音声コールバック

音声コールバックで許可する処理:

- 入力データを bytes にする。
- queueへ投入する。
- overflow flagを立てる。

音声コールバックで禁止する処理:

- base64 encode。
- WebSocket send。
- ファイルI/O。
- UI更新。
- 重いログ出力。
- 長時間ロック。

### 5.3 キュー

- 音声キューは必ず上限付きにする。
- 貼付キューは順序を保持する。
- queue overflow の方針は設定で制御する。
- 初期値は `on_audio_queue_overflow=stop` とする。

### 5.4 ロック

- クリップボード操作は専用ワーカーで直列化する。
- 長時間ロックを保持しない。
- 状態遷移は単一の状態管理オブジェクトで行う。

## 6. ElevenLabs実装ルール

### 6.1 接続

必ず以下を守る。

- endpoint は `wss://api.elevenlabs.io/v1/speech-to-text/realtime`。
- 認証は `xi-api-key` header。
- 設定は query parameter。
- 初期化JSONは送らない。
- `commit_strategy=vad` を使う。
- `vad_commit_strategy` は使わない。
- `session_started.config` の値が要求値と乖離した場合は warning ログのみ出して継続する。
- `commit_strategy` が要求値と乖離した場合のみ、セッションを停止する。

### 6.2 送信

- 送信message typeは `input_audio_chunk`。
- `audio_base_64` に16kHz PCMをbase64 encodeして入れる。
- `sample_rate` は16000。
- 通常チャンクは `commit=false`。
- 停止時または明示commit時のみ `commit=true`。
- manual commit を短時間に連発しない。

### 6.3 受信

処理対象:

- `session_started`
- `partial_transcript`
- `committed_transcript`
- `committed_transcript_with_timestamps`
- エラーイベント

禁止:

- `speech_started` を必須イベントとして扱う。
- partial を貼付する。
- unknown event でクラッシュする。

### 6.4 エラー処理

| エラー                        | 実装ルール                                             |
| ----------------------------- | ------------------------------------------------------ |
| `auth_error`                  | 即停止。リトライしない。                               |
| `quota_exceeded`              | 即停止。リトライしない。                               |
| `unaccepted_terms`            | 即停止。リトライしない。                               |
| `rate_limited`                | バックオフ。連続時は停止。                             |
| `resource_exhausted`          | バックオフ。                                           |
| `queue_overflow`              | 送信設定異常として停止。                               |
| `chunk_size_exceeded`         | チャンク設定を見直す必要があるため停止。               |
| `input_error`                 | audio format、sample rate、message format を疑い停止。 |
| `insufficient_audio_activity` | 無音扱いで停止してよい。                               |
| `commit_throttled`            | manual commit頻度を下げる。                            |
| `session_time_limit_exceeded` | セッションを終了する。                                 |
| `transcriber_error`           | 本文を含まない詳細をログに残し、既定では停止。既知の一時的障害に分類できる場合のみ回数上限付きでバックオフ。 |
| `error`                       | generic error。既定では停止。payload が既知の recoverable subtype に対応する場合のみ、その subtype の方針に従う。 |

## 7. 状態遷移ルール

### 7.1 必須状態

- `Idle`
- `Starting`
- `Connecting`
- `Recording`
- `Reconnecting`
- `Flushing`
- `Error`
- `Exiting`

### 7.2 禁止遷移

- `Recording -> Idle` の直接遷移は禁止。
- `Reconnecting -> Idle` の直接遷移は禁止。
- `Connecting -> Idle` はユーザー停止またはエラー時でも、必要に応じてcleanup状態を通す。

### 7.3 Flushing

`Flushing` では以下を順に実行する。

1. 新規録音を止める。
2. キュー内の未送信チャンクを送る。
3. manual commit を送る。
4. 最終 committed を待つ。
5. 貼付キューを drain する。
6. WebSocket を閉じる。
7. recorder を閉じる。
8. UIをIdleへ戻す。

各ステップはタイムアウトを持つ。

境界条件:

- `final_commit_wait_ms` を過ぎた後に到着した `committed_transcript` は破棄する。
- 破棄した場合、本文はログに出さず `late_committed_discarded` として件数のみ記録する。
- `Flushing` 中の hotkey 入力は無視する。
- `Flushing` 中に WebSocket が切断された場合、再接続は試みない。
- `Flushing` 中にアプリ終了要求が来た場合、短い grace period の後に安全終了する。

## 8. クリップボードと貼付ルール

### 8.1 モード

実装対象:

- `auto_paste_restore_text`
- `auto_paste_no_restore`
- `clipboard_only`

予約値:

- `direct_unicode_input`

未実装の予約値が設定された場合は、起動時に明確なエラーにするか、安全に `clipboard_only` へfallbackする。どちらを採用するかは実装時に固定し、テストする。

### 8.2 復元

- 復元対象は `CF_UNICODETEXT` のみ。
- 非テキスト形式の完全復元を実装済みと主張しない。
- 貼付処理中に sequence number が想定外に変わった場合は復元しない。
- committed text 設定直後の sequence number と復元直前の sequence number が一致する場合のみ復元する。
- クリップボード本文をログに出さない。

### 8.3 貼付失敗

- SendInputの戻り値が0の場合は失敗とみなす。
- 戻り値が成功でも、実際に貼付されたことは完全には検証できない。
- 失敗時は committed text をクリップボードに残す。
- 通知文は本文を含めない。

### 8.4 テスト

- クリップボード操作は抽象化してmockする。
- Windows実クリップボードを使うテストは `windows` marker を付ける。
- CIでは実クリップボードテストを最小限にする。

## 9. ローカルVADルール

- サーバの `speech_started` イベントに依存しない。
- RMSベースで音声活動を判定する。
- `local_vad_threshold` を超えたチャンクが `local_vad_min_active_chunks` 回連続した場合のみ活動と判定する。
- 閾値は設定可能にする。
- 無音タイムアウトはローカルVADで発火する。
- partial受信は補助的にactivity扱いしてもよいが、主判定にしない。
- PTT 押下中は `silence_timeout_sec` を無効化する。
- `Reconnecting` 中は activity 計測を継続してよいが、`silence_timeout_sec` による自動停止は一時停止し、`reconnect_buffer_sec` をハード上限にする。

## 10. 設定管理ルール

### 10.1 config

- config path は `%APPDATA%/voice-typer/config.json`。
- JSONとして読み書きする。
- `config_version` を必須にする。
- migration は `_migrate(version: int, raw: dict[str, object]) -> dict[str, object]` の dispatch 形式とする。
- v1 では identity migration とする。
- v2 以降では `_migrate_v1_to_v2` のような段階関数を追加する。
- 起動時にバリデーションする。
- 破損時は `.bak` を作り、初期設定を再生成する。

### 10.2 APIキー

- configに平文保存しない。
- DPAPIで保存する。
- `has_api_key` で有無だけを管理する。
- MVPの主経路は `scripts/set_api_key.py` とする。
- トレイの Set API key は、このCLIまたは最小入力ダイアログを起動するだけにする。
- DPAPI entropy は固定文字列を使い、ユーザー単位スコープに依存する。

### 10.3 設定値検証

検証対象:

- VAD値の範囲。
- keyterms件数と長さ。
- paste mode。
- target window policy。
- hotkey文字列。
- queue上限。
- timeout値。
- log level。

## 11. ログ規約

### 11.1 ログレベル

| レベル    | 用途                                   |
| --------- | -------------------------------------- |
| `DEBUG`   | 開発時のみ。本文とsecretは禁止。       |
| `INFO`    | 状態遷移、開始、停止、接続、貼付結果。 |
| `WARNING` | 貼付失敗、unknown event、再接続。      |
| `ERROR`   | API認証失敗、マイク失敗、重大エラー。  |

### 11.2 禁止データ

ログに出してはいけない。

- APIキー。
- 音声データ。
- partial text。
- committed text。
- クリップボード本文。
- keyterms内容。
- 入力対象のウィンドウタイトル。

### 11.3 許可データ

- エラー種別。
- duration。
- queue depth。
- state name。
- event type。
- keyterms count。
- config version。
- masked API key suffix。ただし必要時のみ。

### 11.4 ログローテーション

- 1ファイル上限を設定する。
- 世代数を設定する。
- 古いログを自動削除する。
- 既定値は `max_bytes=5MB`、`backup_count=5` とする。

## 12. テスト規約

### 12.1 テスト方針

- pure logic はunit testで網羅する。
- 外部APIはmockする。
- API仕様はcontract testで固定する。
- Windows APIはwrapperをmockしてunit testし、最小限のWindows smoke testを別に置く。
- 実APIを使うテストは手動扱いにする。

### 12.2 ディレクトリ

```text
tests/
├── unit/
├── contract/
├── integration/
├── windows/
└── manual/
```

### 12.3 marker

| marker    | 意味                                         |
| --------- | -------------------------------------------- |
| `windows` | Windows runner 専用。                        |
| `manual`  | 手動実行。CIでは実行しない。                 |
| `network` | 実ネットワークを使う。CIでは原則実行しない。 |
| `slow`    | 時間がかかる。                               |

### 12.4 必須テスト

#### config

- 初期設定生成。
- 破損config backup。
- version migration。
- keyterms検証。
- paste mode検証。

#### secure store

- DPAPI wrapper が呼ばれる。
- APIキーがconfigに保存されない。
- 取得失敗時のエラー。

#### protocol

- endpoint。
- query parameter。
- `commit_strategy=vad`。
- `vad_commit_strategy` 非存在。
- `commit_strategy=manual` は MVP では `ConfigError`。
- keyterms encode。
- audio message encode。
- event parse。
- `config.elevenlabs_enable_logging` が query parameter `enable_logging` に写像される。

#### state

- 正常開始。
- 正常停止。
- Flushing。
- Flushing 中 hotkey 無視。
- final待機タイムアウト後の遅延 committed 破棄。
- Flushing 中 WebSocket 切断時に再接続しない。
- reconnect。
- error。
- exit。

#### audio

- chunk生成。
- queue overflow。
- RMS。
- silence timeout。
- PTT中は silence timeout が無効。
- Reconnecting中は `reconnect_buffer_sec` 上限が優先される。

#### clipboard and paste

- 各 paste mode。
- sequence変更時の復元抑止。
- committed text 設定直後 sequence と復元直前 sequence が一致する場合のみ復元。
- SendInput失敗。
- clipboard lock。
- 直前1件の committed segment と空白正規化後に完全一致した場合のみ重複破棄。
- foreground が自プロセスの場合に `last_known_target_hwnd` へfallback。

### 12.5 テストでの本文扱い

- テスト用の文字列は機密ではない固定文のみ使う。
- テスト失敗時のassert messageにAPIキーや実クリップボード本文を含めない。
- snapshot test に本文やsecretを含めない。

## 13. CI規約

### 13.1 必須CI

`.github/workflows/ci.yml` に以下を入れる。

- ubuntu-latest で ruff check。
- ubuntu-latest で black check。
- ubuntu-latest で mypy。
- ubuntu-latest と windows-latest で pytest unit。
- ubuntu-latest と windows-latest で pytest contract。
- windows-latest で import smoke。

### 13.2 runner

- `ubuntu-latest` は lint/typecheck の主runnerとする。
- `windows-latest` は unit/contract、Windows import smoke、Windows wrapper smoke に使う。

### 13.3 secrets

- CIに実ElevenLabs APIキーを標準では置かない。
- 実APIテストはmanual workflowにする。
- secretsをログに出さない。

### 13.4 build smoke

- PyInstaller build smoke は毎PRでは実行しない。
- `build-smoke.yml` として nightly または `workflow_dispatch` で実行する。
- `windows-smoke.yml` は手動または main push で clipboard wrapper、hotkey wrapper、DPAPI smoke を実行する。

## 14. 手動検証規約

### 14.1 POC順序

実装は以下の順で検証する。

1. ElevenLabs Realtime API POC。
2. 録音パイプライン POC。
3. ホットキー POC。
4. 貼付 POC。
5. 状態管理とFlushing。
6. オーバーレイ、トレイ、設定、パッケージング。

ElevenLabs Realtime API POC では `scripts/manual_realtime_smoke.py` を実行し、manual commit、エラーpayload詳細、`session_started.config` の actual schema を `tests/contract/fixtures/` に固定してから `transcriber.py` の本実装へ進む。

ホットキー POC では、`VK_NONCONVERT` 単独 `RegisterHotKey`、`Ctrl+VK_NONCONVERT` PTT、Toggle/PTT二重発火、`hotkey_suppress_original_key=true` の抑止、IME競合、IME の無変換キー機能や IME ON/OFF を意図せず奪わないかを1日程度で検証する。失敗パターンが見つかった場合は Toggle も低レベルフックへ統一する案を採用する。

### 14.2 E2E対象アプリ

- Notepad。
- Word。
- Chrome input。
- Chrome textarea。
- Google Docs。
- Slack。
- Teams。
- VSCode。
- Notion。
- 管理者権限で起動したNotepad。
- パスワード入力欄。

### 14.3 検証観点

- 貼付できるか。
- 貼付できない場合にクリップボードへ残るか。
- 元のテキストクリップボードが復元されるか。
- 画像やファイルをコピーしていた場合の注意が妥当か。
- フォーカスを奪わないか。
- 無変換キーがIME操作と競合しないか。
- PTTとToggleが二重発火しないか。
- 停止直前の発話が落ちないか。

## 15. セキュリティ規約

### 15.1 secret

- APIキーを平文保存しない。
- APIキーをprintしない。
- APIキーを例外messageに含めない。
- APIキーをテストフィクスチャに含めない。

### 15.2 privacy

- 発話本文をログに出さない。
- クリップボード本文をログに出さない。
- ウィンドウタイトルも原則ログに出さない。
- 本文を含むオブジェクトの `repr` に注意する。

### 15.3 clipboard

- クリップボード履歴に残る可能性をREADMEに書く。
- `clipboard_only` は認識結果が残ることを明示する。
- 機密入力向けには将来 `sensitive_mode` を検討する。

## 16. ドキュメント更新規約

### 16.1 更新が必要な場合

以下の場合は恒久ドキュメントを更新する。

- 要件が変わった。
- APIパラメータが変わった。
- 状態遷移が変わった。
- 設定項目が追加、変更、削除された。
- モジュール構成が変わった。
- Windows制約への対応方針が変わった。
- セキュリティ方針が変わった。

### 16.2 ファイル別更新

| 変更内容                         | 更新対象                    |
| -------------------------------- | --------------------------- |
| ユーザー価値、範囲、受け入れ条件 | `product-requirements.md`   |
| API、状態遷移、機能詳細          | `functional-design.md`      |
| 技術スタック、スレッド、CI、配布 | `architecture.md`           |
| コーディング規約、テスト規約     | `development-guidelines.md` |
| 用語、命名                       | `glossary.md`               |
| ファイル構成                     | `repository-structure.md`   |
| agent向け恒久ルール              | `AGENTS.md`                 |

### 16.3 外部仕様確認

以下は変更前に公式情報を確認する。

- ElevenLabs API endpoint。
- query parameter。
- message type。
- event type。
- error type。
- pricingやkeyterms追加料金。
- Zero Retention Mode。
- Microsoft Win32 API 制約。

## 17. PRチェックリスト

PR作成前に確認する。

- ruffが通る。
- blackが通る。
- mypyが通る。
- pytestが通る。
- API contract testsが通る。
- Windows smoke testへの影響を確認した。
- 本文やAPIキーがログに出ない。
- 状態遷移でFlushingを省略していない。
- クリップボード復元が安全側である。
- 貼付失敗時にテキストが失われない。
- ドキュメント更新が必要な変更では、該当文書を更新した。
- `repository-structure.md` が構造変更に追随している。

## 18. コマンド例

### 18.1 セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
```

### 18.2 開発実行

```bash
python -m voice_typer
```

### 18.3 品質チェック

```bash
python -m ruff check .
python -m black --check .
python -m mypy voice_typer
python -m pytest
```

### 18.4 Windows smoke

```bash
python -m pytest tests/windows -m windows
```

### 18.5 build smoke

```bash
python -m PyInstaller build/voice_typer.spec --noconfirm
```

## 19. 実装上の注意例

### 19.1 避ける例

```python
# 録音callback内で重い処理をする例。禁止。
def callback(indata, frames, time, status):
    encoded = base64.b64encode(indata.tobytes())
    websocket.send(encoded)
```

### 19.2 推奨例

```python
# callbackではqueue投入だけにする。
def callback(indata, frames, time, status):
    try:
        audio_queue.put_nowait(indata.tobytes())
    except queue.Full:
        overflow_flag.set()
```

### 19.3 避ける例

```python
# partialを貼付してしまう例。禁止。
if event["message_type"] == "partial_transcript":
    paste_queue.put(event["text"])
```

### 19.4 推奨例

```python
if event.message_type == "partial_transcript":
    overlay_events.put(PartialUpdated(text=event.text))
elif event.message_type == "committed_transcript":
    paste_queue.put(TranscriptSegment(text=event.text, ...))
```

## 20. リリース前チェック

- 初回起動時にconfigが生成される。
- APIキー未設定時に録音開始できない。
- APIキーがDPAPI保存される。
- Notepadへ貼付できる。
- `clipboard_only` が動作する。
- 管理者権限アプリへの貼付失敗時に結果が残る。
- 無音タイムアウトが動作する。
- WebSocket切断時に再接続または停止する。
- Stop時に`Flushing`を通る。
- ログに本文とAPIキーがない。
- PyInstaller版で起動する。
- トレイから終了できる。
