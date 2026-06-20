# 02 — CLI conductor alignment (allium-env)

Bring allium-env into the `*man` family's **standard CLI shape** so RepoMan's conductor can
drive it uniformly alongside copyroom, gitman, and testee.

## Scope (narrowed)

For allium-env the goal is specific: **make sure all the agent skills (and prompts) are
installed properly**, and expose that as a family-conforming `doctor` the conductor can run.

allium-env's whole job is delivering Allium's agent assets into a repo: it installs vendored
skills, local CLI skills, the templated `allium-entrypoint` skill, and (optionally) prompts —
via `scripts/install-codex-assets.sh`, with `scripts/check-codex-assets-installed.sh` deciding
whether a (re)install is needed. Today that verification only runs implicitly on shell entry
and isn't reachable as `<command> doctor`, so `repoman doctor` can't confirm the assets landed.

This project adds a minimal, family-conforming CLI whose **`doctor` verifies skill/prompt
installation** (porting/strengthening `check-codex-assets-installed.sh`), with `install-skills`
to fix it and `init` to adopt. Wrapping Allium's *spec* verbs (`allium check/analyse`) is **out
of scope** for this pass.

## Decision required — the command name

The manager command cannot be `allium` (that's the pinned third-party binary from
`juxt/allium-tools`, added to PATH by `devenv.nix`). Recommended: **`alliman`** (fits the
`*man` family). Whatever you choose, RepoMan's `registry.py` `spec` entry (currently
`command="allium"`) must be updated to match — and **must change**, since the conductor would
otherwise call `allium doctor` on the third-party binary, which has no such verb.

## What ships

| Piece | Detail |
|---|---|
| `src/alliman/` Python package | `cli.py` (Typer), `doctor.py` (Pydantic — NEW), `init.py`, `models.py` |
| `pyproject.toml` | **replace** the `template-py` stub — `[project.scripts] alliman = "alliman.cli:app"` |
| `alliman doctor` | NEW: verifies **all expected skills + the entrypoint + manifest + prompts** are installed; exit 0/2 |
| `alliman install-skills` | delegate to `allium-install-codex-skills` (the existing installer) |
| `alliman init` | family init: devenv import snippet + pointer to the entrypoint skill |
| Tests | `tests/` — doctor unit tests over a tmp install tree + CliRunner |

## Read first

1. `01-alliman-cli.md` — the detailed, code-grounded implementation guide.
2. `KICKOFF_PROMPT.md` — paste into a fresh session in this repo to begin.

## The family CLI contract (the "common way")

1. **One Typer CLI, one console script** — `[project.scripts] <command> = "<pkg>.cli:app"`.
2. **Universal subcommands** — `init` and `doctor`, plus the domain verbs (here: `install-skills`).
3. **`doctor` → Pydantic report** — `run_doctor() -> DoctorReport`, `--json`, exit `0`/`2`.
   Mirror `../copyroom/src/copyroom/doctor.py`.
4. **`0/1/2/3` exit contract** — `0` ok · `2` infra/config (assets not installed) is the one
   that matters here.
5. **Pydantic-normalized output**.
6. **Runs inside `devenv shell`**.
7. **Still a devenv module** — unchanged installer wiring; additionally puts the CLI on PATH.
8. **RepoMan alignment (downstream)** — update repoman's `registry.py` (`spec` → the new
   command name), `repoman.lock`, and a `modules/managers/<name>.nix`.
