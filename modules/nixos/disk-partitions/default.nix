{ lib, ... }:
{
  options = {
    diskPartitions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };
  config = {
    diskPartitions = {
      btrfs = import ./btrfs.nix;
      grubMbr = import ./grub-mbr.nix;
    };
  };
}
