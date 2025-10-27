{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf;
  inherit (config.my-lib.settings)
    internalDomain
    ;
  cfg = config.commonSettings.network;
in
{
  options.commonSettings.network = {
    localdns = {
      enable = mkEnableOption "Local DNS resolver";
      cacheSize = mkOption {
        type = lib.types.int;
        description = "Max cache size for knot-resolver in MB";
        default = 100;
      };
    };
    tailscale = {
      enable = mkEnableOption "Tailscale client" // {
        default = true;
      };
      before = mkOption {
        default = [ ];
        type = lib.types.listOf lib.types.str;
      };
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.tailscale.enable {
      sops = {
        secrets = {
          "tailscale/authkey" = {
            sopsFile = ../../../machines/secrets.yaml;
          };
        };
      };

      services.tailscale = {
        enable = true;
        openFirewall = true;
        permitCertUid = mkIf config.services.caddy.enable config.services.caddy.user;
        extraUpFlags = [ "--accept-routes" ] ++ (lib.optional cfg.localdns.enable "--accept-dns=false");
        authKeyFile = config.sops.secrets."tailscale/authkey".path;
      };
      networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
      commonSettings.network.tailscale.before = (
        lib.optional config.services.caddy.enable "caddy.service"
      );

      systemd.services.tailscaled.before = cfg.tailscale.before;
      systemd.services.tailscaled.serviceConfig.ExecStartPost =
        pkgs.writers.writePython3 "tailscale-wait-online"
          {
            flakeIgnore = [
              "E401" # import on one line
              "E501" # line length limit
            ];
          }
          ''
            import subprocess, json, time

            for _ in range(30):
                status = json.loads(
                    subprocess.run(
                        ["${lib.getExe config.services.tailscale.package}", "status", "--peers=false", "--json"], capture_output=True
                    ).stdout
                )["Self"]["Online"]
                if status:
                    exit(0)
                time.sleep(1)

            exit(1)
          '';

    })

    (mkIf cfg.localdns.enable {
      services.resolved = mkIf config.networking.useNetworkd {
        llmnr = "false";
        extraConfig = ''
          ${lib.optionalString (!config.commonSettings.network.enableProxy) "DNS=127.0.0.1 ::1"}
          DNSStubListener=no
        '';
      };

      system.nssDatabases.hosts = mkIf config.networking.useNetworkd (
        lib.mkForce [
          "mymachines"
          "files"
          "myhostname"
          "dns"
        ]
      );

      networking.resolvconf = {
        enable = !config.networking.useNetworkd;
        dnsExtensionMechanism = false;
        # We should disable local resolver if dae is enabled
        # to let dns traffic go through dae
        useLocalResolver = !config.commonSettings.network.enableProxy;
      };

      services.kresd = {
        enable = true;
        listenPlain = [ "127.0.0.1:53" ];
        listenTLS = [ "127.0.0.1:853" ];
        extraConfig =
          let
            listToLuaTable =
              x:
              lib.pipe x [
                (builtins.split "\n")
                (builtins.filter (s: s != [ ] && s != ""))
                (lib.strings.concatMapStrings (x: "'${x}',"))
              ];
            chinaDomains = listToLuaTable (builtins.readFile ./china-domains.txt);
            globalSettings = ''
              log_level("info")
              modules = { 'hints > iterate', 'stats', 'predict' }
              cache.size = ${toString cfg.localdns.cacheSize} * MB
              trust_anchors.remove(".")
            '';
            tsSettings = ''
              internalDomains = policy.todnames({'${internalDomain}'})
              policy.add(policy.suffix(policy.STUB({'100.100.100.100'}), internalDomains))
            '';
            proxySettings = ''
              policy.add(policy.domains(
                policy.ANSWER({ [kres.type.A] = { rdata=kres.str2ip('67.230.168.47'), ttl=300 } }),
                { todname('la-00.namely.icu') }))
              policy.add(policy.domains(
                policy.ANSWER({ [kres.type.A] = { rdata=kres.str2ip('185.217.108.59'), ttl=300 } }),
                { todname('fra-00.namely.icu') }))
            '';
            mainlandSettings = ''
              chinaDomains = policy.todnames({'namely.icu', ${chinaDomains}})
              policy.add(policy.suffix(policy.TLS_FORWARD({
                { "223.5.5.5", hostname="dns.alidns.com" },
                { "223.6.6.6", hostname="dns.alidns.com" },
              }), chinaDomains))
              policy.add(policy.all(policy.TLS_FORWARD({
                { "8.8.8.8", hostname="dns.google" },
                { "8.8.4.4", hostname="dns.google" },
              })))
            '';
            overseaSettings = ''
              policy.add(policy.all(policy.TLS_FORWARD({
                { "8.8.8.8", hostname="dns.google" },
                { "8.8.4.4", hostname="dns.google" },
              })))
            '';
          in
          globalSettings
          + (if config.services.tailscale.enable then tsSettings else "")
          + (
            if (config.inMainland && config.commonSettings.network.enableProxy) then
              proxySettings + mainlandSettings
            else
              overseaSettings
          );
      };
    })
  ];
}
