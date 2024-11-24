(final: prev: {
  ubootOrangePiR1LtsPackage = prev.buildUBoot {
    defconfig = "orangepi-r1-plus-lts-rk3328_defconfig";
    enableParallelBuilding = true;

    BL31 = "${prev.armTrustedFirmwareRK3328}/bl31.elf";
    filesToInstall = [
      "u-boot.itb"
      "idbloader.img"
    ];
  };
})
