{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.mesh-network.caddy;
  meshCfg = config.custom.mesh-network;

  # One .socket unit for all mesh ports: systemd guarantees that all
  # sockets of a single unit are passed in configuration order
  # (systemd.socket(5)), which is what makes the numeric `bind fd/<N>`
  # references in fdRefs deterministic. Ordering between separate
  # socket units is unspecified — one unit per port used to scramble
  # them. The user opts a vhost onto the mesh scope by writing
  # `bind fd/<N>` in its site block; everything else stays on the
  # default-scope listener.
  socketUnits = [ "caddy-mesh.socket" ];
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
        Ports for which a gravity-scoped socket is created. All ports
        share one systemd .socket unit (`caddy-mesh.socket`) whose fds
        are passed to caddy in this order; reference them in vhost
        blocks via `config.custom.mesh-network.caddy.fdRefs."<port>"`.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open the firewall on the listening ports. Safe globally: the
        socket has SO_BINDTODEVICE=gravity, so the kernel only accepts
        connections whose ingress L3MDEV is gravity. Default-scope
        SYNs on the same port don't match any listener (assuming you
        haven't also bound services.caddy there) and get RST'd.
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
        order of `ports` and bundles the TCP + UDP FDs together, so
        vhost blocks can stay declarative:

        ```
        services.caddy.virtualHosts."mesh.example.org".extraConfig = '''
          bind ''${config.custom.mesh-network.caddy.fdRefs."443"}
          ...
        ''';
        ```
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

    # Single .socket unit holding every mesh port. systemd passes the
    # fds of one unit's sockets in the order they are configured
    # (systemd.socket(5)), so the numeric fdRefs mapping stays valid;
    # with one unit per port the inter-unit order is unspecified and
    # the binds got attached to the wrong sockets.
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
        Service = "caddy.service";
        NoDelay = true;
      };
    };

    # Belt-and-suspenders FD passing: declaring Sockets= on the service
    # makes systemd hand the FDs over even when caddy.service starts
    # standalone (boot, restart), not only via socket activation.
    systemd.services.caddy = {
      wants = socketUnits;
      after = socketUnits;
      serviceConfig.Sockets = socketUnits;
    };

    # HTTP/3 needs UDP; the inherited fd is TCP-only. Tell caddy to skip
    # the QUIC listener on the mesh server so it doesn't fail at startup
    # with "network 'fd' cannot handle HTTP/3 connections".
    services.caddy.globalConfig = lib.concatMapStrings (ref: ''
      servers ${ref} {
        protocols h1 h2
      }
    '') (lib.attrValues cfg.fdRefs);

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall cfg.ports;
  };
}
