from __future__ import annotations

from voice_typer import __version__
from voice_typer.main import run


def test_package_has_initial_version() -> None:
    assert __version__ == "0.0.0"


def test_run_exits_successfully() -> None:
    assert run() == 0
