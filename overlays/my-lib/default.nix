{
  mkSystemdDebug =
    { lib, pkgs }:
    {
      ExecStart = lib.mkForce "${pkgs.tmux}/bin/tmux -S /tmp/tmux.socket new-session -s my-session -d";
      ExecStop = lib.mkForce "${pkgs.tmux}/bin/tmux -S /tmp/tmux.socket kill-session -t my-session";
      Type = "forking";
    };
}
// (import ./prometheus.nix)
// (import ./settings.nix)
