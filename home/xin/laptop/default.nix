
{
  home.username = "xin";
  home.homeDirectory = "/home/xin";

  accounts = {
    gmail = {

    };

  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}