{ config, libs, pkgs, ... }:

{
  nixpkgs.overlays = [
    # Workaround https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  
  imports = [
    ../clash.nix
    ../sops.nix
  ];

  environment.systemPackages = with pkgs; [
    git
    clash
  ];

  # Use mirror for binary cache
  nix.settings.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  sops = {
    secrets.password = {
      sopsFile = ./secrets.yaml;
    };
  };

  system.stateVersion = "22.11";
  
  networking = {
    hostName = "raspite";
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
  };

  services.openssh = {
    enable = true;
  };
  
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
  
  users.users.xin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInPn+7cMbH7zCEPJArU/Ot6oq8NHo8a2rYaCfTp7zgd xin@nixos" ];
    # passwordFile = config.sops.secrets.password.path;
    hashedPassword = "$y$j9T$KEOMZBlXtudOYWq/elAdI.$Vd3X8rjEplbuRBeZPp.8/gpL3zthpBNjhBR47wFc8D4";
  };
  
}