{
  self,
  sops-nix,
  run0-sudo-shim,
  comin,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    self.nixosModules.default
    sops-nix.nixosModules.sops
    run0-sudo-shim.nixosModules.default
    comin.nixosModules.comin
  ];

  networking.hostName = "devbox";
  nixpkgs.hostPlatform = "aarch64-linux";
  system.stateVersion = "25.11";
  time.timeZone = "Asia/Shanghai";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "ca-derivations"
  ];

  commonSettings = {
    auth = {
      enable = true;
      totp.enable = false;
    };
    comin.enable = false;
    nix.enable = false;
    network = {
      enableProxy = false;
      tailscale.enable = false;
    };
  };

  programs.fish.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "xin@auth.xiny.li") return polkit.Result.YES;
    });
  '';

  services.openssh.hostKeys = [
    {
      path = "/var/lib/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  environment.etc."ssh/auth" = lib.mkForce {
    mode = "0555";
    user = "root";
    group = "root";
    text = ''
      #!${pkgs.bash}/bin/bash
      exec 3>&1
      if ! ${pkgs.util-linux}/bin/runuser -u opksshuser -- \
        /run/wrappers/bin/opkssh verify "$1" "$2" "$3" \
          2> >(${pkgs.util-linux}/bin/logger -t devbox-auth -p auth.info) 1>&3
      then
        printf 'user=%s type=%s key_prefix=%.32s\n' "$1" "$3" "$2" \
          | ${pkgs.util-linux}/bin/logger -t devbox-auth -p auth.info
        printf '%s\n' 'opkssh verify failed; falling back to Kanidm keys' \
          | ${pkgs.util-linux}/bin/logger -t devbox-auth -p auth.info
        ${pkgs.util-linux}/bin/runuser -u kanidm-ssh-runner -- \
          ${pkgs.kanidm_1_11}/bin/kanidm_ssh_authorizedkeys "$1" \
          2> >(${pkgs.util-linux}/bin/logger -t devbox-auth -p auth.info)
      fi
    '';
  };

  services.opkssh.authorizations = [
    {
      user = "xin@auth.xiny.li";
      principal = "65876f3e-d489-4e3e-af3e-99a541bbb855";
      issuer = "https://auth.xiny.li/oauth2/openid/opkssh";
    }
  ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 8;
    mem = 16384;

    interfaces = [
      {
        type = "user";
        id = "qemu";
        mac = "02:00:00:00:00:01";
      }
    ];

    forwardPorts = [
      {
        from = "host";
        proto = "tcp";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.port = 22;
      }
    ];

    writableStoreOverlay = "/nix/.rw-store";

    volumes = [
      {
        image = "/var/lib/microvms/devbox/nix-store-overlay.img";
        mountPoint = "/nix/.rw-store";
        size = 8192;
      }
      {
        image = "var.img";
        mountPoint = "/var";
        size = 16384;
      }
      {
        image = "home.img";
        mountPoint = "/home";
        size = 131072;
      }
    ];
  };
}
