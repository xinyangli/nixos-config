{
  buildPythonPackage,
  fetchurl,
  setuptools,
  setuptools-scm,
  wheel,
  requests,
  verlib2,
}:

# 3.x (requests-based) instead of 5.x: niquests pulls in urllib3-future,
# which has no binary cache on the pinned nixpkgs fork and builds for
# a very long time. All APIs this repo uses exist in 3.x.
buildPythonPackage {
  pname = "grafana-client";
  version = "3.11.0";
  pyproject = true;

  build-system = [
    setuptools
    setuptools-scm
    wheel
  ];

  # fetchPypi builds a dashed sdist filename; the real file uses an
  # underscore, so pin the files.pythonhosted.org URL directly.
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/c2/fd/ff491f3b9c82933632491323b7bfbdb10da1c1aec87115ca4b82c238f101/grafana-client-3.11.0.tar.gz";
    hash = "sha256-f4m5LrY6M3lA2vsUjXCv3ESS/YJli1Kd3w+Vln4U01k=";
  };

  # setuptools 83 validates build-system.requires at build time; the sdist
  # pins setuptools_scm<9 while nixpkgs ships 10.x, so drop the caps.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"pip>=20.0",' "" \
      --replace-fail '"setuptools_scm[toml]>=4.0,<8"' '"setuptools_scm[toml]>=4.0"'
    substituteInPlace setup.cfg \
      --replace-fail 'setuptools-scm<9' 'setuptools-scm'
  '';

  propagatedBuildInputs = [
    requests
    verlib2
  ];

  # The wheel pins verlib2==0.2.0; nixpkgs ships 26.x, which is API-compatible.
  pythonRelaxDeps = [ "verlib2" ];

  doCheck = false;
}
