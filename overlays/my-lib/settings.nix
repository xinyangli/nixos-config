{
  settings = {
    alertmanagerPort = 9093;
    idpUrl = "auth.xiny.li";
    mailUrl = "mail.xiny.li";
    gotosocialUrl = "https://gts.xiny.li";
    minifluxUrl = "https://rss.xiny.li";
    hedgedocDomain = "docs.xiny.li";
    forgejoDomain = "git.xiny.li";
    forgejoGitDomain = "git.xiny.li";
    vaultwardenUrl = "https://vaultwarden.xiny.li";
    ntfyUrl = "https://ntfy.xiny.li";
    grafanaUrl = "https://grafana.xiny.li";
    synapseUrl = "https://xiny.li";
    matrixAuthUrl = "https://matrix-auth.xiny.li";
    synapseDelegateUrl = "https://synapse.xiny.li";
    rusticalUrl = "https://calendar.xiny.li";

    transmissionExporterUrl = "agate.coho-tet.ts.net:19091";
    ocisUrl = "https://drive.xiny.li:8443";

    prometheusCollectors = [
      "thorite.coho-tet.ts.net"
    ];

    internalDomain = "coho-tet.ts.net";

    garageFactor = 1;
  };
}
