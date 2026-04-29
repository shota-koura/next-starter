# プロダクト要求定義書（product-requirements.md）

最終更新: 2026-04-29

## 1. プロダクト概要

voice-typer は、Windows ユーザーが任意のアプリケーションに対して、ホットキー操作で日本語音声入力を行える常駐型ディクテーション支援ツールである。

ElevenLabs Scribe v2 Realtime API を使い、録音中の暫定認識結果をオーバーレイへ表示し、VADまたは手動コミットで確定したテキストを、アクティブウィンドウへ貼付またはクリップボードへ保存する。

本プロダクトは、Aquavoice や Superwhisper のような「どのアプリにも素早く音声入力できる体験」を Windows 上で提供することを目指す。ただし、Windows の入力注入、権限、クリップボード仕様の制約により、自動貼付は best effort として扱う。

## 2. ビジョン

Windows 上で文章を書くユーザーが、キーボード入力、IME操作、アプリごとの音声入力機能を意識せず、現在使っているアプリに対して自然に話すだけで日本語テキストを入力できる状態を作る。

## 3. 解決する課題

- Windows 標準の音声入力では、専門用語、固有名詞、長文の句読点、話し言葉の整形に不満が残ることがある。
- macOS 向けには軽快な音声入力アプリが存在する一方、Windows で同等の体験を得にくい。
- Word、Slack、ブラウザ、VSCode、Notion など、アプリごとに入力手段を切り替えるのは煩雑である。
- 長文作成時、タイピングによる身体的負担と認知負荷が大きい。
- クラウド音声認識の利用料金を抑えるため、停止忘れや無音継続を避けたい。
- クリップボード経由で貼付する音声入力ツールでは、既存クリップボードの破壊やクリップボード履歴への残留が不安になる。

## 4. 提供価値

- グローバルホットキーから即座に録音を開始できる。
- 認識途中の内容をオーバーレイで確認できる。
- 確定したテキストをセグメント単位で対象アプリへ自動貼付できる。
- 自動貼付を使わず、クリップボード保存のみで安全に使うこともできる。
- 日本語専用の設定により、最小限のUIで利用できる。
- keyterms により、固有名詞や専門用語を認識バイアスとして登録できる。
- 無音タイムアウトとエラー時停止により、不要なAPI利用を抑制できる。
- APIキーをユーザー自身が管理し、アプリ自体は軽量なローカルツールとして運用できる。

## 5. ターゲットユーザー

### 5.1 主要ターゲット

- 日本語で長文を書く Windows ユーザー。
- ライター、研究者、エンジニア、企画職、コンサルタント、営業、サポート担当など、文章作成頻度が高いユーザー。
- macOS の Aquavoice や Superwhisper の体験を Windows でも求めるユーザー。
- ElevenLabs API キーを自分で取得、設定できるテックリテラシー層。
- Word、Google Docs、Slack、Teams、Notion、VSCode、ブラウザ入力欄など複数アプリをまたいで入力したいユーザー。

### 5.2 非ターゲット

- macOS または Linux 専用ユーザー。
- 完全オフライン動作を求めるユーザー。
- 医療、法務、金融など、音声データを外部クラウドへ送信できない厳格な環境。
- チーム単位の権限管理、監査ログ、管理者配布を求めるエンタープライズ用途。
- 多言語認識、翻訳、議事録要約を主目的とするユーザー。
- すべてのアプリへ確実に直接入力できることを必須要件とするユーザー。

## 6. MVP スコープ

### 6.1 MVP に含める

