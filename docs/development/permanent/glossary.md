# 用語集（glossary.md）

最終更新: 2026-04-29

## 1. 目的

この文書は voice-typer で使う用語、コード上の命名、意味、避けるべき言い換えを定義する。

実装、ドキュメント、ログ、UI文言で同じ概念に異なる名前を使わないための一次ソースである。

## 2. プロダクト用語

| 日本語             | コード上の表現      | 説明                                                                        |
| ------------------ | ------------------- | --------------------------------------------------------------------------- |
| voice-typer        | `voice_typer`       | 本アプリケーション。Windows用日本語音声入力ツール。                         |
| 音声入力           | `dictation`         | ユーザーの発話をテキスト化し、貼付または保存する行為。                      |
| セッション         | `session`           | 録音開始から停止完了までの一連の処理。複数の確定セグメントを含み得る。      |
| 確定セグメント     | `TranscriptSegment` | 1つの committed event から作る貼付対象テキスト単位。                        |
| 待機中             | `Idle`              | マイクもWebSocketも開いていない通常状態。                                   |
| 録音中             | `Recording`         | マイク入力を取得し、WebSocketへ音声を送っている状態。                       |
| 確定中             | `Flushing`          | 停止後、未送信音声、manual commit、最終結果、貼付キューを処理している状態。 |
| 再接続中           | `Reconnecting`      | WebSocket切断後に短時間の音声を保持しながら接続復旧を試みる状態。           |
| 自動貼付           | `auto_paste`        | 確定テキストをクリップボードへ置き、Ctrl+Vを送る処理。                      |
| クリップボード保存 | `clipboard_only`    | 自動貼付せず、認識結果をクリップボードに保存するモード。                    |
| 安全モード         | `clipboard_only`    | 入力対象アプリを壊したくない場合の推奨モード。                              |

## 3. 音声認識用語

| 日本語           | コード上の表現                       | 説明                                                                                  |
| ---------------- | ------------------------------------ | ------------------------------------------------------------------------------------- |
| 暫定テキスト     | `partial` / `partial_transcript`     | 確定前の認識結果。オーバーレイ表示だけに使い、貼付しない。                            |
| 確定テキスト     | `committed` / `committed_transcript` | commit 後の認識結果。貼付またはクリップボード保存の対象。                             |
| commit           | `commit`                             | 音声セグメントを確定させる処理。                                                      |
| VAD commit       | `commit_strategy=vad`                | ElevenLabs側の音声活動検出により自動でcommitする方式。                                |
| manual commit    | `commit=true`                        | クライアント側が明示的にcommitを要求する方式。停止時の補助に使う。                    |
| サーバVAD        | `server_vad`                         | ElevenLabs側のVAD。commit判断に使う。                                                 |
| ローカルVAD      | `local_vad`                          | アプリ側のRMS判定。無音タイムアウトとコスト保護に使う。                               |
| RMS              | `rms`                                | PCMサンプルの二乗平均平方根。音量の簡易指標。                                         |
| 無音タイムアウト | `silence_timeout`                    | ローカル音声活動が一定時間ない場合に停止する仕組み。                                  |
| 音声チャンク     | `AudioChunk`                         | 一定時間分のPCMデータ。MVPでは100msを基本とする。                                     |
| 接続中バッファ   | `connect_buffer`                     | ホットキー押下後、WebSocket接続完了までの音声を保持するキュー。`preroll` と呼ばない。 |
| 再接続バッファ   | `reconnect_buffer`                   | WebSocket切断中に短時間だけ音声を保持するキュー。                                     |
| true preroll     | `pre_hotkey_preroll`                 | ホットキー押下前の音声を保持する方式。MVPでは採用しない。                             |
| previous text    | `previous_text`                      | 再接続後の文脈補助として最初の音声チャンクに付与する直近確定テキスト末尾。            |
| keyterms         | `keyterms`                           | 認識バイアス用語。最大50件、各20文字以内を基本とする。                                |

## 4. ElevenLabs API 用語

