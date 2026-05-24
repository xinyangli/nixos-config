(
  final: prev:
  let
    callPackage = prev.lib.callPackageWith prev.pkgs;
  in
  {
    ubootOrangePiR1LtsPackage = prev.buildUBoot {
      defconfig = "orangepi-r1-plus-lts-rk3328_defconfig";
      enableParallelBuilding = true;

      BL31 = "${prev.armTrustedFirmwareRK3328}/bl31.elf";
      filesToInstall = [
        "u-boot.itb"
        "idbloader.img"
      ];
    };
    owncloud-client = import ./pkgs/owncloud-client.nix prev;

    transmission-exporter = prev.callPackage ./pkgs/transmission-exporter.nix { };
    owncloud-shell-resources = callPackage ./pkgs/owncloud-shell-resources.nix { };
    owncloud-nautilus = callPackage ./pkgs/owncloud-nautilus.nix { };
    nerd-fonts-misans = callPackage ./pkgs/nerd-fonts-misans.nix { };

    xwayland-satellite = callPackage ./pkgs/xwayland-satellite.nix { };
    longbridge = callPackage ./pkgs/longbridge.nix { };
    matterjs-server = callPackage ./pkgs/matterjs-server.nix { };

    kanidm-provision = prev.rustPlatform.buildRustPackage (finalAttrs: {
      pname = "kanidm-provision";
      version = "1.3.0-unstable-2025-11-22";

      src = prev.fetchFromGitHub {
        owner = "oddlama";
        repo = "kanidm-provision";
        rev = "304a048bf6ed1a01678db243807a5619a0e32f61";
        hash = "sha256-k+m73Ih+LzBsanbplHIivoF7z+RcRvj6IeoesDdfImc=";
      };

      cargoHash = "sha256-dPTrIc/hTbMlFDXYMk/dTjqaNECazldfW43egDOwyLM=";

      patches = [
        (prev.fetchpatch {
          name = "kanidm-provision-pr29-service-accounts.patch";
          url = "https://github.com/oddlama/kanidm-provision/pull/29.patch";
          hash = "sha256-nFDW3dyxb1AqxmNKEWdShoC2gOxTYg4f/LNUwSejuqE=";
        })
        (prev.fetchpatch {
          name = "kanidm-provision-pr34-ssh-public-keys.patch";
          url = "https://github.com/oddlama/kanidm-provision/pull/34.patch";
          hash = "sha256-+2kilgTxeCF0qsxB2YE000mHdRQJcK/n/71SSjQVDxw=";
        })
        # Locally-authored. Mirrors 6862c31 (PR #31, the upstream POSIX
        # commit for Person/Group) onto the ServiceAccount struct that
        # PR #29 introduced, so service accounts can be made POSIX
        # declaratively.
        ./pkgs/kanidm-provision/service-account-posix.patch
      ];

      # PR #29 leaves `service_accounts` as a non-optional field, which would
      # break every existing caller (including the upstream NixOS module) that
      # does not emit `serviceAccounts`. Default it to an empty map.
      postPatch = ''
        substituteInPlace src/state.rs \
          --replace-fail $'    pub service_accounts: HashMap' \
                        $'    #[serde(default)]\n    pub service_accounts: HashMap'
      '';

      # versionCheckHook fails because the binary still self-reports "1.3.0"
      # while we ship an unstable revision past that tag.
      doInstallCheck = false;

      meta = prev.kanidm-provision.meta;
    });
  }
)
