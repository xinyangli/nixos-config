{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [
    (self: super: { 
      oidc-agent = pkgs.callPackage ./pkgs/oidc-agent { };
      python3 = super.python312;
    })
  ];
}