| 用語                                                 | 説明                                                                   |
| ---------------------------------------------------- | ---------------------------------------------------------------------- |
| `scribe_v2_realtime`                                 | 使用するRealtime STTモデルのID。                                       |
| `wss://api.elevenlabs.io/v1/speech-to-text/realtime` | Realtime WebSocket endpoint。                                          |
| `xi-api-key`                                         | APIキーを送るヘッダ。                                                  |
| `model_id`                                           | 接続時query parameter。MVPでは `scribe_v2_realtime`。                  |
| `language_code`                                      | 接続時query parameter。MVPでは日本語の `jpn`。                         |
| `audio_format`                                       | 接続時query parameter。MVPでは `pcm_16000`。                           |
| `commit_strategy`                                    | 接続時query parameter。MVPでは `vad` のみ許可し、`manual` は将来候補。 |
| `vad_silence_threshold_secs`                         | サーバVADが無音とみなしてcommitするまでの秒数。                        |
| `vad_threshold`                                      | サーバVADの音声活動閾値。                                              |
| `min_speech_duration_ms`                             | サーバVADの最小音声継続時間。                                          |
| `min_silence_duration_ms`                            | サーバVADの最小無音継続時間。                                          |
| `no_verbatim`                                        | フィラーや言い淀み除去の指定。                                         |
| `include_timestamps`                                 | timestamp付きcommittedを受けるかどうか。MVPではfalse。                 |
| `include_language_detection`                         | 言語検出を含めるかどうか。MVPではfalse。                               |
| `enable_logging`                                     | ElevenLabs側のlogging設定。Zero Retention Modeの利用可否は契約依存。   |
| `input_audio_chunk`                                  | クライアントから送る音声チャンクメッセージ。                           |
| `audio_base_64`                                      | base64 encoded PCM。                                                   |
| `sample_rate`                                        | 送信音声のサンプルレート。MVPでは16000。                               |
| `session_started`                                    | WebSocket接続確立後に受信するイベント。                                |
| `partial_transcript`                                 | 暫定認識結果イベント。                                                 |
| `committed_transcript`                               | 確定認識結果イベント。                                                 |
| `committed_transcript_with_timestamps`               | timestamp付き確定認識結果イベント。                                    |

## 5. 使わないAPI用語

| 使わない表現          | 理由                                                            | 正しい表現                              |
| --------------------- | --------------------------------------------------------------- | --------------------------------------- |
| `vad_commit_strategy` | 現行APIの接続パラメータではない。                               | `commit_strategy=vad`                   |
| `speech_started`      | Realtime event reference の基本受信イベントとして前提にしない。 | ローカルVADの `voice_activity_detected` |
| セッション初期化JSON  | 接続設定はquery parameterで送る。                               | 接続URL query parameter                 |
| 真のプリロール        | MVPでは待機中マイクを開かない。                                 | 接続中バッファ                          |

## 6. 状態用語

| 状態           | 説明                                  | 主な入口                     | 主な出口                                           |
| -------------- | ------------------------------------- | ---------------------------- | -------------------------------------------------- |
| `Idle`         | 待機中。マイク、WebSocketなし。       | 起動完了、flush完了。        | ホットキー開始。                                   |
| `Starting`     | 録音開始と接続準備。                  | ホットキー開始。             | `Connecting`。                                     |
| `Connecting`   | WebSocket接続中。音声はbufferへ保持。 | recorder started。           | `Recording`、`Reconnecting`、`Flushing`、`Error`。 |
| `Recording`    | 録音、送信、受信、貼付を実行。        | `session_started`。          | `Flushing`、`Reconnecting`。                       |
| `Reconnecting` | 接続断から復旧中。                    | WebSocket切断。              | `Recording`、`Flushing`、`Error`。                 |
| `Flushing`     | 停止処理中。finalと貼付を処理。       | stop、PTT release、timeout。 | `Idle`、`Error`。                                  |
| `Error`        | ユーザー対応が必要な異常。            | 認証失敗等。                 | `Idle`。                                           |
| `Exiting`      | 終了処理中。                          | Exit。                       | プロセス終了。                                     |

## 7. UI用語

