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
        default = 63001;
      };
      interfaces = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      iptfs = mkEnableOption "iptfs" // {
        default = true;
      };
    };
    config = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "path to ranet config";
    };
    bird = {
      enable = mkEnableOption "bird integration";
      exit.enable = mkEnableOption "exit node";
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
        }) cfg.ipsec.endpoints;
      }
      // lib.optionalAttrs cfg.ipsec.iptfs {
        experimental.iptfs = true;
      }
    );
    systemd.services.gravity-ipsec =
      let
        command = "ranet --vici=/run/strongswan/charon.vici -c /etc/ranet/config.json -r /var/lib/gravity/registry.json -k ${config.sops.secrets.ipsec.path}";
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
          # charon-kernel enslaves XFRM interfaces under the gravity VRF.
          # Block ranet (and therefore charon's IKE initiation) until the
          # kernel device exists, otherwise interface setup races
          # systemd-networkd.
          "sys-subsystem-net-devices-gravity.device"
        ];
        after = [
          "network-online.target"
          "strongswan-swanctl.service"
          "sys-subsystem-net-devices-gravity.device"
        ];
        wantedBy = [ "multi-user.target" ];
        reloadTriggers = [
          config.environment.etc."ranet/config.json".source
          config.environment.etc."gravity/registry.json".source
        ];
      };
    systemd.timers.gravity-reload = {
      timerConfig = {
        OnCalendar = "*:0/15";
      };
      wantedBy = [ "timers.target" ];
    };
    networking.firewall.interfaces = lib.genAttrs cfg.ipsec.interfaces (_: {
      allowedUDPPorts = [ cfg.ipsec.port ];
    });

    services.charon-kernel = {
      enable = true;
      interfaceNamePrefix = "gn";
    };

    services.strongswan-swanctl = {
      enable = true;
      strongswan.extraConfig =
        let
          interfaces = lib.strings.concatStringsSep "," cfg.ipsec.interfaces;
        in
        ''
          charon {
            ikesa_table_size = 32
            ikesa_table_segments = 4
            reuse_ikesa = yes
            ${lib.optionalString (builtins.length cfg.ipsec.interfaces == 0) "interfaces_use = ${interfaces}"}
            port = 0
            port_nat_t = ${toString cfg.ipsec.port}
            retransmit_timeout = 30
            retransmit_base = 1
            load_modular = yes
            plugins {
              include ${config.services.strongswan-swanctl.package}/share/strongswan/templates/config/plugins/*.conf
              socket-default {
                set_source = yes
                set_sourceif = yes
              }
              dhcp {
                load = no
              }
              kernel-netlink {
                load = no
              }
              kernel-rust {
                load = yes
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
