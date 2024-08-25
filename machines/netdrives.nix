{ pkgs, config, ... }:
{
  sops.secrets = {
    autofs-nas = {
      owner = "davfs2";
    };
    autofs-nas-secret = {
      path = "/etc/davfs2/secrets";
    };
  };
  fileSystems."/media/nas" = {
    device = "https://home.xinyang.life:5244/dav";
    fsType = "davfs";
    options = [
      "uid=1000"
      "gid=1000"
      "rw"
      "_netdev"
    ];

  };
}
