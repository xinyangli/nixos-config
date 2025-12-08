{
  lib,
  stdenvNoCC,
  fetchzip,
  nerd-font-patcher,
  unzip,
  parallel,
}:

stdenvNoCC.mkDerivation {
  pname = "nerd-fonts-misans";
  version = "0-unstable-2025-08-05";

  nativeBuildInputs = [
    nerd-font-patcher
    unzip
    parallel
  ];

  src = fetchzip {
    url = "https://web.archive.org/web/20231112185845/https://hyperos.mi.com/font-download/MiSans_Global_ALL.zip";
    stripRoot = false;
    hash = "sha256-NtOv7YO7B2uhJUGXnal9UK1TBBqIOrAtTUX+lmyyEwU=";
  };

  postUnpack = ''
    find "$sourceRoot/MiSans Global _ALL/" -name "*.zip" -exec unzip "{}" -d $sourceRoot/ \;
  '';

  # only extract the variable font because everything else is a duplicate
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/opentype/{misans,misans-nerd}
    mkdir -p $out/share/fonts/truetype/{misans,misans-nerd}

    find . -not -path '*/[@.]*' -name "*.otf" -exec install -Dm644 "{}" -t $out/share/fonts/opentype/misans/ \;
    find . -not -path '*/[@.]*' -name "*.ttf" -name "MiSans-*.ttf" -print0 | parallel -0 -j ''${NIX_BUILD_CORES:0} nerd-font-patcher --no-progressbars -q --variable-width-glyphs -c -out "$out/share/fonts/truetype/misans-nerd/" "{}"

    runHook postInstall
  '';

  # for f in $out/share/fonts/truetype/misans/*.ttf; do
  #   nerd-font-patcher --complete --outputdir $out/share/fonts/truetype/misans-nerd/ "$f"
  # done

  meta = with lib; {
    homepage = "https://hyperos.mi.com/font/zh/download/";
    description = "Free fonts developed by XiaoMi Corporation.";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
