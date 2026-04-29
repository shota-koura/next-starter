# 初回準備PR 要件

## 背景

`voice-typer` は Python 3.12.x の Windows 常駐デスクトップアプリとして開発する。一方、現在のリポジトリには Next.js と FastAPI の初期テンプレートが残っている。

`docs/development/permanent/development-guidelines.md` §4.0 に従い、最初の作業ブランチではテンプレート削除、最小 Python パッケージ雛形、開発ツール設定、初期 CI だけを独立PRとして準備する。

## スコープ

- 既存テンプレート由来の frontend / backend ファイルを削除する。
- `voice_typer/` の最小パッケージ雛形を追加する。
- Python 3.12.x 用の `pyproject.toml`、`requirements.txt`、`requirements-dev.txt`、`.python-version` を追加する。
- ruff、black、mypy、pytest の初期設定を追加する。
- GitHub Actions の最小 CI を Python 用に更新する。
- README の初期セットアップ手順を Python 構成へ更新する。

## 非スコープ

- ElevenLabs Realtime API の接続実装。
- 録音、貼付、ホットキー、オーバーレイ、トレイの実装。
- Windows API wrapper の本実装。
- PyInstaller build smoke や Windows smoke の本格 CI。
- 本番依存ライブラリの追加。

## 受け入れ条件

- `python -m voice_typer` が実装ロジックなしの最小エントリポイントとして起動できる。
- `pytest` が最小 smoke test を実行して成功する。
- `ruff check .`、`ruff format --check .`、`black --check .`、`mypy voice_typer tests` が成功する。
- CI は Python 3.12 を使い、ruff、black、mypy、pytest を実行する。
- テンプレート由来の Next.js / FastAPI 実装と Node 前提の CI が残っていない。

## 制約

- 実装ロジックは追加しない。
- transcript、音声、API key を扱うコードは追加しない。
- 既存の永続ドキュメント更新はこのブランチに含める。
