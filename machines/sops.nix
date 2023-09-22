{ ... }:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    # TODO: How to generate this key when bootstrap?
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      clash_subscription_link = { 
        owner = "xin";
      };
    };
  };
}