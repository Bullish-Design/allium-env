# Allium CLI Agent Skills

This package contains folder-oriented agent skills for using the `allium` CLI on `.allium` spec folders. It assumes the CLI is already installed and working.

## Scope

These skills do not replace `/allium`, `/allium:elicit`, `/allium:distill`, `/allium:propagate`, `/allium:tend`, or `/allium:weed`. They are operational CLI skills for running and interpreting commands.

## Included skills

- `allium-cli-project-conventions`
- `allium-cli-overview`
- `allium-cli-command-reference`
- `allium-cli-check`
- `allium-cli-analyse`
- `allium-cli-parse`
- `allium-cli-model`
- `allium-cli-plan`
- `allium-cli-diagnostics-repair`
- `allium-cli-output-interpretation`
- `allium-cli-agent-runbooks`
- `allium-cli-ci-and-quality-gates`

## Folder-level convention

Users invoke these skills on a folder of `.allium` files. The agent must resolve the folder to an entrypoint file before running CLI commands. Do not pass directories directly to `allium check`, `allium analyse`, `allium model`, or `allium plan`.

Typical convention:

```bash
SPEC_DIR="specs/allium"
ENTRYPOINT="specs/allium/index.allium"
allium check "$ENTRYPOINT"
allium analyse "$ENTRYPOINT"
```

## Suggested placement

Copy the `.agents/skills/` directory into the repository root:

```text
.agents/
  skills/
    allium-cli-project-conventions/
      SKILL.md
    ...
```

## Build order used

The skills are ordered to match the recommended operational priority:

1. project conventions
2. overview
3. command reference
4. check
5. diagnostics repair
6. analyse
7. model
8. plan
9. agent runbooks
10. output interpretation
11. parse
12. CI and quality gates
