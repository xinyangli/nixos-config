# Cutting edge practices in NixOS that is great but not yet default
# The newer, the better!

{
  config = {
    services.dbus.implementation = "broker";
  };
}