| 項目               | 内容                                                                    |
| ------------------ | ----------------------------------------------------------------------- |
| 対応OS             | Windows 10 / 11 x64                                                     |
| 認識言語           | 日本語専用                                                              |
| 録音開始           | グローバルホットキー Toggle                                             |
| Push-to-Talk       | グローバルホットキー長押し                                              |
| 音声認識           | ElevenLabs Scribe v2 Realtime API                                       |
| commit             | `commit_strategy=vad` を基本とし、停止時に manual commit を補助的に使う |
| 暫定表示           | partial をオーバーレイに表示                                            |
| 自動貼付           | committed をクリップボード経由で貼付                                    |
| クリップボード保存 | 自動貼付しない `clipboard_only` モードを提供                            |
| クリップボード復元 | テキスト形式を対象に best effort で復元                                 |
| 自動停止           | ローカルVADに基づく無音タイムアウト                                     |
| APIキー保護        | Windows DPAPI で暗号化保存                                              |
| 常駐               | システムトレイ常駐                                                      |
| 設定               | JSON設定ファイルと最小限のトレイ操作                                    |
| ログ               | 本文を含まないイベントログとメトリクス                                  |

### 6.2 MVP に含めない

| 項目                               | 理由                                            |
| ---------------------------------- | ----------------------------------------------- |
| macOS / Linux 対応                 | Windows 固有API前提のため                       |
| 多言語切替                         | MVPでは日本語体験を優先                         |
| オフライン認識                     | Scribe v2 Realtime API を前提とするため         |
| 翻訳                               | 音声入力に集中するため                          |
| 要約、整形AI                       | まず入力体験を安定させるため                    |
| 話者分離                           | 個人ディクテーション用途では不要                |
| 常時マイクプリバッファ             | プライバシーとユーザー不安が大きいため          |
| 非テキストクリップボードの完全復元 | Win32クリップボードの実装負荷とリスクが高いため |
| 管理者権限アプリへの貼付保証       | Windows の UIPI 制約により保証不可              |
| GUI設定画面                        | 初期実装ではJSON設定とトレイ操作で十分          |
| 企業向け管理機能                   | 個人ツールとして設計するため                    |

## 7. 主要機能

| ID    | 機能                 | 概要                                                                                  |
| ----- | -------------------- | ------------------------------------------------------------------------------------- |
| FR-1  | グローバルホットキー | Toggle と Push-to-Talk で録音を操作する。                                             |
| FR-2  | 録音パイプライン     | ホットキー押下後に録音を開始し、16kHz PCM へ正規化する。                              |
| FR-3  | 接続中バッファ       | WebSocket 接続完了までの音声をローカルキューに保持し、接続後に順次送信する。          |
| FR-4  | Realtime 文字起こし  | ElevenLabs Realtime WebSocket へ音声チャンクを送信する。                              |
| FR-5  | partial 表示         | 暫定認識結果をオーバーレイに表示する。                                                |
| FR-6  | committed 貼付       | 確定セグメントを貼付キューへ投入し、対象アプリへ貼付する。                            |
| FR-7  | クリップボードモード | 自動貼付、復元、保存のみなどのモードを提供する。                                      |
| FR-8  | ローカルVAD自動停止  | ローカル音声活動が一定時間ない場合に停止する。                                        |
| FR-9  | Flushing             | 停止時に未送信音声、manual commit、最終確定結果、貼付キューを処理してからIdleへ戻る。 |
| FR-10 | 再接続               | 接続断時に短時間の音声を保持し、文脈補助付きで再接続する。                            |
| FR-11 | keyterms             | 専門用語や固有名詞を最大50件まで設定できる。                                          |
| FR-12 | システムトレイ       | 常駐状態、開始、停止、終了、設定ファイルを開く操作を提供する。                        |
| FR-13 | 設定管理             | JSON設定とDPAPI secret store を管理する。                                             |
| FR-14 | ログとメトリクス     | 発話本文を含めず、状態遷移と性能計測を記録する。                                      |

## 8. 機能要件詳細

### FR-1 グローバルホットキー

#### 要件

- Toggle ホットキーで録音開始と停止を切り替える。
- Push-to-Talk ホットキーでは、押下中のみ録音し、リリースで停止する。
- 初期値は以下を基本とする。
  - Toggle: `nonconvert`
  - Push-to-Talk: `ctrl+nonconvert`
