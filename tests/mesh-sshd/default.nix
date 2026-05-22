{ pkgs, lib, ... }:

# Validates `custom.mesh-network.sshd.enable`: a `mesh-sshd.socket`
# (BindToDevice=gravity, Accept=yes) hands each accepted FD to a
# transient `mesh-sshd@<id>.service` instance running sshd in inetd
# mode. The host sshd's default-scope listener is unaffected; same
# port (22) is served in two routing scopes by two independent
# listeners. To prove the VRF binding is real, we stop sshd.service
# mid-test and observe that the mesh path keeps working while the
# default scope goes dark.

let
  testKey = pkgs.runCommand "mesh-sshd-test-key" { nativeBuildInputs = [ pkgs.openssh ]; } ''
    mkdir -p $out
    ssh-keygen -t ed25519 -N "" -C "mesh-sshd-test" -f $out/id_ed25519
  '';

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
      openssh.authorizedKeys.keyFiles = [ "${testKey}/id_ed25519.pub" ];
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

    for src, dst in [(alpha, "fd00:42::2"), (beta, "fd00:42::1")]:
        src.wait_until_succeeds(
            f"ip -6 route show vrf gravity {dst}/128 | grep -q .",
            timeout=120,
        )

    for m in (alpha, beta):
        m.succeed("install -d -m 700 /root/.ssh")
        m.succeed("install -m 600 ${testKey}/id_ed25519 /root/.ssh/id_ed25519")

    ssh_opts = (
        "-o StrictHostKeyChecking=no "
        "-o UserKnownHostsFile=/dev/null "
        "-o BatchMode=yes "
        "-o ConnectTimeout=5 "
        "-i /root/.ssh/id_ed25519"
    )

    # ---------- Phase 1: socket is bound to gravity ----------
    for m in (alpha, beta):
        bound = m.succeed(
            "systemctl show mesh-sshd.socket -p BindToDevice --value"
        ).strip()
        assert bound == "gravity", (
            f"{m.name}: expected mesh-sshd.socket BindToDevice=gravity, got: {bound!r}"
        )
        # The accept-socket listener should show the %gravity SO_BINDTODEVICE
        # marker in ss, confirming systemd actually set it.
        listeners = m.succeed("ss -lntpH")
        assert "%gravity:22" in listeners, (
            f"{m.name}: no %gravity-scoped listener on :22; got:\n{listeners}"
        )

    # ---------- Phase 2: both ssh paths work concurrently ----------
    out = alpha.succeed(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    ).strip()
    assert out == "beta", f"underlay ssh: got {out!r}"

    out = alpha.succeed(
        f"ip vrf exec gravity ssh {ssh_opts} -p 22 root@fd00:42::2 hostname"
    ).strip()
    assert out == "beta", f"mesh ssh: got {out!r}"

    # ---------- Phase 3: stop host sshd, VRF still answers, underlay goes dark ----------
    beta.succeed("systemctl stop sshd.service")

    out = alpha.succeed(
        f"ip vrf exec gravity ssh {ssh_opts} -p 22 root@fd00:42::2 hostname"
    ).strip()
    assert out == "beta", (
        f"mesh ssh after sshd.service stop: expected mesh-sshd.socket to still accept, got {out!r}"
    )

    rc, out = alpha.execute(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    )
    assert rc != 0, (
        f"underlay ssh after sshd.service stop should fail "
        f"(mesh-sshd.socket is VRF-scoped, no listener in default scope); "
        f"got rc={rc}, out={out!r}"
    )
  '';
}
