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
    settings = {
      keymap_mode = "vim-insert";
      style = "compact";
      invert = true;
    };
  };
  programs.nix-your-shell = {
    enable = true;
    nix-output-monitor.enable = true;
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
      if test -x ${pkgs.nix-your-shell}/bin/nix-your-shell
          ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
      end
      functions prompt_login | sed 's/(set_color \$fish_color_user) "\$USER" (set_color normal) @ //' | source
      functions fish_prompt | sed 's/(prompt_pwd) \$normal (fish_vcs_prompt) \$normal " "\$prompt_status/(prompt_pwd) \$normal (fish_vcs_prompt) \$normal (fish_environment_prompt) " "\$prompt_status/' | source

      function fish_greeting
          set -l gray (set_color 999)
          set -l normal (set_color normal)
          set -l green (set_color green)

          set -l date_time (date "+%Y-%m-%d %H:%M")
          set -l up_time (w | head -1 | string replace -r "\d{2}:\d{2}:\d{2} " "")

          set -l mem_total (string match -r 'MemTotal:\s+(\d+)' < /proc/meminfo)[2]
          set -l mem_avail (string match -r 'MemAvailable:\s+(\d+)' < /proc/meminfo)[2]

          set -l mem_used_pct (math -s0 "100 * (1 - $mem_avail / $mem_total)")
          set -l mem_total_gb (math -s1 "$mem_total / 1024 / 1024")
          set -l mem_avail_gb (math -s1 "$mem_avail / 1024 / 1024")

          echo -e -s "$date_time $gray|$normal $up_time"
          echo -e -s "Memory: $green$mem_used_pct%$normal used $gray($mem_avail_gb / $mem_total_gb GB avail)$normal"
      end

      function fish_environment_prompt
          if test -n "$IN_NIX_SHELL"
            echo -n -s (set_color blue) "  " (set_color normal)
          else if test -n "$DIRENV_ENABLED"
            echo -n -s "  "
          end
      end

      function fish_command_not_found
          if test -x ${pkgs.comma}/bin/comma
              ${pkgs.comma}/bin/comma $argv
          else
              __fish_default_command_not_found_handler $argv
          end
      end

      function fish_command_not_found
        ${pkgs.comma}/bin/comma $argv
      end
      set -gx LS_COLORS (${lib.getExe pkgs.vivid} generate catppuccin-mocha)
      bind ctrl-alt-e edit_command_buffer
    '';
    functions = {
      gitignore = "curl -sL https://www.gitignore.io/api/'$argv'";
    };
  };
}
