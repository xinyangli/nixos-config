{
  inputs = {
    # Pin nixpkgs to a specific commit
    nixpkgs.url = "github:xinyangli/nixpkgs/deploy";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
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

    my-nixvim = {
      url = "git+https://git.xinyang.life/xin/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
    };

    stylix = {
      url = "github:xinyangli/stylix";
      # inputs.nixpkgs.follows = "nixpkgs";
      # inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      self,
      home-manager,
      nixpkgs,
      nixos-hardware,
      flake-utils,
      nur,
      catppuccin,
      my-nixvim,
      ...
    }@inputs:
    let
      nixvimOverlay = (final: prev: { nixvim = self.packages.${prev.stdenv.system}.nixvim; });
      overlayModule =
        { ... }:
        {
          nixpkgs.overlays = [
            nixvimOverlay
            (import ./overlays/add-pkgs.nix)
          ];
        };
      deploymentModule = {
        deployment.targetUser = "xin";
      };
      sharedColmenaModules = [
        self.nixosModules.default
        deploymentModule
      ];
      sharedHmModules = [
        inputs.sops-nix.homeManagerModules.sops
        inputs.nix-index-database.hmModules.nix-index
        catppuccin.homeManagerModules.catppuccin
        self.homeManagerModules
      ];
      mkHome =
        user: host:
        { ... }:
        {
          imports = [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                sharedModules = sharedHmModules;
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                };
              };
              home-manager.users.${user} = (import ./home).${user}.${host};
            }
          ];
        };
      mkHomeConfiguration = user: host: {
        name = user;
        value = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          modules = [
            (import ./home).${user}.${host}
            overlayModule
          ] ++ sharedHmModules;
          extraSpecialArgs = {
            inherit inputs;
          };
        };
      };
      mkNixos =
        {
          system,
          modules,
          specialArgs ? { },
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgs // {
            inherit inputs system;
          };
          modules = [
            self.nixosModules.default
            nur.nixosModules.nur
          ] ++ modules;
        };
    in
    {
      nixpkgs = nixpkgs;
      nixosModules.default = {
        imports = [
          ./modules/nixos
          overlayModule
        ];
      };
      homeManagerModules = import ./modules/home-manager;

      homeConfigurations = builtins.listToAttrs [ (mkHomeConfiguration "xin" "calcite") ];

      colmenaHive = inputs.colmena.lib.makeHive {
        meta = {
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          specialArgs = {
            inherit inputs;
          };
        };

        massicot =
          { ... }:
          {
            deployment.targetHost = "49.13.13.122";
            deployment.buildOnTarget = true;

            imports = [
              { nixpkgs.system = "aarch64-linux"; }
              machines/massicot
            ] ++ sharedColmenaModules;
          };

        tok-00 =
          { ... }:
          {
            imports = [ machines/dolomite ] ++ sharedColmenaModules;
            nixpkgs.system = "x86_64-linux";
            networking.hostName = "tok-00";
            system.stateVersion = "23.11";
            deployment = {
              targetHost = "video01.namely.icu";
              buildOnTarget = false;
              tags = [ "proxy" ];
            };
          };

        la-00 =
          { ... }:
          {
            imports = [ machines/dolomite ] ++ sharedColmenaModules;
            nixpkgs.system = "x86_64-linux";
            networking.hostName = "la-00";
            system.stateVersion = "21.05";
            deployment = {
              targetHost = "la-00.video.namely.icu";
              buildOnTarget = false;
              tags = [ "proxy" ];
            };
          };

        raspite =
          { ... }:
          {
            deployment = {
              targetHost = "raspite.local";
              buildOnTarget = false;
            };
            nixpkgs.system = "aarch64-linux";
            imports = [
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              nixos-hardware.nixosModules.raspberry-pi-4
              machines/raspite/configuration.nix
            ] ++ sharedColmenaModules;
          };

        weilite =
          { ... }:
          {
            imports = [ machines/weilite ] ++ sharedColmenaModules;
            deployment = {
              targetHost = "weilite.coho-tet.ts.net";
              targetPort = 22;
              buildOnTarget = false;
            };
            nixpkgs.system = "x86_64-linux";
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
      } // self.colmenaHive.nodes;

    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nix
              git
              colmena
              sops
              nix-output-monitor
              nil
              nvd
            ];
          };
        };

        packages = {
          nixvim = my-nixvim.packages.${system}.default;
        };
      }
    );
}
