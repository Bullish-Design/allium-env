#!/usr/bin/env bash
set -euo pipefail

require_env() {
  var_name="$1"
  if [ -z "${!var_name:-}" ]; then
    echo "Error: required environment variable $var_name is not set." >&2
    exit 2
  fi
}

resolve_target_root() {
  target_dir="$1"
  case "$target_dir" in
    /*)
      printf '%s\n' "$target_dir"
      ;;
    *)
      if git rev-parse --show-toplevel >/dev/null 2>&1; then
        repo_root="$(git rev-parse --show-toplevel)"
        printf '%s/%s\n' "$repo_root" "$target_dir"
      else
        printf '%s/%s\n' "$PWD" "$target_dir"
      fi
      ;;
  esac
}

require_env ALLIUM_CODEX_SKILLS_DIR
require_env ALLIUM_EXPECTED_VENDORED_SOURCE
require_env ALLIUM_EXPECTED_CLI_SOURCE
require_env ALLIUM_PROMPTS_ENABLED

if [ "$ALLIUM_PROMPTS_ENABLED" = "1" ]; then
  require_env ALLIUM_CODEX_PROMPTS_DIR
  require_env ALLIUM_EXPECTED_PROMPTS_SOURCE
fi

skills_target_root="$(resolve_target_root "$ALLIUM_CODEX_SKILLS_DIR")"
prompts_target_root=""
if [ "$ALLIUM_PROMPTS_ENABLED" = "1" ]; then
  prompts_target_root="$(resolve_target_root "$ALLIUM_CODEX_PROMPTS_DIR")"
fi

needs_install=0
if [ ! -f "$skills_target_root/.allium-devenv-source" ] || [ ! -f "$skills_target_root/allium-entrypoint/SKILL.md" ]; then
  needs_install=1
elif ! grep -Fq "Vendored Allium source: $ALLIUM_EXPECTED_VENDORED_SOURCE" "$skills_target_root/.allium-devenv-source"; then
  needs_install=1
elif ! grep -Fq "Local Allium CLI skills source: $ALLIUM_EXPECTED_CLI_SOURCE" "$skills_target_root/.allium-devenv-source"; then
  needs_install=1
elif [ "$ALLIUM_PROMPTS_ENABLED" = "1" ] && [ ! -d "$prompts_target_root" ]; then
  needs_install=1
elif [ "$ALLIUM_PROMPTS_ENABLED" = "1" ] && ! grep -Fq "Local Allium prompts source: $ALLIUM_EXPECTED_PROMPTS_SOURCE" "$skills_target_root/.allium-devenv-source"; then
  needs_install=1
fi

if [ "$needs_install" -eq 1 ]; then
  echo
  if [ "$ALLIUM_PROMPTS_ENABLED" = "1" ]; then
    echo "allium-env setup needed: skills and prompts are not installed in $skills_target_root / $prompts_target_root"
  else
    echo "allium-env setup needed: skills are not installed in $skills_target_root"
  fi
  echo "Run: allium-install-codex-skills"
  echo "Optional: set allium.codexSkills.autoInstall = true to install automatically on shell entry."
  echo
  exit 1
fi
