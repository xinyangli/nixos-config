{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom-hm.omp;
  configDir = "${config.my-lib.flakePath config}/config/omp";
in
{
  options.custom-hm.omp = {
    enable = lib.mkEnableOption "omp";

    extensions = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "herdr"
        ]
      );
      default = [ ];
      example = [ "herdr" ];
      description = "Extensions to install for omp.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages = [ pkgs.llm-agents.omp ];

    home.file = {
      ".omp/agent/config.yml".source = config.lib.file.mkOutOfStoreSymlink "${configDir}/config.yml";
      ".omp/agent/skills".source = config.lib.file.mkOutOfStoreSymlink "${configDir}/skills";
    };

    home.activation.installOmpExtensions = lib.mkIf (cfg.extensions != [ ]) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${lib.optionalString (lib.elem "herdr" cfg.extensions) ''
          $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr integration install omp
        ''}
      ''
    );
  };
}
