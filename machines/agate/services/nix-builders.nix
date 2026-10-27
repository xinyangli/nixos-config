{ config, ... }:
let
  builderToken = config.sops.secrets."hydra/builder_token".path;
in
{
  sops.secrets."hydra/builder_token" = {
    owner = "hydra-queue-runner";
    group = "hydra";
    mode = "0440";
  };

  services.hydra.queueRunner = {
    grpc.address = "[fda1:6cbb:db78::7]";
    settings = {
      machineFreeFn = "DynamicWithMaxJobLimit";
      tokenPaths = [ builderToken ];
    };
  };

  networking.firewall.allowedTCPPorts = [ config.services.hydra.queueRunner.grpc.port ];

  # Agate builds locally; hafnon connects to the mesh listener above.
  services.hydra-builder = {
    enable = true;
    queueRunnerAddr = "http://${config.services.hydra.queueRunner.grpc.address}:${toString config.services.hydra.queueRunner.grpc.port}";
    authorizationFile = builderToken;
    settings = {
      maxJobs = 16;
      systems = [ "aarch64-linux" ];
      supportedFeatures = [
        "kvm"
        "nixos-test"
        "big-parallel"
        "benchmark"
      ];
    };
  };

  systemd.services.hydra-builder.after = [ "hydra-queue-runner.service" ];
}
