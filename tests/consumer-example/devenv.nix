{ pkgs, ... }:

{
  packages = [
    pkgs.git
  ];

  # Enable Allium support from the imported devenv-allium module
  allium.enable = true;
  allium.specsDir = ".scratch/specs";
}
