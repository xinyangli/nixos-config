(
  final: prev:
  let
    callPackage = prev.lib.callPackageWith prev.pkgs;
  in
  {
    ubootOrangePiR1LtsPackage = prev.buildUBoot {
      defconfig = "orangepi-r1-plus-lts-rk3328_defconfig";
      enableParallelBuilding = true;

      BL31 = "${prev.armTrustedFirmwareRK3328}/bl31.elf";
      filesToInstall = [
        "u-boot.itb"
        "idbloader.img"
      ];
    };
    owncloud-client = import ./pkgs/owncloud-client.nix prev;

    transmission-exporter = prev.callPackage ./pkgs/transmission-exporter.nix { };
    owncloud-shell-resources = callPackage ./pkgs/owncloud-shell-resources.nix { };
    owncloud-nautilus = callPackage ./pkgs/owncloud-nautilus.nix { };
    nerd-fonts-misans = callPackage ./pkgs/nerd-fonts-misans.nix { };

    xwayland-satellite = callPackage ./pkgs/xwayland-satellite.nix { };
    longbridge = callPackage ./pkgs/longbridge.nix { };
  }
)
