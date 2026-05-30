# DEVENV Allium Implementation Guide

This guide describes how to create a dedicated `devenv-allium` repository that owns the Allium-related devenv module, the vendored Allium skill source, and the helper scripts needed by consuming projects.

The goal is to let any devenv-managed project opt in with a small `devenv.yaml` import and a small `devenv.nix` configuration block.

## Target architecture

```text
devenv-allium/
├── devenv.nix
├── README.md                         # optional but recommended
└── .vendor/
    └── allium/                       # vendored Allium source

consumer-project/
├── devenv.yaml                       # imports devenv-allium
├── devenv.nix                        # enables allium.enable
├── devenv.lock                       # pins imported input revisions
└── .agents/
    └── skills/                       # generated or committed Allium skills
```

The shared repo is responsible for reusable Allium behavior. Consumer repos should not also vendor Allium unless they intentionally need a project-specific fork.

## Relevant devenv rules

Before implementing the repo, understand these constraints:

1. `devenv.yaml` is where a consumer declares external inputs and imports.
2. Remote input imports should expose reusable behavior through `devenv.nix`, not through a remote `devenv.yaml` that consumers expect to be merged.
3. `devenv.lock` records the resolved input revisions and should be committed by consuming projects.
4. `devenv update` refreshes those pinned input revisions.
5. Devenv scripts can declare per-script runtime packages through the script-level `packages` attribute. This lets a script use tools such as `git` without requiring each consumer project to add those tools globally.

References:

- https://devenv.sh/reference/yaml-options
- https://devenv.sh/composing-using-imports/
- https://devenv.sh/inputs/
- https://devenv.sh/scripts/
- https://devenv.sh/blog/2025/09/17/devenv-19-scaling-nix-projects-using-modules-and-profiles/
- https://devenv.sh/blog/2025/10/07/devenv-110-monorepo-nix-support-with-devenvyaml-imports/
- https://devenv.sh/blog/2026/03/05/devenv-20-a-fresh-interface-to-nix/

## Step 1: Create the shared repository

Pick a repository name. This guide uses `devenv-allium`.

```bash
mkdir devenv-allium
cd devenv-allium
git init
```

Create the hidden vendor directory:

```bash
mkdir -p .vendor
```

## Step 2: Vendor Allium into the shared repo

Use `git subtree` to vendor the Allium source under `.vendor/allium`.

```bash
ALLIUM_REPO="https://github.com/juxt/allium.git"
ALLIUM_COMMIT="82da292e989d518f79189fdfef4446d0d517c277"

git subtree add \
  --prefix ".vendor/allium" \
  "$ALLIUM_REPO" \
  "$ALLIUM_COMMIT" \
  --squash
```

Expected result:

```text
.vendor/allium/skills/allium/SKILL.md
.vendor/allium/skills/elicit/SKILL.md
.vendor/allium/skills/distill/SKILL.md
.vendor/allium/skills/propagate/SKILL.md
.vendor/allium/skills/tend/SKILL.md
.vendor/allium/skills/weed/SKILL.md
```

Check that the expected skill files exist:

```bash
find .vendor/allium/skills -maxdepth 2 -name SKILL.md | sort
```

If the expected paths do not exist, stop and inspect the vendored Allium tree before continuing. The reusable module assumes this layout.

## Step 3: Add the reusable devenv module

Copy the provided `devenv.nix` file into the root of `devenv-allium`.

Expected path:

```text
devenv-allium/devenv.nix
```

The module defines these options:

```nix
allium.enable
allium.specsDir
allium.cli.enable
allium.cli.package
allium.codexSkills.enable
allium.codexSkills.targetDir
allium.codexSkills.skills
```

It also defines these scripts when `allium.enable = true`:

```text
allium-check
allium-analyse
allium-install-codex-skills
```

And these configuration options:

```nix
allium.codexSkills.autoInstall
```

### What the module does

`allium-check` runs:

```bash
allium check <configured specs directory>
```

`allium-analyse` runs:

