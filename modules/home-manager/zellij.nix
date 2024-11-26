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
          shared {
            bind "F1" { GoToTab 1; SwitchToMode "Normal"; }
            bind "F2" { GoToTab 2; SwitchToMode "Normal"; }
            bind "F3" { GoToTab 3; SwitchToMode "Normal"; }
            bind "F4" { GoToTab 4; SwitchToMode "Normal"; }
            bind "F5" { GoToTab 5; SwitchToMode "Normal"; }
            bind "F6" { GoToTab 6; SwitchToMode "Normal"; }
            bind "F7" { GoToTab 7; SwitchToMode "Normal"; }
            bind "F8" { GoToTab 8; SwitchToMode "Normal"; }
            bind "F9" { GoToTab 9; SwitchToMode "Normal"; }
          }
          shared_except "pane" "locked" {
            bind "Ctrl b" { SwitchToMode "Pane"; }
          }
          shared_except "locked" {
            bind "Ctrl h" { MoveFocusOrTab "Left"; }
            bind "Ctrl l" { MoveFocusOrTab "Right"; }
            bind "Ctrl j" { MoveFocus "Down"; }
            bind "Ctrl k" { MoveFocus "Up"; }
            unbind "Alt h" "Alt l" "Alt j" "Alt k" "Alt f"
          }
          unbind "Ctrl p" "Ctrl n"
      }
    '';
  };
}
