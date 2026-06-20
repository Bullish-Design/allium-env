# Guide — `alliman` CLI: verify skills are installed properly (family contract)

**Goal (narrowed):** give allium-env a family-conforming command (`alliman`) whose **`doctor`
confirms all agent skills + prompts are installed properly**, with `install-skills` to fix it
and `init` to adopt — so RepoMan's `repoman doctor` can verify the asset install. Wrapping
Allium's spec verbs (`allium check/analyse`) is **out of scope** for this pass.

## Current state (verified)

- `devenv.nix` (repo root) — the importable module. Relevant to this pass:
  - vendors Allium under `.vendor/allium`; bundles local CLI skills (`.skills/allium-cli`), an
    `allium-entrypoint` skill (`.skills/allium-entrypoint`), and prompts (`.agents`);
  - options `allium.codexSkills.{enable,autoInstall,targetDir,skills}` and
    `allium.codexPrompts.{enable,targetDir}`; `allium.specsDir`;
  - `scripts.allium-install-codex-skills` execs `scripts/install-codex-assets.sh` with a set of
    `ALLIUM_*` env vars (sources + targets + skill list + specsDir);
  - `enterShell` runs `scripts/check-codex-assets-installed.sh`; if `autoInstall`, it installs.
- `scripts/install-codex-assets.sh` — the installer. It installs: each skill in
  `ALLIUM_SHELL_SKILL_LIST` (default `allium elicit distill propagate tend weed`) from
  `.vendor/allium/skills`; every local CLI skill under `.skills/allium-cli/skills`; the
  `allium-entrypoint` skill (templated with `specsDir` via `minijinja-cli`); optionally the
  prompts. It then writes a manifest `<skills_target>/.allium-devenv-source` recording the
  source paths.
- `scripts/check-codex-assets-installed.sh` — the verifier. It reports "needs install" (exit 1)
  unless: `<skills_target>/.allium-devenv-source` exists **and** `allium-entrypoint/SKILL.md`
  exists **and** the manifest records the expected vendored + CLI (+ prompts) sources **and**
  the prompts target exists when prompts are enabled.
- `pyproject.toml` — still the `template-py` template. **Replace it.**

The `doctor` below ports the verifier's criteria and **strengthens** them: it also checks that
**each expected skill directory** actually has a `SKILL.md` (the verifier only checks the
manifest + entrypoint, so a partial install can slip through).

## Step 0 — confirm the command name

Use **`alliman`** (the manager) — never `allium` (the third-party binary). If you pick another
name, replace it everywhere and update RepoMan's registry downstream.

## Target layout

```
allium-env/
  pyproject.toml            # REPLACE template-py → real alliman package
  src/alliman/
    __init__.py
    __main__.py
    cli.py                  # Typer app: doctor + install-skills + init
    doctor.py               # run_doctor() -> DoctorReport (verify install)
    models.py
    init.py
  tests/
    test_doctor.py
    test_cli.py
  devenv.nix                # (edit) add a python venv so `alliman` is on PATH
  scripts/*.sh              # unchanged (the engine)
```

## Step 1 — `pyproject.toml` (replace the template stub)

```toml
[project]
name = "alliman"
version = "0.1.0"
description = "Agentic spec/asset manager (Allium) — devenv module + conforming CLI."
requires-python = ">=3.13"
dependencies = ["pydantic>=2.12", "typer>=0.12"]

[project.optional-dependencies]
dev = ["pytest>=8.0", "pytest-cov>=5.0", "ruff>=0.5"]

[project.scripts]
alliman = "alliman.cli:app"

[build-system]
requires = ["hatchling>=1.18"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/alliman"]

[tool.pytest.ini_options]
addopts = "-ra --cov=alliman --cov-report=term-missing"
testpaths = ["tests"]
pythonpath = ["src"]

[tool.ruff]
line-length = 120
target-version = "py313"
```

Delete `src/template_py/` and fix the leftover `[tool.mypy]`/coverage targets.

## Step 2 — `src/alliman/doctor.py` (the heart of this pass)

Verify the asset install. Read the same configuration the module exports as `ALLIUM_*` env
(with the documented defaults as fallback), then check the install tree.

