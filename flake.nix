{
  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "/home/xin/repo/GitHub/xinyangli/nixpkgs";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    nixos-cn = {
      url = "github:nixos-cn/flakes";
      # Use the same nixpkgs
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    conduit.url = "gitlab:famedly/conduit/v0.6.0";
    conduit.inputs.nixpkgs.follows = "nixpkgs";

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    flake-utils = {
      url = "github:numtide/flake-utils";
    };
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

      colmena = {
          meta = {
              nixpkgs = import nixpkgs {
                  system = "x86_64-linux";
              };
              machinesFile = ./nixbuild.net;
          };

          massicot = { name, nodes, pkgs, ... }: with inputs; {
              deployment.targetHost = "***REMOVED***";
              deployment.targetUser = "root";

              imports = [
                  { nixpkgs.system = "aarch64-linux"; }
                  machines/massicot
              ];
          };
      };

      nixosConfigurations.calcite = mkNixos {
        system = "x86_64-linux";
        modules = [
          nixos-hardware.nixosModules.asus-zephyrus-ga401
          machines/calcite/configuration.nix
          (mkHome "xin" "calcite")
        ];
      };

      nixosConfigurations.massicot = mkNixos {
        system = "aarch64-linux";
        modules = [
          machines/massicot
          (mkHome "xin" "raspite")
        ];
      };

      nixosConfigurations.dolomite = mkNixos {
        system = "x86_64-linux";
        modules = [
          machines/dolomite
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
