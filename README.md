# devenv-allium

Shared devenv module for Allium support.

This repo owns:

- the vendored Allium source under `.vendor/allium`
- bundled local agent skill bundle under `.skills/allium-cli/skills`
- the pinned Allium CLI package definition
- reusable devenv scripts:
  - `allium-setup` - initialize or update vendored Allium
  - `allium-check`
  - `allium-analyse`
  - `allium-install-codex-skills`

## First time setup

After cloning this repository, initialize the vendored Allium source:

```bash
devenv shell
allium-setup
```

This runs `git subtree add` to vendor the Allium source under `.vendor/allium`.

## Use in a project

Add this to the consuming project's `devenv.yaml`:

```yaml
inputs:
  allium-dev:
    url: github:YOUR_ORG/devenv-allium?ref=v0.2.0
    flake: false

imports:
  - allium-dev
```

For a private GitHub repository over SSH:

```yaml
inputs:
  allium-dev:
    url: git+ssh://git@github.com/YOUR_ORG/devenv-allium.git?ref=v0.2.0
    flake: false

imports:
  - allium-dev
```

Then enable the module in the consuming project's `devenv.nix`:

```nix
{ ... }:

{
  allium.enable = true;
  allium.specsDir = ".scratch/specs";
}
```

Enter the shell and install skills:

```bash
devenv shell
allium-install-codex-skills
```

This installs:

- selected vendored skills from `.vendor/allium/skills`
- bundled local CLI skills from `.skills/allium-cli/skills`

Run Allium checks:

```bash
allium-check
allium-analyse
```

## Optional: Automatic skill installation

Enable `autoInstall` to have skills install automatically on shell entry:

```nix
{ ... }:

{
  allium.enable = true;
  allium.specsDir = ".scratch/specs";
  allium.codexSkills.autoInstall = true;
}
```

## Updating vendored Allium

To update to a newer Allium commit in this shared repo:

```bash
ALLIUM_REPO="https://github.com/juxt/allium.git"
ALLIUM_COMMIT="<new-reviewed-commit>"

git subtree pull \
  --prefix ".vendor/allium" \
  "$ALLIUM_REPO" \
  "$ALLIUM_COMMIT" \
  --squash
```

Review the diff:

```bash
git diff --stat
git diff -- .vendor/allium/skills
```

If the Allium CLI release changes, update the pinned release URL and hash in `devenv.nix`.

Tag and push:

```bash
git tag v0.2.0
git push origin main --tags
```

Then in consuming projects, update and test:

```bash
devenv update
devenv shell
allium-install-codex-skills
allium-check
allium-analyse
```

## Platform support

The `devenv.nix` pins Allium CLI releases for:

- `x86_64-linux` (verified)
- `aarch64-darwin` (placeholder - update with real hash)
- `x86_64-darwin` (placeholder - update with real hash)

To add support for additional platforms, update `alliumCliRelease` in `devenv.nix` with the appropriate download URL and hash.

Common Nix system names:

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

For unsupported platforms, consuming projects can:

1. Set `allium.cli.enable = false` and provide `allium` another way.
2. Override `allium.cli.package` with their own Allium package.

## Configuration options

- `allium.enable` - Enable Allium support
- `allium.specsDir` - Directory containing `.allium` spec files (default: `.scratch/specs`)
- `allium.cli.enable` - Add pinned Allium CLI to shell (default: `true`)
- `allium.cli.package` - Allium CLI package to use
- `allium.codexSkills.enable` - Provide `allium-install-codex-skills` script (default: `true`)
- `allium.codexSkills.autoInstall` - Auto-install skills on shell entry (default: `false`)
- `allium.codexSkills.targetDir` - Where to install skills (default: `.agents/skills`)
- `allium.codexSkills.skills` - List of vendored skill directories to install from `.vendor/allium/skills`