```bash
allium analyse <configured specs directory>
```

`allium-install-codex-skills` copies the vendored Allium skill directories into the consuming repository, defaulting to:

```text
.agents/skills
```

The installer copies the complete skill directories, not only the `SKILL.md` files. This preserves the relative file structure used by the Allium skill material.

## Step 4: Add a README to the shared repo

Create `README.md` with the following content, then adjust `YOUR_ORG` to match your GitHub organization or username.

```md
# devenv-allium

Shared devenv module for Allium support.

This repo owns:

- the vendored Allium source under `.vendor/allium`
- the pinned Allium CLI package definition
- reusable devenv scripts:
  - `allium-check`
  - `allium-analyse`
  - `allium-install-codex-skills`

## Use in a project

Add this to the consuming project's `devenv.yaml`:

```yaml
inputs:
  allium-dev:
    url: github:YOUR_ORG/devenv-allium?ref=v0.1.0
    flake: false

imports:
  - allium-dev
```

For a private GitHub repository over SSH:

```yaml
inputs:
  allium-dev:
    url: git+ssh://git@github.com/YOUR_ORG/devenv-allium.git?ref=v0.1.0
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

Run Allium checks:

```bash
allium-check
allium-analyse
```

### Optional: Automatic skill installation

If you want skills to install automatically when entering the shell, enable `autoInstall`:

```nix
{ ... }:

{
  allium.enable = true;
  allium.specsDir = ".scratch/specs";
  allium.codexSkills.autoInstall = true;
}
```

With this setting, `allium-install-codex-skills` runs automatically the first time you enter a shell (tracked via a marker file in `$XDG_CACHE_HOME`). This is useful when consuming projects expect skills to be present immediately after `devenv shell`.

## Updating vendored Allium

```bash
ALLIUM_REPO="https://github.com/juxt/allium.git"
ALLIUM_COMMIT="<new-reviewed-commit>"

git subtree pull \
  --prefix ".vendor/allium" \
  "$ALLIUM_REPO" \
  "$ALLIUM_COMMIT" \
  --squash
```

If the Allium CLI release changes, update the pinned release URL and hash in `devenv.nix`.

Tag the shared repo after updates:

```bash
git tag v0.2.0
git push origin main --tags
```
```

## Step 5: Commit the shared repo

Review the files:

```bash
git status
```

You should see at least:

```text
devenv.nix
README.md
.vendor/allium/...
```

Commit them:

```bash
git add devenv.nix README.md .vendor/allium
git commit -m "Create shared Allium devenv module"
```

## Step 6: Publish the shared repo

Create the remote repository in GitHub or your Git host. Then push it.

```bash
git remote add origin git@github.com:YOUR_ORG/devenv-allium.git
git push -u origin main
```

Create the first stable tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Use tags for consumer imports. Avoid requiring consumers to track a moving branch unless that is intentional.

## Step 7: Test from a local consumer repo before using it broadly

Create a scratch consumer project:

```bash
mkdir /tmp/allium-consumer-test
cd /tmp/allium-consumer-test
git init
```

Create `devenv.yaml` pointing at the local repo. Use `git+file` with an absolute path.

```yaml
inputs:
  allium-dev:
    url: git+file:///ABSOLUTE/PATH/TO/devenv-allium
    flake: false

imports:
  - allium-dev
```

Create `devenv.nix`:

```nix
{ ... }:

{
  allium.enable = true;
  allium.specsDir = ".scratch/specs";
}
```

Enter the devenv shell:

```bash
devenv shell
```

Install the skills:

```bash
allium-install-codex-skills
```

Check the generated files:

```bash
find .agents/skills -maxdepth 2 -name SKILL.md | sort
```

Expected result:

```text
.agents/skills/allium/SKILL.md
.agents/skills/distill/SKILL.md
.agents/skills/elicit/SKILL.md
.agents/skills/propagate/SKILL.md
.agents/skills/tend/SKILL.md
.agents/skills/weed/SKILL.md
```

Check that the helper scripts are available:

```bash
which allium-check
which allium-analyse
which allium-install-codex-skills
```

Check the Allium CLI:

```bash
which allium
allium --help
```

If `allium --help` works, the pinned CLI package is available in the shell.

## Step 8: Use the shared module in a real project

In a real consuming project, add this to `devenv.yaml`:

```yaml
inputs:
  allium-dev:
    url: github:YOUR_ORG/devenv-allium?ref=v0.1.0
    flake: false

