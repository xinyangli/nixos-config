{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [
    (self: super: { 
      ssh-tpm-agent =
        pkgs.callPackage ./pkgs/ssh-tpm-agent.nix { };
    })
  ];
}
