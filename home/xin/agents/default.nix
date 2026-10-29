{ pkgs, ... }:
{
  config = {
    nixpkgs.config.allowUnfree = true;
    home.packages = with pkgs.llm-agents; [
      omp
      rtk
      tuicr
    ];
  };
}