- 無変換キーは IME 操作と競合する可能性があるため、設定で変更可能にする。
- 無変換キーは既定候補であり、成立性はホットキー POC で検証する。
- 登録不可または IME 競合が強い場合、既定ホットキーを別候補へ変更できるようにする。
- Toggle と Push-to-Talk の二重発火を防ぐ。
- Toggle 実装は Win32 `RegisterHotKey` を第一候補にする。
- Push-to-Talk 実装は低レベルキーフックまたは `keyboard` ライブラリを使う。

#### 受け入れ条件

- Toggle を1回押すと録音が開始する。
- Toggle を録音中に押すと `Flushing` を経て停止する。
- Push-to-Talk を押している間だけ録音する。
- `ctrl+nonconvert` 押下時に `nonconvert` Toggle が同時発火しない。
- ホットキー登録に失敗した場合、エラー表示とログを残し、アプリは継続する。

### FR-2 録音パイプライン

#### 要件

- ホットキー押下直後に録音を開始する。
- 16kHz、16bit、mono、little-endian PCM を送信形式とする。
- 100ms単位を基本チャンクとする。
- 録音コールバック内では、PCM bytes をキューへ投入するだけにする。
- base64 encode、WebSocket送信、RMS計算は録音コールバック外で行う。
- 16kHzでマイクを開けない場合は、デバイス既定サンプルレートで開き、16kHzへリサンプリングする。
- リサンプリングにも失敗した場合、マイク利用不可として通知する。

#### 受け入れ条件

- 正常なマイク環境で100ms単位のPCMチャンクを生成できる。
- 録音コールバックでネットワークI/Oを行わない。
- 16kHz非対応デバイスでも、fallbackまたは明確なエラー通知が行われる。
- キューが満杯になった場合、設定されたポリシーに従って停止または古いチャンク破棄を行う。
- セッション開始時点の既定入力デバイスを使い、セッション中の既定デバイス変更には追従しない。
- セッション中にデバイスハンドルが無効化された場合はマイク失敗として停止し、可能な範囲で `Flushing` を実行する。
- 次回録音開始時に、その時点の既定入力デバイスを再取得する。

### FR-3 接続中バッファ

#### 要件

- ホットキー押下前の音声は取得しない。
- ホットキー押下後、WebSocket接続が完了するまでの音声を接続中バッファへ保持する。
- `session_started` 受信後、接続中バッファの音声チャンクを古い順に送信する。
- バッファ上限を超えた場合は、古いチャンクを破棄するか停止する。初期値は停止とする。

#### 受け入れ条件

- WebSocket接続前に話し始めても、接続中の音声が可能な範囲で送信される。
- 待機中にマイクは開かれない。
- バッファ上限超過時の動作がログに残る。

### FR-4 Realtime 文字起こし

#### 要件

- WebSocket エンドポイントは `wss://api.elevenlabs.io/v1/speech-to-text/realtime` を使う。
- APIキーは `xi-api-key` ヘッダで送る。
- 以下の値は query parameter として送る。
  - `model_id=scribe_v2_realtime`
  - `language_code=jpn`
  - `audio_format=pcm_16000`
  - `commit_strategy=vad`
  - `vad_silence_threshold_secs`
  - `vad_threshold`
  - `min_speech_duration_ms`
  - `min_silence_duration_ms`
  - `no_verbatim`
  - `include_timestamps`
  - `include_language_detection`
  - `enable_logging`
  - `keyterms`
- 独自の初期化JSONメッセージは送らない。
- 音声送信メッセージは `message_type=input_audio_chunk` を使う。
- 停止時は必要に応じて `commit=true` を含む最終チャンクまたはcommit用メッセージを送る。
- `previous_text` は再接続後の最初の音声チャンクにのみ付与できる。50文字未満を目安にする。

