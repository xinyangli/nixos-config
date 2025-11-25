{
  stdenv,
  lib,
  fetchFromGitHub,
  nautilus-python,
  python3,
  cmake,
  owncloud-shell-resources,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "owncloud-nautilus";
  version = "6.0.0";

  src = fetchFromGitHub {
    owner = "owncloud";
    repo = "client-desktop-shell-integration-nautilus";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-GaURNFhAAYXwiDTTQT2u2hKPAv2QzvIq7p+N4j9cBr4=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    nautilus-python
    python3.pkgs.pygobject3
    owncloud-shell-resources
  ];

  meta = with lib; {
    description = "Nautilus extension for ownCloud desktop client";
    homepage = "https://github.com/owncloud/client-desktop-shell-integration-nautilus";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ xinyangli ];
  };
})
