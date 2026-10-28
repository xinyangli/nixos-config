{ pkgs, lib, ... }:

# Validates SSH through the main-table mesh route.

let
  inherit (import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey
    snakeOilPublicKey
    ;

  nodes = {
    alpha = { underlay = "192.168.1.1"; announced = "fd00:42::1"; };
    beta  = { underlay = "192.168.1.2"; announced = "fd00:42::2"; };
  };

  mkNode = hostname: spec: { config, ... }: {
    imports = [
      (import ../ipsec-mesh/common.nix {
        inherit hostname;
        underlayAddr = spec.underlay;
        announcedAddr = spec.announced;
      })
    ];

    custom.mesh-network.nodes = lib.mkForce {
      alpha = {
        commonName = "alpha";
        endpoints = [
          { serialNumber = "0"; addressFamily = "ip4"; address = "192.168.1.1"; port = 13000; }
        ];
      };
      beta = {
        commonName = "beta";
        endpoints = [
          { serialNumber = "0"; addressFamily = "ip4"; address = "192.168.1.2"; port = 13000; }
        ];
      };
    };

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };

    users.users.root = {
      openssh.authorizedKeys.keys = [ snakeOilPublicKey ];
    };

    environment.systemPackages = with pkgs; [ openssh ];
  };
in
{
  name = "mesh-sshd-direct-l3mdev";

  nodes = lib.mapAttrs mkNode nodes;

  testScript = ''
    start_all()

    for m in (alpha, beta):
        m.wait_for_unit("strongswan-swanctl.service")
        m.wait_for_unit("gravity-ipsec.service")
        m.wait_for_unit("bird.service")

        accept = m.succeed("sysctl -n net.ipv4.tcp_l3mdev_accept").strip()
        assert accept == "1", f"{m.name}: tcp_l3mdev_accept={accept}"
        m.wait_for_unit("sshd.service")

    for src, dst in [(alpha, "fd00:42::2"), (beta, "fd00:42::1")]:
        src.wait_until_succeeds(
            f"ip -6 route show vrf gravity {dst}/128 | grep -q .",
            timeout=120,
        )

    for m in (alpha, beta):
        m.succeed("install -d -m 700 /root/.ssh")
        m.succeed("install -m 600 ${snakeOilPrivateKey} /root/.ssh/id_ecdsa")

    ssh_opts = (
        "-o StrictHostKeyChecking=no "
        "-o UserKnownHostsFile=/dev/null "
        "-o BatchMode=yes "
        "-o ConnectTimeout=5 "
        "-i /root/.ssh/id_ecdsa"
    )

    out = alpha.succeed(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    ).strip()
    assert out == "beta", f"underlay ssh: got {out!r}"

    # No client-side VRF binding or proxy: the main-table route plus
    # tcp_l3mdev_accept carries the connection and its return traffic.
    out = alpha.succeed(
        f"ssh {ssh_opts} -p 22 root@fd00:42::2 hostname"
    ).strip()
    assert out == "beta", f"mesh ssh: got {out!r}"
  '';
}