#### 受け入れ条件

- 接続URLが現行のAPI仕様に沿って生成される。
- `vad_commit_strategy` という不正パラメータを送らない。
- `commit_strategy=manual` は MVP では設定不正として扱う。
- API認証エラー時にリトライを続けない。
- `partial_transcript`、`committed_transcript`、`committed_transcript_with_timestamps`、エラーイベントを処理できる。
- 未知イベントは安全に無視またはwarning出力される。

### FR-5 partial 表示

#### 要件

- partial はオーバーレイ表示にのみ使う。
- partial は対象アプリへ貼付しない。
- partial は確定前の結果であり、後から変わる可能性があるものとして扱う。
- オーバーレイはフォーカスを奪わない。
- オーバーレイはドラッグ移動でき、位置を永続化する。

#### 受け入れ条件

- 録音中に partial が視認できる。
- partial 表示によりアクティブアプリのフォーカスが失われない。
- partial が貼付されない。

### FR-6 committed 貼付

#### 要件

- committed は確定セグメントとして扱う。
- 空文字列、空白のみ、重複セグメントは貼付しない。
- 重複判定は直前1件の committed segment との完全一致に限定する。
- 比較前に前後空白を除去し、連続空白を単一空白へ正規化する。
- セッション全体との比較、部分一致、類似度判定、NFKC 正規化は MVP では行わない。
- committed は受信順に貼付キューへ投入する。
- 貼付キューは専用ワーカーで処理する。
- 貼付対象は `target_window_policy` に従う。
- 初期値は `foreground_at_commit` とする。
- 貼付時に foreground window が変わった場合の挙動を設定で制御できる。
- `Recording` 開始時に foreground window を `last_known_target_hwnd` として保存する。
- committed 受信時の foreground window が自プロセスの overlay、tray、config window の場合、`last_known_target_hwnd` へフォールバックする。
- target hwnd が存在しない、無効、最小化、入力不可、または権限制約で `SendInput` できない場合は貼付失敗として扱う。
- 貼付失敗時は committed text をクリップボードに残す。

#### 受け入れ条件

- Notepad など標準的なテキスト入力欄へ確定テキストを貼付できる。
- 貼付失敗時にテキストが失われない。
- 貼付失敗時に通知される。
- 複数 committed が順序通り貼付される。

### FR-7 クリップボードモード

#### 要件

`paste_mode` として以下を提供する。

| 値                        | 動作                                                                                              |
| ------------------------- | ------------------------------------------------------------------------------------------------- |
| `auto_paste_restore_text` | committed をクリップボードへ置き、Ctrl+V を送信し、可能なら元のテキストクリップボードを復元する。 |
| `auto_paste_no_restore`   | committed をクリップボードへ置き、Ctrl+V を送信し、認識結果をクリップボードに残す。               |
| `clipboard_only`          | 自動貼付せず、committed をクリップボードへ保存する。                                              |
| `direct_unicode_input`    | 将来候補。クリップボードを使わず Unicode 入力を試す。MVPでは実験扱いまたは未実装。                |

#### 受け入れ条件

- `clipboard_only` では対象アプリへキー入力を送らない。
- `clipboard_only` は標準利用モードではなく、安全モード、診断モード、貼付不能環境向けの代替モードとする。
- `auto_paste_restore_text` ではテキスト形式の元クリップボードを可能な範囲で復元する。
- テキスト復元は `CF_UNICODETEXT` のみ、かつ clipboard sequence guard が成功した場合のみ行う。
- 非テキスト形式の完全復元を保証しないことが仕様に明記されている。
- 貼付処理中にクリップボード sequence が変わった場合、古い内容を復元しない。

### FR-8 ローカルVAD自動停止

#### 要件

