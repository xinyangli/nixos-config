{ inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];
  sops = {
    defaultSopsFile = ./secrets.yaml;
    # TODO: How to generate this key when bootstrap?
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      clash_subscription_link = { 
        owner = "root";
      };
      singbox_password = {
        owner = "root";
      };
      singbox_domain = {
        owner = "root";
      };
      singbox_sg_server = {
         owner = "root";
      };
      singbox_sg_password = {
         owner = "root";
      };
      singbox_sg_uuid = {
         owner = "root";
      };
    };
  };
}
