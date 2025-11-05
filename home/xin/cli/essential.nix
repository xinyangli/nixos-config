{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    dig
    file
    unar
    tree
    wget
    tmux
    inetutils
    jq
    dust # du + rust
    fd
    ripgrep
    grc
  ];
  programs.zoxide.enable = true;

  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
  };
  programs.fish = {
    enable = true;
    shellAliases = {
      sctl = "systemctl --user";
      ssctl = "sudo systemctl";
      jctl = "journalctl --user";
      sjctl = "sudo journalctl";
    };
    plugins = with pkgs.fishPlugins; [
      {
        name = "pisces";
        src = pisces.src;
      }
      {
        name = "done";
        src = done.src;
      }
      {
        name = "hydro";
        src = hydro.src;
      }
      {
        name = "grc";
        src = grc.src;
      }
    ];
    interactiveShellInit = ''
      fish_config prompt choose default
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
      set -gx LS_COLORS (${lib.getExe pkgs.vivid} generate catppuccin-mocha)
    '';
    functions = {
      gitignore = "curl -sL https://www.gitignore.io/api/$argv";
    };
  };
}
