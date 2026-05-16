{
  custom.mesh-network = {
    organization = "xinyangli";

    # Every host on the mesh shows up here. Adding a host = (a) append it,
    # (b) add the host's age recipient to .sops.yaml's
    # `modules/nixos/mesh/secrets.yaml` rule, (c) `sops updatekeys`.
    nodes = {
      fra-00 = {
        commonName = "fra-00";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = "185.217.108.59";
          }
        ];
      };
      la-00 = {
        commonName = "la-00";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = "67.230.168.47";
          }
        ];
      };
      thorite = {
        commonName = "thorite";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = "23.165.200.99";
          }
        ];
      };
      biotite = {
        commonName = "biotite";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = "45.142.178.32";
          }
        ];
      };
      cinnabar = {
        commonName = "cinnabar";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = null;
          }
        ];
      };
      hafnon = {
        commonName = "hafnon";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = "homo.j8.network";
          }
          {
            serialNumber = "1";
            addressFamily = "ip4";
            address = "homo-3p.j8.network";
          }
        ];
      };
    };
  };
}
