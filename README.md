# voice-typer

`voice-typer` は、Windows 11 x64 上で任意のアプリへ日本語音声入力を行う常駐型ディクテーション支援ツールです。

ElevenLabs Scribe v2 Realtime API を使い、録音中の暫定認識結果をオーバーレイへ表示し、確定したセグメントをアクティブアプリへ貼付またはクリップボードへ保存します。

## 重要な前提

- 対象 OS は Windows 11 x64 です。
- 初期実装の実装言語は Python 3.12.x です。
- 音声認識は ElevenLabs Scribe v2 Realtime API を使います。
- 音声データは ElevenLabs API に送信されます。
- API キーは Windows DPAPI でユーザー単位に暗号化保存します。平文の設定ファイル保存は禁止です。
- 自動貼付はクリップボードへ確定テキストを入れて `Ctrl+V` を送る方式を MVP の基本とします。
- `SendInput(Ctrl+V)` は Windows の権限分離、対象アプリ、入力欄状態に依存するため best effort です。
- 貼付に失敗した場合でも、認識済みテキストはクリップボードに残してユーザーへ通知します。
- クリップボード経由で貼付する場合、Windows のクリップボード履歴やクラウド同期に認識テキストが残る可能性があります。

詳細な要求、設計、制約は `docs/development/permanent/` 配下の永続ドキュメントを一次ソースとして扱います。

## 永続ドキュメント

- `docs/development/permanent/product-requirements.md`
- `docs/development/permanent/functional-design.md`
- `docs/development/permanent/architecture.md`
- `docs/development/permanent/development-guidelines.md`
- `docs/development/permanent/glossary.md`
- `docs/development/permanent/repository-structure.md`

## 現在のリポジトリ状態

このリポジトリは Python 3.12.x の最小パッケージ構成です。

初回準備PRでは既存テンプレートを削除し、最小 `voice_typer/` パッケージ雛形と Python 用 CI だけを追加しています。実装ロジックはまだ含みません。

今後の大きな実装順序は以下です。

1. ElevenLabs Realtime API の最小 POC
2. 録音パイプライン POC
3. 貼付 POC
4. ホットキー POC
5. state machine と `Flushing` 実装
6. オーバーレイ、トレイ、設定 UI
7. パッケージングとインストーラ

API、録音、貼付の不確実性を解消する前に UI を作り込みません。

## 初期セットアップ

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install -U pip
python -m pip install -r requirements-dev.txt
```

Windows PowerShell の場合:

```bash
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -U pip
python -m pip install -r requirements-dev.txt
```

WSL などで `venv` / `ensurepip` が使えない場合は、`uv` で `.venv` を作成できます。

```bash
uv venv .venv --python 3.12
uv pip install --python .venv/bin/python -r requirements-dev.txt
. .venv/bin/activate
```

最小エントリポイント:

```bash
python -m voice_typer
```

## 検証

```bash
ruff check .
ruff format --check .
black --check .
mypy voice_typer tests
pytest
```

## パッケージ構成

```text
voice_typer/
├── __init__.py
├── __main__.py
└── main.py
```

今後の実装では `docs/development/permanent/repository-structure.md` に従って、録音、ElevenLabs API、貼付、UI、Windows API wrapper を段階的に追加します。

## 開発ルール

agent 向け恒久ルールは `AGENTS.md` を参照してください。

大きな作業では `docs/development/.steering/` 配下に作業単位の `requirements.md`、必要に応じて `implementation-plan.md`、`tasklist.md` を作成します。小規模作業でステアリング不要と判断した場合は、後追いでステアリングを作成しません。

PR 提案前またはタスク完了前は、変更範囲に応じて `$verify-full` を通します。
