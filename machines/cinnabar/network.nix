{
  pkgs,
  lib,
  ...
}:
let
  eduroamCaCert = pkgs.writeText "eduroam-ca.pem" ''
    -----BEGIN CERTIFICATE-----
    MIICVDCCAdugAwIBAgIQZ3SdjXfYO2rbIvT/WeK/zjAKBggqhkjOPQQDAzBsMQsw
    CQYDVQQGEwJHUjE3MDUGA1UECgwuSGVsbGVuaWMgQWNhZGVtaWMgYW5kIFJlc2Vh
    cmNoIEluc3RpdHV0aW9ucyBDQTEkMCIGA1UEAwwbSEFSSUNBIFRMUyBFQ0MgUm9v
    dCBDQSAyMDIxMB4XDTIxMDIxOTExMDExMFoXDTQ1MDIxMzExMDEwOVowbDELMAkG
    A1UEBhMCR1IxNzA1BgNVBAoMLkhlbGxlbmljIEFjYWRlbWljIGFuZCBSZXNlYXJj
    aCBJbnN0aXR1dGlvbnMgQ0ExJDAiBgNVBAMMG0hBUklDQSBUTFMgRUNDIFJvb3Qg
    Q0EgMjAyMTB2MBAGByqGSM49AgEGBSuBBAAiA2IABDgI/rGgltJ6rK9JOtDA4MM7
    KKrxcm1lAEeIhPyaJmuqS7psBAqIXhfyVYf8MLA04jRYVxqEU+kw2anylnTDUR9Y
    STHMmE5gEYd103KUkE+bECUqqHgtvpBBWJAVcqeht6NCMEAwDwYDVR0TAQH/BAUw
    AwEB/zAdBgNVHQ4EFgQUyRtTgRL+BNUW0aq8mm+3oJUZbsowDgYDVR0PAQH/BAQD
    AgGGMAoGCCqGSM49BAMDA2cAMGQCMBHervjcToiwqfAircJRQO9gcS3ujwLEXQNw
    SaSS6sUUiHCm0w2wqsosQJz76YJumgIwK0eaB8bRwoF8yguWGEEbo/QwCZ61IygN
    nxS2PFOiTAZpffpskcYqSUXm7LcT4Tps
    -----END CERTIFICATE-----
  '';
  eduroamIwdProfile = pkgs.writeText "eduroam.8021x" ''
    [Security]
    EAP-Method=PEAP
    EAP-Identity=@aalto.fi
    EAP-PEAP-CACert=/var/lib/iwd/eduroam-ca.pem
    EAP-PEAP-ServerDomainMask=radius.org.aalto.fi
    EAP-PEAP-Phase2-Method=MSCHAPV2
    EAP-PEAP-Phase2-Identity=xinyang.li@aalto.fi

    [Settings]
    AutoConnect=true
  '';
in
{
  imports = [ ];

  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = true;
        RoamThreshold = -62;
        RoamThreshold5G = -65;
        RoamRetryInterval = 15;
        CriticalRoamThreshold = -70;
        CriticalRoamThreshold5G = -70;
      };
      Scan = {
        DisablePeriodicScan = false;
      };
      Network = {
        EnableIPv6 = true;
        NameResolvingService = "resolvconf";
      };
      Settings = {
        AutoConnect = true;
      };
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/iwd 0700 root root - -"
    "C /var/lib/iwd/eduroam-ca.pem 0600 root root - ${eduroamCaCert}"
    "C /var/lib/iwd/eduroam.8021x 0600 root root - ${eduroamIwdProfile}"
  ];
  systemd.network.networks."99-wireless-client-dhcp".enable = false;
  systemd.network.networks."10-en" = {
    matchConfig = {
      Name = "en*";
    };
    networkConfig = {
      DHCP = true;
    };
    dhcpV4Config.RouteMetric = 100;
    ipv6AcceptRAConfig.RouteMetric = 100;
    dhcpPrefixDelegationConfig.RouteMetric = 100;
  };

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 5000 ];
  # Use nftables to manager firewall
  networking.nftables.enable = true;

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  programs.kdeconnect = {
    enable = true;
  };

  networking.useNetworkd = true;
  networking.resolvconf.enable = true;
  services.resolved.enable = false;
  custom.mesh-network = {
    ipsec = {
      enable = true;
      commonName = "cinnabar";
      endpoints = [
        {
          serialNumber = "0";
          addressFamily = "ip4";
          address = null;
        }
      ];
      interfaces = [ ];
    };
    bird.enable = true;
    address = [ "fda1:6cbb:db78::5/128" ];
    gost.enable = true;
  };
}
