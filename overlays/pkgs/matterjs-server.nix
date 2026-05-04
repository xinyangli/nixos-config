{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
  pkg-config,
  python3,
  udev,
}:

buildNpmPackage rec {
  pname = "matterjs-server";
  version = "0.6.5-alpha.0-20260502-c981ea0";

  src = fetchFromGitHub {
    owner = "matter-js";
    repo = "matterjs-server";
    rev = "852d029dee370981ee22859c40d1873021028932";
    hash = "sha256-QBfP5lQ/VTMJEwitAbB7Nl+EzNiMdj7cAVYtTuosHL4=";
  };

  nodejs = nodejs_22;

  npmDepsHash = "sha256-Qveo8b92Y5y2AZR8wCiFbCCRyydandnRJghrHoWt464=";

  # python3 + pkg-config + udev are needed to compile the optional `usb` native
  # module (pulled in by @stoprocent/bluetooth-hci-socket for BLE provisioning).
  nativeBuildInputs = [
    makeWrapper
    pkg-config
    python3
  ];
  buildInputs = [ udev ];

  # Patch a vendored dep inside node_modules. node_modules only exists after
  # npmConfigHook runs `npm ci`, so this can't go in postPatch — has to wait
  # until configurePhase is done.
  postConfigure = ''
    patch -p1 < ${./matterjs-broadcast-recv.patch}
  '';

  # Build pipeline (from package.json `build` script) needs two passes
  # because the workspace `generate` step depends on outputs of the first
  # `nacho-build` pass, and `bundle` needs the second one.
  npmBuildScript = "build";

  # buildNpmPackage's default installPhase calls `npm pack` which doesn't
  # cope with workspaces. Lay out everything we need under
  # $out/lib/matterjs-server and provide a wrapper.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/matterjs-server
    cp -r packages node_modules package.json package-lock.json \
      $out/lib/matterjs-server/

    makeWrapper ${lib.getExe nodejs_22} $out/bin/matterjs-server \
      --add-flags "--enable-source-maps" \
      --add-flags "$out/lib/matterjs-server/packages/matter-server/dist/esm/MatterServer.js"

    runHook postInstall
  '';

  meta = {
    description = "Open Home Foundation Matter Server based on matter.js";
    homepage = "https://github.com/matter-js/matterjs-server";
    license = lib.licenses.asl20;
    mainProgram = "matterjs-server";
    platforms = lib.platforms.linux;
  };
}
