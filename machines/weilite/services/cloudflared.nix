{ pkgs, ... }:
{
  services.cloudflared = {
    enable = true;
    tunnels =
      {
      };
  };
}
