{
  lib,
  ...
}:
{
  imports = [
    ./pantheon.nix
  ];
  options.custom-hm.gui.polkit = lib.mkOption {
    type = lib.types.enum [
      ""
      "pantheon"
    ];
    default = "";
    description = ''
      The policy kit agent to use for authentication.
      This is the GUI that pops up when you need to enter a password for
      administrative tasks.
    '';
  };
}
