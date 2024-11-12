{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.custom-hm.git;
in
{
  options.custom-hm.git = {
    enable = mkEnableOption "Enable git configuration";
    signing = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Git ssh signing";
          keyFile = mkOption {
            type = types.str;
            default = "~/.ssh/id_ed25519_sk.pub";
          };
        };
      };
    };
  };
  config = {
    programs.git = mkIf cfg.enable {
      enable = true;
      delta.enable = true;
      userName = "Xinyang Li";
      userEmail = "lixinyang411@gmail.com";
      aliases = {
        graph = "log --all --oneline --graph --decorate";
        a = "add";
        d = "diff";
        s = "status";
        ck = "checkout";
      };
      signing = mkIf cfg.signing.enable {
        signByDefault = true;
        key = cfg.signing.keyFile;
      };
      extraConfig.user = mkIf cfg.signing.enable { signingkey = cfg.signing.keyFile; };
      extraConfig.gpg = mkIf cfg.signing.enable { format = "ssh"; };
    };
  };
}
