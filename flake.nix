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
      inputs.nixpkgs.follows = "nixpkgs";
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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      sops-nix,
      flake-utils,
      nur,
      catppuccin,
      my-nixvim,
      nix-vscode-extensions,
      colmena,
      nix-index-database,
      disko,
      ...
    }:
    let
      editorOverlay = (
        final: prev: {
          inherit (nix-vscode-extensions.extensions.${prev.stdenv.system}) vscode-marketplace;
          inherit (self.packages.${prev.stdenv.system}) nixvim;
        }
      );
      overlayModule =
        { ... }:
        {
          options.my-lib = nixpkgs.lib.mkOption {
            type = nixpkgs.lib.types.attrs;
            default = import ./overlays/my-lib;
          };
          config = {
            nixpkgs.overlays = [
              editorOverlay
              (import ./overlays/add-pkgs.nix)
            ];
          };
        };
      deploymentModule = {
        deployment.targetUser = "xin";
      };
      sharedHmModules = [
        self.homeManagerModules.default
        sops-nix.homeManagerModules.sops
        nix-index-database.hmModules.nix-index
        catppuccin.homeManagerModules.catppuccin
      ];
      sharedNixosModules = [
        self.nixosModules.default
        sops-nix.nixosModules.sops
      ];
      nodeNixosModules = {
        calcite = [
          nixos-hardware.nixosModules.asus-zephyrus-ga401
          nur.nixosModules.nur
          catppuccin.nixosModules.catppuccin
          machines/calcite/configuration.nix
          # (mkHome "xin" "calcite")
        ];
        hk-00 = [
          ./machines/dolomite/claw.nix
          ./machines/dolomite/common.nix
        ];
        la-00 = [
          ./machines/dolomite/bandwagon.nix
          ./machines/dolomite/common.nix
        ];
        fra-00 = [
          ./machines/dolomite/fra.nix
          ./machines/dolomite/common.nix
        ];
        osmium = [
          ./machines/osmium
        ];
        thorite = [
          disko.nixosModules.disko
          ./machines/thorite
        ];
        biotite = [
          disko.nixosModules.disko
          ./machines/biotite
        ];
      };
      sharedColmenaModules = [
        deploymentModule
      ] ++ sharedNixosModules;
      mkHome =
        user: host:
        { ... }:
        {
          imports = [ home-manager.nixosModules.home-manager ];
          config = {
            home-manager = {
              sharedModules = sharedHmModules;
              useGlobalPkgs = true;
              useUserPackages = true;
            };
            home-manager.users.${user} = (import ./home).${user}.${host};
          };
        };
      mkNixos =
        {
          hostname,
          system ? null,
        }:
        nixpkgs.lib.nixosSystem {
          modules = sharedNixosModules ++ nodeNixosModules.${hostname};
        };
      # TODO:
      mkColmenaHive =
        {
          hostname,
        }:
        colmena.lib.makeHive {
          meta = {
            # FIXME:
            nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          };
        };
    in
    {
      nixosModules.default = {
        imports = [
          ./modules/nixos
          overlayModule
        ];
      };
      homeManagerModules.default = import ./modules/home-manager;

      colmenaHive = colmena.lib.makeHive {
        meta = {
          # FIXME:
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
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

        la-00 =
          { ... }:
          {
            imports = nodeNixosModules.la-00 ++ sharedColmenaModules;
            nixpkgs.system = "x86_64-linux";
            networking.hostName = "la-00";
            system.stateVersion = "21.05";
            deployment = {
              targetHost = "la-00.video.namely.icu";
              buildOnTarget = false;
              tags = [ "proxy" ];
            };
          };

        hk-00 =
          { ... }:
          {
            imports = nodeNixosModules.hk-00 ++ sharedColmenaModules;
            nixpkgs.system = "x86_64-linux";
            networking.hostName = "hk-00";
            system.stateVersion = "24.05";
            deployment = {
              targetHost = "hk-00.video.namely.icu";
              buildOnTarget = false;
              tags = [ "proxy" ];
            };
          };

        fra-00 =
          { ... }:
          {
            imports = nodeNixosModules.fra-00 ++ sharedColmenaModules;
            nixpkgs.system = "x86_64-linux";
            networking.hostName = "fra-00";
            system.stateVersion = "24.05";
            deployment = {
              targetHost = "fra-00.video.namely.icu";
              buildOnTarget = false;
              tags = [ "proxy" ];
            };
          };

        raspite =
          { ... }:
          {
            deployment = {
              targetHost = "raspite.coho-tet.ts.net";
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
        thorite =
          { ... }:
          {
            imports = nodeNixosModules.thorite ++ sharedColmenaModules;
            deployment = {
              buildOnTarget = false;
            };
          };
        biotite =
          { ... }:
          {
            imports = nodeNixosModules.biotite ++ sharedColmenaModules;
          };
      };

      nixosConfigurations = {
        calcite = mkNixos {
          hostname = "calcite";
        };

        osmium = mkNixos {
          hostname = "osmium";
        };
      } // self.colmenaHive.nodes;

    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        mkHomeConfiguration = user: host: {
          name = user;
          value = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              (import ./home).${user}.${host}
              overlayModule
            ] ++ sharedHmModules;
          };
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nix
              git
              colmena.packages.${system}.colmena
              sops
              nix-output-monitor
              nil
              nvd
              nh
              (python3.withPackages (ps: with ps; [ requests ]))
            ];
          };
        };

        homeConfigurations = builtins.listToAttrs [ (mkHomeConfiguration "xin" "calcite") ];

        packages = {
          nixvim = my-nixvim.packages.${system}.default;
        };
      }
    );
}
