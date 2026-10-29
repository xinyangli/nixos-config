{ config, pkgs, ... }:
{
  programs.vicinae = {
    enable = true;
    # Use nixpkgs' prebuilt vicinae (same version as the flake) instead of
    # compiling the flake's package from source; upstream CI does not push
    # Linux binaries to vicinae.cachix.org, so the flake package always
    # builds locally (Qt6/CMake, very slow).
    package = pkgs.vicinae;
    systemd = {
      enable = true;
      autoStart = true;
    };
    settings = {
      faviconService = "twenty";
      font.size = 12;
      popToRootOnClose = false;
      closeOnFocusLoss = true;
      rootSearch.searchFiles = false;
      theme.name = "catppuccin-${config.catppuccin.flavor}"; # Use dark theme to match your setup
      window = {
        csd = true;
        rounding = 12;
      };
    };
  };
}
