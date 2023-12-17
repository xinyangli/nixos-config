{ config, pkgs, lib, ... }: 

with lib;

let
  cfg = config.custom-hm.fish;
in
{
  options = {
    enable = mkEnableOption "fish";
    plugins = mkOption {
      type = types.listOf types.str;
      default = [ "pisces" "done" "hydro" ];
    };
    functions = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
    };
    alias = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
    };
  };

  config = {
    programs.fish = mkIf cfg.enable {
      enable = true;
      plugins = with pkgs; filter (
        e: hasAttr e.name builtins.listToAttrs # { "xxx" = true; }
           (map (p: { name = p; value = true; }) cfg.plugins) # { name = "xxx"; value = true; }
        ) [
        {
          name = "pisces";
          src = fishPlugins.pisces.src;
        }
        {
          name = "done";
          src = fishPlugins.done.src;
        }
        {
          name = "hydro";
          src = fishPlugins.hydro.src;
        }
      ];
      interactiveShellInit = let
        extraInit = if cfg.functions.enable then ''
          ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
          function fish_right_prompt
            if test -n "$IN_NIX_SHELL"
              echo -n "<nix-shell>"
            else if test $SHLVL -ge 3
              echo -n "<🚀lv$SHLVL>"
            end
          end
          function fish_command_not_found
            ${pkgs.comma}/bin/comma $argv
          end
        '' else "";
      in ''
        fish_config theme choose 'ayu Dark'
        fish_config prompt choose arrow
      '' + extraInit;
      functions = mkIf cfg.functions.enable {
        gitignore = "curl -sL https://www.gitignore.io/api/$argv";
      };
    };
  };
}
