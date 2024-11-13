# modified from https://github.com/isabelroses/dotfiles/blob/2fd4d2d0cb8254cad5ce4b089d81114e1b88ad02/modules/extra/home-manager/gtklock.nix
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.custom-hm.gui.gtklock;

  inherit (lib.modules) mkIf;
  inherit (lib.options)
    mkOption
    mkEnableOption
    mkPackageOption
    literalExpression
    ;
  inherit (lib.strings) optionalString concatStringsSep;
  inherit (lib.lists) optionals;
  inherit (lib.types)
    oneOf
    str
    path
    listOf
    either
    package
    nullOr
    attrs
    ;
  inherit (lib.generators) toINI;

  # the main config includes two very niche options: style (which takes a path) and modules, which takes a list of module paths
  # concatted by ";"
  # for type checking purposes, I prefer templating the main section of the config and let the user safely choose options
  # extraConfig takes an attrset, and converts it to the correct INI format - it's mostly just strings and integers, so that's fine
  baseConfig = ''
    [main]
    ${optionalString (cfg.config.gtk-theme != "") "gtk-theme=${cfg.config.gtk-theme}"}
    ${optionalString (cfg.config.style != "") "style=${cfg.config.style}"}
    ${optionalString (cfg.config.modules != [ ]) "modules=${concatStringsSep ";" cfg.config.modules}"}
  '';

  finalConfig = baseConfig + optionals (cfg.extraConfig != null) (toINI { } cfg.extraConfig);
in
{
  options.custom-hm.gui.gtklock = {
    enable = mkEnableOption "GTK-based lockscreen for Wayland";
    package = mkPackageOption pkgs "gtklock" { };

    config = {
      gtk-theme = mkOption {
        type = str;
        default = "";
        description = ''
          GTK theme to use for gtklock.
        '';
        example = "Adwaita-dark";
      };

      style = mkOption {
        type = oneOf [
          str
          path
        ];
        default = "";
        description = ''
          The css file to be used for gtklock.
        '';
        example = literalExpression ''
          pkgs.writeText "gtklock-style.css" '''
            window {
              background-size: cover;
              background-repeat: no-repeat;
              background-position: center;
            }
          '''
        '';
      };

      modules = mkOption {
        type = listOf (either package str);
        default = [ ];
        description = ''
          A list of gtklock modulesto use. Can either be packages, absolute paths, or strings.
        '';
        example = literalExpression ''
          [
            "${pkgs.gtklock-powerbar-module.outPath}/lib/gtklock/powerbar-module.so"
            "${pkgs.gtklock-playerctl-module.outPath}/lib/gtklock/playerctl-module.so"
          ];
        '';
      };
    };

    extraConfig = mkOption {
      type = nullOr attrs;
      default =
        {
        };
      description = ''
        Extra configuration to append to gtklock configuration file.
        Mostly used for appending module configurations.
      '';
      example = literalExpression ''
        countdown = {
          countdown-position = "top-right";
          justify = "right";
          countdown = 20;
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."gtklock/config.ini".source = pkgs.writeText "gtklock-config.ini" finalConfig;
  };
}
