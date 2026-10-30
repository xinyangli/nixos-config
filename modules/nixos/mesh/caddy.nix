{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.mesh-network.caddy;
  meshCfg = config.custom.mesh-network;

  # One .socket unit per VRF scope. Within a unit, systemd passes the
  # fds of its sockets in configuration order (systemd.socket(5)); the
  # order *between* units is unspecified, and Caddy only understands
  # numeric `bind fd/<N>` (no LISTEN_FDNAMES lookup). The wrapper below
  # closes that gap: it re-sorts the inherited fds by
  # FileDescriptorName into the canonical layout before exec'ing caddy,
  # so fdRefs is deterministic no matter which unit systemd starts
  # first. ReusePort=true on both units is load-bearing: the kernel
  # only lets a wildcard and a SO_BINDTODEVICE socket share a port
  # number when both carry SO_REUSEPORT; without it the second bind
  # fails with EADDRINUSE in either order.
  socketUnits = [ "caddy-mesh.socket" ] ++ lib.optional (cfg.publicPorts != [ ]) "caddy-public.socket";

  caddyWithSortedFds = pkgs.writeShellScript "caddy-with-sorted-fds" ''
    set -euo pipefail
    : "''${LISTEN_FDNAMES:=}"
    names=( ''${LISTEN_FDNAMES//:/ } )
    # Stash every inherited fd at 1000+i so the canonical layout can be
    # rebuilt regardless of the order systemd passed them in.
    for i in "''${!names[@]}"; do
      eval "exec $((1000+i))<&$((3+i))"
    done
    take() {
      local name=$1 count=$2 n=0 i
      for i in "''${!names[@]}"; do
        if [ "$n" -lt "$count" ] && [ "''${names[$i]}" = "$name" ]; then
          printf '%s\n' "$((1000+i))"
          n=$((n+1))
        fi
      done
      if [ "$n" -ne "$count" ]; then
        echo "caddy-with-sorted-fds: expected $count fd(s) named '$name', got $n (LISTEN_FDNAMES=$LISTEN_FDNAMES)" >&2
        exit 1
      fi
    }
    ${lib.optionalString (cfg.ports != [ ]) ''
      mapfile -t meshfds < <(take mesh ${toString (builtins.length cfg.ports)})
    ''}
    ${lib.optionalString (cfg.publicPorts != [ ]) ''
      mapfile -t pubfds < <(take public ${toString (builtins.length cfg.publicPorts)})
    ''}
    ${lib.concatStrings (
      lib.imap0 (
        i: _p: "eval \"exec $((3 + ${toString i}))<&\\$" + "{meshfds[${toString i}]}\"\n"
      ) cfg.ports
    )}
    ${lib.concatStrings (
      lib.imap0 (
        i: _p:
        "eval \"exec $((3 + ${
          toString (builtins.length cfg.ports)
        } + ${toString i}))<&\\$" + "{pubfds[${toString i}]}\"\n"
      ) cfg.publicPorts
    )}
    exec ${config.services.caddy.package}/bin/caddy run --config ${config.services.caddy.configFile} --adapter caddyfile
  '';
