{
  inputs = {
    # Pin nixpkgs to a specific commit
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.11";

    nur.url = "github:nix-community/NUR";
    nur-xddxdd = {
      url = "github:xddxdd/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    nixos-cn = {
      url = "github:nixos-cn/flakes";
      # Use the same nixpkgs
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
  };


  outputs = { self, nixpkgs, nur, nixos-cn, ...}@attrs: {
    nixosConfigurations.xin-laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [
        nur.nixosModules.nur
        machines/laptop/configuration.nix
      ];
    };
  };
}
