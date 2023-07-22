{ pkgs, ... }: {
  programs.fish = {
    enable = true;
    plugins = with pkgs; [
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
    interactiveShellInit = ''
      fish_config theme choose 'ayu Dark'
      fish_config prompt choose arrow
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
    '';
    functions = {
      gitignore = "curl -sL https://www.gitignore.io/api/$argv";
    };
  };
}