imports:
  - allium-dev
```

For a private repo over SSH, use:

```yaml
inputs:
  allium-dev:
    url: git+ssh://git@github.com/YOUR_ORG/devenv-allium.git?ref=v0.1.0
    flake: false

imports:
  - allium-dev
```

Then enable the module in the consuming project's `devenv.nix`:

```nix
{ pkgs, ... }:

{
  packages = [
    pkgs.git
    pkgs.uv
  ];

  languages.python = {
    enable = true;
    version = "3.13";
    venv.enable = true;
    uv.enable = true;
  };

  allium = {
    enable = true;
    specsDir = ".scratch/specs";
  };
}
```

Then run:

```bash
devenv shell
allium-install-codex-skills
allium-check
allium-analyse
```

Commit these files in the consuming project:

```text
devenv.yaml
devenv.nix
devenv.lock
```

Then decide whether to commit `.agents/skills`.

## Step 9: Decide whether `.agents/skills` should be committed

There are two reasonable policies.

### Policy A: Commit generated skills

Use this when coding agents need the skills present immediately after checkout.

Pros:

- Agent environments can read skills without running setup first.
- Reviewers can see exactly what changed when Allium is updated.
- Reproducibility does not depend on each local shell running the installer.

Cons:

- The consuming repo contains generated vendor output.
- Allium updates create larger diffs.

Recommended when the repo is primarily used by coding agents or CI-like agent workflows.

### Policy B: Do not commit generated skills

Use this when you want cleaner consumer repositories.

Add this to the consuming project's `.gitignore`:

```gitignore
# Generated from imported devenv-allium module
.agents/skills/allium
.agents/skills/elicit
.agents/skills/distill
.agents/skills/propagate
.agents/skills/tend
.agents/skills/weed
.agents/skills/.allium-devenv-source
```

Pros:

- Consumer repos stay smaller.
- The shared repo remains the only source of vendored Allium code.

Cons:

- Developers and agents must run `allium-install-codex-skills` after entering the shell.
- Fresh checkouts do not contain the skill files until setup runs.

Recommended when human developers reliably enter the devenv shell before using the repo.

## Step 10: Update vendored Allium later

In `devenv-allium`:

```bash
cd /path/to/devenv-allium

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

If the Allium CLI release also changed, update these values in `devenv.nix`:

```nix
alliumCliRelease = {
  x86_64-linux = {
    url = "...";
    hash = "...";
  };
};
```

Commit and tag:

```bash
git add devenv.nix .vendor/allium
git commit -m "Update vendored Allium"
git tag v0.2.0
git push origin main --tags
```

In each consuming project:

```bash
devenv update
devenv shell
allium-install-codex-skills
allium-check
allium-analyse
```

Commit the updated lockfile:

```bash
git add devenv.lock
git commit -m "Update shared Allium devenv input"
```

If the consumer commits generated skills, also commit the regenerated `.agents/skills` changes:

```bash
git add .agents/skills
git commit -m "Regenerate Allium agent skills"
```

## Step 11: Platform support notes

The provided `devenv.nix` includes pinned releases for multiple platforms:

```nix
alliumCliRelease = {
  x86_64-linux = { ... };
  aarch64-darwin = { ... };
  x86_64-darwin = { ... };
};
```

If a platform is not supported:
- Consumers with `allium.cli.enable = false` will not error.
- Consumers with the default `allium.cli.enable = true` will get a clear error message only when they enter the shell.
- Either add your platform to `alliumCliRelease` in the shared repo, or override `allium.cli.package` in the consuming project.