| 日本語         | コード上の表現         | 説明                                          |
| -------------- | ---------------------- | --------------------------------------------- |
| オーバーレイ   | `overlay`              | 画面上に表示する非アクティブ小ウィンドウ。    |
| 待機表示       | `idle_overlay`         | Idle時の小さい表示。                          |
| 録音表示       | `recording_overlay`    | Recording時の表示。                           |
| 接続中表示     | `connecting_overlay`   | Connecting時の表示。                          |
| 再接続中表示   | `reconnecting_overlay` | Reconnecting時の表示。                        |
| 確定中表示     | `flushing_overlay`     | Flushing時の表示。                            |
| エラー表示     | `error_overlay`        | Error時の表示。                               |
| トレイアイコン | `tray_icon`            | システムトレイ上のアイコン。                  |
| トレイメニュー | `tray_menu`            | Start、Stop、Open config、Exitなど。          |
| 通知           | `notification`         | 貼付失敗、APIキー未設定などの短いメッセージ。 |

## 8. クリップボード用語

| 日本語                   | コード上の表現              | 説明                                                                                                   |
| ------------------------ | --------------------------- | ------------------------------------------------------------------------------------------------------ |
| 貼付モード               | `paste_mode`                | committed text の出力方法。                                                                            |
| テキスト復元付き自動貼付 | `auto_paste_restore_text`   | Ctrl+V後、元のテキストクリップボードを復元するモード。                                                 |
| 復元なし自動貼付         | `auto_paste_no_restore`     | Ctrl+V後、認識結果をクリップボードに残すモード。                                                       |
| クリップボードのみ       | `clipboard_only`            | 自動貼付せず、認識結果をクリップボードへ保存するモード。                                               |
| 直接Unicode入力          | `direct_unicode_input`      | クリップボードを使わずSendInput Unicodeを試す将来候補。                                                |
| クリップボード退避       | `clipboard_backup`          | 貼付前に元のテキストを保持すること。                                                                   |
| クリップボード復元       | `clipboard_restore`         | 貼付後に元のテキストを戻すこと。                                                                       |
| sequence number          | `clipboard_sequence_number` | クリップボード変更検出に使う値。                                                                       |
| clipboard sequence guard | `clipboard_sequence_guard`  | committed text 設定直後と復元直前の sequence number が一致する場合のみ元テキスト復元を許可する安全策。 |
| 非テキスト形式           | `non_text_clipboard_format` | 画像、ファイル、HTML、RTF、アプリ独自形式など。MVPでは完全復元対象外。                                 |
| 貼付キュー               | `paste_queue`               | committed segment を順序通り処理するキュー。                                                           |
| 貼付ワーカー             | `paster_worker`             | クリップボード操作とSendInputを直列処理するスレッド。                                                  |
| 貼付対象fallback         | `last_known_target_hwnd`    | `Recording` 開始時の foreground window。committed 受信時に自プロセスが foreground の場合の貼付候補。   |

## 9. Windows API 用語

| 用語                         | 説明                                                              |
| ---------------------------- | ----------------------------------------------------------------- |
| Win32 API                    | Windows desktop API。64bit環境でも慣習的にWin32と呼ぶことがある。 |
| `RegisterHotKey`             | システムワイドホットキーを登録するWin32関数。Toggleの第一候補。   |
| `WM_HOTKEY`                  | 登録済みホットキー押下時に送られるメッセージ。                    |
| low-level keyboard hook      | キー押下、リリースを検出するためのフック。PTT候補。               |
| `SendInput`                  | キー入力を注入するWin32関数。Ctrl+V送信に使う。                   |
| UIPI                         | User Interface Privilege Isolation。入力注入の権限制約。          |
| integrity level              | Windowsプロセスの整合性レベル。通常権限、管理者権限など。         |
| secure desktop               | UAC等で使われる保護されたデスクトップ。自動貼付対象外。           |
| `OpenClipboard`              | クリップボードを開くWin32関数。                                   |
| `EmptyClipboard`             | クリップボードを空にするWin32関数。                               |
| `SetClipboardData`           | クリップボードへデータを設定するWin32関数。                       |
| `GetClipboardSequenceNumber` | クリップボード変更検出に使うWin32関数。                           |
| DPAPI                        | Windows Data Protection API。APIキー暗号化保存に使う。            |
| Mutex                        | 多重起動防止に使うWindows同期オブジェクト。                       |
| DPI awareness                | 高DPI環境でUI座標を正しく扱うための設定。                         |
| monitor clamp                | オーバーレイが画面外に出た場合に近いモニタ内へ戻す処理。          |

## 10. 設定用語

