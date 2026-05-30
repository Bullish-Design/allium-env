# Consumer Project Example

This is a test consumer project demonstrating how to use the `devenv-allium` shared module.

## Files

- **devenv.yaml** - Declares the `allium-dev` input pointing to the local devenv-allium repo
- **devenv.nix** - Enables and configures the Allium module
- **.scratch/specs/example.allium** - Example Allium specification file

## Testing

To test this consumer project:

```bash
cd tests/consumer-example

# Enter the devenv shell
devenv shell

# Verify Allium CLI is available
which allium
allium --help

# Verify Allium helper scripts are available
which allium-check
which allium-analyse
which allium-install-codex-skills

# Install Allium skills
allium-install-codex-skills

# Verify skills were installed
find .agents/skills -maxdepth 2 -name SKILL.md | sort

# Validate the example spec
allium-check
```

## Configuration

The `devenv.nix` enables Allium with minimal configuration:

```nix
{
  allium.enable = true;
  allium.specsDir = ".scratch/specs";
}
```

Available options:

- `allium.enable` - Enable Allium support (default: false)
- `allium.specsDir` - Directory containing `.allium` spec files (default: ".scratch/specs")
- `allium.cli.enable` - Include Allium CLI in shell (default: true)
- `allium.codexSkills.enable` - Provide allium-install-codex-skills script (default: true)
- `allium.codexSkills.autoInstall` - Auto-install skills on shell entry (default: false)
- `allium.codexSkills.targetDir` - Where to install skills (default: ".agents/skills")

## URL Format

The `devenv.yaml` uses `git+file://` for local testing:

```yaml
inputs:
  allium-dev:
    url: git+file:///home/andrew/Documents/Projects/allium-env
    flake: false
```

For production use, change to a GitHub URL:

```yaml
inputs:
  allium-dev:
    url: github:YOUR_ORG/devenv-allium?ref=v0.3.1
    flake: false
```
