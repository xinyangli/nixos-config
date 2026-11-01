{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.mesh-network.caddy;
  meshCfg = config.custom.mesh-network;

  # One .socket unit per VRF scope. Within a unit, systemd passes the
  # fds of its sockets in configuration order (systemd.socket(5)); the
  # order *between* units is unspecified. The
  # caddy-systemd-socket-activation plugin resolves `bind sd/<name>/<N>`
  # through LISTEN_FDNAMES inside Caddy, making the references independent
  # of cross-unit fd order. Mesh sockets bind each configured mesh address
  # rather than a wildcard: when publicPorts shares a port, exact-address
  # lookup selects the mesh socket for mesh traffic and the public wildcard
  # socket for everything else. ReusePort=true lets those sockets coexist.
  socketUnits = [ "caddy-mesh.socket" ] ++ lib.optional (cfg.publicPorts != [ ]) "caddy-public.socket";

  meshAddresses = map (address: lib.head (lib.splitString "/" address)) meshCfg.address;
  meshListeners = lib.imap0 (index: listener: listener // { inherit index; }) (
    lib.concatMap (port: map (address: { inherit address port; }) meshAddresses) cfg.ports
  );
  formatAddress = address: if lib.hasInfix ":" address then "[${address}]" else address;

in
{
  options.custom.mesh-network.caddy = {
    # Opt-in per host. Auto-enabling would leave a listening socket on
    # every mesh+caddy host whether or not any vhost uses `bind sd/mesh/N` —
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
        Caddy alongside the mesh socket — i.e. ports where both the public
        and the mesh scope serve traffic. The mesh socket binds each
        configured mesh address while the public socket binds the wildcard;
        both use SO_REUSEPORT, and exact-address lookup keeps ingress routing
        in the intended scope.

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
        map (port: {
          name = toString port;
          value = lib.concatStringsSep " " (
            map (listener: "sd/mesh/${toString listener.index}") (
              lib.filter (listener: listener.port == port) meshListeners
            )
          );
        }) cfg.ports
      );
      defaultText = lib.literalExpression "{ \"<port>\" = \"sd/mesh/<N>\"; ... }";
      description = ''
        Resolved `bind` references per mesh port. The
        caddy-systemd-socket-activation plugin resolves the socket unit's
        FileDescriptorName through LISTEN_FDNAMES. Each entry contains one
        reference per configured mesh address; indices follow port order,
        then `custom.mesh-network.address` order.

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
          value = "sd/public/${toString i}";
        }) cfg.publicPorts
      );
      defaultText = lib.literalExpression "{ \"<port>\" = \"sd/public/<N>\"; ... }";
      description = ''
        Resolved `bind` reference per public port — same mechanism as
        `fdRefs`, using the public socket unit's FileDescriptorName.
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
        assertion = meshCfg.address != [ ];
        message = "custom.mesh-network.caddy.enable requires at least one custom.mesh-network.address for its exact-address listeners";
      }
      {
        assertion = config.services.caddy.enable;
        message = "custom.mesh-network.caddy.enable extends services.caddy with VRF-scoped sockets — enable services.caddy too.";
      }
    ];

    # Gravity-scoped sockets, one unit for every mesh port/address pair.
    # systemd passes a unit's fds in configuration order (systemd.socket(5));
    # across units the order is unspecified, which is why vhosts use the
    # plugin's named sd/ references. Exact-address mesh listeners and the
    # wildcard public listener can share a port through SO_REUSEPORT without
    # sending mesh traffic to the public server. FreeBind allows socket
    # activation before networkd assigns the configured addresses.
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
        ListenStream = map (
          listener: "${formatAddress listener.address}:${toString listener.port}"
        ) meshListeners;
        BindToDevice = "gravity";
        FreeBind = true;
        FileDescriptorName = "mesh";
        ReusePort = true;
        Service = "caddy.service";
        NoDelay = true;
      };
    };

    # Default-VRF sockets for ports that both scopes serve (see
    # publicPorts). The plugin tells the two scopes apart by
    # FileDescriptorName, so unit start order doesn't matter.
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
    systemd.services.caddy = {
      wants = socketUnits;
      after = socketUnits;
      serviceConfig.Sockets = socketUnits;
    };

    # HTTP/3 needs UDP; the inherited fds are TCP-only. Tell caddy to
    # skip the QUIC listener on these servers so it doesn't fail at
    # startup with "network 'sd' cannot handle HTTP/3 connections".
    services.caddy.globalConfig = lib.concatStrings (
      (map (listener: ''
        servers sd/mesh/${toString listener.index}:${toString listener.port} {
          protocols h1 h2
        }
      '') meshListeners)
      ++ (lib.mapAttrsToList (port: ref: ''
        servers ${ref}:${port} {
          protocols h1 h2
        }
      '') cfg.publicFdRefs)
    );

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (cfg.ports ++ cfg.publicPorts);
  };
}
