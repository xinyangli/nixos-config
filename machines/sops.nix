{ ... }:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    # age.keyFile = "/var/lib/sops-nix/keys.txt";
    # age.generateKey = true;
  };
}