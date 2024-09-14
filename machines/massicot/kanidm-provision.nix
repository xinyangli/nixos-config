{ config, lib, ... }:
{
  sops.secrets = {
    "kanidm/ocis_android_secret" = {
      owner = "kanidm";
    };
  };
  systemd.services.kanidm.serviceConfig = {
    BindReadOnlyPaths = [
      config.sops.secrets."kanidm/ocis_android_secret".path
    ];
  };
  services.kanidm.provision = {
    enable = true;
    autoRemove = true;
    groups = {
      forgejo-access = {
        members = [ "xin" ];
      };
      forgejo-admin = {
        members = [ "xin" ];
      };
      gts-users = {
        members = [ "xin" ];
      };
      ocis-users = {
        members = [ "xin" ];
      };
      linux_users = {
        members = [ "xin" ];
      };
      hedgedoc-users = {
        members = [ "xin" ];
      };
      immich-users = {
        members = [
          "xin"
          "zhuo"
          "ycm"
        ];
      };
      grafana-superadmins = {
        members = [ "xin" ];
      };
      grafana-admins = {
        members = [ "xin" ];
      };
      grafana-editors = {
        members = [ "xin" ];
      };
      grafana-users = {
        members = [ "xin" ];
      };
      miniflux-users = {
        members = [ "xin" ];
      };
      idm_people_self_mail_write = {
        members = [ ];
      };
    };
    persons = {
      xin = {
        displayName = "Xinyang Li";
        mailAddresses = [ "lixinyang411@gmail.com" ];
      };

      zhuo = {
        displayName = "Zhuo";
        mailAddresses = [ "13681104320@163.com" ];
      };

      ycm = {
        displayName = "Chunming";
        mailAddresses = [ "chunmingyou@gmail.com" ];
      };
    };
    systems.oauth2 = {
      forgejo = {
        displayName = "ForgeJo";
        originUrl = "https://git.xinyang.life/";
        originLanding = "https://git.xinyang.life/user/oauth2/kandim";
        allowInsecureClientDisablePkce = true;
        scopeMaps = {
          forgejo-access = [
            "openid"
            "email"
            "profile"
            "groups"
          ];
        };
        claimMaps = {
          forgejo_role = {
            joinType = "array";
            valuesByGroup = {
              forgejo-access = [ "Access" ];
              forgejo-admin = [ "Admin" ];
            };
          };
        };
      };
      gts = {
        displayName = "GoToSocial";
        originUrl = "https://xinyang.life/";
        originLanding = "https://xinyang.life/";
        allowInsecureClientDisablePkce = true;
        scopeMaps = {
          gts-users = [
            "openid"
            "email"
            "profile"
            "groups"
          ];
        };
      };
      owncloud = {
        displayName = "ownCloud";
        originUrl = "https://drive.xinyang.life:8443/";
        originLanding = "https://drive.xinyang.life:8443/";
        public = true;
        preferShortUsername = true;
        scopeMaps = {
          ocis-users = [
            "openid"
            "email"
            "profile"
          ];
        };
      };

      owncloud-android = {
        displayName = "ownCloud Apps";
        originLanding = "https://drive.xinyang.life:8443/";
        originUrl = [
          "http://localhost/"
          "http://127.0.0.1/"
          "oc://android.owncloud.com"
        ];
        basicSecretFile = config.sops.secrets."kanidm/ocis_android_secret".path;
        preferShortUsername = true;
        scopeMaps = {
          ocis-users = [
            "openid"
            "email"
            "profile"
            "offline_access"
          ];
        };
      };

      hedgedoc = {
        displayName = "HedgeDoc";
        originUrl = "https://docs.xinyang.life/";
        originLanding = "https://docs.xinyang.life/auth/oauth2";
        allowInsecureClientDisablePkce = true;
        scopeMaps = {
          hedgedoc-users = [
            "openid"
            "email"
            "profile"
          ];
        };
      };
      immich = {
        displayName = "Immich";
        originUrl = [
          "https://immich.xinyang.life:8000/api/oauth/mobile-redirect/"
          "https://immich.xinyang.life:8000/auth/login/"
          "https://immich.xinyang.life:8000/user-settings/"
        ];
        originLanding = "https://immich.xinyang.life:8000/auth/login?autoLaunch=0";
        allowInsecureClientDisablePkce = true;
        scopeMaps = {
          immich-users = [
            "openid"
            "email"
            "profile"
          ];
        };
      };
      miniflux = {
        displayName = "Miniflux";
        originUrl = "https://rss.xinyang.life/";
        originLanding = "https://rss.xinyang.life/";
        scopeMaps = {
          miniflux-users = [
            "openid"
            "email"
            "profile"
          ];
        };
      };
      grafana = {
        displayName = "Grafana";
        originUrl = "https://grafana.xinyang.life/";
        originLanding = "https://grafana.xinyang.life/";
        scopeMaps = {
          grafana-users = [
            "openid"
            "email"
            "profile"
            "groups"
          ];
        };
        claimMaps = {
          grafana_role = {
            joinType = "array";
            valuesByGroup = {
              grafana-superadmins = [ "GrafanaAdmin" ];
              grafana-admins = [ "Admin" ];
              grafana-editors = [ "Editor" ];
            };
          };
        };
      };
    };
  };
}
