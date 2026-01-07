{ config, ... }:
{
  services.vicinae = {
    enable = true;
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
