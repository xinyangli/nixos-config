{ lib }:

# Shared option-shape stubs for nixosTests that import production modules
# without loading sops-nix or the my-lib option. Each value is a NixOS
# module suitable for inclusion in `imports = [ ... ]`.

{
  # Mirrors the option *shape* sops-nix exposes (secrets/templates/placeholder
  # as attrs-of submodule with `path` + `owner`), without doing any actual
  # decryption. Submodule rather than attrsOf unspecified is deliberate: it
  # keeps `.path` reads lazy with respect to `.owner`, which production
  # modules sometimes wire to config.systemd.services.X.serviceConfig.User
  # — forcing evaluation of `owner` would create cycles.
  sops =
    let
      mkSecretSubmodule = lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            default = "/run/secrets/missing-in-test";
          };
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
        };
      };
    in
    {
      options.sops = {
        secrets = lib.mkOption {
          default = { };
          type = lib.types.attrsOf mkSecretSubmodule;
        };
        templates = lib.mkOption {
          default = { };
          type = lib.types.attrsOf mkSecretSubmodule;
        };
        placeholder = lib.mkOption {
          default = { };
          type = lib.types.attrsOf mkSecretSubmodule;
        };
      };
    };

  # Production modules read `config.my-lib.settings.*`. Default the option to
  # the real lib so tests run against the same constants as deploy.
  my-lib = {
    options.my-lib = lib.mkOption {
      type = lib.types.attrs;
      default = import ../overlays/my-lib { inherit lib; };
    };
  };
}