```python
"""`alliman doctor` — verify Allium skills + prompts are installed properly (family contract)."""
from __future__ import annotations

import os
from pathlib import Path

from pydantic import BaseModel

# Default vendored skills installed by install-codex-assets.sh (cfg.codexSkills.skills default).
_DEFAULT_SKILLS = ["allium", "elicit", "distill", "propagate", "tend", "weed"]


class DoctorCheck(BaseModel):
    name: str
    ok: bool
    detail: str = ""


class DoctorReport(BaseModel):
    checks: list[DoctorCheck]

    @property
    def ok(self) -> bool:
        return all(c.ok for c in self.checks)

    def to_dict(self) -> dict:
        return self.model_dump()


def _resolve(root: Path, target: str) -> Path:
    return Path(target) if target.startswith("/") else root / target


def run_doctor(repo_root: Path | None = None) -> DoctorReport:
    root = Path(repo_root or os.environ.get("DEVENV_ROOT") or Path.cwd())
    checks: list[DoctorCheck] = []

    devenv_root = os.environ.get("DEVENV_ROOT")
    checks.append(DoctorCheck(name="devenv shell", ok=bool(devenv_root),
                              detail=devenv_root or "not inside a devenv shell"))

    skills_root = _resolve(root, os.environ.get("ALLIUM_CODEX_SKILLS_DIR", ".agents/skills"))
    skill_list = (os.environ.get("ALLIUM_SHELL_SKILL_LIST") or " ".join(_DEFAULT_SKILLS)).split()
    prompts_enabled = os.environ.get("ALLIUM_PROMPTS_ENABLED", "1") == "1"

    # 1) manifest present (install ran at all)
    manifest = skills_root / ".allium-devenv-source"
    checks.append(DoctorCheck(name="install manifest", ok=manifest.exists(),
                              detail=str(manifest) if manifest.exists()
                                     else "missing — run `alliman install-skills`"))
    manifest_text = manifest.read_text() if manifest.exists() else ""

    # 2) the templated entrypoint skill present
    entry = skills_root / "allium-entrypoint" / "SKILL.md"
    checks.append(DoctorCheck(name="skill: allium-entrypoint", ok=entry.exists(),
                              detail=str(entry) if entry.exists() else "missing — reinstall skills"))

    # 3) every expected vendored skill present with its SKILL.md (STRONGER than the bash check)
    for skill in skill_list:
        sk = skills_root / skill / "SKILL.md"
        checks.append(DoctorCheck(name=f"skill: {skill}", ok=sk.exists(),
                                  detail=str(sk) if sk.exists() else "missing — reinstall skills"))

    # 4) manifest records the expected sources (matches check-codex-assets-installed.sh)
    expected_vendored = os.environ.get("ALLIUM_EXPECTED_VENDORED_SOURCE")
    if expected_vendored:
        ok = f"Vendored Allium source: {expected_vendored}" in manifest_text
        checks.append(DoctorCheck(name="manifest: vendored source", ok=ok,
                                  detail="matches" if ok else "stale/mismatched — reinstall skills"))

    # 5) prompts installed when enabled
    if prompts_enabled:
        prompts_root = _resolve(root, os.environ.get("ALLIUM_CODEX_PROMPTS_DIR", ".agents/prompts"))
        has_prompt = prompts_root.is_dir() and any(prompts_root.glob("*.md"))
        checks.append(DoctorCheck(name="prompts installed", ok=has_prompt,
                                  detail=str(prompts_root) if has_prompt
                                         else "missing — run `alliman install-skills`"))

    return DoctorReport(checks=checks)


def format_doctor_report(report: DoctorReport) -> str:
    return "\n".join(
        ("OK  " if c.ok else "FAIL") + f" {c.name}" + (f" — {c.detail}" if c.detail else "")
        for c in report.checks
    )
```

