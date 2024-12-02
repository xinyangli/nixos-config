{ config, lib, ... }:
{
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
          "yzl"
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

      yzl = {
        displayName = "Zhengli Yang";
        mailAddresses = [ "13391935399@189.cn" ];
      };
    };
    systems.oauth2 = {
      forgejo = {
        displayName = "ForgeJo";
        originUrl = "https://git.xinyang.life/user/oauth2/kanidm/callback";
        originLanding = "https://git.xinyang.life/user/oauth2/kanidm";
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
        originUrl = "https://xinyang.life/auth/callback";
        originLanding = "https://xinyang.life/auth/callback";
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
      gotosocial = {
        displayName = "GoToSocial";
        originUrl = "https://gts.xiny.li/auth/callback";
        originLanding = "https://gts.xiny.li/auth/callback";
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
      # It's used for all the clients. I'm too lazy to change the name.
      owncloud-android = {
        displayName = "ownCloud Apps";
        originLanding = "https://drive.xinyang.life:8443/";
        originUrl = [
          "http://localhost:38622/"
          "http://localhost:43580/"
          "https://drive.xinyang.life:8443/"
          # TODO: Should allow mobile redirect url not ending with /
          # "oc://android.owncloud.com"
        ];
        public = true;
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
        originUrl = "https://docs.xinyang.life/auth/oauth2/callback";
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
          "https://immich.xinyang.life:8000/auth/login"
          "https://immich.xinyang.life:8000/user-settings"
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
        originUrl = "https://rss.xinyang.life/oauth2/oidc/callback";

        originLanding = "https://rss.xinyang.life/oauth2/oidc/redirect";
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
        originUrl = "https://grafana.xinyang.life/login/generic_oauth";
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
