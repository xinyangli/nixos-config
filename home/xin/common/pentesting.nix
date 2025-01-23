{ pkgs, ... }:
{
  home.packages = with pkgs; [
    burpsuite
  ];
}
