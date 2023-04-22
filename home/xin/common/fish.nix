{ pkgs, ... }: {
  programs.fish = {
    enable = true;
    plugins = with pkgs; [
      {
        name = "pisces";
        src = fishPlugins.pisces.src;
      }
      {
        name = "done";
        src = fishPlugins.done.src;
      }
      {
        name = "hydro";
        src = fishPlugins.hydro.src;
      }
    ];
  };
}
