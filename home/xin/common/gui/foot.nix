{ pkgs, lib, ... }:
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "monospace:size=14";
      };
      desktop-notifications = {
        command = "${lib.getExe pkgs.libnotify} --wait --app-name \${app-id} --icon \${app-id} --category \${category} --urgency \${urgency} --expire-time \${expire-time} --hint STRING:image-path:\${icon} --hint BOOLEAN:suppress-sound:\${muted} --hint STRING:sound-name:\${sound-name} --replace-id \${replace-id} \${action-argument} --print-id -- \${title} \${body}";
        inhibit-when-focused = "yes";
      };
    };
  };
}
