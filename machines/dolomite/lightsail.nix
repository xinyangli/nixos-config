{ config, lib, pkgs, modulesPath, ... }:
let
  cfg = config.isLightsail;
in
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
  options = {
    isLightsail = lib.mkEnableOption "Lightsail instance";
  };
  config = lib.mkIf cfg.isLightsail{
    boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";
  };
}
