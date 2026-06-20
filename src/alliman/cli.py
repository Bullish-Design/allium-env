"""alliman CLI — verify/install Allium agent assets (family contract).

Minimal conforming surface: ``doctor`` (the new verification surface), ``install-skills`` (delegates
to the proven ``allium-install-codex-skills`` installer — one install path, never reimplemented),
and ``init`` (adoption). Exit codes follow the family ``0/1/2/3`` contract; ``2`` (infra/config —
assets not installed) is the one that matters for ``repoman doctor``.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Annotated

import typer

from alliman.doctor import format_doctor_report, run_doctor

app = typer.Typer(
    name="alliman",
    help="Agentic spec/asset manager (Allium).",
    no_args_is_help=True,
    add_completion=False,
)


@app.command("install-skills")
def install_skills() -> None:
    """Install Allium skills + prompts (delegates to allium-install-codex-skills)."""
    if shutil.which("allium-install-codex-skills") is None:
        typer.echo(
            "allium-install-codex-skills not on PATH — are you in the devenv shell?",
            err=True,
        )
        raise typer.Exit(2)
    raise typer.Exit(subprocess.run(["allium-install-codex-skills"]).returncode)


@app.command()
def doctor(
    json_output: Annotated[bool, typer.Option("--json", help="Emit the report as JSON")] = False,
    repo_root: Annotated[Path | None, typer.Option("--repo-root", help="Repo root to inspect")] = None,
) -> None:
    """Verify all Allium skills + prompts are installed properly (exit 0 ok / 2 broken)."""
    report = run_doctor(repo_root)
    typer.echo(json.dumps(report.to_dict(), indent=2) if json_output else format_doctor_report(report))
    raise typer.Exit(0 if report.ok else 2)


@app.command()
def init(
    force: Annotated[bool, typer.Option("--force", help="Overwrite existing scaffolding")] = False,
    repo_root: Annotated[Path | None, typer.Option("--repo-root", help="Repo root to scaffold")] = None,
) -> None:
    """Scaffold alliman into a repo: devenv import snippet + agent-skill pointer."""
    from alliman.init import run_init

    for line in run_init(repo_root or Path.cwd(), force=force):
        typer.echo(line)
