"""``alliman doctor`` — verify Allium skills + prompts are installed properly (family contract).

This ports the criteria of ``scripts/check-codex-assets-installed.sh`` and **strengthens** them:
where the bash verifier only checks the manifest + the entrypoint ``SKILL.md``, ``doctor`` also
confirms that *every expected skill directory* actually carries its own ``SKILL.md`` — so a
partial install (a missing skill dir) is surfaced as exit 2 rather than slipping through.

Configuration is read from the same ``ALLIUM_*`` environment the devenv module exports for the
installer / ``enterShell`` wiring (see ``devenv.nix``), with the module's documented defaults as
fallbacks, so ``doctor`` agrees with the installer about what "installed" means.
"""

from __future__ import annotations

import os
from pathlib import Path

from alliman.models import DoctorCheck, DoctorReport

# Default vendored skills installed by install-codex-assets.sh (cfg.codexSkills.skills default).
_DEFAULT_SKILLS = ["allium", "elicit", "distill", "propagate", "tend", "weed"]


def _resolve(root: Path, target: str) -> Path:
    """Resolve a module target dir: absolute as-is, otherwise relative to the repo root."""
    return Path(target) if target.startswith("/") else root / target


def run_doctor(repo_root: Path | None = None) -> DoctorReport:
    """Verify the Allium asset install and return the aggregate report."""
    root = Path(repo_root or os.environ.get("DEVENV_ROOT") or Path.cwd())
    checks: list[DoctorCheck] = []

    devenv_root = os.environ.get("DEVENV_ROOT")
    checks.append(
        DoctorCheck(
            name="devenv shell",
            ok=bool(devenv_root),
            detail=devenv_root or "not inside a devenv shell",
        )
    )

    skills_root = _resolve(root, os.environ.get("ALLIUM_CODEX_SKILLS_DIR", ".agents/skills"))
    skill_list = (os.environ.get("ALLIUM_SHELL_SKILL_LIST") or " ".join(_DEFAULT_SKILLS)).split()
    prompts_enabled = os.environ.get("ALLIUM_PROMPTS_ENABLED", "1") == "1"

    # 1) manifest present (install ran at all)
    manifest = skills_root / ".allium-devenv-source"
    checks.append(
        DoctorCheck(
            name="install manifest",
            ok=manifest.exists(),
            detail=str(manifest) if manifest.exists() else "missing — run `alliman install-skills`",
        )
    )
    manifest_text = manifest.read_text() if manifest.exists() else ""

    # 2) the templated entrypoint skill present
    entry = skills_root / "allium-entrypoint" / "SKILL.md"
    checks.append(
        DoctorCheck(
            name="skill: allium-entrypoint",
            ok=entry.exists(),
            detail=str(entry) if entry.exists() else "missing — reinstall skills",
        )
    )

    # 3) every expected vendored skill present with its SKILL.md (STRONGER than the bash check)
    for skill in skill_list:
        sk = skills_root / skill / "SKILL.md"
        checks.append(
            DoctorCheck(
                name=f"skill: {skill}",
                ok=sk.exists(),
                detail=str(sk) if sk.exists() else "missing — reinstall skills",
            )
        )

    # 4) manifest records the expected vendored source (matches check-codex-assets-installed.sh)
    expected_vendored = os.environ.get("ALLIUM_EXPECTED_VENDORED_SOURCE")
    if expected_vendored:
        ok = f"Vendored Allium source: {expected_vendored}" in manifest_text
        checks.append(
            DoctorCheck(
                name="manifest: vendored source",
                ok=ok,
                detail="matches" if ok else "stale/mismatched — reinstall skills",
            )
        )

    # 5) prompts installed when enabled
    if prompts_enabled:
        prompts_root = _resolve(root, os.environ.get("ALLIUM_CODEX_PROMPTS_DIR", ".agents/prompts"))
        has_prompt = prompts_root.is_dir() and any(prompts_root.glob("*.md"))
        checks.append(
            DoctorCheck(
                name="prompts installed",
                ok=has_prompt,
                detail=str(prompts_root) if has_prompt else "missing — run `alliman install-skills`",
            )
        )

    return DoctorReport(checks=checks)


def format_doctor_report(report: DoctorReport) -> str:
    """Render *report* as plain text (one line per check)."""
    return "\n".join(
        ("OK  " if c.ok else "FAIL") + f" {c.name}" + (f" — {c.detail}" if c.detail else "")
        for c in report.checks
    )