- 各録音チャンクのRMSを計算する。
- RMSが `local_vad_threshold` を超えた場合、音声活動ありとする。
- 実際の活動確定は、閾値超過チャンクが `local_vad_min_active_chunks` 回連続した場合に限定する。
- 音声活動が `silence_timeout_sec` 継続して検出されない場合、自動停止する。
- サーバイベントの `speech_started` には依存しない。
- 自動停止はコスト保護として働く。
- PTT 押下中は `silence_timeout_sec` を無効化する。
- Toggle録音中は `silence_timeout_sec` をローカルVADで有効にする。

#### 受け入れ条件

- 無音状態が設定秒数続くと停止する。
- 小さな環境音だけではタイマーが過剰にリセットされない。
- partialが返らない無音セッションでも停止できる。

### FR-9 Flushing

#### 要件

- 停止操作後は `Flushing` 状態へ移行する。
- `Flushing` 中は新規録音を停止する。
- 未送信チャンクを送る。
- manual commit を送る。
- `final_commit_wait_ms` まで最終 committed を待つ。
- 貼付キューを drain する。
- WebSocket を閉じる。
- UIをIdleへ戻す。
- `final_commit_wait_ms` を過ぎた後に到着した committed は破棄する。
- 破棄した場合、本文はログに出さず `late_committed_discarded` として件数のみ記録する。
- `Flushing` 中のホットキー入力は無視し、必要に応じて「確定処理中です」と通知する。
- `Flushing` 中に WebSocket が切断された場合、再接続は試みず、受信済み committed の貼付キュー drain 後に `Idle` へ戻る。

#### 受け入れ条件

- 停止直前の発話が落ちにくい。
- 最終 committed が貼付されてから Idle へ戻る。
- final待機がタイムアウトしてもアプリは復帰する。
- final待機タイムアウト後に遅延到着した committed が貼付されない。
- Flushing中の再押下で新規録音が始まらない。

### FR-10 再接続

#### 要件

- WebSocket が切断された場合、`Reconnecting` へ移行する。
- 切断直後から最大 `reconnect_buffer_sec` 分の音声をローカルキューに保持する。
- バッファ上限を超えた場合は録音を停止するか古い音声を破棄する。初期値は停止とする。
- 再接続後の最初のチャンクには、直近 committed の末尾を `previous_text` として付与できる。
- `previous_text` は50文字未満を目安とする。
- `Reconnecting` 中はローカルVADの activity 計測を継続してよいが、`silence_timeout_sec` による自動停止は一時停止する。
- `reconnect_buffer_sec` を `Reconnecting` のハード上限とする。
- `reconnect_buffer_sec` を超えた場合は再接続失敗として停止し、未認識音声が失われ得ることを通知する。

#### 受け入れ条件

- 短いネットワーク切断から復帰できる。
- 再接続中であることがオーバーレイに表示される。
- 長い切断では無制限に音声を溜めない。

### FR-11 keyterms

#### 要件

- `keyterms` を設定ファイルで指定できる。
- 最大50件、各20文字以内をバリデーションする。
- `enable_keyterms=false` の場合は送信しない。
- keyterms 使用時は追加料金が発生し得ることを設定例とREADMEで明記する。

#### 受け入れ条件

- 不正な keyterms は起動時に検出される。
- URL encode が正しく行われる。
- 無効化時には query parameter に keyterms を含めない。

### FR-12 システムトレイ

#### 要件

- アプリはバックグラウンド常駐する。
- トレイメニューから以下を操作できる。
  - Start
  - Stop
  - Open config
  - Open logs
  - Set API key
  - Exit
- 状態に応じてトレイ表示を更新する。
- 終了時は録音、WebSocket、ホットキー、トレイ、オーバーレイを安全に解放する。

#### 受け入れ条件

- トレイから終了できる。
- 録音中に終了した場合も `Flushing` または安全な停止処理が行われる。

### FR-13 設定管理

#### 要件

