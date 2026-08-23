{ pkgs, lib, ... }:

# Validates `custom.mesh-network.sshd.enable`.

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
  name = "mesh-sshd-vrf-bind";

  nodes = lib.mapAttrs mkNode nodes;

  testScript = ''
    start_all()

    for m in (alpha, beta):
        m.wait_for_unit("strongswan-swanctl.service")
        m.wait_for_unit("gravity-ipsec.service")
        m.wait_for_unit("bird.service")
        m.wait_for_unit("sshd.service")
        m.wait_for_unit("mesh-sshd.socket")
        m.wait_for_unit("mesh-sshd.service")

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

    # ---------- Phase 1: socket bound to gravity ----------
    for m in (alpha, beta):
        bound = m.succeed(
            "systemctl show mesh-sshd.socket -p BindToDevice --value"
        ).strip()
        assert bound == "gravity", (
            f"{m.name}: expected mesh-sshd.socket BindToDevice=gravity, got: {bound!r}"
        )
        listeners = m.succeed("ss -lntpH")
        assert "%gravity:22" in listeners, (
            f"{m.name}: no %gravity-scoped listener on :22; got:\n{listeners}"
        )

    # ---------- Phase 2: both ssh paths work ----------
    out = alpha.succeed(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    ).strip()
    assert out == "beta", f"underlay ssh: got {out!r}"

    out = alpha.succeed(
        f"ip vrf exec gravity ssh {ssh_opts} -p 22 root@fd00:42::2 hostname"
    ).strip()
    assert out == "beta", f"mesh ssh: got {out!r}"

    # ---------- Phase 3: sshd saw the mesh session as 127.0.0.1 ----------
    beta.succeed(
        "journalctl -u sshd.service --since '60 sec ago' | "
        "grep -E 'Accepted publickey for root from 127\\.0\\.0\\.1'"
    )

    # ---------- Phase 4: stopping mesh-sshd.socket closes only the mesh path ----------
    beta.succeed("systemctl stop mesh-sshd.socket mesh-sshd.service")

    rc, out = alpha.execute(
        f"ip vrf exec gravity ssh {ssh_opts} -p 22 root@fd00:42::2 hostname"
    )
    assert rc != 0, (
        f"mesh ssh after stopping mesh-sshd.socket should fail; got rc={rc}, out={out!r}"
    )

    out = alpha.succeed(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    ).strip()
    assert out == "beta", (
        f"underlay ssh after stopping mesh-sshd.socket should still work "
        f"(host sshd is independent); got {out!r}"
    )
  '';
}
