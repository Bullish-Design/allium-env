# Kickoff prompt — allium-env CLI conductor alignment

Paste the block below into a fresh session in the `allium-env` repo to begin.

---

You are implementing **CLI conductor alignment** in the `allium-env` repo
(`/home/andrew/Documents/Projects/allium-env`). allium-env is the `spec` member of the `*man`
family: a devenv module that installs Allium's agent assets (vendored skills, local CLI skills,
the templated `allium-entrypoint` skill, and optional prompts) into a repo.

## Scope (narrowed — read carefully)

The goal for this pass is specific: **make sure all the agent skills (and prompts) are installed
properly**, and expose that as a family-conforming `doctor` so RepoMan's `repoman doctor` can
verify it. Concretely: a minimal `alliman` Typer CLI with a Pydantic `doctor` that verifies the
install, an `install-skills` verb that delegates to the existing installer, and `init`.
**Out of scope:** wrapping Allium's spec verbs (`allium check/analyse`).

## Decide first — the command name

`allium` is the pinned third-party binary, so the manager command must differ. Recommended:
**`alliman`** (fits the `*man` family). Whatever you pick, RepoMan's registry must be updated to
match downstream — and **must** change (the conductor would otherwise call `allium doctor` on
the third-party binary).

## Read first (the design is settled)

1. `.scratch/projects/02-cli-conductor-alignment/README.md` — scope, name decision, family contract.
2. `.scratch/projects/02-cli-conductor-alignment/01-alliman-cli.md` — the detailed guide. Implement to it.
3. Ground truth for "installed properly": `scripts/install-codex-assets.sh` and
   `scripts/check-codex-assets-installed.sh`. Reference doctor: `../copyroom/src/copyroom/doctor.py`.

If reality differs from the guide, fix the code and **note the discrepancy in the guide**.

## Environment rules (hard requirements)

- This repo uses **devenv**. Run every in-repo command inside it: `devenv shell -- <cmd>`.
  **Never** run bare `uv`/`python`/`pytest`.
- The installer needs the vendored source (`.vendor/allium`) and a git repo; `doctor` is pure
  filesystem inspection and unit-tests with `tmp_path` + `ALLIUM_*` env vars.
- Do **not** add AI-attribution trailers to commits/PRs.
- Commit on a branch (e.g. `cli-conductor-alignment`); don't push unless asked.

## Order of work

1. Confirm the command name. Read the two asset scripts to pin the exact `ALLIUM_*` env names.
2. Replace the `template-py` `pyproject.toml`; create `src/alliman/`; remove `src/template_py`.
3. `doctor.py` — verify manifest + entrypoint + **every expected skill's SKILL.md** + prompts;
   `tests/test_doctor.py` over a tmp tree → `pytest` green.
4. `cli.py` (`doctor` + `install-skills` + `init`) + `init.py` + `tests/test_cli.py` → green.
5. `devenv.nix` — add a minimal Python venv carrying `alliman` so the CLI is on PATH.
6. Verify the before/after `doctor` exit flip across `install-skills` (see the guide).

## Definition of done

- `devenv shell -- alliman --help` lists `install-skills / doctor / init`.
- `devenv shell -- alliman doctor` exits **2** with clear per-skill FAIL lines before install,
  and **0** (all OK) after `alliman install-skills`; `--json` emits valid JSON.
- `doctor` flags a *partial* install (a missing skill dir), not just a missing manifest.
- `devenv shell -- pytest` green; doctor tests cover the healthy tree + missing-skill + missing-manifest.
- Guide updated for any divergence (esp. the exact `ALLIUM_*` env-var names).

## Guardrails

- **Never** name the console script `allium` — that's the third-party binary.
- Don't reimplement the installer — `install-skills` delegates to `allium-install-codex-skills`.
  `doctor` is the new verification surface.
- Match the family conventions: Typer CLI, Pydantic models, the `0/1/2/3` exit contract.
- Don't change RepoMan from here; the registry rename (`spec` → `alliman`) + lock + module are a
  downstream change in the `repoman` repo (noted in the guide).
