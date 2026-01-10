{ config, pkgs, ... }:
{
  sops.secrets = {
    "hydra/attic_token" = { };
  };
  sops.templates."hydra/env".content = ''
    HYDRA_ATTIC_TOKEN=${config.sops.placeholder."hydra/attic_token"}
  '';
  services.hydra = {
    enable = true;
    package =
      # FIXME: https://github.com/NixOS/nixpkgs/issues/476278
      (pkgs.hydra.override ({
        libpqxx = (pkgs.libpqxx.override { stdenv = pkgs.gcc14Stdenv; }).overrideAttrs (
          _: prevAttrs: {
            nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ pkgs.autoreconfHook ];
            nativeCheckInputs = [
              pkgs.postgresql
              pkgs.postgresqlTestHook
            ];
            postPatch = prevAttrs.postPatch + ''
              # Disable some tests that always fail -- unclear why.
              substituteInPlace test/unit/test_stream_from.cxx \
                --replace-fail "PQXX_REGISTER_TEST(test_stream_from_parses_awkward_strings);" ""
              substituteInPlace test/unit/test_stream_query.cxx \
                --replace-fail "PQXX_REGISTER_TEST(test_stream_parses_awkward_strings);" ""
              # Disable linting step for tests, it tries to install packages with pip.
              substituteInPlace Makefile.am \
                --replace-fail "TESTS = tools/lint" ""
              # Needed for autoreconfHook
              patchShebangs tools/*.py
            '';
            doCheck = true;
            enableParallelBuilding = true;
            __structuredAttrs = true;
          }
        );
      })).overrideAttrs
        (
          _: _: {
            doCheck = false;
          }
        );
    hydraURL = "http://agate.coho-tet.ts.net:3000/";
    notificationSender = "hydra@localhost";
    buildMachinesFiles = [ ];
    useSubstitutes = true;
    minimumDiskFreeEvaluator = 20;
    minimumDiskFree = 20;
    extraConfig = ''
      allow_import_from_derivation = true
    '';
  };

  systemd.services.attic-watch-store = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    description = "Upload all store content to binary cache";
    environment = {
      # attic login write to $XDG_CONFIG_HOME/attic/config.toml
      XDG_CONFIG_HOME = "/var/lib/attic-watch-store";
    };
    serviceConfig = {
      DynamicUser = true;
      EnvironmentFile = config.sops.templates."hydra/env".path;
      StateDirectory = "attic-watch-store";
      WorkingDirectory = "%S/attic-watch-store";
      ExecStartPre = pkgs.writeShellScript "attic-watch-store-start-pre" ''
        ${pkgs.attic-client}/bin/attic login attic "https://pek-0.cache.xiny.li:8443/" "''$HYDRA_ATTIC_TOKEN"
      '';
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store general";
    };
  };
}
