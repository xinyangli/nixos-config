{ inputs, config, pkgs, ... }:
{
  imports = [
    ../common
    ../vscode.nix
    ../alacritty.nix
    inputs.nix-index-database.hmModules.nix-index
  ];

  programs.nix-index-database.comma.enable = true;

  home.username = "xin";
  home.homeDirectory = "/home/xin";
  home.stateVersion = "23.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  accounts.email.accounts.gmail = {
    primary = true;
    address = "lixinyang411@gmail.com";
    flavor = "gmail.com";
  };

  accounts.email.accounts.whu = {
    address = "lixinyang411@whu.edu.cn";
  };

  accounts.email.accounts.foxmail = {
    address = "lixinyang411@foxmail.com";
  };

  home.packages = with pkgs; [
    thunderbird
    remmina
  ];
}
