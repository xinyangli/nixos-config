{
  config,
  lib,
  pkgs,
  sbcPkgs,
  ...
}:
let
  kernelConfig = lib.kernel;
  arm64DefconfigWithoutHsr = pkgs.runCommand
    "linux-${pkgs.linux_latest.version}-arm64-defconfig-without-hsr"
    { nativeBuildInputs = [ pkgs.xz ]; }
    ''
      tar --extract --xz --file ${pkgs.linux_latest.src} \
        --wildcards --to-stdout '*/arch/arm64/configs/defconfig' \
        > defconfig
      sed '/^CONFIG_HSR=m$/d' defconfig > $out
      test -s $out
      ! grep -q '^CONFIG_HSR=m$' $out
    '';

  linuxPackages_bpir4_latest = pkgs.linuxKernel.packagesFor (
    pkgs.linux_latest.override {
      autoModules = false;
      ignoreConfigErrors = true;
      defconfig = "KBUILD_DEFCONFIG=../../../../../${lib.removePrefix "/" (toString arm64DefconfigWithoutHsr)} defconfig";

      structuredExtraConfig =
        sbcPkgs.linuxPackages_frankw_latest_bananaPiR4.kernel.structuredExtraConfig
        // (with kernelConfig; {
          ARCH_MEDIATEK = yes;

          ARM_MEDIATEK_CPUFREQ = yes;
          ARM_MEDIATEK_CPUFREQ_HW = yes;
          ARM_MEDIATEK_CCI_DEVFREQ = yes;
          PM_DEVFREQ = yes;

          CRYPTO_BLAKE2B = module;
          CRYPTO_CRC32C = module;
          CRYPTO_SHA256 = module;
          CRYPTO_XXHASH = module;
          EFIVAR_FS = module;

          COMMON_CLK_MEDIATEK = yes;
          COMMON_CLK_MT7988 = yes;
          EINT_MTK = yes;
          HW_RANDOM_MTK = yes;
          I2C_MT65XX = yes;
          I2C_MUX = yes;
          I2C_MUX_PCA954x = yes;
          PINCTRL_MT7988 = yes;
          PWM_MEDIATEK = yes;
          REGMAP_I2C = yes;
          REGULATOR_FIXED_VOLTAGE = yes;
          REGULATOR_RT5190A = yes;
          RESET_TI_SYSCON = yes;
          SRAM = yes;

          MMC_MTK = yes;
          MTD_NAND_ECC_MEDIATEK = yes;
          BLK_DEV_NVME = module;
          NVME_HWMON = yes;

          MEDIATEK_WATCHDOG = yes;
          MTK_HSDMA = yes;
          MTK_INFRACFG = yes;
          MTK_LVTS_THERMAL = yes;
          MTK_PMIC_WRAP = yes;
          MTK_THERMAL = yes;
          MTK_SOC_THERMAL = yes;
          MTK_TIMER = yes;
          NVMEM_MTK_EFUSE = yes;
          RTC_DRV_PCF8563 = yes;
          SENSORS_PWM_FAN = yes;

          PCIE_MEDIATEK = yes;
          PCIE_MEDIATEK_GEN3 = yes;
          PHY_MTK_TPHY = yes;
          PHY_MTK_XFI_TPHY = yes;
          PHY_MTK_XSPHY = yes;

          USB_XHCI_MTK = yes;
          USB_STORAGE = yes;

          BRIDGE = yes;
          HSR = yes;
          NET_DSA = yes;
          NET_DSA_MT7530 = yes;
          NET_DSA_TAG_MTK = yes;
          NET_MEDIATEK_SOC = yes;
          NET_MEDIATEK_SOC_WED = yes;
          NET_VENDOR_MEDIATEK = yes;
          MII = module;
          LED_TRIGGER_PHY = yes;
          PCS_MTK_LYNXI = yes;
          SFP = yes;

          AQUANTIA_PHY = module;
          MARVELL_10G_PHY = module;
          MARVELL_PHY = module;
          MEDIATEK_2P5GE_PHY = module;
          MEDIATEK_GE_PHY = yes;

          MT7915E = module;
          MT798X_WMAC = yes;
          MT7996E = module;

          EEPROM_AT24 = yes;
          MTD_SPI_NAND = yes;
          MTD_SPI_NOR = yes;
          SPI_MTK_NOR = yes;
          SPI_MTK_SNFI = yes;
          SPI_MT65XX = yes;
        });
    }
  );
in
{
  imports = [
  ];
  config = {
    boot.kernelPackages = lib.mkForce linuxPackages_bpir4_latest;

    nixpkgs.hostPlatform = "aarch64-linux";
    system.stateVersion = "25.05";

    commonSettings = {
      auth.enable = true;
      network.localdns.enable = true;
      serverComponents.enable = true;
    };

    services.openssh.enable = true;
    time.timeZone = "Asia/Shanghai";
  };
}
