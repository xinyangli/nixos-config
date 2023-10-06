{ config, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  services.sing-box = {
    enable = true;
    settings = {
      
    };
  };
}
