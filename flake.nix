{
  inputs = {
    # Pin nixpkgs to a specific commit
    nixpkgs.url = "github:xinyangli/nixpkgs/deploy";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    internet-traffic-assignments = {
      url = "git+https://git.xiny.li/xin/InternetTraffic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/main";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
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

    run0-sudo-shim = {
      url = "github:lordgrimmauld/run0-sudo-shim";
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
      url = "git+https://git.xiny.li/xin/nixvim";
    };

    catppuccin = {
      url = "github:catppuccin/nix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comin = {
      url = "github:xinyangli/comin/garnix-executor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-sbc = {
      url = "github:nakato/nixos-sbc/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    mcps-nix = {
      url = "github:roman/mcps.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    chinese-fonts-overlay = {
      url = "github:brsvh/chinese-fonts-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ranet-ipsec = {
      url = "github:NickCao/ranet";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nix-claude-code = {
      url = "github:ryoppippi/nix-claude-code";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      internet-traffic-assignments,
      home-manager,
      nixos-hardware,
      sops-nix,
      run0-sudo-shim,
      flake-utils,
      nur,
      catppuccin,
      my-nixvim,
      nix-vscode-extensions,
      colmena,
      simple-nixos-mailserver,
      nix-index-database,
      disko,
      comin,
      nixos-sbc,
      lanzaboote,
      mcps-nix,
      vicinae,
      chinese-fonts-overlay,
      ranet-ipsec,
      nix-claude-code,
      ...
    }:
    let
      editorOverlay = (
        final: prev: {
          inherit (nix-vscode-extensions.extensions.${prev.stdenv.hostPlatform.system}) vscode-marketplace;
          inherit (self.packages.${prev.stdenv.hostPlatform.system}) nixvim;
        }
      );
      mylibModule = {
        options.my-lib = nixpkgs.lib.mkOption {
          type = nixpkgs.lib.types.attrs;
          default = import ./overlays/my-lib { lib = nixpkgs.lib; };
        };
      };
      overlayModule = {
        config = {
          nixpkgs.overlays = [
            editorOverlay
            chinese-fonts-overlay.overlays.default
            ranet-ipsec.overlays.default
            (import ./overlays/add-pkgs.nix)
          ];
        };
      };
      deploymentModule = {
        deployment.targetUser = "xin";
      };
      sharedHmModules = [
        mylibModule
        self.homeManagerModules.default
        sops-nix.homeManagerModules.sops
        nix-index-database.homeModules.nix-index
        catppuccin.homeModules.catppuccin
        vicinae.homeManagerModules.default
      ];
      sharedNixosModules = [
        self.nixosModules.default
        sops-nix.nixosModules.sops
        comin.nixosModules.comin
        run0-sudo-shim.nixosModules.default
      ];
      nodeNixosModules = {
        weilite = [
          ./machines/weilite
        ];
        agate = [
          disko.nixosModules.disko
          ./machines/agate
          internet-traffic-assignments.nixosModules.assignment2
        ];
        hafnon = [
          disko.nixosModules.disko
          ./machines/hafnon
        ];
        cinnabar = [
          disko.nixosModules.disko
          catppuccin.nixosModules.catppuccin
          lanzaboote.nixosModules.lanzaboote
          machines/cinnabar/configuration.nix
          # (mkHome "xin" "cinnabar")
        ];
        la-00 = [
          disko.nixosModules.disko
          ./machines/dolomite/bandwagon.nix
          ./machines/dolomite/common.nix
          internet-traffic-assignments.nixosModules.assignment2
        ];
        fra-00 = [
          disko.nixosModules.disko
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
          simple-nixos-mailserver.nixosModule
          ./machines/biotite
        ];
        baryte = [
          nixos-sbc.nixosModules.default
          nixos-sbc.nixosModules.boards.bananapi.bpir4
          ./machines/baryte
        ];
      };
      sharedColmenaModules = [
        deploymentModule
      ]
      ++ sharedNixosModules;
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
          modules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          modules =
            sharedNixosModules
            ++ nodeNixosModules.${hostname}
            ++ [
              (
                { lib, ... }:
                {
                  networking.hostName = lib.mkDefault hostname;
                }
              )
            ]
            ++ modules;
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
          mylibModule
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

        la-00 =
          { ... }:
          {
            imports = nodeNixosModules.la-00 ++ sharedColmenaModules;
            nixpkgs.system = "x86_64-linux";
            networking.hostName = "la-00";
            system.stateVersion = "21.05";
            deployment = {
              targetHost = "la-00.video.10118244.xyz";
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
              targetHost = "fra-00.video.10118244.xyz";
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
            ]
            ++ sharedColmenaModules;
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

        osmium =
          { ... }:
          {
            deployment = {
              targetHost = "osmium.coho-tet.ts.net";
              buildOnTarget = false;
            };
            imports = nodeNixosModules.osmium ++ sharedColmenaModules;
          };
      };

      homeConfigurations =
        let
          idmUsername = "xin@auth.xiny.li";
          idmHmModule = {
            home = {
              stateVersion = "25.11";
              homeDirectory = "/home/${idmUsername}";
              username = idmUsername;
            };
          };
        in
        {
          "xin-x86_64-linux" = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              system = "x86_64-linux";
              config = {
                allowUnfree = true;
              };
            };
            modules = [
              ./home/xin/full.nix
              ./modules/home-manager
              idmHmModule
              overlayModule
            ]
            ++ sharedHmModules;
          };
          "xin-x86_64-minimal-cli" = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              system = "x86_64-linux";
            };
            modules = [
              ./home/xin/minimal-cli.nix
              ./modules/home-manager
              idmHmModule
              overlayModule
            ]
            ++ sharedHmModules;
          };
          "xin-x86_64-full-cli" = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              system = "x86_64-linux";
            };
            modules = [
              ./home/xin/full-cli.nix
              ./modules/home-manager
              idmHmModule
              overlayModule
            ]
            ++ sharedHmModules;
          };
        };

      nixosConfigurations = {
        cinnabar = mkNixos {
          hostname = "cinnabar";
        };

        weilite = mkNixos {
          hostname = "weilite";
        };

        agate = mkNixos {
          hostname = "agate";
        };

        hafnon = mkNixos {
          hostname = "hafnon";
        };

        baryte = mkNixos {
          hostname = "baryte";
        };
      }
      // self.colmenaHive.nodes;

      hydraJobs =
        let
          includeHosts = [
            "agate"
            "raspite"
            "baryte"
            "osmium"
          ];
        in
        builtins.listToAttrs (
          map (h: {
            name = h;
            value = self.nixosConfigurations.${h}.config.system.build.toplevel;
          }) includeHosts
        );
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        mkHomeConfiguration = user: host: {
          name = "${user}-${host}";
          value = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              (import ./home).${user}.${host}
              overlayModule
            ]
            ++ sharedHmModules;
          };
        };
      in
      {
        checks = {
          backup-test = pkgs.testers.nixosTest (import ./tests/backup.nix);
        };

        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              colmena.packages.${system}.colmena
              nix
              git
              sops
              nix-output-monitor
              nil
              nvd
              nh
              (python3.withPackages (ps: with ps; [ requests ]))
              sbctl
              nix-claude-code.packages.${system}.default
              # mcp-nixos
              mcps-nix.packages.${system}.mcp-language-server
              # mcps-nix.packages.${system}.mcp-servers
              nixd
            ];
          };
        };

        packages = {
          nixvim = my-nixvim.packages.${system}.default;
        };
      }
    );
}
