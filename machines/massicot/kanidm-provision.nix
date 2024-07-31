{
  enable = true;
  autoRemove = true;
  groups = {
    forgejo-access = {
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
      members = [ "xin" "zhuo" ];
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
  };
  systems.oauth2 = {
    forgejo = {
      displayName = "ForgeJo";
      originUrl = "https://git.xinyang.life/";
      originLanding = "	https://git.xinyang.life/user/oauth2/kandim";
      allowInsecureClientDisablePkce = true;
      scopeMaps = {
        forgejo-access = [ "openid" "email" "profile" "groups" ];
      };
    };
    gts = {
      displayName = "GoToSocial";
      originUrl = "https://xinyang.life/";
      allowInsecureClientDisablePkce = true;
      scopeMaps = {
        gts-users = [ "openid" "email" "profile" "groups" ];
      };
    };
    owncloud = {
      displayName = "ownCloud";
      originUrl = "https://home.xinyang.life:9201/";
      public = true;
      scopeMaps = {
        ocis-users = [ "openid" "email" "profile" ];
      };
    };
    hedgedoc = {
      displayName = "HedgeDoc";
      originUrl = "https://docs.xinyang.life/";
      originLanding = "https://docs.xinyang.life/auth/oauth2";
      allowInsecureClientDisablePkce = true;
      scopeMaps = {
        hedgedoc-users = [ "openid" "email" "profile" ];
      };
    };
    immich-mobile = {
      displayName = "Immich";
      originUrl = "https://immich.xinyang.life:8000/api/oauth/mobile-redirect/";
      allowInsecureClientDisablePkce = true;
      scopeMaps = {
        immich-users = [ "openid" "email" "profile" ];
      };
    };
  };
}