{ pkgs, lib, ... }:

# Validates `custom.mesh-network.sshd.enable`, which spawns a second sshd
# bound to the gravity VRF via systemd's BindNetworkInterface= (added in
# v260). The VRF binding has to actually scope the listener: connections
# arriving through the VRF must be accepted, while ones arriving via the
# default routing scope on the same port must be refused — otherwise the
# whole point of running a parallel mesh sshd is moot.

let
  # The mesh-sshd listens on a port distinct from the host sshd so we can
  # unambiguously attribute reachability/unreachability to BindNetworkInterface=
  # rather than to two sshds racing for the same bind() in different scopes.
  meshSshPort = 2222;

  # Generated at eval time and embedded in both nodes; lets root@alpha ssh
  # into root@beta without password/agent dance inside the VM.
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

    # peers.nix in common.nix declares alpha/beta/gamma; this test only
    # uses two of them. mkForce-trim to alpha+beta so charon doesn't keep
    # retrying IKE_SA_INIT against a non-existent gamma for the whole run.
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

    custom.mesh-network.sshd = {
      enable = true;
      port = meshSshPort;
    };

    # services.openssh provides host keys + the sshd_config that mesh-sshd
    # reuses. Keep host sshd on the default port to confirm it isn't
    # disturbed by the parallel mesh instance.
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

    # ---------- Phase 1: mesh is up ----------
    for m in (alpha, beta):
        m.wait_for_unit("strongswan-swanctl.service")
        m.wait_for_unit("gravity-ipsec.service")
        m.wait_for_unit("bird.service")
        m.wait_for_unit("sshd.service")
        m.wait_for_unit("mesh-sshd.service")

    # Bird needs to install a babel route to the peer's mesh address before
    # we attempt any ssh; otherwise the VRF lookup yields no route and ssh
    # fails on "network is unreachable" rather than on the auth path.
    for src, dst in [(alpha, "fd00:42::2"), (beta, "fd00:42::1")]:
        src.wait_until_succeeds(
            f"ip -6 route show vrf gravity {dst}/128 | grep -q .",
            timeout=120,
        )

    # ---------- Phase 2: install the test ssh key on the client ----------
    # The key was baked into the VM at build time via authorizedKeys.keyFiles;
    # the private half lives in the nix store at ${testKey}/id_ed25519 and
    # is readable by root inside the VM.
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

    # ---------- Phase 3: BindNetworkInterface= is wired into the unit ----------
    # `systemctl show` reads the live unit; if systemd v260 stripped the
    # directive (e.g. on a kernel without the BPF feature) it'd return
    # empty here and the subsequent VRF-scoping behavior wouldn't hold.
    for m in (alpha, beta):
        bound = m.succeed(
            "systemctl show mesh-sshd.service -p BindNetworkInterface --value"
        ).strip()
        assert bound == "gravity", (
            f"{m.name}: expected mesh-sshd.service BindNetworkInterface=gravity, got: {bound!r}"
        )

    # ---------- Phase 4: ssh over the mesh succeeds ----------
    # Client also goes through the gravity VRF so its outbound socket
    # routes via the mesh tunnel. From there, the server's mesh-sshd
    # (BindNetworkInterface=gravity) must accept the connection.
    out = alpha.succeed(
        f"ip vrf exec gravity ssh {ssh_opts} -p ${toString meshSshPort} "
        "root@fd00:42::2 hostname"
    ).strip()
    assert out == "beta", f"expected mesh ssh to land on beta, got: {out!r}"

    out = beta.succeed(
        f"ip vrf exec gravity ssh {ssh_opts} -p ${toString meshSshPort} "
        "root@fd00:42::1 hostname"
    ).strip()
    assert out == "alpha", f"expected reverse mesh ssh to land on alpha, got: {out!r}"

    # ---------- Phase 5: mesh-sshd port is invisible outside the VRF ----------
    # Same port, but the client's socket is in the default VRF and the
    # destination is beta's *underlay* address. The mesh-sshd listener is
    # scoped to gravity, so this connection must NOT reach it. With
    # tcp_l3mdev_accept=0 and no other listener on this port in the
    # default scope, ssh should fail (refused or timeout).
    rc, out = alpha.execute(
        f"ssh {ssh_opts} -p ${toString meshSshPort} "
        "root@192.168.1.2 hostname"
    )
    assert rc != 0, (
        f"expected ssh to beta's underlay:${toString meshSshPort} to fail "
        f"(mesh-sshd is VRF-scoped); succeeded with output: {out!r}"
    )

    # ---------- Phase 6: host sshd on port 22 still works over underlay ----------
    # Sanity check: the parallel mesh-sshd hasn't broken or shadowed the
    # default sshd, which still answers on its normal scope/port.
    out = alpha.succeed(
        f"ssh {ssh_opts} -p 22 root@192.168.1.2 hostname"
    ).strip()
    assert out == "beta", f"expected host sshd to answer on underlay:22, got: {out!r}"
  '';
}