- 設定ファイルは `%APPDATA%/voice-typer/config.json` に置く。
- APIキー本体はDPAPIで暗号化し、設定ファイルに平文保存しない。
- 設定には `config_version` を持たせる。
- 破損した設定ファイルはバックアップして初期設定を再生成する。
- 設定値は起動時にバリデーションする。

#### 受け入れ条件

- 初回起動時に設定ファイルが生成される。
- APIキー未設定時は録音開始できず、設定を促す。
- MVPのAPIキー設定主経路は `scripts/set_api_key.py` とする。
- トレイの Set API key は、このCLIまたは最小入力ダイアログを起動するだけにする。
- 設定破損時にアプリがクラッシュしない。

### FR-14 ログとメトリクス

#### 要件

- ログには本文、音声、APIキー、クリップボード本文を出さない。
- 以下のメトリクスを記録する。
  - `hotkey_pressed_at`
  - `recorder_started_at`
  - `websocket_connected_at`
  - `session_started_at`
  - `first_audio_sent_at`
  - `first_partial_received_at`
  - `committed_received_at`
  - `paste_completed_at`
  - `state_transition`
  - `error_type`
- ログローテーションを行う。

#### 受け入れ条件

- 性能評価に必要な時刻が記録される。
- 認識本文がログに含まれない。
- APIキーがマスクされる。

## 9. 非機能要件

### 9.1 性能

| 指標                                | 目標           |
| ----------------------------------- | -------------- |
| ホットキー押下 -> 録音UI表示        | p95 200ms以内  |
| ホットキー押下 -> WebSocket接続完了 | p95 1500ms以内 |
| first audio sent -> first partial   | p95 1000ms以内 |
| committed受信 -> 貼付完了           | p95 300ms以内  |
| 録音チャンク間隔                    | 100ms基本      |
| 待機中ネットワーク通信              | 0              |
| 待機中マイク利用                    | 0              |

外部APIとネットワーク品質に依存する値は、初期実装後に実測で調整する。

### 9.2 信頼性

- 無音時に自動停止する。
- WebSocket切断時に再接続または明確な停止を行う。
- 貼付失敗時にテキストを失わない。
- クリップボード復元は安全側に倒す。
- 録音キューや送信キューの上限を設ける。
- 例外でUIスレッドを停止させない。

### 9.3 セキュリティ

- APIキーをDPAPIで保護する。
- APIキーをログに出さない。
- 発話本文をログに出さない。
- クリップボード履歴に残る可能性をユーザーに明示する。
- ElevenLabs 側のデータ保持は同社の契約条件と設定に依存することを明示する。

### 9.4 プライバシー

- 待機中にマイクを開かない。
- ホットキー押下後だけ録音する。
- 本文は必要期間だけメモリ上に保持する。
- sensitive mode を将来追加できる設計にする。
- `clipboard_only` 使用時は、認識結果がクリップボードへ残ることを明示する。

### 9.5 ユーザビリティ

- 操作はホットキー中心にする。
- 認識中であることが一目でわかる。
- 再接続中、貼付失敗、APIキー未設定、クォータ不足が明確に通知される。
- オーバーレイはフォーカスを奪わない。
- オーバーレイはアクティブモニタまたは保存位置に表示される。

### 9.6 保守性

- モジュール責務を分離する。
- API連携は contract test を持つ。
- Windows固有APIは `voice_typer/windows/` 配下に分離する。
- 外部API仕様変更時に修正箇所が限定されるようにする。

## 10. 制約

### 10.1 Windows入力制約

- `SendInput` は UIPI の制約を受ける。
- 通常権限アプリから管理者権限アプリへ入力注入できるとは限らない。
- `SendInput` がUIPIで失敗した場合、失敗原因を戻り値だけで特定できないことがある。
- 対象アプリが Ctrl+V を無効化している場合、自動貼付は失敗する。

### 10.2 クリップボード制約

