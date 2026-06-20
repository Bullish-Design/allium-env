"""CliRunner tests for the alliman CLI surface (doctor / install-skills / init)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from typer.testing import CliRunner

from alliman.cli import app
from alliman.doctor import _DEFAULT_SKILLS

runner = CliRunner()


def _build_healthy(root: Path) -> None:
    skills_root = root / ".agents/skills"
    skills_root.mkdir(parents=True, exist_ok=True)
    for skill in [*_DEFAULT_SKILLS, "allium-entrypoint"]:
        sk = skills_root / skill
        sk.mkdir(parents=True, exist_ok=True)
        (sk / "SKILL.md").write_text(f"# {skill}\n")
    (skills_root / ".allium-devenv-source").write_text(
        "Vendored Allium source: /nix/store/abc-allium\n"
    )
    prompts = root / ".agents/prompts"
    prompts.mkdir(parents=True, exist_ok=True)
    (prompts / "p.md").write_text("# p\n")


@pytest.fixture(autouse=True)
def _env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DEVENV_ROOT", "/tmp/fake-devenv")
    monkeypatch.setenv("ALLIUM_CODEX_SKILLS_DIR", ".agents/skills")
    monkeypatch.setenv("ALLIUM_CODEX_PROMPTS_DIR", ".agents/prompts")
    monkeypatch.setenv("ALLIUM_SHELL_SKILL_LIST", " ".join(_DEFAULT_SKILLS))
    monkeypatch.setenv("ALLIUM_EXPECTED_VENDORED_SOURCE", "/nix/store/abc-allium")
    monkeypatch.setenv("ALLIUM_PROMPTS_ENABLED", "1")


def test_help_lists_all_verbs() -> None:
    result = runner.invoke(app, ["--help"])
    assert result.exit_code == 0
    for verb in ("install-skills", "doctor", "init"):
        assert verb in result.output


def test_doctor_broken_exits_2(tmp_path: Path) -> None:
    result = runner.invoke(app, ["doctor", "--repo-root", str(tmp_path)])
    assert result.exit_code == 2
    assert "FAIL" in result.output


def test_doctor_healthy_exits_0(tmp_path: Path) -> None:
    _build_healthy(tmp_path)
    result = runner.invoke(app, ["doctor", "--repo-root", str(tmp_path)])
    assert result.exit_code == 0, result.output


def test_doctor_json_is_valid(tmp_path: Path) -> None:
    _build_healthy(tmp_path)
    result = runner.invoke(app, ["doctor", "--json", "--repo-root", str(tmp_path)])
    assert result.exit_code == 0, result.output
    payload = json.loads(result.output)
    assert "checks" in payload
    assert all({"name", "ok", "detail"} <= set(c) for c in payload["checks"])


def test_install_skills_missing_script_exits_2(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("alliman.cli.shutil.which", lambda _name: None)
    result = runner.invoke(app, ["install-skills"])
    assert result.exit_code == 2
    assert "not on PATH" in result.output


def test_init_prints_snippet(tmp_path: Path) -> None:
    result = runner.invoke(app, ["init", "--repo-root", str(tmp_path)])
    assert result.exit_code == 0
    assert "devenv.yaml" in result.output
    assert "alliman install-skills" in result.output
