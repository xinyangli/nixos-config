{ config, lib, ... }: 

with lib;

let
  cfg = config.custom-hm.zellij;
in
{
  options.custom-hm.zellij = {
    enable = mkEnableOption "zellij configurations";
  };
  config = {
    programs.zellij = mkIf cfg.enable {
      enable = true;
      settings = {
        default_shell = "fish";
      };
    };
    xdg.configFile."zellij/config.kdl".text = ''
      keybinds {
          shared_except "pane" "locked" {
            bind "Ctrl b" { SwitchToMode "Pane"; }
          }
          shared_except "locked" {
            bind "Ctrl h" { MoveFocusOrTab "Left"; }
            bind "Ctrl l" { MoveFocusOrTab "Right"; }
            bind "Ctrl j" { MoveFocus "Down"; }
            bind "Ctrl k" { MoveFocus "Up"; }
            unbind "Alt h" "Alt l" "Alt j" "Alt k"
          }
          unbind "Ctrl p" "Ctrl n"
      }
    '';
  };
}
