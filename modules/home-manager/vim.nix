{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption getExe;
  cfg = config.custom-hm.neovim;
  tomlFormat = pkgs.formats.toml { };
  neovideConfig = {
    neovim-bin = getExe pkgs.nixvim;
    fork = true;
  };
in
{
  options.custom-hm.neovim = {
    enable = mkEnableOption "neovim configurations";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [ nixvim neovide ];
    programs.neovim.enable = false;
    home.file.".config/neovide/config.toml" = {
      source = tomlFormat.generate "neovide-config" neovideConfig;
    };
  };
}