> Every check here is a **hard** check (a missing/partial install is exit 2 — the toolchain
> isn't ready, which is exactly what we want `repoman doctor` to surface). The env vars
> (`ALLIUM_CODEX_SKILLS_DIR`, `ALLIUM_SHELL_SKILL_LIST`, `ALLIUM_EXPECTED_VENDORED_SOURCE`,
> `ALLIUM_PROMPTS_ENABLED`, …) are already exported by the module's installer/enterShell
> wiring — `doctor` reads the same ones so it agrees with the installer about what "installed"
> means. Confirm the names against `devenv.nix` and the two scripts; the defaults above are the
> documented fallbacks.

## Step 3 — `src/alliman/cli.py`

Minimal conforming surface: `doctor`, `install-skills`, `init`.

```python
"""alliman CLI — verify/install Allium agent assets (family contract)."""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Annotated

import typer

from alliman.doctor import format_doctor_report, run_doctor

app = typer.Typer(name="alliman", help="Agentic spec/asset manager (Allium).",
                  no_args_is_help=True, add_completion=False)


@app.command("install-skills")
def install_skills() -> None:
    """Install Allium skills + prompts (delegates to allium-install-codex-skills)."""
    if shutil.which("allium-install-codex-skills") is None:
        typer.echo("allium-install-codex-skills not on PATH — are you in the devenv shell?", err=True)
        raise typer.Exit(2)
    raise typer.Exit(subprocess.run(["allium-install-codex-skills"]).returncode)


@app.command()
def doctor(json_output: Annotated[bool, typer.Option("--json")] = False,
           repo_root: Annotated[Path | None, typer.Option("--repo-root")] = None) -> None:
    """Verify all Allium skills + prompts are installed properly (exit 0 ok / 2 broken)."""
    report = run_doctor(repo_root)
    typer.echo(json.dumps(report.to_dict(), indent=2) if json_output else format_doctor_report(report))
    raise typer.Exit(0 if report.ok else 2)


@app.command()
def init(force: Annotated[bool, typer.Option("--force")] = False,
         repo_root: Annotated[Path | None, typer.Option("--repo-root")] = None) -> None:
    """Scaffold alliman into a repo: devenv import snippet + agent-skill pointer."""
    from alliman.init import run_init
    for line in run_init(repo_root or Path.cwd(), force=force):
        typer.echo(line)
```

> Don't reimplement the installer — `install-skills` delegates to the proven
> `allium-install-codex-skills` script so there's one install path. `doctor` is the new
> verification surface.

## Step 4 — `src/alliman/init.py`

allium-env already installs an `allium-entrypoint` skill that owns the Allium narrative, so
`init` should **point at it / trigger the installer**, not write a competing skill. Minimum:
print the devenv import snippet and run (or recommend) `alliman install-skills`. If you do write
an adoption note skill, give it the deferral footer *"see the `repoman` skill"* so RepoMan's
skill-linter is satisfied.

## Step 5 — `devenv.nix` (put the CLI on PATH)

allium-env's module has no Python venv today. Add a minimal one carrying `alliman` (gated
alongside the existing `cfg.enable` config):

```nix
  languages.python = {
    enable = true;
    version = "3.13";
    uv.enable = true;
    venv = { enable = true; requirements = '' alliman ''; };
  };
```

Dev: `uv pip install --editable .` (or RepoMan lock `path:` → editable). Consumers: pinned
package / lock entry.

## Step 6 — tests

```
tests/test_doctor.py   # build a tmp skills tree (manifest + entrypoint + each skill SKILL.md +
                       #   prompts) → ok; remove one skill / the manifest → FAIL + exit-2 shape.
                       #   Drive paths via monkeypatch.setenv(ALLIUM_CODEX_SKILLS_DIR=...).
tests/test_cli.py      # CliRunner: doctor --json parses; install-skills missing script → exit 2.
```

The doctor is pure filesystem inspection, so it unit-tests cleanly with `tmp_path` + env vars —
no need to run the real installer.

## Verification

```bash
# in a repo that imports allium-env (or this repo's shell):
devenv shell -- alliman --help                          # install-skills / doctor / init
devenv shell -- bash -c 'alliman doctor; echo exit=$?'  # FAIL+2 before install
devenv shell -- alliman install-skills                  # runs the installer
devenv shell -- bash -c 'alliman doctor; echo exit=$?'  # all OK + 0 after install
devenv shell -- alliman doctor --json                   # valid JSON
devenv shell -- pytest
```

The before/after `doctor` exit flip (2 → 0 across an `install-skills`) is the core proof that
"all skills are installed properly" is now machine-checkable through the family contract.

## Downstream — RepoMan alignment (note, don't do it here)

In the **repoman** repo (separate change): rename the `spec` registry entry's `command`
`"allium"` → `"alliman"` (required — see above), keep `doctor=["doctor"]`, add a
`[managers.spec]` lock entry + a `modules/managers/<name>.nix`. Then `repoman doctor` will run
`alliman doctor` and report whether the Allium skills are installed.

## Risks

| Risk | Mitigation |
|---|---|
| `doctor` env-var names drift from the scripts | Read the exact `ALLIUM_*` names from `devenv.nix` + both scripts; the guide's defaults are documented fallbacks. Add a test pinning them. |
| Name collision with the `allium` binary | Manager is `alliman`; never shadow `allium`. Update RepoMan registry. |
| Partial install passes the old bash check | `doctor` strengthens it: every expected skill dir must have `SKILL.md`, not just the manifest. |
| `template-py` leftovers | Remove `src/template_py`; fix mypy/coverage targets to `alliman`. |
