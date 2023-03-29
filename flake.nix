{
  inputs = {
    # Pin nixpkgs to a specific commit
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";

    nur.url = "github:nix-community/NUR";
    };

  outputs = { self, nixpkgs, nur }: {
    nixosConfigurations.xin-laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nur.nixosModules.nur
        machines/laptop/configuration.nix
      ];
    };
  };
}