in
{
  options.custom.mesh-network.caddy = {
    # Opt-in per host. Auto-enabling would leave a listening socket on
    # every mesh+caddy host whether or not any vhost uses `bind fd/N` —
    # connections to it would hang on accept() with no Caddy site
    # behind them. Hosts that actually serve mesh-internal vhosts
    # enable this explicitly.
    enable = lib.mkEnableOption "VRF-scoped sockets attached to services.caddy for mesh-internal vhosts";

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        80
        443
      ];
      description = ''
        Ports for which a gravity-scoped socket is created
        (`caddy-mesh.socket`, SO_BINDTODEVICE=gravity). fds are passed
        to caddy in this order; reference them in vhost blocks via
        `config.custom.mesh-network.caddy.fdRefs."<port>"`.
      '';
    };

    publicPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = ''
        Ports that need a default-VRF (all-interfaces) socket passed to
        caddy alongside the mesh socket — i.e. ports where both the
        public and the mesh scope serve traffic. The wildcard and the
        BindToDevice socket share the port number via SO_REUSEPORT
        (both this unit and caddy's own sockets set it); ingress
        routing stays correct because listener lookup scores the
        device-bound socket higher for gravity-ingress packets.

        Vhosts for these ports must NOT rely on caddy's default bind:
        every https site on a publicPort needs an explicit
        `bind ''${config.custom.mesh-network.caddy.publicFdRefs."<port>"}`
        or caddy falls back to binding the port itself and collides
        with the socket. Plain-HTTP (ACME http-01, redirects) on other
        ports keeps working via caddy's own listeners.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open the firewall on the listening ports. Safe globally: the
        mesh socket has SO_BINDTODEVICE=gravity, so the kernel only
        accepts connections whose ingress L3MDEV is gravity. Default-
        scope SYNs on the same port don't match any listener (assuming
        you haven't also bound services.caddy there) and get RST'd.
      '';
    };

    fdRefs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.listToAttrs (
        lib.imap0 (i: port: {
          name = toString port;
          value = "fd/${toString (3 + i)}";
        }) cfg.ports
      );
      defaultText = lib.literalExpression "{ \"<port>\" = \"fd/<N>\"; ... }";
      description = ''
        Resolved `bind` reference per mesh port. Caddy's `bind fd/<N>`
        only accepts numeric file descriptors (no LISTEN_FDNAMES
        lookup); this attribute computes the right indices from the
        order of `ports`, so vhost blocks can stay declarative:

        ```
        services.caddy.virtualHosts."mesh.example.org".extraConfig = '''
          bind ''${config.custom.mesh-network.caddy.fdRefs."443"}
          ...
        ''';
        ```
      '';
    };

    publicFdRefs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.listToAttrs (
        lib.imap0 (i: port: {
          name = toString port;
          value = "fd/${toString (3 + builtins.length cfg.ports + i)}";
        }) cfg.publicPorts
      );
      defaultText = lib.literalExpression "{ \"<port>\" = \"fd/<N>\"; ... }";
      description = ''
        Resolved `bind` reference per public port — same mechanism as
        `fdRefs`, placed after the mesh fds in the canonical layout.
        Use for public vhosts that share a port number with the mesh
        scope; see `publicPorts` for the pitfalls.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = meshCfg.ipsec.enable;
        message = "custom.mesh-network.caddy.enable requires custom.mesh-network.ipsec.enable so the gravity VRF exists for BindToDevice= to target.";
      }
      {
        assertion = config.services.caddy.enable;
        message = "custom.mesh-network.caddy.enable extends services.caddy with VRF-scoped sockets — enable services.caddy too.";
      }
    ];

    # Gravity-scoped sockets, one unit for all mesh ports. systemd
    # passes a unit's fds in configuration order (systemd.socket(5));
    # across units the order is unspecified, which is why ExecStart is
    # wrapped (see caddyWithSortedFds). ReusePort=true is required for
    # the socket to share a port number with caddy-public.socket (or
    # with anything else on that port): the kernel refuses a wildcard
    # and a BindToDevice bind on the same port unless both carry
    # SO_REUSEPORT, regardless of bind order.
    systemd.sockets.caddy-mesh = {
      description = "Caddy mesh sockets (gravity VRF)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-networkd.service" ];
      # Triggering caddy.service via the socket is the systemd-blessed
      # path for passing LISTEN_FDS; caddy is already wantedBy
      # multi-user.target so this doesn't change start ordering, only
      # the FD-passing contract.
      socketConfig = {
        # TCP-only. Pairing a ListenDatagram for HTTP/3 doesn't
        # compose with Caddy v2's `bind` semantics — Caddy tries to
        # use every bound address for h1/h2 and a UDP fdgram errors
        # out. The protocols block in globalConfig below disables
        # h3 explicitly so caddy doesn't try to spin one up.
        ListenStream = cfg.ports;
        BindToDevice = "gravity";
        FileDescriptorName = "mesh";
        ReusePort = true;
        Service = "caddy.service";
        NoDelay = true;
      };
    };

    # Default-VRF sockets for ports that both scopes serve (see
    # publicPorts). Same fd contract as caddy-mesh.socket; the wrapper
    # tells the two apart by FileDescriptorName, so unit start order
    # doesn't matter.
    systemd.sockets.caddy-public = lib.mkIf (cfg.publicPorts != [ ]) {
      description = "Caddy public sockets (default VRF)";
      wantedBy = [ "multi-user.target" ];
      socketConfig = {
        ListenStream = cfg.publicPorts;
        FileDescriptorName = "public";
        ReusePort = true;
        Service = "caddy.service";
        NoDelay = true;
      };
    };

    # Belt-and-suspenders FD passing: declaring Sockets= on the service
    # makes systemd hand the FDs over even when caddy.service starts
    # standalone (boot, restart), not only via socket activation.
    # ExecStart is wrapped so the inherited fds land at the canonical
    # positions fdRefs/publicFdRefs promise, independent of the order
    # systemd happened to pass them in.
    systemd.services.caddy = {
      wants = socketUnits;
      after = socketUnits;
      serviceConfig = {
        Sockets = socketUnits;
        ExecStart = lib.mkForce [ "${caddyWithSortedFds}" ];
      };
    };

    # HTTP/3 needs UDP; the inherited fds are TCP-only. Tell caddy to
    # skip the QUIC listener on these servers so it doesn't fail at
    # startup with "network 'fd' cannot handle HTTP/3 connections".
    services.caddy.globalConfig = lib.concatMapStrings (ref: ''
      servers ${ref} {
        protocols h1 h2
      }
    '') (lib.attrValues cfg.fdRefs ++ lib.attrValues cfg.publicFdRefs);

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (cfg.ports ++ cfg.publicPorts);
  };
}
