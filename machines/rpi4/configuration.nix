{ config, libs, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
  ];
  nixpkgs.overlays = [
    # Workaround https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  
  imports = [ ];

  system.stateVersion = "22.11";
  
  networking = {
    hostName = "pi-wh";
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
  };

  services.openssh = {
    enable = true;
  };
  
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
  
  users.users.pi = {
    isNormalUser = true;
    home = "/home/pi";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInPn+7cMbH7zCEPJArU/Ot6oq8NHo8a2rYaCfTp7zgd xin@nixos" ];
  };
  
}