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

    nixos-cn = {
      url = "github:nixos-cn/flakes";
      # Use the same nixpkgs
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
  };


  outputs = { self, nixpkgs, nur, home-manager, sops-nix, nixos-cn, ... }@inputs:
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
    };
}
