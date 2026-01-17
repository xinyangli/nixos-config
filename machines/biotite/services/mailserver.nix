{ config, ... }:
let
  inherit (config.my-lib.settings) mailUrl;
in
{

  security.acme = {
    acceptTerms = true;
    certs.${mailUrl} = {
      email = "lixinyang411@gmail.com";
      listenHTTP = "127.0.0.1:1360";
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts."http://${mailUrl}".extraConfig = ''
      reverse_proxy ${config.security.acme.certs.${mailUrl}.listenHTTP}
    '';
  };

  mailserver = {
    enable = true;
    stateVersion = 3;
    fqdn = mailUrl;
    domains = [ "xiny.li" ];

    x509.useACMEHost = config.mailserver.fqdn;

    loginAccounts = {
      "xin@xiny.li" = {
        hashedPassword = "$y$j9T$/wzIqvSyeWXynQ9wWro2L0$A16VahPnXbXC.pNR9cQPn52r3T4vsQM.UmXn2nD9dWD";
        aliases = [ "me@xiny.li" ];
      };
      "notify@xiny.li" = {
        hashedPassword = "$y$j9T$pNp.6ennlf4rmgd61FC/Q.$Xy1WZOy4OYzUxT3yNyYCVIn6ENFIz3If/.GjUnXMBs0";
      };
      "forgejo-notify@xiny.li" = {
        hashedPassword = "$y$j9T$8myJrmpVLqxQiWDN2zoRJ/$.g8a4TXwp07Jw1irWqq7ggBkTfyAuebfOQ6L8ZzXgD6";
      };
    };
    extraVirtualAliases = {
      "abuse@xiny.li" = "xin@xiny.li";
      "postmaster@xiny.li" = "xin@xiny.li";
    };
  };
}
