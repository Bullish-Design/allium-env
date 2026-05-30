# Script Functionality Guide

## ⚠️ GOLDEN RULE

**All scripts must use established environment variables and module configuration values for ALL paths and functionality. NO hardcoded paths. NO assumptions about directory structure.**

This ensures:
- Relative paths work consistently across all scripts and projects
- Users can customize behavior via module options
- Scripts respect the actual configuration, not defaults
- All scripts are compatible with any project layout

---

## Overview

Scripts defined in the shared `devenv-allium` module's `devenv.nix` are automatically available to all consuming projects. This document explains how to add and manage scripts in the shared module.

## How Scripts Are Available

When a consuming project imports `devenv-allium`:

```yaml
inputs:
  allium-dev:
    url: github:Bullish-Design/allium-env?ref=v0.1.0
    flake: false

imports:
  - allium-dev
```

All scripts defined in the shared repo's `devenv.nix` become available in the consumer's devenv shell.

## Current Scripts

### Always Available (Not Gated)

**`allium-setup`** - Initialize or update vendored Allium source
- Available to all projects (even those with `allium.enable = false`)
- Used to initialize the shared repo's `.vendor/allium` via git subtree
- Can be run repeatedly; checks if already initialized

### Gated by `allium.enable = true`

**`allium-check`** - Validate Allium specifications
```bash
allium check <specsDir>
```
- Parses `.allium` files in the configured specs directory
- Returns structured JSON diagnostics
- Available when `allium.enable = true`

**`allium-analyse`** - Analyze Allium specifications
```bash
allium analyse <specsDir>
```
- Performs deeper analysis on specifications
- Available when `allium.enable = true`

**`allium-install-codex-skills`** - Install Allium skills
```bash
allium-install-codex-skills
```
- Copies skill directories from `.vendor/allium/skills` to target directory
- Gated by `allium.codexSkills.enable` (defaults to `true`)
- Validates skill structure and uses atomic operations

## Adding New Scripts

### Pattern 1: Always Available

Add to the first element of `lib.mkMerge`:

```nix
config = lib.mkMerge [
  {
    scripts.my-script = {
      description = "Brief description";
      packages = [ pkgs.git pkgs.jq ];  # Optional: packages needed for script
      exec = ''
        # Script implementation
        echo "Available everywhere"
      '';
    };
  }
  ...
]
```

### Pattern 2: Gated by Allium Enable

Add within `lib.mkIf cfg.enable`:

```nix
(lib.mkIf cfg.enable {
  scripts.allium-rebuild-specs = {
    description = "Rebuild all specifications";
    packages = [ pkgs.git ];
    exec = ''
      set -euo pipefail
      allium check ${lib.escapeShellArg cfg.specsDir}
      allium analyse ${lib.escapeShellArg cfg.specsDir}
    '';
  };
})
```

### Pattern 3: Gated by Sub-Option

Add within `lib.mkIf (cfg.enable && cfg.codexSkills.enable)`:

```nix
(lib.mkIf (cfg.enable && cfg.codexSkills.enable) {
  scripts.allium-list-skills = {
    description = "List available Allium skills";
    exec = ''
      echo "Available skills:"
      ls -1 ${lib.escapeShellArg (toString alliumSource)}/skills
    '';
  };
})
```

## Script Template

Use this template for consistency:

```nix
scripts.<name> = {
  description = "One-line description of what the script does";
  packages = [ ];  # Only if additional packages needed
  exec = ''
    set -euo pipefail

    # Script implementation
  '';
};
```

## Best Practices

1. **Use established environment variables**: ALL scripts must use the module's configuration values (`cfg.specsDir`, `cfg.codexSkills.targetDir`, etc.) instead of hardcoding paths. This ensures:
   - Consistency across all scripts
   - Relative paths work uniformly
   - Users can customize via module options
   - No assumptions about directory structure

