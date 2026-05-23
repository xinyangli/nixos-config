{ pkgs, lib, ... }:

# Exercises the `pkgs.kanidm-provision` override defined in
# overlays/add-pkgs.nix, including:
#   * oddlama/kanidm-provision#29 — service accounts
#   * oddlama/kanidm-provision#34 — SSH public keys on persons
#   * locally-authored patch — POSIX attrs on service accounts
#
# Imports the real production declarations from machines/biotite so the test
# mirrors what the deploy actually does: persons + groups + oauth2 clients,
# plus the production extraJsonFile that declares nix_access_hydra (a POSIX
# service account in the nix-builders group).

let
  certs = import (pkgs.path + "/nixos/tests/common/acme/server/snakeoil-certs.nix");
  serverDomain = certs.domain;

  certsPath = pkgs.runCommand "snakeoil-certs" { } ''
    mkdir $out
    cp ${certs."${serverDomain}".cert} $out/snakeoil.crt
    cp ${certs."${serverDomain}".key} $out/snakeoil.key
  '';

  idmAdminPassword = "very-strong-password-for-idm-admin";

  stubs = import ../stubs.nix { inherit lib; };
in
{
  name = "kanidm-provision";

  nodes.provision =
    { pkgs, config, ... }:
    {
      imports = [
        stubs.my-lib
        stubs.sops
        ../../machines/biotite/services/kanidm-provision.nix
      ];

      # The owncloud-android oauth2 client reads its basic secret from this
      # path; production wires it to sops-nix, the test provides a writable
      # stand-in.
      sops.secrets."kanidm/ocis_android_client_secret".path =
        "${pkgs.writeText "fake-ocis-secret" "test-only-not-a-real-secret"}";

      services.kanidm = {
        package = pkgs.kanidmWithSecretProvisioning_1_9;
        server = {
          enable = true;
          settings = {
            origin = "https://${serverDomain}";
            domain = serverDomain;
            bindaddress = "[::]:443";
            tls_chain = "${certsPath}/snakeoil.crt";
            tls_key = "${certsPath}/snakeoil.key";
          };
        };
        client = {
          enable = true;
          settings = {
            uri = "https://${serverDomain}";
            verify_ca = true;
            verify_hostnames = true;
          };
        };
        provision = {
          # Pin a known idm_admin password so the testScript can log in. In
          # production this is left unset so kanidmd rotates it on each boot.
          idmAdminPasswordFile = pkgs.writeText "idm-admin-pw" idmAdminPassword;
        };
      };

      security.pki.certificateFiles = [ certs.ca.cert ];

      networking.hosts."::1" = [ serverDomain ];
      networking.firewall.allowedTCPPorts = [ 443 ];

      users.users.kanidm.shell = pkgs.bashInteractive;

      environment.systemPackages = [
        pkgs.kanidmWithSecretProvisioning_1_9
        pkgs.jq
      ];
    };

  testScript = ''
    def assert_contains(haystack, needle):
        if needle not in haystack:
            print("--- haystack ---")
            print(haystack)
            print("----------------")
            raise Exception(f"Expected string '{needle}' was not found")

    provision.start()
    provision.wait_for_unit("kanidm.service")
    provision.wait_until_succeeds("curl -Lsf https://${serverDomain} | grep Kanidm")

    with subtest("idm_admin login uses provisioned password"):
        out = provision.succeed(
            "KANIDM_PASSWORD=${idmAdminPassword} kanidm login -D idm_admin"
        )
        assert_contains(out, "Login Success for idm_admin")

    with subtest("production persons exist"):
        for name, display in [
            ("xin", "Xinyang Li"),
            ("zhuo", "Zhuo"),
            ("ycm", "Chunming"),
            ("yzl", "Zhengli Yang"),
        ]:
            out = provision.succeed(f"kanidm person get {name}")
            assert_contains(out, f"name: {name}")
            assert_contains(out, f"displayname: {display}")

    with subtest("production groups exist and have expected members"):
        out = provision.succeed("kanidm group get immich-users")
        assert_contains(out, "name: immich-users")
        for m in ["xin", "zhuo", "ycm", "yzl"]:
            assert_contains(out, f"member: {m}")

        out = provision.succeed("kanidm group get forgejo-access")
        assert_contains(out, "name: forgejo-access")
        assert_contains(out, "member: xin")

    with subtest("production oauth2 resource servers exist"):
        for name in [
            "forgejo",
            "gotosocial",
            "owncloud",
            "owncloud-android",
            "hedgedoc",
            "immich",
            "miniflux",
            "grafana",
            "synapse",
            "rustical",
            "jellyfin",
        ]:
            out = provision.succeed(f"kanidm system oauth2 get {name}")
            assert_contains(out, f"name: {name}")

    with subtest("nix_access_hydra service account from PR #29 + local POSIX patch"):
        # `kanidm service-account get` in 1.9 omits displayname from its
        # human-readable output; verify the attributes it does print.
        out = provision.succeed("kanidm service-account get nix_access_hydra")
        assert_contains(out, "name: nix_access_hydra")
        assert_contains(out, "class: service_account")
        assert_contains(out, "class: posixaccount")
        assert_contains(out, "entry_managed_by:")
        assert_contains(out, "nix_access_hydra_admins")
        assert_contains(out, "loginshell: /run/current-system/sw/bin/bash")

        # POSIX attrs from the locally-authored ServiceAccount patch.
        out = provision.succeed("kanidm service-account posix show nix_access_hydra")
        assert_contains(out, "nix_access_hydra")
        assert_contains(out, "/run/current-system/sw/bin/bash")

    with subtest("nix-builders POSIX group with nix_access_hydra"):
        out = provision.succeed("kanidm group get nix-builders")
        assert_contains(out, "name: nix-builders")
        assert_contains(out, "member: nix_access_hydra")

        out = provision.succeed("kanidm group posix show nix-builders")
        assert_contains(out, "nix-builders")
        assert_contains(out, "gidnumber:")

    provision.succeed("kanidm logout -D idm_admin")
  '';
}