| 設定キー                      | 説明                                                                                                                         |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `config_version`              | 設定ファイル形式のバージョン。                                                                                               |
| `api_key_storage`             | APIキー保存方式。MVPでは `dpapi`。                                                                                           |
| `has_api_key`                 | APIキーが保存済みかどうか。キー本体ではない。                                                                                |
| `model_id`                    | ElevenLabs model ID。                                                                                                        |
| `language_code`               | 認識言語。MVPでは `jpn`。                                                                                                    |
| `audio_format`                | APIに送る音声形式。                                                                                                          |
| `commit_strategy`             | commit方式。MVPでは `vad`。                                                                                                  |
| `vad_silence_threshold_secs`  | サーバVADの無音commit秒数。                                                                                                  |
| `vad_threshold`               | サーバVAD閾値。                                                                                                              |
| `local_vad_threshold`         | ローカルRMS判定の閾値。                                                                                                      |
| `local_vad_min_active_chunks` | 閾値超過が連続した場合のみ音声活動とみなす最小チャンク数。                                                                   |
| `silence_timeout_sec`         | ローカル無音自動停止秒数。                                                                                                   |
| `paste_mode`                  | 貼付モード。                                                                                                                 |
| `paste_delay_ms`              | `SendInput` で Ctrl+V を送った後、復元判定を始めるまで待つ時間。                                                             |
| `paste_timeout_ms`            | paste worker が1件の paste task を開始してから、クリップボード設定、Ctrl+V、復元または復元抑止、通知までを完了する最大時間。 |
| `clipboard_open_timeout_ms`   | クリップボードを開く retry の最大時間。必要なら追加する設定。                                                                |
| `target_window_policy`        | 貼付対象ウィンドウの決め方。                                                                                                 |
| `audio_queue_max_chunks`      | 音声キュー最大チャンク数。                                                                                                   |
| `on_audio_queue_overflow`     | 音声キュー溢れ時の方針。                                                                                                     |
| `reconnect_buffer_sec`        | 再接続中に音声を保持する最大秒数。                                                                                           |
| `final_commit_wait_ms`        | Flushing中に最終committedを待つ最大時間。                                                                                    |
| `elevenlabs_enable_logging`   | ElevenLabs側loggingの指定。                                                                                                  |
| `enable_logging`              | ElevenLabs API の query parameter 名。設定キー `elevenlabs_enable_logging` から写像する。                                    |
| `local_log_level`             | ローカルログレベル。                                                                                                         |

## 11. エラー用語

| 用語                          | 説明                                 | 基本対応                           |
| ----------------------------- | ------------------------------------ | ---------------------------------- |
| `auth_error`                  | ElevenLabs認証失敗。                 | リトライしない。APIキー確認。      |
| `quota_exceeded`              | 利用枠超過。                         | リトライしない。利用枠確認。       |
| `unaccepted_terms`            | 規約未承諾。                         | リトライしない。ElevenLabs側対応。 |
| `rate_limited`                | レート制限。                         | バックオフ。                       |
| `resource_exhausted`          | リソース不足。                       | バックオフ。                       |
| `queue_overflow`              | サーバまたはクライアントキュー過多。 | 停止、設定見直し。                 |
| `chunk_size_exceeded`         | 音声チャンク過大。                   | 停止、チャンク設定修正。           |
| `input_error`                 | 入力形式またはパラメータ不正。       | 停止、設定確認。                   |
| `insufficient_audio_activity` | 音声活動不足。                       | 無音扱い。                         |
| `commit_throttled`            | commit要求過多。                     | commit頻度を下げる。               |
| `session_time_limit_exceeded` | セッション時間上限超過。             | セッション終了。                   |
| `transcriber_error`           | 文字起こし処理エラー。               | 既定停止。既知の一時的障害のみ上限付き再接続。 |
| `error`                       | 汎用サーバエラー。                   | 既定停止。既知の recoverable subtype のみ個別方針。 |
| `PasteError`                  | 貼付失敗。                           | クリップボード保持、通知。         |
| `ClipboardError`              | クリップボード操作失敗。             | retryまたは通知。                  |
| `MicrophoneUnavailableError`  | マイク初期化失敗。                   | 録音不可通知。                     |

## 12. 命名規則

### 12.1 採用する表現

