{ pkgs, lib, config, ... }:

let
  cfg = config.allium;

  alliumSource = ./.vendor/allium;
  alliumCliSkillBundle = ./.skills/allium-cli;
  alliumEntrypointSkill = ./.skills/allium-entrypoint;

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
    enable = (lib.mkEnableOption "Allium support") // {
      default = true;
    };

    specsDir = lib.mkOption {
      type = lib.types.str;
      default = ".scratch/specs/allium";
      description = "Directory where .allium specification files are stored. Baked into the entrypoint skill so agents know where to read and write specs.";
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

  config = lib.mkIf cfg.enable {
    packages = lib.optionals (cfg.cli.enable && systemSupported) [
      cfg.cli.package
    ];

    scripts.allium-install-codex-skills = lib.mkIf cfg.codexSkills.enable {
        description = "Install Allium skills into the current repository.";
        packages = [
          pkgs.git
          pkgs.coreutils
          pkgs.minijinja
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
          allium_cli_skill_bundle=${lib.escapeShellArg (toString alliumCliSkillBundle)}
          allium_cli_skills_dir="$allium_cli_skill_bundle/skills"
          allium_entrypoint_source=${lib.escapeShellArg (toString alliumEntrypointSkill)}
          specs_dir=${lib.escapeShellArg cfg.specsDir}
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
          echo "Vendored source: $allium_skills_dir"
          echo "Local source: $allium_cli_skills_dir"
          echo "Target: $target_root"
          echo

          install_skill_dir() {
            source_path="$1"
            target_path="$2"
            tmp_path="$target_root/.tmp-$(basename "$target_path")"

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
          }

          for skill in ${shellSkillList}; do
            source_path="$allium_skills_dir/$skill"
            target_path="$target_root/$skill"
            install_skill_dir "$source_path" "$target_path"
          done

          found_local_cli_skill=0
          for source_path in "$allium_cli_skills_dir"/*; do
            if [ ! -d "$source_path" ]; then
              continue
            fi

            if [ ! -f "$source_path/SKILL.md" ]; then
              continue
            fi

            found_local_cli_skill=1
            skill_name="$(basename "$source_path")"
            install_skill_dir "$source_path" "$target_root/$skill_name"
          done

          if [ "$found_local_cli_skill" -eq 0 ]; then
            echo "Error: expected at least one skill directory with SKILL.md in $allium_cli_skills_dir." >&2
            exit 1
          fi

          # Install entrypoint skill with specsDir baked in via Jinja2
          entrypoint_target="$target_root/allium-entrypoint"
          entrypoint_tmp="$target_root/.tmp-allium-entrypoint"
          rm -rf "$entrypoint_tmp"
          cp -R "$allium_entrypoint_source" "$entrypoint_tmp"
          chmod -R u+w "$entrypoint_tmp"
          minijinja-cli "$entrypoint_tmp/SKILL.md" -Dspecs_dir="$specs_dir" -o "$entrypoint_tmp/SKILL.md"
          rm -rf "$entrypoint_target"
          mv "$entrypoint_tmp" "$entrypoint_target"
          echo "Installed $entrypoint_target (specsDir=$specs_dir)"

          cat > "$target_root/.allium-devenv-source" <<SOURCE_EOF
Generated by allium-install-codex-skills.
Source module: devenv-allium
Vendored Allium source: $allium_source
Local Allium CLI skills source: $allium_cli_skills_dir

Do not edit these generated skill copies directly.
Update the shared devenv-allium repo, then rerun allium-install-codex-skills.
SOURCE_EOF

          echo
          echo "Allium skills installed."
          echo
          echo "If another editor reads skills from a different directory, symlink from $target_root."
        '';
      };

      enterShell = lib.optionalString cfg.codexSkills.enable ''
        _allium_target_dir=${lib.escapeShellArg cfg.codexSkills.targetDir}
        _allium_expected_vendored_source=${lib.escapeShellArg (toString alliumSource)}
        _allium_expected_cli_source=${lib.escapeShellArg "${toString alliumCliSkillBundle}/skills"}
        case "$_allium_target_dir" in
          /*)
            _allium_target_root="$_allium_target_dir"
            ;;
          *)
            if git rev-parse --show-toplevel >/dev/null 2>&1; then
              _allium_repo_root="$(git rev-parse --show-toplevel)"
              _allium_target_root="$_allium_repo_root/$_allium_target_dir"
            else
              _allium_target_root="$PWD/$_allium_target_dir"
            fi
            ;;
        esac

        _allium_needs_install=0
        if [ ! -f "$_allium_target_root/.allium-devenv-source" ] || [ ! -f "$_allium_target_root/allium-entrypoint/SKILL.md" ]; then
          _allium_needs_install=1
        elif ! grep -Fq "Vendored Allium source: $_allium_expected_vendored_source" "$_allium_target_root/.allium-devenv-source"; then
          _allium_needs_install=1
        elif ! grep -Fq "Local Allium CLI skills source: $_allium_expected_cli_source" "$_allium_target_root/.allium-devenv-source"; then
          _allium_needs_install=1
        fi

        if [ "$_allium_needs_install" -eq 1 ]; then
          echo
          echo "allium-env setup needed: skills are not installed in $_allium_target_root"
          echo "Run: allium-install-codex-skills"
          echo "Optional: set allium.codexSkills.autoInstall = true to install automatically on shell entry."
          echo
        fi

        unset _allium_target_dir _allium_target_root _allium_repo_root
        unset _allium_expected_vendored_source _allium_expected_cli_source
      '' + lib.optionalString (cfg.codexSkills.enable && cfg.codexSkills.autoInstall) ''
        # Auto-install Allium skills on shell entry.
        if [ "$_allium_needs_install" -eq 1 ]; then
          allium-install-codex-skills
        fi
        unset _allium_needs_install
      '';
  };
}
