{
  lib,
  stdenvNoCC,
  python3,
  fetchFromGitHub,
  fetchPypi,
  makeWrapper,
}:
let
  # Not in nixpkgs (and unrelated to the similarly-named `click-configfile`).
  # hcpy uses it for the `--config` option on hc2mqtt / hc-login.
  click-config-file = python3.pkgs.buildPythonPackage rec {
    pname = "click-config-file";
    version = "0.6.0";
    format = "wheel";
    src = fetchPypi {
      pname = "click_config_file";
      inherit version format;
      python = "py2.py3";
      dist = "py2.py3";
      hash = "sha256-PFgC3sQ37VlvGB78mI9isQac1IqRLigM2EDucFgPOdc=";
    };
    propagatedBuildInputs = with python3.pkgs; [
      click
      configobj
    ];
    doCheck = false;
  };
  pythonEnv = python3.withPackages (
    ps: with ps; [
      beautifulsoup4
      requests
      pycryptodome
      websocket-client
      paho-mqtt
      lxml
      click
      click-config-file
      pyyaml
    ]
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hcpy";
  version = "0.4.11";

  src = fetchFromGitHub {
    owner = "hcpy2-0";
    repo = "hcpy";
    tag = "v${finalAttrs.version}";
    hash = "sha256-HxH0ucYxEDHlr3Cdcbt8WzdW8sPKse0392ktZUZ0cbU=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d $out/share/hcpy
    install -m0644 *.py $out/share/hcpy/
    cp -r config $out/share/hcpy/config

    for script in hc2mqtt hc-login; do
      makeWrapper ${pythonEnv.interpreter} $out/bin/$script \
        --add-flags "$out/share/hcpy/$script.py"
    done

    runHook postInstall
  '';

  meta = {
    description = "Bridge Bosch-Siemens Home Connect appliances to MQTT over local TLS-PSK";
    homepage = "https://github.com/hcpy2-0/hcpy";
    license = lib.licenses.mit;
    mainProgram = "hc2mqtt";
    platforms = lib.platforms.linux;
  };
})
