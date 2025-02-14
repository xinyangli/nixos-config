{
  settings = {
    alertmanagerPort = 9093;
    idpUrl = "auth.xiny.li";
    gotosocialUrl = "https://gts.xiny.li";
    minifluxUrl = "https://rss.xiny.li";
    hedgedocDomain = "docs.xiny.li";
    forgejoDomain = "git.xiny.li";
    forgejoGitDomain = "git.xiny.li";
    vaultwardenUrl = "https://vaultwarden.xiny.li";
    ntfyUrl = "https://ntfy.xiny.li";
    grafanaUrl = "https://grafana.xiny.li";
    synapseUrl = "https://xiny.li";
    synapseDelegateUrl = "https://synapse.xiny.li";

    transmissionExporterUrl = "weilite.coho-tet.ts.net:19091";

    prometheusCollectors = [
      "thorite.coho-tet.ts.net"
    ];

    internalDomain = "coho-tet.ts.net";
  };
}
