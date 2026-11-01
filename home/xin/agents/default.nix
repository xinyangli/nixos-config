{ pkgs, ... }:
{
  custom-hm.omp = {
    enable = true;
    extensions = [ "herdr" ];
  };

  home.packages = with pkgs.llm-agents; [
    rtk
    tuicr
  ];
}
