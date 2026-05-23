{ pkgs, lib, ... }:

# Validates custom.mesh-network.caddy.enable: a `caddy-mesh-<port>.socket`
# created by systemd with BindToDevice=gravity, handed to the same caddy
# process that serves the default-scope vhosts. A vhost opts onto the
# mesh by writing `bind fd/<N>` in its site block; everything else stays
# on the default listener.
#
# Two ports kept apart on purpose: :${defaultPort} reaches the default
# listener (underlay only), :${meshPort} reaches the mesh socket (VRF
# only). Same caddy process, two scopes.

let
  defaultPort = 8080;
  meshPort = 8081;
  meshPayload = "mesh-caddy";
  defaultPayload = "default-caddy";

  nodes = {
    alpha = {
      underlay = "192.168.1.1";
      announced = "fd00:42::1";
    };
    beta = {
      underlay = "192.168.1.2";
      announced = "fd00:42::2";
    };
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

    # mesh-sshd default-enables on every mesh node and would fail its
    # assertion in this test (no services.openssh). Disable explicitly.
    custom.mesh-network.sshd.enable = false;

    custom.mesh-network.caddy = {
      enable = true;
      ports = [ meshPort ];
    };

    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
        admin off
      '';
      virtualHosts."http://:${toString defaultPort}".extraConfig = ''
        respond "${defaultPayload}"
      '';
      # Same caddy, different scope: this vhost binds the systemd-passed
      # FDs instead of opening its own listener, so it only sees traffic
      # the gravity-scoped socket accepted. fdRefs resolves to the
      # `fd/N fdgram/N+1` pair for the configured port.
      virtualHosts."http://:${toString meshPort}".extraConfig = ''
        bind ${config.custom.mesh-network.caddy.fdRefs.${toString meshPort}}
        respond "${meshPayload}"
      '';
    };

    # services.caddy doesn't auto-open the firewall; we need the
    # underlay port reachable so the default-scope vhost is testable.
    networking.firewall.allowedTCPPorts = [ defaultPort ];

    environment.systemPackages = with pkgs; [ curl ];
  };
in
{
  name = "mesh-caddy-socket-activation";

  nodes = lib.mapAttrs mkNode nodes;

  testScript = ''
    start_all()

    for m in (alpha, beta):
        m.wait_for_unit("strongswan-swanctl.service")
        m.wait_for_unit("gravity-ipsec.service")
        m.wait_for_unit("bird.service")
        m.wait_for_unit("caddy.service")
        # The .socket unit is what carries BindToDevice=gravity; if it
        # didn't activate, the mesh FD never reached caddy.
        m.wait_for_unit("caddy-mesh-${toString meshPort}.socket")

    for src, dst in [(alpha, "fd00:42::2"), (beta, "fd00:42::1")]:
        src.wait_until_succeeds(
            f"ip -6 route show vrf gravity {dst}/128 | grep -q .",
            timeout=120,
        )

    # ---------- Socket wiring sanity ----------
    # The .socket should be bound to gravity and the listener for that
    # port should carry the %gravity SO_BINDTODEVICE marker (this is
    # what the equivalent mesh-caddy.service attempt was missing).
    for m in (alpha, beta):
        bound = m.succeed(
            "systemctl show caddy-mesh-${toString meshPort}.socket -p BindToDevice --value"
        ).strip()
        assert bound == "gravity", (
            f"{m.name}: BindToDevice on the .socket is {bound!r}, expected 'gravity'"
        )
        listeners = m.succeed("ss -lntpH -f inet6")
        assert "%gravity:${toString meshPort}" in listeners, (
            f"{m.name}: expected a %gravity-scoped listener on ${toString meshPort}; got:\n{listeners}"
        )

    # ---------- Mesh port reachable only via VRF ----------
    out = beta.succeed(
        "ip vrf exec gravity curl -sS --max-time 5 http://[fd00:42::1]:${toString meshPort}/"
    ).strip()
    assert out == "${meshPayload}", f"beta over mesh: got {out!r}"

    rc, out = beta.execute(
        "curl -sS --max-time 5 http://192.168.1.1:${toString meshPort}/"
    )
    assert rc != 0, (
        f"beta over underlay should NOT reach mesh port ${toString meshPort} "
        f"(it's BindToDevice=gravity); got rc={rc}, out={out!r}"
    )

    # ---------- Default port reachable only via underlay ----------
    out = beta.succeed(
        "curl -sS --max-time 5 http://192.168.1.1:${toString defaultPort}/"
    ).strip()
    assert out == "${defaultPayload}", f"beta over underlay: got {out!r}"

    # tcp_l3mdev_accept=0 (set by the mesh module) means the default
    # listener won't accept VRF-scoped traffic, so this should fail.
    rc, out = beta.execute(
        "ip vrf exec gravity curl -sS --max-time 5 http://[fd00:42::1]:${toString defaultPort}/"
    )
    assert rc != 0, (
        f"beta over mesh should NOT reach default port ${toString defaultPort} "
        f"(default scope listener, tcp_l3mdev_accept=0); got rc={rc}, out={out!r}"
    )
  '';
}
