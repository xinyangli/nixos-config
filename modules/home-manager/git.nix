{ config, pkgs, lib, ... }: 

with lib;

let
  cfg = config.custom-hm.git;
in
{
  options = {
    enable = mkEnableOption "Enable git configuration";
  };
  config = {
    programs.git = {
      enable = true;
      delta.enable = true;
      userName = "Xinyang Li";
      userEmail = "lixinyang411@gmail.com";
      aliases = {
        graph = "log --all --oneline --graph --decorate";
        a = "add";
        d = "diff";
        s = "status";
      };
    };
  };
}