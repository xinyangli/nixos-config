{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib) mkIf;
  cfg = config.custom.mesh-network;
in
{
  options.custom.mesh-network = {
    ipsec = {
      enable = mkEnableOption "ipsec";
      commonName = mkOption { type = types.str; };
      endpoints = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              serialNumber = mkOption { type = types.str; };
              addressFamily = mkOption {
                type = types.enum [
                  "ip4"
                  "ip6"
                ];
              };
              address = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
            };
          }
        );
      };
      port = mkOption {
        type = types.port;
        default = 13000;
      };
      interfaces = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      iptfs = mkEnableOption "iptfs";
    };
    config = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "path to ranet config";
    };
    bird = {
      enable = mkEnableOption "bird integration";
      exit.enable = mkEnableOption "exit node";
      routes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "routes to be announced for local node";
      };
    };
  };

  config = mkIf cfg.ipsec.enable {
    sops.secrets.ipsec = { };
    environment.systemPackages = [ config.services.strongswan-swanctl.package ];
    environment.etc."ranet/config.json".source = (pkgs.formats.json { }).generate "config.json" (
      {
        organization = cfg.organization;
        common_name = cfg.ipsec.commonName;
        endpoints = map (ep: {
          serial_number = ep.serialNumber;
          address_family = ep.addressFamily;
          address = ep.address;
          port = cfg.ipsec.port;
          updown = pkgs.writeShellScript "updown" ''
            set -eu
            IP=${pkgs.iproute2}/bin/ip
            LINK=gn$(printf '%08x\n' "$PLUTO_IF_ID_OUT")
            case "$PLUTO_VERB" in
              up-client)
                # Only create the xfrm device here. Networkd's
                # `42-gn.network` (in modules/nixos/mesh/default.nix)
                # matches `gn*` and is responsible for enslaving the
                # interface to the gravity VRF, setting MTU/multicast,
                # and bringing it up. Splitting create-vs-configure
                # this way avoids racing networkd's state machine
                # over the freshly-appearing link.
                $IP link add "$LINK" type xfrm if_id "$PLUTO_IF_ID_OUT"
                ;;
              down-client)
                $IP link del "$LINK" || true
                ;;
            esac
          '';
        }) cfg.ipsec.endpoints;
      }
      // lib.optionalAttrs cfg.ipsec.iptfs {
        experimental.iptfs = true;
      }
    );
    systemd.services.gravity-ipsec =
      let
        command = "ranet -c /etc/ranet/config.json -r /var/lib/gravity/registry.json -k ${config.sops.secrets.ipsec.path}";
      in
      {
        path = [
          pkgs.ranet
          pkgs.iproute2
        ];
        script = "${command} up";
        reload = "${command} up";
        preStop = "${command} down";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        unitConfig = {
          AssertFileNotEmpty = "/var/lib/gravity/registry.json";
        };
        bindsTo = [ "strongswan-swanctl.service" ];
        wants = [
          "network-online.target"
          "strongswan-swanctl.service"
          # The updown script enslaves xfrm interfaces under the gravity
          # VRF. Block ranet (and therefore charon's IKE initiation)
          # until the kernel device exists, otherwise updown races
          # systemd-networkd.
          "sys-subsystem-net-devices-gravity.device"
        ];
        after = [
          "network-online.target"
          "strongswan-swanctl.service"
          "sys-subsystem-net-devices-gravity.device"
        ];
        wantedBy = [ "multi-user.target" ];
        # Both files matter: config.json changes when this host's local
        # endpoint changes; registry.json changes when the fleet
        # membership in peers.nix changes. Without the second trigger,
        # adding a new peer to peers.nix never reaches ranet and the
        # mesh is silently incomplete after deploy.
        reloadTriggers = [
          config.environment.etc."ranet/config.json".source
          config.environment.etc."gravity/registry.json".source
        ];
      };
    networking.firewall.interfaces = lib.genAttrs cfg.ipsec.interfaces (_: {
      allowedUDPPorts = [ cfg.ipsec.port ];
    });

    services.strongswan-swanctl = {
      enable = true;
      strongswan.extraConfig = ''
        charon {
          ikesa_table_size = 32
          ikesa_table_segments = 4
          reuse_ikesa = yes
          interfaces_use = ${lib.strings.concatStringsSep "," cfg.ipsec.interfaces}
          port = 0
          port_nat_t = ${toString cfg.ipsec.port}
          retransmit_timeout = 30
          retransmit_base = 1
          plugins {
            socket-default {
              set_source = yes
              set_sourceif = yes
            }
            dhcp {
              load = no
            }
          }
        }
        charon-systemd {
          journal {
            # 1 = control flow + IKE state transitions. -1 silences charon
            # entirely, which makes auth failures impossible to diagnose;
            # bump to 1 for at least the rollout window.
            default = 1
            ike = 2
            cfg = 2
          }
        }
      '';
    };
  };
}
