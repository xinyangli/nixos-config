{
  lib,
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule rec {
  pname = "transmission-exporter";
  version = "0-unstable-2024-10-09";
  rev = "v${version}";

  src = fetchFromGitHub {
    rev = "a7872aa2975c7a95af680c51198f4a363e226c8f";
    owner = "metalmatze";
    repo = "transmission-exporter";
    sha256 = "sha256-Ky7eCvC1AqHheqGGOGBNKbtVgg4Y8hDG67gCVlpUwZo=";
  };

  vendorHash = "sha256-YhmfrM5iAK0zWcUM7LmbgFnH+k2M/tE+f/QQIQmQlZs=";

  ldflags = [
    "-X github.com/prometheus/common/version.Version=${version}"
    "-X github.com/prometheus/common/version.Revision=${rev}"
  ];

  meta = {
    description = "Prometheus exporter for Transmission torrent client.";
    homepage = "https://github.com/pborzenkov/transmission-exporter";
    mainProgram = "transmission-exporter";
    license = [ lib.licenses.mit ];
    maintainers = [ lib.maintainers.xinyangli ];
  };
}
