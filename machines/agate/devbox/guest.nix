{
  self,
  sops-nix,
  run0-sudo-shim,
  comin,
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
    network.tailscale.enable = false;
  };

  programs.fish.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "xin@auth.xiny.li") return polkit.Result.YES;
    });
  '';

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
