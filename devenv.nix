{ lib, config, ... }:

let
  # The conforming `alliman` CLI lives in this repo (src/alliman). When the module is consumed
  # from elsewhere the source isn't at the project root, so the dev venv is only wired up when
  # the source is actually present; consumers pin the published package downstream instead.
  alliManSrcPresent = builtins.pathExists (config.devenv.root + "/src/alliman");
in
{
  # Allium's nix-layer provisioning (CLI derivation, installer script, env, asset
  # check) now lives in the reusable, enable-gated ./modules/allium.nix so meta-modules
  # (repoman) can import it. This shell opts in explicitly.
  imports = [ ./modules/allium.nix ];

  allium.enable = true;

  # Put the family-conforming `alliman` CLI (doctor / install-skills / init) on PATH via an
  # editable install of this repo's package, so `repoman doctor` can call `alliman doctor`.
  # Repo-local dev convenience — intentionally NOT in the reusable module (a consumer installs
  # `alliman` from its own lock/venv, not from this source tree).
  languages.python = lib.mkIf alliManSrcPresent {
    enable = true;
    version = "3.13";
    uv.enable = true;
    venv = {
      enable = true;
      requirements = "-e ${config.devenv.root}[dev]";
    };
  };
}
