{ config, lib, ... }:
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
  };

  config = {
    networking.resolvconf = mkIf cfg.localdns.enable {
      enable = true;
      dnsExtensionMechanism = false;
      useLocalResolver = true;
    };

    services.resolved.enable = mkIf cfg.localdns.enable false;

    services.tailscale = mkIf cfg.localdns.enable {
      extraUpFlags = [ "--accept-dns=false" ];
    };

    services.kresd = mkIf cfg.localdns.enable {
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
            log_level("notice")
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
              policy.ANSWER({ [kres.type.A] = { rdata=kres.str2ip('8.218.218.229'), ttl=300 } }),
              { todname('hk-00.namely.icu') }))
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
        + (if config.services.dae.enable then proxySettings else "")
        + (if config.services.tailscale.enable then tsSettings else "")
        + (if config.inMainland then mainlandSettings else overseaSettings);
    };
  };
}
