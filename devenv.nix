{ pkgs, lib, config, ... }:

let
  cfg = config.allium;

  alliumSource = ./.vendor/allium;

  defaultAlliumSkills = [
    "allium"
    "elicit"
    "distill"
    "propagate"
    "tend"
    "weed"
  ];

  shellSkillList =
    builtins.concatStringsSep " " (map lib.escapeShellArg cfg.codexSkills.skills);

  # Pinned Allium CLI release.
  # Add entries for additional systems as needed.
  alliumCliRelease = {
    x86_64-linux = {
      url = "https://github.com/juxt/allium-tools/releases/download/v3.2.3/allium-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256-Phr77ZmwOaH+ZZsaOqpp27J0v+GKBoBXHJ0KSrOsIF8=";
    };
    aarch64-darwin = {
      url = "https://github.com/juxt/allium-tools/releases/download/v3.2.3/allium-aarch64-apple-darwin.tar.gz";
      hash = "sha256-PLACEHOLDER_AARCH64_DARWIN";
    };
    x86_64-darwin = {
      url = "https://github.com/juxt/allium-tools/releases/download/v3.2.3/allium-x86_64-apple-darwin.tar.gz";
      hash = "sha256-PLACEHOLDER_X86_64_DARWIN";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  systemSupported = builtins.hasAttr system alliumCliRelease;

  alliumCli =
    if systemSupported then
      pkgs.stdenv.mkDerivation {
        pname = "allium";
        version = "3.2.3";

        src = pkgs.fetchurl {
          inherit (alliumCliRelease.${system}) url hash;
        };

        sourceRoot = ".";
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          binary="$(find . -type f -name allium | head -n1)"

          if [ -z "$binary" ]; then
            echo "Could not find allium binary in release archive" >&2
            exit 1
          fi

          install -m755 "$binary" "$out/bin/allium"

          runHook postInstall
        '';

        meta = with lib; {
          description = "Pinned Allium CLI";
          homepage = "https://github.com/juxt/allium-tools";
          mainProgram = "allium";
          platforms = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
        };
      }
    else
      null;
in
{
  options.allium = {
    enable = lib.mkEnableOption "Allium support";

    specsDir = lib.mkOption {
      type = lib.types.str;
      default = ".scratch/specs";
      description = "Directory containing .allium specification files.";
    };

    cli = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to add the pinned Allium CLI package to the shell.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default =
          if systemSupported then
            alliumCli
          else
            throw ''
              No pinned Allium CLI release configured for system: ${system}

              Either:
              - add this platform to alliumCliRelease in devenv-allium,
              - set allium.cli.enable = false in your consuming project, or
              - override allium.cli.package with your own package.
            '';
        description = "Allium CLI package to add to the shell.";
      };
    };

    codexSkills = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to provide a script that installs Allium skills into the project.";
      };

      autoInstall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to automatically run allium-install-codex-skills when entering the shell.";
      };

      targetDir = lib.mkOption {
        type = lib.types.str;
        default = ".agents/skills";
        description = "Directory, relative to the Git root unless absolute, where skills should be installed.";
      };

      skills = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = defaultAlliumSkills;
        description = "Skill directories to copy from the vendored Allium source.";
      };
    };
  };

  config = lib.mkMerge [
    # allium-setup is always available (not gated by cfg.enable)
    # so it can be used to initialize the shared repo
    {
      scripts.allium-setup = {
        description = "Initialize or update vendored Allium source.";
        packages = [
          pkgs.git
          pkgs.coreutils
        ];

        exec = ''
          set -euo pipefail

          ALLIUM_REPO="https://github.com/juxt/allium.git"
          ALLIUM_COMMIT="82da292e989d518f79189fdfef4446d0d517c277"

          if [ -d ".vendor/allium" ]; then
            echo "Allium source already vendored at .vendor/allium"
            echo "To update, run:"
            echo "  git subtree pull --prefix .vendor/allium $ALLIUM_REPO $ALLIUM_COMMIT --squash"
          else
            echo "Initializing Allium vendored source..."
            mkdir -p .vendor
            git subtree add \
              --prefix ".vendor/allium" \
              "$ALLIUM_REPO" \
              "$ALLIUM_COMMIT" \
              --squash
            echo "Allium vendored successfully."
            echo "Verify with: find .vendor/allium/skills -maxdepth 2 -name SKILL.md | sort"
          fi
        '';
      };
    }

    (lib.mkIf cfg.enable {
      packages = lib.optionals (cfg.cli.enable && systemSupported) [
        cfg.cli.package
      ];

      scripts.allium-check = {
        description = "Run allium check against the configured specs directory.";
        exec = ''
          set -euo pipefail
          allium check ${lib.escapeShellArg cfg.specsDir}
        '';
      };

      scripts.allium-analyse = {
        description = "Run allium analyse against the configured specs directory.";
        exec = ''
          set -euo pipefail
          allium analyse ${lib.escapeShellArg cfg.specsDir}
        '';
      };

      scripts.allium-install-codex-skills = lib.mkIf cfg.codexSkills.enable {
        description = "Install vendored Allium skills into the current repository.";
        packages = [
          pkgs.git
          pkgs.coreutils
        ];

        exec = ''
          set -euo pipefail

          if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
            echo "Error: run this from inside a Git repository." >&2
            exit 1
          fi

          repo_root="$(git rev-parse --show-toplevel)"
          allium_source=${lib.escapeShellArg (toString alliumSource)}
          allium_skills_dir="$allium_source/skills"
          codex_skills_dir=${lib.escapeShellArg cfg.codexSkills.targetDir}

          case "$codex_skills_dir" in
            /*)
              target_root="$codex_skills_dir"
              ;;
            *)
              target_root="$repo_root/$codex_skills_dir"
              ;;
          esac

          mkdir -p "$target_root"

          echo "Installing Allium skills"
          echo "Source: $allium_skills_dir"
          echo "Target: $target_root"
          echo

          for skill in ${shellSkillList}; do
            source_path="$allium_skills_dir/$skill"
            target_path="$target_root/$skill"
            tmp_path="$target_root/.tmp-$skill"

            if [ ! -f "$source_path/SKILL.md" ]; then
              echo "Error: expected $source_path/SKILL.md to exist." >&2
              exit 1
            fi

            rm -rf "$tmp_path"
            cp -R "$source_path" "$tmp_path"
            chmod -R u+w "$tmp_path"

            rm -rf "$target_path"
            mv "$tmp_path" "$target_path"

            echo "Installed $target_path"
          done

          cat > "$target_root/.allium-devenv-source" <<SOURCE_EOF
Generated by allium-install-codex-skills.
Source module: devenv-allium
Vendored Allium source: $allium_source

Do not edit these generated skill copies directly.
Update the shared devenv-allium repo, then rerun allium-install-codex-skills.
SOURCE_EOF

          echo
          echo "Allium skills installed."
          echo
          echo "If another editor reads skills from a different directory, symlink from $target_root."
        '';
      };

      enterShell = lib.mkIf cfg.codexSkills.autoInstall ''
        # Auto-install Allium skills on shell entry.
        # Use a marker file to avoid re-running on every shell entry.
        _allium_marker="''${XDG_CACHE_HOME:-$HOME/.cache}/devenv-allium-skills-installed"
        if [ ! -f "$_allium_marker" ]; then
          allium-install-codex-skills
          mkdir -p "''${XDG_CACHE_HOME:-$HOME/.cache}"
          touch "$_allium_marker"
        fi
        unset _allium_marker
      '';
    })
  ];
}
