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
    };
  };
}