| 概念                   | 採用表現             |
| ---------------------- | -------------------- |
| 暫定認識結果           | `partial`            |
| 確定認識結果           | `committed`          |
| 確定単位               | `segment`            |
| サーバVADによるcommit  | `vad_commit`         |
| ローカル無音判定       | `local_vad`          |
| 停止後の確定処理       | `flush` / `Flushing` |
| 接続中音声保持         | `connect_buffer`     |
| ホットキー前音声保持   | `pre_hotkey_preroll` |
| 貼付処理               | `paste`              |
| クリップボード保存のみ | `clipboard_only`     |
| APIキー保存            | `secure_store`       |

### 12.2 避ける表現

| 避ける表現            | 理由                         | 代替                                            |
| --------------------- | ---------------------------- | ----------------------------------------------- |
| `final`               | API event名と曖昧。          | `committed`                                     |
| `result`              | partialかcommittedか曖昧。   | `partial` / `committed`                         |
| `preroll`             | ホットキー前か接続中か曖昧。 | `connect_buffer` または `pre_hotkey_preroll`    |
| `vad_commit_strategy` | APIパラメータとして不正。    | `commit_strategy`                               |
| `speech_started`      | 前提イベントとして使わない。 | `voice_activity_detected`                       |
| `api_logging`         | ローカルログと混同しやすい。 | `elevenlabs_enable_logging`                     |
| `logging_enabled`     | ローカルかAPI側か曖昧。      | `local_log_level` / `elevenlabs_enable_logging` |

## 13. UI文言の対応

| 状況          | UI文言                                                         |
| ------------- | -------------------------------------------------------------- |
| Idle          | 待機中                                                         |
| Starting      | 準備中                                                         |
| Connecting    | 接続中                                                         |
| Recording     | 録音中                                                         |
| Reconnecting  | 再接続中                                                       |
| Flushing      | 確定中                                                         |
| Error         | エラー                                                         |
| APIキー未設定 | APIキーが設定されていません                                    |
| 貼付失敗      | 貼付できませんでした。認識結果はクリップボードに保存しました。 |
| 無音停止      | 無音が続いたため停止しました                                   |
| マイク失敗    | マイクを開始できませんでした                                   |

UI文言に本文、APIキー、ウィンドウタイトルを含めない。

## 14. ログイベント名

| イベント名               | 説明                                |
| ------------------------ | ----------------------------------- |
| `app_started`            | アプリ起動。                        |
| `app_exiting`            | アプリ終了開始。                    |
| `state_transition`       | 状態遷移。                          |
| `hotkey_start_requested` | ホットキー開始要求。                |
| `hotkey_stop_requested`  | ホットキー停止要求。                |
| `recorder_started`       | 録音開始。                          |
| `recorder_stopped`       | 録音停止。                          |
| `websocket_connecting`   | WebSocket接続開始。                 |
| `websocket_connected`    | WebSocket接続完了。                 |
| `session_started`        | API session_started受信。           |
| `first_audio_sent`       | 最初の音声チャンク送信。            |
| `first_partial_received` | 最初のpartial受信。本文は出さない。 |
| `committed_received`     | committed受信。本文は出さない。     |
| `paste_started`          | 貼付開始。本文は出さない。          |
| `paste_completed`        | 貼付完了。                          |
| `paste_failed`           | 貼付失敗。                          |
| `flush_started`          | Flushing開始。                      |
| `flush_completed`        | Flushing完了。                      |
| `silence_timeout`        | 無音タイムアウト。                  |
| `reconnect_started`      | 再接続開始。                        |
| `reconnect_completed`    | 再接続完了。                        |
| `api_error_received`     | APIエラー受信。                     |
| `audio_queue_overflow`   | 音声キュー溢れ。                    |

## 15. 文書内での注意

- 「リアルタイム入力」という表現は、partialがリアルタイム表示され、committedが確定単位で貼付される、という意味で使う。
- 「すべてのアプリで入力できる」とは書かない。
- 「多くの通常入力欄で自動貼付できるが、Windows制約により失敗し得る」と書く。
- 「クリップボードを復元する」と書く場合は、テキスト形式のみ、best effort、ユーザー変更時は復元しない、という条件を添える。
- 「プリロール」と書く場合は、MVPでは接続中バッファであり、ホットキー押下前の音声ではないことを明確にする。
