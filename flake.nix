{
  inputs = {
    # Pin nixpkgs to a specific commit
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions =  {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nixos-cn = {
      url = "github:nixos-cn/flakes";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  
    nur = {
      url = "github:nix-community/NUR";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.stable.follows = "nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
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
          self.homeManagerModules
        ];
      };
      mkNixos = { system, modules, specialArgs ? {}}: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = specialArgs // { inherit inputs system; };
        modules = [
          self.nixosModules.default
          home-manager.nixosModules.home-manager
          nur.nixosModules.nur
        ] ++ modules;
      };
      evalSecrets = import ./eval_secrets.nix;
    in
    {
      nixosModules.default = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      colmenaHive = colmena.lib.makeHive {
          meta = {
              nixpkgs = import nixpkgs {
                  system = "x86_64-linux";
              };
              machinesFile = ./nixbuild.net;
              specialArgs = {
                inherit inputs;
              };
          };

          massicot = { name, nodes, pkgs, ... }: with inputs; {
              deployment.targetHost = "49.13.13.122";
              deployment.targetUser = "xin";

              imports = [
                  { nixpkgs.system = "aarch64-linux"; }
                  self.nixosModules.default
                  machines/massicot
              ];
          };

          sgp-00 = { name, nodes, pkgs, ... }: with inputs; {
              imports = [
                self.nixosModules.default
                machines/dolomite
              ];
              nixpkgs.system = "x86_64-linux";
              networking.hostName = "sgp-00";
              system.stateVersion = "23.11";
              deployment = {
                targetHost = "video.namely.icu";
                buildOnTarget = false;
                tags = [ "proxy" ];
              };
          };

          tok-00 = { name, nodes, pkgs, ... }: with inputs; {
              imports = [
                self.nixosModules.default
                machines/dolomite
              ];
              nixpkgs.system = "x86_64-linux";
              networking.hostName = "tok-00";
              system.stateVersion = "23.11";
              deployment = {
                targetHost = "video01.namely.icu";
                buildOnTarget = false;
                tags = [ "proxy" ];
              };
          };
      };

      nixosConfigurations = {
        calcite = mkNixos {
          system = "x86_64-linux";
          modules = [
            nixos-hardware.nixosModules.asus-zephyrus-ga401
            machines/calcite/configuration.nix
            (mkHome "xin" "calcite")
          ];
        }; 
        raspite = mkNixos {
          system = "aarch64-linux";
          modules = [
            nixos-hardware.nixosModules.raspberry-pi-4
            machines/raspite/configuration.nix
            (mkHome "xin" "raspite")
          ];
        };
      } // self.colmenaHive.nodes;

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
    };
}
