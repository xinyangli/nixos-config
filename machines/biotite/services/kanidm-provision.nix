{ pkgs, config, ... }:
let
  inherit (config.my-lib.settings)
    gotosocialUrl
    minifluxUrl
    hedgedocDomain
    forgejoDomain
    grafanaUrl
    synapseDelegateUrl
    matrixAuthUrl
    ocisUrl
    rusticalUrl
    jellyfinUrl
    ;

  # The kanidm-provision NixOS module has no options for service accounts or
  # POSIX/SSH attributes (those fields come from our local patches against
  # the kanidm-provision binary). Inject them through extraJsonFile so the
  # provisioner sees a complete state file.
  extraJson = pkgs.writeText "kanidm-provision-extras.json" (
    builtins.toJSON {
      groups.nix-builders = {
        members = [ "nix_access_hydra" ];
        enableUnix = true;
      };
      # entry_managed_by delegation: nix_provisioner manages nix_access_hydra
      # via group membership. The agate keygen one-shot uses a `--rw` token
      # for nix_provisioner (NOT for nix_access_hydra) so the manager-ACP
      # path grants ssh_publickey writes. A token tied to nix_access_hydra
      # itself can't self-write its SSH keys.
      groups.nix_access_hydra_admins.members = [ "nix_provisioner" ];
      serviceAccounts.nix_provisioner = {
        displayName = "Provisioner for nix_access_hydra (agate pubkey rotation)";
        entryManagedBy = "xin";
      };
      serviceAccounts.nix_access_hydra = {
        displayName = "Nix remote-build access (Hydra)";
        entryManagedBy = "nix_access_hydra_admins";
        enableUnix = true;
        # bash (not nologin) so sshd will run `nix-daemon --stdio` over the
        # SSH session for ssh-ng remote builds. nologin would have sshd
        # refuse command execution entirely.
        loginShell = "/run/current-system/sw/bin/bash";
      };
      persons.xin.sshPublicKeys = [
        {
          tag = "canary";
          key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJbh0FCYKW+U48IKO0brePOzaUEkMU5L+/KOdotEFdm+AAAABHNzaDo=";
        }
        {
          tag = "pigeon";
          key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOJ9m1KLt14L2rDj3Fy+I5d0HORcGdh1sgQen4Z8TC8HAAAABHNzaDo=";
        }
        {
          tag = "sapphire-termius";
          key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNDfLOyV08kYrxqVYFIu9qmxWNkVHXEBF0PpBumjgM4hkKOTCWCQ3wC4rsv+UYGlmxZYh29kH57TFcUGdPYGIXs=";
        }
      ];
    }
  );
in
{
  sops.secrets = {
    "kanidm/ocis_android_client_secret" = {
      owner = config.systemd.services.kanidm.serviceConfig.User;
    };
  };

  services.kanidm.provision = {
    enable = true;
    autoRemove = true;
    extraJsonFile = extraJson;
    groups = {
      # Unix Groups
      unix_admin = {
        members = [ "xin" ];
      };

      # Posix group whose members receive remote-build privileges on the
      # hafnon builder. POSIX-enabled + member list live in extraJson because
      # the NixOS module has no options for them.
      nix-builders = { };

      # Non-Unix Groups
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
      immich-admin = {
        members = [
          "xin"
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
      synapse-users = {
        members = [ "xin" ];
      };
      rustical-users = {
        members = [ "xin" ];
      };
      jellyfin-admins = {
        members = [ "xin" ];
      };
      jellyfin-users = {
        members = [ "xin" ];
      };
      idm_people_self_mail_write = {
        members = [ ];
      };
    };
    persons = {
      xin = {
        displayName = "Xinyang Li";
        mailAddresses = [
          "lixinyang411@gmail.com"
          "me@xiny.li"
          "xin@xiny.li"
        ];
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
        originUrl = "https://${forgejoDomain}/user/oauth2/kanidm/callback";
        originLanding = "https://${forgejoDomain}/user/oauth2/kanidm";
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
      gotosocial = {
        displayName = "GoToSocial";
        originUrl = "${gotosocialUrl}/auth/callback";
        originLanding = "${gotosocialUrl}/auth/callback";
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
        displayName = "ownCloud Apps";
        originLanding = ocisUrl;
        originUrl = [
          "${ocisUrl}/oidc-callback.html"
          "http://127.0.0.1:15241/"
          "oc://android.owncloud.com"
          # TODO: Should allow mobile redirect url not ending with /
        ];
        public = true;
        enableLocalhostRedirects = true;
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

      owncloud-android = {
        displayName = "ownCloud Apps";
        originLanding = ocisUrl;
        originUrl = [
          "oc://android.owncloud.com"
        ];
        basicSecretFile = config.sops.secrets."kanidm/ocis_android_client_secret".path;
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
        originUrl = "https://${hedgedocDomain}/auth/oauth2/callback";
        originLanding = "https://${hedgedocDomain}/auth/oauth2";
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
          "https://immich.xiny.li:8443/api/oauth/mobile-redirect/"
          "https://immich.xiny.li:8443/auth/login"
          "https://immich.xiny.li:8443/user-settings"
        ];
        originLanding = "https://immich.xiny.li:8443/auth/login?autoLaunch=0";
        scopeMaps = {
          immich-users = [
            "openid"
            "email"
            "profile"
          ];
        };
        claimMaps = {
          immich_role = {
            joinType = "array";
            valuesByGroup = {
              immich-users = [ "user" ];
              immich-admin = [ "admin" ];
            };
          };
        };
      };
      miniflux = {
        displayName = "Miniflux";
        originUrl = "${minifluxUrl}/oauth2/oidc/callback";
        originLanding = "${minifluxUrl}/oauth2/oidc/redirect";
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
        originUrl = "${grafanaUrl}/login/generic_oauth";
        originLanding = "${grafanaUrl}/";
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
      synapse = {
        displayName = "Synapse";
        originUrl = "${matrixAuthUrl}/upstream/callback/01K83K1FPGYD79ENWVY0RTWHTB";
        originLanding = "${synapseDelegateUrl}/";
        enableLegacyCrypto = true;
        scopeMaps = {
          synapse-users = [
            "openid"
            "email"
            "profile"
          ];
        };
      };
      rustical = {
        displayName = "Rustical";
        originUrl = "${rusticalUrl}/frontend/login/oidc/callback";
        originLanding = "${rusticalUrl}/";
        scopeMaps = {
          rustical-users = [
            "openid"
            "profile"
            "groups"
          ];
        };
      };
      jellyfin = {
        displayName = "Jellyfin";
        originUrl = "${jellyfinUrl}/frontend/login/oidc/callback";
        originLanding = "${jellyfinUrl}/sso/OID/redirect/kanidm";
        scopeMaps = {
          jellyfin-users = [
            "openid"
            "profile"
            "groups"
          ];
        };
        claimMaps = {
          jellyfin_role = {
            joinType = "array";
            valuesByGroup = {
              jellyfin-admins = [ "Admin" ];
              jellyfin-users = [ "User" ];
            };
          };
        };
      };
    };
  };
}