- クリップボードは複数フォーマットを同時に持つことがある。
- 新しいテキストをクリップボードへ置く際、既存の非テキスト形式を失う可能性がある。
- テキスト以外のクリップボード完全復元はMVPでは保証しない。
- Windows のクリップボード履歴やクラウド同期に認識結果が残る可能性がある。

### 10.3 API制約

- ElevenLabs API の仕様、価格、利用可能な機能は変更され得る。
- keyterms 使用時は追加料金が発生し得る。
- Zero Retention Mode の利用可否は契約プランに依存する。
- `commit_strategy=vad` でも、長時間無停止で話し続けると committed のタイミングが遅れる可能性がある。
- MVPでは `commit_strategy=manual` の常時運用を提供しない。
- manual commit を短時間に過剰送信すると throttling の対象になり得る。

## 11. ユーザーストーリー

### US-1 通常の音声入力

ユーザーとして、文章を書いている最中にホットキーを押すだけで録音を開始し、話した内容を現在の入力欄へ入れたい。これにより、キーボード入力へ戻ることなく文章作成を続けられる。

受け入れ条件:

- ホットキーで録音が開始する。
- オーバーレイに認識途中のテキストが表示される。
- 確定したテキストが対象アプリへ貼付される。
- 停止時に最後の発話が可能な範囲で確定される。

### US-2 クリップボードだけに保存

ユーザーとして、貼付対象アプリを壊したくない場合や入力欄が特殊な場合に、音声認識結果をクリップボードへ保存するだけにしたい。

受け入れ条件:

- `paste_mode=clipboard_only` で自動貼付が行われない。
- 確定テキストがクリップボードに残る。
- ユーザーが手動で任意の場所へ貼付できる。

### US-3 専門用語の認識

ユーザーとして、プロジェクト名、製品名、人名などを辞書登録し、認識精度を上げたい。

受け入れ条件:

- `keyterms` に最大50件まで登録できる。
- 長すぎる用語は起動時に検出される。
- keyterms の追加コストについて設定例で確認できる。

### US-4 停止忘れ防止

ユーザーとして、録音停止を忘れても、無音が続いたら自動停止してほしい。

受け入れ条件:

- ローカルVADにより無音を判定する。
- 設定秒数の無音で停止する。
- 停止時は `Flushing` を経て最終確定を試みる。

### US-5 貼付失敗時の安全性

ユーザーとして、貼付に失敗しても認識結果を失いたくない。

受け入れ条件:

- 自動貼付に失敗した場合、認識結果はクリップボードへ残る。
- ユーザーへ貼付失敗が通知される。
- アプリはクラッシュしない。

### US-6 機密性のある入力

ユーザーとして、ログや設定ファイルにAPIキーや発話内容を残したくない。

受け入れ条件:

- APIキーはDPAPIで暗号化される。
- 発話本文がログへ保存されない。
- クリップボード履歴に残る可能性が明記される。

## 12. 受け入れ条件一覧

### AC-1 API接続

- APIキーが設定されている場合、ElevenLabs Realtime WebSocket へ接続できる。
- 接続時のパラメータは query parameter として送られる。
- `session_started` を受信できる。
- `vad_commit_strategy` は使われない。

### AC-2 音声入力

- マイクから音声チャンクを取得できる。
- 16kHz PCM として送信できる。
- partial が表示される。
- committed が貼付キューへ入る。

### AC-3 貼付

- 通常権限のテキスト入力欄へ committed を貼付できる。
- 貼付失敗時に committed がクリップボードへ残る。
- クリップボード復元がユーザー操作を上書きしない。

### AC-4 停止

- Toggle 停止、PTT リリース、自動停止のすべてで `Flushing` を通る。
- 最終 committed を待つ。
- タイムアウト後は安全に Idle へ戻る。

### AC-5 エラー

- `auth_error` はリトライしない。
- `quota_exceeded` はリトライしない。
- `rate_limited` はバックオフする。
- `input_error` は送信設定エラーとして停止する。
- 不明エラーでもアプリはクラッシュしない。

