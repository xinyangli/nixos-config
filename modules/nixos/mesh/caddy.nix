{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.mesh-network.caddy;
  meshCfg = config.custom.mesh-network;

  # One .socket unit per mesh port. systemd owns the bind (with
  # BindToDevice=gravity), then passes the FD into services.caddy
  # alongside Caddy's normal listeners. The user opts a vhost onto
  # the mesh scope by writing `bind fd/${fdName port}` in its site
  # block; everything else stays on the default-scope listener.
  socketName = port: "caddy-mesh-${toString port}";
  fdName = port: "mesh-${toString port}";
  socketUnits = map (p: "${socketName p}.socket") cfg.ports;
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
        Ports for which a gravity-scoped socket is created. Each yields
        one systemd .socket unit named `caddy-mesh-<port>.socket` with
        FileDescriptorName=`mesh-<port>`; reference in vhost blocks via
        `bind fd/mesh-<port>`.
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

    systemd.sockets = lib.listToAttrs (
      map (port: {
        name = socketName port;
        value = {
          description = "Caddy mesh socket on port ${toString port} (gravity VRF)";
          wantedBy = [ "sockets.target" ];
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
            ListenStream = port;
            BindToDevice = "gravity";
            FileDescriptorName = fdName port;
            Service = "caddy.service";
            NoDelay = true;
          };
        };
      }) cfg.ports
    );

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
    services.caddy.globalConfig = ''
      servers ${lib.concatStringsSep " " (lib.attrValues cfg.fdRefs)} {
        protocols h1 h2
      }
    '';

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall cfg.ports;
  };
}
