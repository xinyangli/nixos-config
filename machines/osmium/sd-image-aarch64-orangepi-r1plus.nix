{
  config,
  modulesPath,
  lib,
  pkgs,
  ...
}:
let
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "earlycon"
    "console=ttyS2,1500000"
    "consoleblank=0"
  ];
  boot.supportedFilesystems = lib.mkForce [
    "ext4"
    "vfat"
    "ntfs"
  ];

  sdImage = {
    compressImage = false;
    imageBaseName = "nixos-sd-image-orange-pi-r1-plus-lts";
    firmwarePartitionOffset = 16;
    populateFirmwareCommands = ''
      echo "Install U-Boot: ${pkgs.ubootOrangePiR1LtsPackage}"
      dd if=${pkgs.ubootOrangePiR1LtsPackage}/idbloader.img of=$img seek=64 conv=notrunc
      dd if=${pkgs.ubootOrangePiR1LtsPackage}/u-boot.itb of=$img seek=16384 conv=notrunc
    '';
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };
}
