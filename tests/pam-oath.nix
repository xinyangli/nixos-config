{ pkgs, run0SudoShimModule }:

let
  stubs = import ./stubs.nix { inherit (pkgs) lib; };
  node =
    { lib, ... }:
    {
      imports = [
        stubs.my-lib
        stubs.sops
        run0SudoShimModule
        ../modules/nixos/common-settings/auth.nix
      ];

      commonSettings.auth = {
        enable = true;
        sshAccess = false;
      };
      services.kanidm.unix.enable = lib.mkForce false;
      services.userborn.enable = lib.mkForce false;
      users.groups.systemd-journal.members = lib.mkForce [ ];

      security.polkit.adminIdentities = lib.mkForce [ "unix-group:wheel" ];
      security.polkit.persistentAuthentication = lib.mkForce false;

      users.users = {
        admin = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          password = "test-password";
        };
        unenrolled = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          password = "test-password";
        };
      };

      sops.secrets."oath/users.oath".path = toString (pkgs.writeText "oath-users" ''
        HOTP/T30/6 admin - 3132333435363738393031323334353637383930
      '');
    };
in
{
  name = "pam-oath-test";

  nodes = {
    first = node;
    second = node;
  };

  testScript = ''
    start_all()
    for machine in (first, second):
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("oath-usersfile.service")

    code = first.succeed("oathtool --totp 3132333435363738393031323334353637383930").strip()
    first.succeed(f"su - admin -c 'echo {code} | sudo --stdin -v'")
    second.succeed(f"su - admin -c 'echo {code} | sudo --stdin -v'")

    first.succeed("su - unenrolled -c 'echo test-password | sudo --stdin -v'")
    first.succeed("su - admin -c '(echo xxxxxx; echo test-password) | sudo --stdin -v'")
  '';
}
