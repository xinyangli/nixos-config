{
  stdenv,
  lib,
  fetchFromGitHub,
  cmake,
  kdePackages,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "owncloud-shell-resources";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owncloud";
    repo = "client-desktop-shell-integration-resources";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-BfVrq1hBKJes7pWMdRYM22o66SpoOKgbRi2Z3j1kYSQ=";
  };

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
  ];

  meta = with lib; {
    description = "Resources for ownCloud desktop shell integration";
    homepage = "https://github.com/owncloud/client-desktop-shell-integration-resources";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ xinyangli ];
  };
})
