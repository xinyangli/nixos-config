{ lib
, stdenv
, fetchFromGitHub
, curl
, webkitgtk
, libmicrohttpd
, libsecret
, qrencode
, libsodium
, pkg-config
, help2man
}:

stdenv.mkDerivation rec {
  pname = "oidc-agent";
  version = "5.1.0";

  src = fetchFromGitHub {
    owner = "indigo-dc";
    repo = "oidc-agent";
    rev = "v${version}";
    sha256 = "sha256-cOK/rZ/jnyALLuhDM3+qvwwe4Fjkv8diQBkw7NfVo0c="
    ;
  };

  buildInputs = [
    pkg-config
    help2man
  ];
  nativeBuildInputs = [
    curl
    webkitgtk
    libmicrohttpd
    libsecret
    qrencode
    libsodium
  ];
  enableParallelBuilding = true;

  installPhase = ''
    make -j $NIX_BUILD_CORES PREFIX=$out BIN_PATH=$out LIB_PATH=$out/lib \
         install_bin install_lib install_conf
  '';
  postFixup = ''
    # Override with patched binary to be used by help2man
    cp -r $out/bin/* bin
    make install_man PREFIX=$out
  '';


  meta = with lib; {
    description = "oidc-agent for managing OpenID Connect tokens on the command line";
    homepage = "https://github.com/indigo-dc/oidc-agent";
    maintainers = [ ];
    license = licenses.mit;
  };
}

