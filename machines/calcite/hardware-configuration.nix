# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "ahci"
    "usbhid"
  ];
  boot.initrd.kernelModules = [ ];

  boot.initrd = {
    systemd.enable = true; # initrd uses systemd
    luks = {
      fido2Support = false; # because systemd
      devices.cryptroot = {
        device = "/dev/disk/by-uuid/5a51f623-6fbd-4843-9f83-c895067e8e7d";
        crypttabExtraOpts = [ "fido2-device=auto" ]; # cryptenroll
      };
    };
  };
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    # device = "/dev/disk/by-label/NIXROOT";
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-label/EFIBOOT";
    fsType = "vfat";
  };

  fileSystems."/media/data" = {
    device = "/dev/nvme0n1p7";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=1000"
      "nofail"
      "x-systemd.device-timeout=2"
    ];
  };

  swapDevices = [ { device = "/dev/disk/by-label/NIXSWAP"; } ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.tailscale0.useDHCP = lib.mkDefault true;
  # networking.interfaces.virbr0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wg0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    powerManagement.enable = true;
    dynamicBoost.enable = lib.mkForce false;
    open = true;
  };

  hardware.bluetooth.enable = true;
}
