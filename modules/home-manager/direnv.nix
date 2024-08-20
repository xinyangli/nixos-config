{ config, lib, ... }:
with lib;

let
  cfg = config.custom-hm.direnv;
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
  options.custom-hm.direnv = {
    enable = mkEnableOption "direnv";
  };
  config = {
    programs = mkIf cfg.enable {
      direnv = {
        enable = true;
        stdlib = changeCacheDir;
      };
    };
  };
}
