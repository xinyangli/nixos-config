{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
with lib;
let
  cfg = config.ec2;
in
{
  imports = [
    "${modulesPath}/profiles/headless.nix"
    # Note: While we do use the headless profile, we also explicitly
    # turn on the serial console on ttyS0 below. This is because
    # AWS does support accessing the serial console:
    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-access-to-serial-console.html
    "${modulesPath}/virtualisation/ec2-data.nix"
    "${modulesPath}/virtualisation/amazon-init.nix"
  ];

  options = {
    isLightsail = mkEnableOption "Lightsail instance";
  };

  config = mkIf config.isLightsail {
    boot.loader.grub.device = "/dev/nvme0n1";

    # from nixpkgs amazon-image.nix
    assertions = [ ];

    boot.growPartition = true;

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    fileSystems."/boot" = {
      # The ZFS image uses a partition labeled ESP whether or not we're
      # booting with EFI.
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };

    boot.extraModulePackages = [ config.boot.kernelPackages.ena ];
    boot.initrd.kernelModules = [ "xen-blkfront" ];
    boot.initrd.availableKernelModules = [ "nvme" ];
    boot.kernelParams = [
      "console=ttyS0,115200n8"
      "random.trust_cpu=on"
    ];

    # Prevent the nouveau kernel module from being loaded, as it
    # interferes with the nvidia/nvidia-uvm modules needed for CUDA.
    # Also blacklist xen_fbfront to prevent a 30 second delay during
    # boot.
    boot.blacklistedKernelModules = [
      "nouveau"
      "xen_fbfront"
    ];

    boot.loader.grub.efiSupport = cfg.efi;
    boot.loader.grub.efiInstallAsRemovable = cfg.efi;
    boot.loader.timeout = 1;
    boot.loader.grub.extraConfig = ''
      serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
      terminal_output console serial
      terminal_input console serial
    '';

    systemd.services.fetch-ec2-metadata = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.curl ];
      script = builtins.readFile ./ec2-metadata-fetcher.sh;
      serviceConfig.Type = "oneshot";
      serviceConfig.StandardOutput = "journal+console";
    };

    # Amazon-issued AMIs include the SSM Agent by default, so we do the same.
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/ami-preinstalled-agent.html
    services.amazon-ssm-agent.enable = true;

    # Allow root logins only using the SSH key that the user specified
    # at instance creation time.
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "prohibit-password";

    # Enable the serial console on ttyS0
    systemd.services."serial-getty@ttyS0".enable = true;

    # Creates symlinks for block device names.
    services.udev.packages = [ pkgs.amazon-ec2-utils ];

    # Force getting the hostname from EC2.
    # networking.hostName = mkDefault "";

    # Always include cryptsetup so that Charon can use it.
    environment.systemPackages = [ pkgs.cryptsetup ];

    # EC2 has its own NTP server provided by the hypervisor
    services.timesyncd.enable = true;
    services.timesyncd.servers = [ "169.254.169.123" ];

    # udisks has become too bloated to have in a headless system
    # (e.g. it depends on GTK).
    services.udisks2.enable = false;
  };
}
