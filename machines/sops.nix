{
  config,
  lib,
  ...
}:
{
  config = {
    sops = {
      defaultSopsFile = ./secrets.yaml;
      # TODO: How to generate this key when bootstrap?
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = {
        github_public_token = {
          owner = "root";
        };
        singbox_sg_server = {
          owner = "root";
        };
        singbox_jp_server = {
          owner = "root";
        };
        private_dns_address = {
          owner = "root";
        };
      };
      secrets.grafana_cloud_api = lib.mkIf config.services.prometheus.enable { owner = "prometheus"; };
    };
  };
}
