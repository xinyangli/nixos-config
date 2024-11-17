{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    getExe
    types
    attrsets
    ;
  cfg = config.custom-hm.neovim;
  tomlFormat = pkgs.formats.toml { };
  fontItem =
    with types;
    either str (submodule {
      options = {
        family = {
          type = str;
        };
        style = {
          type = nullOr str;
          default = null;
        };
      };
    });
  fontType = types.either fontItem (types.listOf fontItem);
  neovideConfig = {
    neovim-bin = getExe pkgs.nixvim;
    fork = true;
    frame = "none";
  };
in
{
  options.custom-hm.neovim = {
    enable = mkEnableOption "neovim configurations";
    font = {
      # Required options
      normal = lib.mkOption {
        type = fontType;
        description = ''
          The normal font description. Can be:
          - A table with "family" (required) and "style" (optional).
          - A string indicating the font family.
          - An array of strings or tables as described above.
        '';
      };

      size = lib.mkOption {
        type = lib.types.float;
        description = "Required font size.";
      };

      # Optional options
      bold = lib.mkOption {
        type = types.nullOr fontType;
        default = null;
        description = ''
          Optional bold font description. Can be:
          - A table with "family" (optional) and "style" (optional).
          - A string indicating the font family.
          - An array of strings or tables as described above.
        '';
      };

      italic = lib.mkOption {
        type = types.nullOr fontType;
        default = null;
        description = "Optional italic font description.";
      };

      bold_italic = lib.mkOption {
        type = types.nullOr fontType;
        default = null;
        description = "Optional bold-italic font description.";
      };

      features = lib.mkOption {
        type = types.nullOr (lib.types.attrsOf (lib.types.listOf lib.types.str));
        default = { };
        description = ''
          Optional font features. A table where the key is the font family and
          the value is a list of font features. Each feature can be:
          - +<feature> (e.g., +ss01)
          - -<feature> (e.g., -calt)
          - <feature>=<value> (e.g., ss02=2)
        '';
      };

      width = lib.mkOption {
        type = types.nullOr types.float;
        default = null;
        description = "Optional font width.";
      };

      hinting = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional font hinting (none, slight, medium, full).";
      };

      edging = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional font edging (none, antialiased, subpixel).";
      };

    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nixvim
      neovide
    ];
    programs.neovim.enable = false;
    home.file.".config/neovide/config.toml" = {
      source = tomlFormat.generate "neovide-config" (
        neovideConfig
        // (attrsets.filterAttrsRecursive (n: v: v != null) {
          font = cfg.font;
        })
      );
    };
  };
}
