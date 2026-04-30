{
  pkgs,
  lib,
  kernel ? pkgs.linuxPackages_latest.kernel,
}:

pkgs.stdenv.mkDerivation {
  pname = "asus-wmi-kernel-module";
  inherit (kernel)
    src
    version
    postPatch
    nativeBuildInputs
    ;

  patches = [
    (pkgs.fetchpatch {
      name = "asus-wmi-fix-camera-key-led-on-zenbook-s14.patch";
      url = "https://lore.kernel.org/all/adg6GzkykThAB_4u@djouze-zen/raw";
      hash = "sha256-hL5zSb6SaKS/7sl3BOFJItdgMcncgO1x8Np5AqnhP/s=";
    })
  ];

  kernel_dev = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  modulePath = "drivers/platform/x86";

  buildPhase = ''
    BUILT_KERNEL=$kernel_dev/lib/modules/$kernelVersion/build

    cp $BUILT_KERNEL/Module.symvers .
    cp $BUILT_KERNEL/.config        .
    cp $kernel_dev/vmlinux          .

    make "-j$NIX_BUILD_CORES" modules_prepare
    make "-j$NIX_BUILD_CORES" M=$modulePath modules
  '';

  installPhase = ''
    make \
      INSTALL_MOD_PATH="$out" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M="$modulePath" \
      modules_install
  '';

  meta = {
    description = "Asus Generic WMI Driver";
    license = lib.licenses.gpl3;
  };
}
