{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkOption types mkIf;
  cfg = config.custom.mesh-network;
in
{
  options.custom.mesh-network = {
    nodes = mkOption {
      description = "All hosts participating in the mesh, keyed by hostname.";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            commonName = mkOption { type = types.str; };
            endpoints = mkOption {
              type = types.listOf (
                types.submodule {
                  options = {
                    serialNumber = mkOption { type = types.str; };
                    addressFamily = mkOption { type = types.enum [ "ip4" "ip6" ]; };
                    address = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                    };
                    port = mkOption {
                      type = types.port;
                      default = 63001;
                    };
                  };
                }
              );
            };
          };
        }
      );
    };

    organization = mkOption {
      type = types.str;
      default = "xinyangli";
      description = ''
        Fleet-wide organization name. All hosts MUST agree — IPsec authentication
        relies on every node sharing one (organization, org-keypair) tuple, with
        identities differentiated only by `common_name`.
      '';
    };

    orgPubKey = mkOption {
      type = types.path;
      default = ./org.pub;
      description = "Path to the organization's Ed25519 public key (PEM SubjectPublicKeyInfo).";
    };
  };

  config = mkIf cfg.ipsec.enable {
    environment.etc."gravity/registry.json".source =
      (pkgs.formats.json { }).generate "registry.json" [
        {
          organization = cfg.organization;
          public_key = builtins.readFile cfg.orgPubKey;
          nodes = lib.mapAttrsToList (_: node: {
            common_name = node.commonName;
            endpoints = map (ep: {
              serial_number = ep.serialNumber;
              address_family = ep.addressFamily;
              address = ep.address;
              port = ep.port;
            }) node.endpoints;
          }) cfg.nodes;
        }
      ];

    # gravity-ipsec.service has AssertFileNotEmpty on this path; the unit
    # was originally written against /var/lib/gravity, so keep the symlink
    # rather than rewriting the assertion.
    systemd.tmpfiles.rules = [
      "d /var/lib/gravity 0755 root root - -"
      "L+ /var/lib/gravity/registry.json - - - - /etc/gravity/registry.json"
    ];
  };
}
