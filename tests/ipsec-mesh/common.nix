{ hostname, underlayAddr, announcedAddr }:
{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/nixos/mesh
  ];

  options.sops = {
    secrets = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
    templates = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
    placeholder = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };

  config = {
    networking.hostName = hostname;
    networking.useDHCP = false;
    # Required by the mesh module's assertion: the gravity VRF and gravity-lo
    # dummy are declared via systemd-networkd, so without networkd the VRF
    # never materialises and the updown script's `master gravity` would fail.
    networking.useNetworkd = true;
    systemd.network.enable = true;
    networking.firewall.enable = false;

    virtualisation.vlans = [ 1 ];
    networking.interfaces.eth1.ipv4.addresses = [
      { address = underlayAddr; prefixLength = 24; }
    ];

    boot.kernelModules = [ "sch_netem" ];

    environment.systemPackages = with pkgs; [
      iproute2
      bird2
      iputils
      jq
    ];

    # mkForce makes this the sole definition of sops.secrets, overriding the
    # module's `sops.secrets.ipsec.sopsFile = ./secrets.yaml` so sops-nix
    # never tries to decrypt the placeholder file shipped with the module.
    sops.secrets = lib.mkForce {
      ipsec.path = "${./keys/org.key}";
    };

    custom.mesh-network = {
      organization = "meshtest";
      ipsec = {
        enable = true;
        commonName = hostname;
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = underlayAddr;
          }
        ];
        port = 13000;
        interfaces = [ "eth1" ];
      };
      bird = {
        enable = true;
        routes = [ "${announcedAddr}/128" ];
        # Tightened from the 20s prod default so babel converges within the
        # test's time budget.
        helloInterval = "1 s";
        updateInterval = "1 s";
        routerIdInterface = "eth1";
      };
      orgPubKey = ./keys/org.pub;
      nodes = {
        alpha = {
          commonName = "alpha";
          endpoints = [
            { serialNumber = "0"; addressFamily = "ip4"; address = "192.168.1.1"; }
          ];
        };
        beta = {
          commonName = "beta";
          endpoints = [
            { serialNumber = "0"; addressFamily = "ip4"; address = "192.168.1.2"; }
          ];
        };
        gamma = {
          commonName = "gamma";
          endpoints = [
            { serialNumber = "0"; addressFamily = "ip4"; address = "192.168.1.3"; }
          ];
        };
      };
    };
  };
}
