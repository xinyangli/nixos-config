{ pkgs, lib, ... }:

# Validates custom.mesh-network.gost.enable:
# - gost-mesh listens in the default VRF (no gravity BindToDevice on the listener)
# - outgoing connections use SO_BINDTODEVICE=gravity (?interface=gravity in -L URI)
# - a SOCKS5 client on the default VRF can proxy through to a gravity-scoped service
# - a direct default-VRF connection to the same gravity address fails (strict VRF)
#
# Topology: alpha runs gost-mesh; beta hosts an HTTP service bound to its
# gravity VRF address. The test exercises both local (alpha→alpha→beta-gravity)
# and remote (beta-underlay→alpha-gost→beta-gravity) proxy paths.

let
  proxyPort = 1080;
  meshHttpPort = 8080;

  underlayOf = {
    alpha = "192.168.1.1";
    beta  = "192.168.1.2";
  };
  gravityOf = {
    alpha = "fd00:42::1";
    beta  = "fd00:42::2";
  };

  mkBase = hostname: { config, pkgs, lib, ... }: {
    imports = [
      (import ../ipsec-mesh/common.nix {
        inherit hostname;
        underlayAddr = underlayOf.${hostname};
        announcedAddr = gravityOf.${hostname};
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

    custom.mesh-network.sshd.enable = false;

    environment.systemPackages = with pkgs; [ curl python3 ];
  };
in
{
  name = "mesh-gost-proxy";

  nodes = {
    alpha = { config, pkgs, lib, ... }: {
      imports = [ (mkBase "alpha") ];
      custom.mesh-network.gost = {
        enable = true;
        port = proxyPort;
        openFirewall = true;
      };
    };
    beta = mkBase "beta";
  };

  testScript = ''
    start_all()

    for m in (alpha, beta):
        m.wait_for_unit("strongswan-swanctl.service")
        m.wait_for_unit("gravity-ipsec.service")
        m.wait_for_unit("bird.service")

    alpha.wait_for_unit("gost-mesh.service")

    for src, dst in [(alpha, "${gravityOf.beta}"), (beta, "${gravityOf.alpha}")]:
        src.wait_until_succeeds(
            f"ip -6 route show vrf gravity {dst}/128 | grep -q .",
            timeout=120,
        )

    # ---------- Phase 1: listener is in the default VRF ----------
    # gost-mesh must NOT carry a %gravity suffix — that would make it
    # gravity-scoped and unreachable by default-VRF clients.
    listeners = alpha.succeed("ss -lntpH")
    assert ":${toString proxyPort}" in listeners, (
        f"alpha: expected gost listener on port ${toString proxyPort}; got:\n{listeners}"
    )
    assert "%gravity:${toString proxyPort}" not in listeners, (
        f"alpha: gost-mesh listener must not be gravity-scoped; got:\n{listeners}"
    )

    # ---------- Phase 2: start a gravity-only HTTP service on beta ----------
    # python3 http.server under ip vrf exec binds to all gravity-VRF addresses,
    # including fd00:42::2. It is not reachable from the default VRF.
    beta.succeed(
        "ip vrf exec gravity python3 -m http.server ${toString meshHttpPort} --bind '::' &>/tmp/http.log &"
    )
    beta.wait_until_succeeds(
        "ip vrf exec gravity curl -sS --max-time 5 "
        "http://[${gravityOf.beta}]:${toString meshHttpPort}/",
        timeout=30,
    )

    # ---------- Phase 3: default-VRF direct access fails ----------
    # fd00:42::/48 is not in alpha's default routing table; strict VRF mode
    # (net.vrf.strict_mode=1) prevents cross-VRF socket delivery.
    rc, _ = alpha.execute(
        "curl -sS --max-time 5 http://[${gravityOf.beta}]:${toString meshHttpPort}/"
    )
    assert rc != 0, (
        "alpha default VRF must NOT reach beta's gravity-scoped HTTP service directly"
    )

    # ---------- Phase 4: proxy works from gost host (loopback) ----------
    # gost dials fd00:42::2:8080 with SO_BINDTODEVICE=gravity, routing via
    # table 100 where Babel has installed the route to beta's gravity address.
    alpha.succeed(
        "curl -sS --max-time 10 "
        "--socks5-hostname 127.0.0.1:${toString proxyPort} "
        "http://[${gravityOf.beta}]:${toString meshHttpPort}/"
    )

    # ---------- Phase 5: proxy works from a remote client (beta underlay) ----------
    beta.succeed(
        "curl -sS --max-time 10 "
        "--socks5-hostname ${underlayOf.alpha}:${toString proxyPort} "
        "http://[${gravityOf.beta}]:${toString meshHttpPort}/"
    )
  '';
}
