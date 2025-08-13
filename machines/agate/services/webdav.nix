{ config, ... }:
{

  sops.secrets = {
    "webdav/photosync/password" = { };
  };

  sops.templates."webdav.env" = {
    content = ''
      PHOTOSYNC_PASSWORD=${config.sops.placeholder."webdav/photosync/password"}
    '';
  };

  services.webdav = {
    enable = true;
    settings = {
      address = "127.0.0.1";
      port = "16065";
      permissions = "CRUD";
      behindProxy = true;
      users = [
        {
          username = "photosync";
          password = "{env}PHOTOSYNC_PASSWORD";
        }
      ];
    };
    group = "privimg";
    environmentFile = config.sops.templates."webdav.env".path;
  };

  systemd.services.webdav.serviceConfig = {
    BindPaths = [
      "/storage/pictures/xin/originals:%t/webdav/photosync"
    ];
    RuntimeDirectory = "webdav";
    WorkingDirectory = "%t/webdav";
  };

  users.users."${config.services.webdav.user}".extraGroups = [
    "privimg"
  ];

  services.caddy.virtualHosts."https://agate.coho-tet.ts.net:6065".extraConfig = ''
    reverse_proxy ${config.services.webdav.settings.address}:${config.services.webdav.settings.port}
  '';
}