### AC-6 セキュリティ

- APIキーは平文保存されない。
- ログに本文が残らない。
- ログにAPIキーが残らない。

### AC-7 Windows smoke

- 初回準備PRでは Windows runner で import smoke と unit test が通る。
- 実装対象が追加された後は、pywin32、sounddevice、websockets、tkinter、pystray の relevant な import smoke が通る。
- PyInstaller build smoke は packaging 作業で `build/voice_typer.spec` と packaging 依存を追加した後に通る。

## 13. 初期設定例

```json
{
  "config_version": 1,
  "api_key_storage": "dpapi",
  "has_api_key": false,
  "language_code": "jpn",
  "model_id": "scribe_v2_realtime",
  "audio_format": "pcm_16000",
  "commit_strategy": "vad",
  "vad_silence_threshold_secs": 1.2,
  "vad_threshold": 0.4,
  "min_speech_duration_ms": 100,
  "min_silence_duration_ms": 100,
  "no_verbatim": true,
  "include_timestamps": false,
  "include_language_detection": false,
  "elevenlabs_enable_logging": true,
  "enable_keyterms": true,
  "keyterms": [],
  "hotkey_toggle": "nonconvert",
  "hotkey_ptt": "ctrl+nonconvert",
  "hotkey_suppress_original_key": false,
  "paste_mode": "auto_paste_restore_text",
  "paste_delay_ms": 200,
  "paste_timeout_ms": 1500,
  "target_window_policy": "foreground_at_commit",
  "audio_chunk_ms": 100,
  "audio_queue_max_chunks": 50,
  "on_audio_queue_overflow": "stop",
  "local_vad_threshold": 500,
  "silence_timeout_sec": 180,
  "reconnect_buffer_sec": 3,
  "final_commit_wait_ms": 2500,
  "overlay_enabled": true,
  "overlay_position": null,
  "startup_enabled": false,
  "local_log_level": "INFO"
}
```

## 14. 成功指標

### 14.1 定量指標

- 1回のホットキー操作で録音開始できる成功率が高い。
- 通常入力欄への貼付成功率が高い。
- 貼付失敗時にテキスト喪失が発生しない。
- 無音タイムアウトにより停止忘れが防止される。
- p95レイテンシが性能目標内に収まる。
- 発話本文を含むログ出力が0件である。

### 14.2 定性指標

- ユーザーが「現在録音中かどうか」を迷わない。
- ユーザーが「貼付できなかったが、クリップボードには残っている」と理解できる。
- クリップボード復元の限界が明確である。
- APIキーやクラウド送信に関する不安が説明で軽減される。

## 15. リスクと対策

| リスク               | 影響                       | 対策                                                   |
| -------------------- | -------------------------- | ------------------------------------------------------ |
| API仕様変更          | 接続不能、認識不能         | contract test、公式ドキュメント確認、API層分離         |
| Windows UIPI         | 管理者権限アプリへ貼付不可 | best effort 明記、失敗時クリップボード保持             |
| クリップボード破壊   | ユーザーのコピー内容喪失   | `clipboard_only`、sequence確認、テキスト復元限定の明記 |
| 待機中マイク不安     | ユーザー不信               | MVPでは待機中マイクを開かない                          |
| 無音判定不安定       | 停止忘れ、誤停止           | ローカルVAD閾値を設定可能にする                        |
| WebSocket切断        | 音声欠落                   | 短時間バッファと再接続、長時間は停止                   |
| final committed 欠落 | 末尾発話が貼付されない     | `Flushing` 状態で待機する                              |
| APIキー漏洩          | セキュリティ事故           | DPAPI、マスク、ログ禁止                                |
| keyterms追加コスト   | 想定外課金                 | `enable_keyterms` と注意表示                           |
| Zero Retention 誤解  | プライバシー誤認           | 契約プラン依存と明記                                   |
