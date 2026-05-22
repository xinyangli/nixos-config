{ pkgs, lib, ... }:

# Validates `custom.mesh-network.sshd.enable`: a second sshd unit cloned
# from services.openssh's `sshd.service`, with BindNetworkInterface=gravity
# layered on top. Both daemons share the same sshd_config, host keys, and
# PAM stack, so they both listen on the host port (22) — but in different
# routing scopes. To verify the VRF binding actually scopes the listener,
# we stop the host sshd mid-test and observe that the mesh port is still
# reachable from the VRF but not from the default scope.

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

    # custom.mesh-network.sshd.enable defaults true alongside ipsec; just
    # rely on the default here. The module inherits the host sshd unit
    # wholesale, so anything we configure on services.openssh applies to
    # both instances.
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
        m.wait_for_unit("mesh-sshd.service")

    # Bird must have installed a babel route to the peer's mesh address
    # before we attempt any ssh, otherwise the VRF lookup fails before
    # auth even runs.
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

    # ---------- Phase 1: BindNetworkInterface= is wired ----------
    for m in (alpha, beta):
        bound = m.succeed(
            "systemctl show mesh-sshd.service -p BindNetworkInterface --value"
        ).strip()
        assert bound == "gravity", (
            f"{m.name}: expected BindNetworkInterface=gravity, got: {bound!r}"
        )

    # ---------- Phase 2: both daemons run, both ssh paths work ----------
    # Underlay → host sshd (default scope). Mesh → mesh-sshd. Same port,
    # different scopes. We can't tell from a successful ssh which sshd
    # answered, but both succeeding proves both listeners are live.
    out = alpha.succeed(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    ).strip()
    assert out == "beta", f"underlay ssh: got {out!r}"

    out = alpha.succeed(
        f"ip vrf exec gravity ssh {ssh_opts} -p 22 root@fd00:42::2 hostname"
    ).strip()
    assert out == "beta", f"mesh ssh: got {out!r}"

    # ---------- Phase 3: stopping host sshd proves the scopes are separate ----------
    # With sshd.service stopped on beta, only mesh-sshd remains. If the
    # VRF binding works, mesh ssh keeps working and underlay ssh starts
    # failing — that's the entire point of the module.
    beta.succeed("systemctl stop sshd.service")

    out = alpha.succeed(
        f"ip vrf exec gravity ssh {ssh_opts} -p 22 root@fd00:42::2 hostname"
    ).strip()
    assert out == "beta", (
        f"mesh ssh after sshd stop: expected mesh-sshd to still answer, got {out!r}"
    )

    rc, out = alpha.execute(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    )
    assert rc != 0, (
        f"underlay ssh after sshd stop should fail (mesh-sshd is VRF-scoped, "
        f"no listener in default scope); got rc={rc}, out={out!r}"
    )
  '';
}