If your team uses ARM Linux or other platforms not listed, add entries for those systems:

Common Nix system names:

```text
x86_64-linux
aarch64-linux
x86_64-darwin
aarch64-darwin
```

If a consumer project wants to supply its own Allium package, it can override the package:

```nix
{ pkgs, ... }:

{
  allium = {
    enable = true;
    cli.package = pkgs.callPackage ./nix/allium-cli.nix { };
  };
}
```

If a consumer project already provides `allium` some other way, it can disable the bundled CLI:

```nix
{
  allium = {
    enable = true;
    cli.enable = false;
  };
}
```

In that case, `allium-check` and `allium-analyse` still expect an `allium` executable to be available in `PATH`.

## Troubleshooting

### `imports: - allium-dev` does not work

Check that `devenv.yaml` has both the input and the import:

```yaml
inputs:
  allium-dev:
    url: github:YOUR_ORG/devenv-allium?ref=v0.1.0
    flake: false

imports:
  - allium-dev
```

Check that the shared repo has `devenv.nix` at the repository root.

Do not depend on a remote imported `devenv.yaml` inside the shared repo. Put reusable module behavior in root `devenv.nix`.

### `allium-install-codex-skills` says it is not in a Git repository

Run it from inside the consuming project's Git worktree.

```bash
cd /path/to/consumer-project
allium-install-codex-skills
```

The script uses the Git root as the base for relative `allium.codexSkills.targetDir` paths.

### `expected .../SKILL.md to exist`

The vendored Allium layout is not what the module expects.

Check:

```bash
find .vendor/allium/skills -maxdepth 2 -name SKILL.md | sort
```

If the skill directories moved upstream, update `allium.codexSkills.skills` or update the installer logic.

### `No pinned Allium CLI release configured for system`

The current module does not have a release entry for your platform, and `allium.cli.enable = true` (the default).

Fix by either:

1. Adding your platform to `alliumCliRelease` in the shared repo, then update the consuming project's `devenv.lock`.
2. Setting `allium.cli.enable = false` in the consuming project (you will need to provide `allium` yourself).
3. Overriding `allium.cli.package` in the consuming project with your own package.

### The generated skills were edited by hand

Do not keep manual edits in `.agents/skills`. Change the source in `devenv-allium`, then rerun:

```bash
allium-install-codex-skills
```

The installer intentionally overwrites the generated skill directories.

## Completion checklist for the intern

Shared repo:

- [ ] Created `devenv-allium`.
- [ ] Added Allium subtree under `.vendor/allium`.
- [ ] Confirmed `.vendor/allium/skills/*/SKILL.md` files exist.
- [ ] Added root `devenv.nix`.
- [ ] Added `README.md`.
- [ ] Committed the repo.
- [ ] Pushed to GitHub or the chosen Git host.
- [ ] Tagged `v0.1.0`.

Local consumer test:

- [ ] Created scratch Git repo.
- [ ] Added `devenv.yaml` with `git+file:///.../devenv-allium` input.
- [ ] Added `devenv.nix` with `allium.enable = true`.
- [ ] Ran `devenv shell`.
- [ ] Ran `allium-install-codex-skills`.
- [ ] Confirmed generated `.agents/skills/*/SKILL.md` files.
- [ ] Confirmed `allium --help` works.
- [ ] Confirmed `allium-check` and `allium-analyse` exist.

Real consumer project:

- [ ] Added remote `allium-dev` input to `devenv.yaml`.
- [ ] Added `imports: - allium-dev`.
- [ ] Enabled `allium.enable = true` in `devenv.nix`.
- [ ] Ran `devenv shell`.
- [ ] Ran `allium-install-codex-skills`.
- [ ] Ran `allium-check` and `allium-analyse`.
- [ ] Committed `devenv.yaml`, `devenv.nix`, and `devenv.lock`.
- [ ] Chose whether to commit or ignore `.agents/skills`.
