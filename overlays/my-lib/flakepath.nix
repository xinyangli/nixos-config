{
  flakePath =
    config:
    let
      envPath = builtins.getEnv "XIN_FLAKES_FLAKEPATH";
    in
    if envPath != "" then envPath else "${config.home.homeDirectory}/repo/personal/nixos-config";
}
