{ devboxSpecialArgs, ... }:
{
  microvm.stateDir = "/storage/microvms";
  microvm.autostart = [ "devbox" ];
  microvm.vms.devbox = {
    specialArgs = devboxSpecialArgs;
    config.imports = [ ./guest.nix ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/microvms 0775 microvm kvm - -"
    "d /var/lib/microvms/devbox 0775 microvm kvm - -"
  ];
}
