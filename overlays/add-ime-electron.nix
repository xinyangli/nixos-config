{
  config,
  pkgs,
  lib,
  ...
}:

{
  nixpkgs.overlays = [
    (self: super: {
      element-desktop = super.element-desktop.override { commandLineArgs = "--enable-wayland-ime"; };
    })
  ];
}
