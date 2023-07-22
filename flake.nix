{
  inputs = {
    # Pin nixpkgs to a specific commit
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-cn = {
      url = "github:nixos-cn/flakes";
      # Use the same nixpkgs
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    flake-utils.url = "github:numtide/flake-utils";
  };


  outputs = { self, ... }@inputs:
    with inputs;
    let
      mkHome = user: host: { config, system, ... }: {
        imports = [
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.xin = import ./home/${user}/${host};
            home-manager.extraSpecialArgs = { inherit inputs system; };
          }
        ];
      };
      mkNixos = { system, modules, specialArgs ? {}}: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = specialArgs // { inherit inputs system; };
        modules = [
          home-manager.nixosModules.home-manager
          nur.nixosModules.nur
          sops-nix.nixosModules.sops
        ] ++ modules;
      };
    in
    {
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      nixosConfigurations.calcite = mkNixos {
        system = "x86_64-linux";
        modules = [
          nixos-hardware.nixosModules.asus-zephyrus-ga401
          machines/calcite/configuration.nix
          (mkHome "xin" "calcite")
        ];
      };

      nixosConfigurations.raspite = mkNixos {
        system = "aarch64-linux";
        modules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          machines/raspite/configuration.nix
          (mkHome "xin" "raspite")
        ];
      };


      images.raspite = (mkNixos {
        system = "aarch64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          nixos-hardware.nixosModules.raspberry-pi-4
          machines/raspite/configuration.nix
          {
            nixpkgs.config.allowUnsupportedSystem = true;
            nixpkgs.hostPlatform.system = "aarch64-linux";
            nixpkgs.buildPlatform.system = "x86_64-linux";
          }
        ];
      }).config.system.build.sdImage;
    } // 
      (with flake-utils.lib; (eachSystem defaultSystems (system:
        let pkgs = import nixpkgs { inherit system; }; in
      {
        packages = {
          homeConfigurations."xin" = import ./home/xin/gold { inherit home-manager pkgs; };
        };
      }
      )));
}
