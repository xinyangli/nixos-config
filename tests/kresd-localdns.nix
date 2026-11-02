{ chinaDomainsText }:

# Validates commonSettings.network.localdns (knot-resolver) together with the
# dae proxy stack from mainland.nix, under both enableProxy values:
# - proxy: inMainland && enableProxy -> dae runs with the production config,
#   fed by a fake gost socks5 node (no secrets/online subscription), and kresd
#   serves the generated china domains (~110k) plus static ANSWER policies
# - direct: enableProxy=false -> dae disabled by mainland.nix, kresd runs with
#   fallback forward rules only and must still serve requests (SERVFAIL is
#   fine, there is no upstream in the VM)

{ pkgs, lib, ... }:

let
  stubs = import ./stubs.nix { inherit lib; };

  dig = "${pkgs.dnsutils}/bin/dig";

  base = {
    _module.args = {
      inherit chinaDomainsText;
    };
    imports = [
      ../modules/nixos/common-settings/network.nix
      ../modules/nixos/common-settings/mainland.nix
      stubs.my-lib
      stubs.sops
    ];

    time.timeZone = "Asia/Shanghai";
    commonSettings.network = {
      tailscale.enable = false;
      localdns.enable = true;
    };
    # kresd only listens on loopback in this module; queries come from the node itself
    networking.firewall.enable = false;
  };
in
{
  name = "kresd-localdns";

  nodes = {
    proxy =
      { ... }:
      {
        imports = [ base ];

        # Stand in for the sops-rendered subscription/nodes files: a single
        # static node pointing at the gost fake on node `fake`. Overrides the
        # template content from mainland.nix (which interpolates sops
        # placeholders) so no secrets or online subscription are needed.
        sops = {
          placeholder."dae/sub" = "";
          placeholder."dae/nodes" = "";
          templates."dae/sub.dae" = {
            path = "/etc/dae/sub.dae";
            content = lib.mkForce ''
              node {
                fake: 'socks5://fake:1080'
              }
            '';
          };
        };
        environment.etc."dae/sub.dae".text = ''
          node {
            fake: 'socks5://fake:1080'
          }
        '';
      };

    direct = {
      imports = [
        base
        { commonSettings.network.enableProxy = false; }
      ];
    };

    # Fake proxy node: socks5 endpoint for dae
    fake = {
      systemd.services.gost-fake = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${lib.getExe pkgs.gost} -L=socks5://0.0.0.0:1080";
      };
    };
  };

  testScript = ''
    start_all()
    fake.wait_for_unit("gost-fake.service")

    with subtest("proxy node: dae starts against fake gost node"):
        proxy.wait_for_unit("dae.service")

    with subtest("proxy node: kresd starts with generated china domains"):
        proxy.wait_for_unit("kresd@1.service")
        # generated list actually landed in the kresd config
        proxy.succeed("grep -q \"'baidu.com',\" /etc/knot-resolver/kresd.conf")

    with subtest("proxy node: static ANSWER policy resolves without upstream"):
        out = proxy.succeed("${dig} +short +time=5 +tries=1 @127.0.0.1 la-00.10118244.xyz A")
        assert "67.230.168.47" in out, f"unexpected answer: {out}"

    with subtest("direct node: dae disabled, kresd starts and serves"):
        direct.wait_for_unit("kresd@1.service")
        direct.fail("systemctl is-active --quiet dae.service")
        # no upstream in the VM -> SERVFAIL, but the daemon must answer
        direct.succeed("${dig} +time=5 +tries=1 @127.0.0.1 example.com A")
  '';
}
