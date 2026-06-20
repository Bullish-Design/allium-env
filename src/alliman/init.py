"""``alliman init`` — adopt allium-env into a repo (family contract).

allium-env already ships an ``allium-entrypoint`` skill that owns the Allium narrative, so ``init``
does not write a competing skill: it prints the devenv import snippet and points at the existing
installer / entrypoint. Output is a list of lines so the CLI layer owns echoing.
"""

from __future__ import annotations

from pathlib import Path

_DEVENV_YAML_SNIPPET = """\
# devenv.yaml — import allium-env, then enable it in devenv.nix
inputs:
  allium-env:
    url: github:YOUR_ORG/allium-env
    # flake: false  # if consumed as a plain devenv module
imports:
  - allium-env
"""

_DEVENV_NIX_SNIPPET = """\
# devenv.nix
{
  allium.enable = true;            # install Allium skills + prompts
  # allium.specsDir = ".scratch/specs/allium";  # where .allium specs live
}
"""


def run_init(repo_root: Path, force: bool = False) -> list[str]:
    """Return the adoption guidance for *repo_root* (devenv import snippet + next steps)."""
    root = Path(repo_root)
    lines: list[str] = []
    lines.append(f"alliman init — adopt Allium agent assets in {root}")
    lines.append("")
    lines.append("1) Import the module in devenv.yaml:")
    lines.append("")
    lines.extend("    " + ln for ln in _DEVENV_YAML_SNIPPET.splitlines())
    lines.append("")
    lines.append("2) Enable it in devenv.nix:")
    lines.append("")
    lines.extend("    " + ln for ln in _DEVENV_NIX_SNIPPET.splitlines())
    lines.append("")
    lines.append("3) Install the agent assets, then verify:")
    lines.append("")
    lines.append("    devenv shell -- alliman install-skills")
    lines.append("    devenv shell -- alliman doctor")
    lines.append("")
    lines.append("The installed `allium-entrypoint` skill explains how agents use Allium.")
    lines.append("See the `repoman` skill for how this manager fits the conductor.")
    return lines
