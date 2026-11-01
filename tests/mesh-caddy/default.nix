{ pkgs, lib, ... }:

# Validates custom.mesh-network.caddy.enable: a single `caddy-mesh.socket`
# holding every mesh port, created by systemd with BindToDevice=gravity,
# handed to the same caddy process that serves the default-scope vhosts.
# A vhost opts onto the mesh with `bind sd/mesh/<N>` in its site block;
# everything else stays on the default listener.
#
# Two separate ports keep the original scopes covered; a third shared port
# verifies that publicPorts and mesh sockets can coexist without cross-scope
# virtual-host leaks.

let
  defaultPort = 8080;
  meshPort = 8081;
  sharedPort = 8082;
  tlsPort = 8083;
  meshPayload = "mesh-caddy";
  defaultPayload = "default-caddy";
  sharedMeshPayload = "shared-mesh-caddy";
  sharedPublicPayload = "shared-public-caddy";
  tlsMeshPayload = "tls-mesh-caddy";
  tlsPublicPayload = "tls-public-caddy";

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



    custom.mesh-network.caddy = {
      enable = true;
      ports = [ meshPort sharedPort tlsPort ];
      publicPorts = [ sharedPort tlsPort ];
    };

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/MayCXC/caddy-systemd-socket-activation@v1.0.0"
        ];
        hash = "sha256-qLy94+RwUbcTmwOVK7pZRuADCYkHKoOqIfj4gAMsac0=";
      };
      globalConfig = ''
        admin off
      '';
      virtualHosts."http://:${toString defaultPort}".extraConfig = ''
        respond "${defaultPayload}"
      '';
      # Same caddy, different scope: this vhost binds the systemd-passed
      # FDs instead of opening its own listener, so it only sees traffic
      # the gravity-scoped socket accepted. fdRefs resolves to the named
      # sd/mesh/N listener for the configured port.
      virtualHosts."http://:${toString meshPort}".extraConfig = ''
        bind ${config.custom.mesh-network.caddy.fdRefs.${toString meshPort}}
        respond "${meshPayload}"
      '';
      virtualHosts."http://public.example:${toString sharedPort}".extraConfig = ''
        bind ${config.custom.mesh-network.caddy.publicFdRefs.${toString sharedPort}}
        respond "${sharedPublicPayload}"
      '';
      virtualHosts."http://mesh.example:${toString sharedPort}".extraConfig = ''
        bind ${config.custom.mesh-network.caddy.fdRefs.${toString sharedPort}}
        respond "${sharedMeshPayload}"
      '';
      virtualHosts."https://public-tls.example:${toString tlsPort}".extraConfig = ''
        bind ${config.custom.mesh-network.caddy.publicFdRefs.${toString tlsPort}}
        tls internal
        respond "${tlsPublicPayload}"
      '';
      virtualHosts."https://mesh-tls.example:${toString tlsPort}".extraConfig = ''
        bind ${config.custom.mesh-network.caddy.fdRefs.${toString tlsPort}}
        tls internal
        respond "${tlsMeshPayload}"
      '';
    };

    # services.caddy doesn't auto-open the firewall; we need the
    # underlay port reachable so the default-scope vhost is testable.
    networking.firewall.allowedTCPPorts = [ defaultPort sharedPort tlsPort ];

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
        m.wait_for_unit("caddy-mesh.socket")
        m.wait_for_unit("caddy-public.socket")

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
            "systemctl show caddy-mesh.socket -p BindToDevice --value"
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

    # ---------- Default port reachable through either routing domain ----------
    out = beta.succeed(
        "curl -sS --max-time 5 http://192.168.1.1:${toString defaultPort}/"
    ).strip()
    assert out == "${defaultPayload}", f"beta over underlay: got {out!r}"

    out = beta.succeed(
        "ip vrf exec gravity curl -sS --max-time 5 http://[fd00:42::1]:${toString defaultPort}/"
    ).strip()
    assert out == "${defaultPayload}", f"beta over mesh: got {out!r}"

    # ---------- Same port, separate public and mesh sockets ----------
    out = beta.succeed(
        "curl -sS --max-time 5 -H 'Host: public.example' http://192.168.1.1:${toString sharedPort}/"
    ).strip()
    assert out == "${sharedPublicPayload}", f"public over underlay: got {out!r}"

    out = beta.succeed(
        "ip vrf exec gravity curl -sS --max-time 5 -H 'Host: mesh.example' http://[fd00:42::1]:${toString sharedPort}/"
    ).strip()
    assert out == "${sharedMeshPayload}", f"mesh over gravity: got {out!r}"

    rc, out = beta.execute(
        "curl -sS --max-time 5 -H 'Host: mesh.example' http://192.168.1.1:${toString sharedPort}/"
    )
    assert "${sharedMeshPayload}" not in out, (
        f"mesh vhost leaked onto the public socket: rc={rc}, out={out!r}"
    )

    rc, out = beta.execute(
        "ip vrf exec gravity curl -sS --max-time 5 -H 'Host: public.example' http://[fd00:42::1]:${toString sharedPort}/"
    )
    assert "${sharedPublicPayload}" not in out, (
        f"public vhost leaked onto the mesh socket: rc={rc}, out={out!r}"
    )

    # ---------- TLS must never share accept() with plaintext redirects ----------
    out = beta.succeed(
        "curl -ksS --max-time 5 --resolve public-tls.example:${toString tlsPort}:192.168.1.1 https://public-tls.example:${toString tlsPort}/"
    ).strip()
    assert out == "${tlsPublicPayload}", f"public TLS: got {out!r}"

    for attempt in range(40):
        out = beta.succeed(
            "ip vrf exec gravity curl -ksS --max-time 5 --resolve mesh-tls.example:${toString tlsPort}:[fd00:42::1] https://mesh-tls.example:${toString tlsPort}/"
        ).strip()
        assert out == "${tlsMeshPayload}", f"mesh TLS attempt {attempt + 1}: got {out!r}"

    rc, out = beta.execute(
        "ip vrf exec gravity curl -sS --max-time 5 --resolve mesh-tls.example:${toString tlsPort}:[fd00:42::1] http://mesh-tls.example:${toString tlsPort}/"
    )
    assert "${tlsMeshPayload}" not in out, (
        f"plaintext HTTP reached the TLS application route: rc={rc}, out={out!r}"
    )
  '';
}
