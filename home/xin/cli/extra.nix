{
  config,
  pkgs,
  lib,
  ...
}:
let
  gitSigningKey = "~/.ssh/id_ecdsa.tpm.pub";
  configDir = "${config.my-lib.flakePath config}/config";
in
{
  home.packages = with pkgs; [
    ffmpeg
    rclone

    # Fancy new tools!
    httpie
    curlie
    bat
    btop
    procs
    rust-parallel
    tealdeer
    git-absorb
  ];

  services.ssh-agent =
    let
      p = pkgs.tpm2-pkcs11.override { fapiSupport = false; };
    in
    {
      enable = true;
      pkcs11Whitelist = [
        "/run/current-system/sw/lib/*"
        "${p}/lib/*"
      ];
    };

  # == Terminal enhancement ==
  programs.nix-index-database.comma.enable = true;

  programs.yazi = {
    enable = true;
    shellWrapperName = "yy";
    plugins = with pkgs.yaziPlugins; {
      chmod = chmod;
      git = git;
      bypass = bypass;
    };
    initLua = ''
      require("git"):setup()
    '';
    settings = {
      plugin.prepend_fetchers = [
        {
          id = "git";
          name = "*";
          run = "git";
        }
        {
          id = "git";
          name = "*/";
          run = "git";
        }
      ];
    };

    keymap = {
      manager.prepend_keymap = [
        {
          on = "T";
          run = "plugin toggle-pane max-preview";
          desc = "Maximize or restore the preview pane";
        }
        {
          on = [
            "c"
            "m"
          ];
          run = "plugin chmod";
          desc = "Chmod on selected files";
        }
        {
          on = [ "L" ];
          run = "plugin bypass";
          desc = "Recursively enter child directory, skipping children with only a single subdirectory";
        }
        {
          on = [ "H" ];
          run = "plugin bypass reverse";
          desc = "Recursively enter parent directory, skipping parents with only a single subdirectory";
        }
        {
          on = [ "l" ];
          run = "plugin bypass smart_enter";
          desc = "Open a file, or recursively enter child directory, skipping children with only a single subdirectory";
        }
      ];
    };
  };

  programs.zellij.enable = true;
  # NOTE: Zellij does not support "include" in config. Manage this config ourself for now.
  xdg.configFile."zellij/config.kdl".enable = false;
  xdg.configFile."zellij".source = config.lib.file.mkOutOfStoreSymlink "${configDir}/zellij";

  # == Coding ==
  programs.git = {
    enable = true;
    # delta.enable = true;
    settings = {
      user = {
        name = "Xinyang Li";
        email = "lixinyang411@gmail.com";
      };
      alias = {
        graph = "log --all --oneline --graph --decorate";
        a = "add";
        d = "diff";
        s = "status";
        ck = "checkout";
      };
      absorb = {
        oneFixupPerCommit = true;
        maxStack = 20;
      };
    };
    signing = {
      key = gitSigningKey;
      format = "ssh";
      signByDefault = true;
    };
  };
  programs.lazygit = {
    enable = true;
    settings = {
      git.overrideGpg = true;
    };
  };
  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
      mode = "difftool";
    };
  };

  programs.direnv =
    let
      changeCacheDir = ''
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
            local hash path
            echo "''${direnv_layout_dirs[$PWD]:=$(
                hash="$(sha1sum - <<< "$PWD" | head -c40)"
                path="''${PWD//[^a-zA-Z0-9]/-}"
                echo "''${XDG_CACHE_HOME}/direnv/layouts/''${hash}''${path}"
            )}"
        }
      '';
    in
    {
      enable = true;
      silent = true;
      stdlib = changeCacheDir;
      nix-direnv.enable = true;
    };
}
