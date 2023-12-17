{ config, pkgs, ... }:
{
  imports = [
    ./fish.nix
    ./git.nix
    ./tmux.nix
    ./vim.nix
    ./zellij.nix
  ];
}