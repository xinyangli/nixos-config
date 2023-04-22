{
  programs.git = {
    enable = true;
    delta.enable = true;
    userName = "Xinyang Li";
    userEmail = "lixinyang411@gmail.com";
    aliases = {
      graph = "log --all --oneline --graph --decorate";
      s = "status";
      d = "diff";
    };
  };
}