2. **Use proper quoting**: `lib.escapeShellArg` for user-controlled values to prevent injection attacks

3. **Add error handling**: `set -euo pipefail` at the start for safety

4. **Document dependencies**: List required packages in `packages` attribute

5. **Keep descriptions concise**: One line, 50-70 characters

6. **Validate inputs**: Check that required files exist before processing

7. **Atomic operations**: Use temp files and move for atomicity (see `allium-install-codex-skills`)

## Example: Custom Validation Script

```nix
scripts.allium-validate-strict = {
  description = "Strict validation of all Allium specifications";
  packages = [ pkgs.git ];
  exec = ''
    set -euo pipefail

    specs_dir=${lib.escapeShellArg cfg.specsDir}

    if [ ! -d "$specs_dir" ]; then
      echo "Error: specs directory not found: $specs_dir" >&2
      exit 1
    fi

    echo "Running strict Allium validation..."
    allium check "$specs_dir"
    allium analyse "$specs_dir"
    echo "✓ All validations passed"
  '';
};
```

## Making Scripts Available Only on Some Platforms

Use `lib.optionals` to gate scripts by platform:

```nix
scripts.allium-macos-specific = lib.optionals pkgs.stdenv.isDarwin {
  description = "macOS-specific Allium helper";
  exec = ''
    echo "Running on macOS"
  '';
};
```

## Accessing Module Configuration in Scripts

**CRITICAL**: All scripts MUST use module configuration values for paths and options. This ensures consistency and allows users to customize behavior via module options.

Available configuration references:

- `cfg.specsDir` - Configured specifications directory (escape with `lib.escapeShellArg`)
- `cfg.cli.enable` - Whether CLI is enabled
- `cfg.codexSkills.targetDir` - Where skills are installed (escape with `lib.escapeShellArg`)
- `cfg.codexSkills.skills` - List of skills to operate on
- `alliumSource` - Path to vendored Allium source (`.vendor/allium`)

### ❌ DO NOT DO THIS:

```nix
scripts.bad-example = {
  exec = ''
    allium check .scratch/specs  # ❌ Hardcoded path!
    cp -r /vendor/allium/skills .agents/skills  # ❌ Hardcoded paths!
  '';
};
```

### ✅ DO THIS INSTEAD:

```nix
scripts.good-example = {
  description = "Display current Allium configuration";
  exec = ''
    echo "Specs directory: ${lib.escapeShellArg cfg.specsDir}"
    echo "Skills target: ${lib.escapeShellArg cfg.codexSkills.targetDir}"
    echo "CLI enabled: ${lib.boolToString cfg.cli.enable}"

    # Use config values in actual operations
    allium check ${lib.escapeShellArg cfg.specsDir}
  '';
};
```

### Why This Matters

1. **User Customization**: Consumers can set `allium.specsDir = ".specs"` and all scripts automatically use the custom path
2. **Relative Paths**: Scripts always work with the user's configured relative paths
3. **Consistency**: All scripts respect the same configuration, no surprises
4. **Maintainability**: Changes to paths only need to be made once in the config, not in every script

## Testing New Scripts

1. Add script to `devenv.nix` in shared repo
2. Commit and push
3. In a consumer project, run `devenv update`
4. Enter shell: `devenv shell`
5. Test the script: `<script-name>`

Or use local testing with `git+file://` URL in consumer's devenv.yaml.

## Future Script Ideas

- **`allium-export-specs`** - Export specifications to various formats
- **`allium-watch`** - Watch specs directory and auto-validate on changes
- **`allium-diff-specs`** - Compare specs between commits
- **`allium-generate-report`** - Generate human-readable spec report
- **`allium-merge-specs`** - Merge multiple specification files
- **`allium-lint`** - Custom linting beyond standard validation

## Documentation

When adding scripts, update:
1. This file with description and usage
2. The shared repo's `README.md` if it's a major feature
3. Add to completion checklist in the implementation guide if needed
