{
  inputs = {
    # Pin nixpkgs to a specific commit
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";
    nur-xddxdd = {
      url = "github:xddxdd/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-cn = {
      url = "github:nixos-cn/flakes";
      # Use the same nixpkgs
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
  };


  outputs = { self, ... }@inputs:
    with inputs;
    let
      mkHome = user: host: home-manager.nixosModules.home-manager {
        extraSpecialArgs = { inherit inputs; };
        home-manager.users.${user} = import ./home/${user}/${host};
      };
    in
    {
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      nixosConfigurations.xin-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          machines/laptop/configuration.nix
          nur.nixosModules.nur
          sops-nix.nixosModules.sops
        ];
        specialArgs = inputs;
      };
      nixosConfigurations.rpi4 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          machines/rpi4/configuration.nix
          nixos-hardware.nixosModules.raspberry-pi-4
        ];
      };

      images.rpi4 = (nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          machines/rpi4/configuration.nix
          nixos-hardware.nixosModules.raspberry-pi-4
          {
            nixpkgs.config.allowUnsupportedSystem = true;
            nixpkgs.hostPlatform.system = "aarch64-linux";
            nixpkgs.buildPlatform.system = "x86_64-linux";
            # ... extra configs as above
          }
        ];
      }).config.system.build.sdImage;
    };
}
