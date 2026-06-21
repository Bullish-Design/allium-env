# Reusable Allium devenv module.
#
# This is the importable, enable-gated module that carries Allium's nix-layer
# provisioning: the pinned third-party `allium` CLI derivation, the
# `allium-install-codex-skills` installer script (+ its deps), the `ALLIUM_*` env
# `alliman doctor` reads, and the shell-entry asset-freshness check. It is consumed
# two ways:
#
#   1. allium-env's own ./devenv.nix imports it and sets `allium.enable = true`
#      (plus the repo-local editable `alliman` venv, which stays in devenv.nix).
#   2. A meta-module (repoman) imports `<allium-env>/modules/allium.nix` and flips
#      `allium.enable` on only when its "spec" manager is selected.
#
# `enable` defaults to FALSE so a bare import is inert — the importer opts in. Asset
# paths are relative to THIS file (../.vendor, ../.skills, ../.agents, ../scripts);
# those trees are tracked in git so they materialize through a `flake:false` input.
{ pkgs, lib, config, ... }:

let
  cfg = config.allium;

  alliumSource = ../.vendor/allium;
  alliumCliSkillBundle = ../.skills/allium-cli;
  alliumEntrypointSkill = ../.skills/allium-entrypoint;
  alliumPromptBundle = ../.agents;
  installCodexAssetsScript = ../scripts/install-codex-assets.sh;
  checkCodexAssetsScript = ../scripts/check-codex-assets-installed.sh;

  defaultAlliumSkills = [
    "allium"
    "elicit"
    "distill"
    "propagate"
    "tend"
    "weed"
  ];

  shellSkillList = builtins.concatStringsSep " " (map lib.escapeShellArg cfg.codexSkills.skills);

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
    # Opt-in: a bare import does nothing until the importer sets `allium.enable = true`
    # (allium-env's own devenv.nix does; repoman does it gated on the "spec" manager).
    enable = lib.mkEnableOption "Allium support";

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

    codexPrompts = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install bundled Allium prompts into the project.";
      };

      targetDir = lib.mkOption {
        type = lib.types.str;
        default = ".agents/prompts";
        description = "Directory, relative to the Git root unless absolute, where prompts should be installed.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optionals (cfg.cli.enable && systemSupported) [
      cfg.cli.package
    ];

    # Export the module's effective config so `alliman doctor` verifies the *actual* install
    # target/skills/prompts (not just its built-in defaults). These mirror the inline env the
    # installer and check scripts receive; exporting them into the shell lets doctor agree with
    # the module even when a consumer customizes targetDir / skills / prompts.
    env = {
      ALLIUM_CODEX_SKILLS_DIR = cfg.codexSkills.targetDir;
      ALLIUM_CODEX_PROMPTS_DIR = cfg.codexPrompts.targetDir;
      ALLIUM_SHELL_SKILL_LIST = shellSkillList;
      ALLIUM_PROMPTS_ENABLED = if cfg.codexPrompts.enable then "1" else "0";
      ALLIUM_EXPECTED_VENDORED_SOURCE = toString alliumSource;
    };

    scripts.allium-install-codex-skills = lib.mkIf cfg.codexSkills.enable {
      description = "Install Allium skills (and optional prompts) into the current repository.";
      packages = [
        pkgs.bash
        pkgs.git
        pkgs.coreutils
        pkgs.minijinja
      ];

      exec = ''
        ALLIUM_SOURCE=${lib.escapeShellArg (toString alliumSource)} \
        ALLIUM_SKILLS_DIR=${lib.escapeShellArg "${toString alliumSource}/skills"} \
        ALLIUM_CLI_SKILLS_DIR=${lib.escapeShellArg "${toString alliumCliSkillBundle}/skills"} \
        ALLIUM_ENTRYPOINT_SOURCE=${lib.escapeShellArg (toString alliumEntrypointSkill)} \
        ALLIUM_PROMPTS_DIR=${lib.escapeShellArg "${toString alliumPromptBundle}/prompts"} \
        ALLIUM_SPECS_DIR=${lib.escapeShellArg cfg.specsDir} \
        ALLIUM_CODEX_SKILLS_DIR=${lib.escapeShellArg cfg.codexSkills.targetDir} \
        ALLIUM_CODEX_PROMPTS_DIR=${lib.escapeShellArg cfg.codexPrompts.targetDir} \
        ALLIUM_SHELL_SKILL_LIST=${lib.escapeShellArg shellSkillList} \
        ALLIUM_PROMPTS_ENABLED=${if cfg.codexPrompts.enable then "1" else "0"} \
        ${pkgs.bash}/bin/bash ${lib.escapeShellArg (toString installCodexAssetsScript)}
      '';
    };

    enterShell = lib.optionalString cfg.codexSkills.enable ''
      _allium_needs_install=0
      if ! \
        ALLIUM_CODEX_SKILLS_DIR=${lib.escapeShellArg cfg.codexSkills.targetDir} \
        ALLIUM_CODEX_PROMPTS_DIR=${lib.escapeShellArg cfg.codexPrompts.targetDir} \
        ALLIUM_EXPECTED_VENDORED_SOURCE=${lib.escapeShellArg (toString alliumSource)} \
        ALLIUM_EXPECTED_CLI_SOURCE=${lib.escapeShellArg "${toString alliumCliSkillBundle}/skills"} \
        ALLIUM_EXPECTED_PROMPTS_SOURCE=${lib.escapeShellArg "${toString alliumPromptBundle}/prompts"} \
        ALLIUM_PROMPTS_ENABLED=${if cfg.codexPrompts.enable then "1" else "0"} \
        ${pkgs.bash}/bin/bash ${lib.escapeShellArg (toString checkCodexAssetsScript)}
      then
        _allium_needs_install=1
      fi
    '' + lib.optionalString (cfg.codexSkills.enable && cfg.codexSkills.autoInstall) ''
      # Auto-install Allium skills (and prompts when enabled) on shell entry.
      if [ "$_allium_needs_install" -eq 1 ]; then
        allium-install-codex-skills
      fi
      unset _allium_needs_install
    '';
  };
}
