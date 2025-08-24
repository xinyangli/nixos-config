# Reference: https://github.com/eztakesin/nixos-config-1/blob/0f39a5f554ca607b723ee9e166a2e731f6a84336/home/modules/rime-fcitx.nix
{
  config,
  pkgs,
  lib,
  ...
}:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        (fcitx5-rime.override {
          rimeDataPkgs = [
            rime-ice
            rime-zhwiki
            ../rime-custom
          ];
        })
        fcitx5-gtk
      ];
      waylandFrontend = true;
      settings = {
        globalOptions = { };
        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "rime";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "rime";
        };
      };
    };
  };
}
