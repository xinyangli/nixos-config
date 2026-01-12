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
    ./0001-platform-x86-asus-ami-support-camera-LED-on-newer-de.patch
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
