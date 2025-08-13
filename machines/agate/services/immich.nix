{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.my-lib.settings) idpUrl;

  onnxruntime-1_17_0 = pkgs.callPackage (
    {
      config,
      stdenv,
      lib,
      fetchFromGitHub,
      fetchpatch,
      abseil-cpp_202407,
      cmake,
      cpuinfo,
      eigen,
      flatbuffers_23,
      gbenchmark,
      glibcLocales,
      gtest,
      howard-hinnant-date,
      libpng,
      nlohmann_json,
      pkg-config,
      python3Packages,
      re2,
      zlib,
      microsoft-gsl,
      libiconv,
      protobuf_21,
      pythonSupport ? true,
      cudaSupport ? config.cudaSupport,
      ncclSupport ? config.cudaSupport,
      cudaPackages ? { },
    }@inputs:

    let
      version = "1.21.0";

      src = fetchFromGitHub {
        owner = "microsoft";
        repo = "onnxruntime";
        tag = "v${version}";
        hash = "sha256-BaHXpK6Ek+gsld7v+OBM+C3FjrPiyMQYP1liv7mEjho=";
        fetchSubmodules = true;
      };

      stdenv = throw "Use effectiveStdenv instead";
      effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else inputs.stdenv;

      cudaArchitecturesString = cudaPackages.flags.cmakeCudaArchitecturesString;

      mp11 = fetchFromGitHub {
        owner = "boostorg";
        repo = "mp11";
        tag = "boost-1.82.0";
        hash = "sha256-cLPvjkf2Au+B19PJNrUkTW/VPxybi1MpPxnIl4oo4/o=";
      };

      safeint = fetchFromGitHub {
        owner = "dcleblanc";
        repo = "safeint";
        tag = "3.0.28";
        hash = "sha256-pjwjrqq6dfiVsXIhbBtbolhiysiFlFTnx5XcX77f+C0=";
      };

      pytorch_clog = effectiveStdenv.mkDerivation {
        pname = "clog";
        version = "3c8b153";
        src = "${cpuinfo.src}/deps/clog";

        nativeBuildInputs = [
          cmake
          gbenchmark
          gtest
        ];
        cmakeFlags = [
          (lib.cmakeBool "USE_SYSTEM_GOOGLEBENCHMARK" true)
          (lib.cmakeBool "USE_SYSTEM_GOOGLETEST" true)
          (lib.cmakeBool "USE_SYSTEM_LIBS" true)
          # 'clog' tests set 'CXX_STANDARD 11'; this conflicts with our 'gtest'.
          (lib.cmakeBool "CLOG_BUILD_TESTS" false)
        ];
      };

      onnx = fetchFromGitHub {
        owner = "onnx";
        repo = "onnx";
        tag = "v1.17.0";
        hash = "sha256-9oORW0YlQ6SphqfbjcYb0dTlHc+1gzy9quH/Lj6By8Q=";
      };

      cutlass = fetchFromGitHub {
        owner = "NVIDIA";
        repo = "cutlass";
        tag = "v3.5.1";
        hash = "sha256-sTGYN+bjtEqQ7Ootr/wvx3P9f8MCDSSj3qyCWjfdLEA=";
      };

      dlpack = fetchFromGitHub {
        owner = "dmlc";
        repo = "dlpack";
        tag = "v0.6";
        hash = "sha256-YJdZ0cMtUncH5Z6TtAWBH0xtAIu2UcbjnVcCM4tfg20=";
      };

      isCudaJetson = cudaSupport && cudaPackages.flags.isJetsonBuild;
    in
    effectiveStdenv.mkDerivation rec {
      pname = "onnxruntime";
      inherit src version;

      patches = [
        # drop with the next update
        # https://github.com/microsoft/onnxruntime/pull/23939
        (fetchpatch {
          url = "https://github.com/microsoft/onnxruntime/commit/55553703eaa8cd01d2b01cc21171a0ea515c888a.patch";
          hash = "sha256-gL1rMNUcteKcjLmdJ+0r67rvNrC31bAyKYx4aeseWkM=";
        })
      ];

      nativeBuildInputs = [
        cmake
        pkg-config
        python3Packages.python
        protobuf_21
      ]
      ++ lib.optionals pythonSupport (
        with python3Packages;
        [
          pip
          python
          pythonOutputDistHook
          setuptools
          wheel
        ]
      )
      ++ lib.optionals cudaSupport [
        cudaPackages.cuda_nvcc
        cudaPackages.cudnn-frontend
      ]
      ++ lib.optionals isCudaJetson [
        cudaPackages.autoAddCudaCompatRunpath
      ];

      buildInputs = [
        cpuinfo
        eigen
        glibcLocales
        howard-hinnant-date
        libpng
        nlohmann_json
        microsoft-gsl
        pytorch_clog
        zlib
      ]
      ++ lib.optionals pythonSupport (
        with python3Packages;
        [
          numpy
          pybind11
          packaging
        ]
      )
      ++ lib.optionals effectiveStdenv.hostPlatform.isDarwin [
        libiconv
      ]
      ++ lib.optionals cudaSupport (
        with cudaPackages;
        [
          cuda_cccl # cub/cub.cuh
          libcublas # cublas_v2.h
          libcurand # curand.h
          libcusparse # cusparse.h
          libcufft # cufft.h
          cudnn # cudnn.h
          cuda_cudart
        ]
        ++ lib.optionals (cudaSupport && ncclSupport) (
          with cudaPackages;
          [
            nccl
          ]
        )
      );

      nativeCheckInputs = [
        gtest
      ]
      ++ lib.optionals pythonSupport (
        with python3Packages;
        [
          pytest
          sympy
          onnx
        ]
      );

      # TODO: build server, and move .so's to lib output
      # Python's wheel is stored in a separate dist output
      outputs = [
        "out"
        "dev"
      ]
      ++ lib.optionals pythonSupport [ "dist" ];

      enableParallelBuilding = true;

      cmakeDir = "../cmake";

      cmakeFlags = [
        (lib.cmakeBool "ABSL_ENABLE_INSTALL" true)
        (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
        (lib.cmakeBool "FETCHCONTENT_QUIET" false)
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ABSEIL_CPP" "${abseil-cpp_202407.src}")
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_DLPACK" "${dlpack}")
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_FLATBUFFERS" "${flatbuffers_23.src}")
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_MP11" "${mp11}")
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ONNX" "${onnx}")
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_RE2" "${re2.src}")
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_SAFEINT" "${safeint}")
        (lib.cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
        # fails to find protoc on darwin, so specify it
        (lib.cmakeFeature "ONNX_CUSTOM_PROTOC_EXECUTABLE" "${protobuf_21}/bin/protoc")
        (lib.cmakeBool "onnxruntime_BUILD_SHARED_LIB" true)
        (lib.cmakeBool "onnxruntime_BUILD_UNIT_TESTS" doCheck)
        (lib.cmakeBool "onnxruntime_USE_FULL_PROTOBUF" false)
        (lib.cmakeBool "onnxruntime_USE_CUDA" cudaSupport)
        (lib.cmakeBool "onnxruntime_USE_NCCL" (cudaSupport && ncclSupport))
        (lib.cmakeBool "onnxruntime_ENABLE_LTO" (!cudaSupport || cudaPackages.cudaOlder "12.8"))
      ]
      ++ lib.optionals pythonSupport [
        (lib.cmakeBool "onnxruntime_ENABLE_PYTHON" true)
      ]
      ++ lib.optionals cudaSupport [
        (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CUTLASS" "${cutlass}")
        (lib.cmakeFeature "onnxruntime_CUDNN_HOME" "${cudaPackages.cudnn}")
        (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaArchitecturesString)
        (lib.cmakeFeature "onnxruntime_NVCC_THREADS" "1")
      ];

      env = lib.optionalAttrs effectiveStdenv.cc.isClang {
        NIX_CFLAGS_COMPILE = "-Wno-error";
      };

      # aarch64-linux fails cpuinfo test, because /sys/devices/system/cpu/ does not exist in the sandbox
      doCheck = !(cudaSupport || effectiveStdenv.buildPlatform.system == "aarch64-linux");

      requiredSystemFeatures = lib.optionals cudaSupport [ "big-parallel" ];

      postPatch = ''
        substituteInPlace cmake/libonnxruntime.pc.cmake.in \
          --replace-fail '$'{prefix}/@CMAKE_INSTALL_ @CMAKE_INSTALL_
        echo "find_package(cudnn_frontend REQUIRED)" > cmake/external/cudnn_frontend.cmake

        # https://github.com/microsoft/onnxruntime/blob/c4f3742bb456a33ee9c826ce4e6939f8b84ce5b0/onnxruntime/core/platform/env.h#L249
        substituteInPlace onnxruntime/core/platform/env.h --replace-fail \
          "GetRuntimePath() const { return PathString(); }" \
          "GetRuntimePath() const { return PathString(\"$out/lib/\"); }"
      ''
      + lib.optionalString (effectiveStdenv.hostPlatform.system == "aarch64-linux") ''
        # https://github.com/NixOS/nixpkgs/pull/226734#issuecomment-1663028691
        rm -v onnxruntime/test/optimizer/nhwc_transformer_test.cc
      '';

      postBuild = lib.optionalString pythonSupport ''
        ${python3Packages.python.interpreter} ../setup.py bdist_wheel
      '';

      postInstall = ''
        # perform parts of `tools/ci_build/github/linux/copy_strip_binary.sh`
        install -m644 -Dt $out/include \
          ../include/onnxruntime/core/framework/provider_options.h \
          ../include/onnxruntime/core/providers/cpu/cpu_provider_factory.h \
          ../include/onnxruntime/core/session/onnxruntime_*.h
      '';

      passthru = {
        inherit cudaSupport cudaPackages; # for the python module
        protobuf = protobuf_21;
        tests = lib.optionalAttrs pythonSupport {
          python = python3Packages.onnxruntime;
        };
      };

      meta = with lib; {
        description = "Cross-platform, high performance scoring engine for ML models";
        longDescription = ''
          ONNX Runtime is a performance-focused complete scoring engine
          for Open Neural Network Exchange (ONNX) models, with an open
          extensible architecture to continually address the latest developments
          in AI and Deep Learning. ONNX Runtime stays up to date with the ONNX
          standard with complete implementation of all ONNX operators, and
          supports all ONNX releases (1.2+) with both future and backwards
          compatibility.
        '';
        homepage = "https://github.com/microsoft/onnxruntime";
        changelog = "https://github.com/microsoft/onnxruntime/releases/tag/v${version}";
        # https://github.com/microsoft/onnxruntime/blob/master/BUILD.md#architectures
        platforms = platforms.unix;
        license = licenses.mit;
        maintainers = with maintainers; [
          puffnfresh
          ck3d
          cbourjau
        ];
      };
    }
  ) { };

  user = config.systemd.services.immich-server.serviceConfig.User;
  immichUrl = "immich.xiny.li:8443";
  jsonSettings = {
    oauth = {
      enabled = true;
      issuerUrl = "https://${idpUrl}/oauth2/openid/immich/.well-known/openid-configuration";
      clientId = "immich";
      clientSecret = config.sops.placeholder."immich/oauth_client_secret";
      scope = "openid email profile";
      signingAlgorithm = "ES256";
      storageLabelClaim = "email";
      buttonText = "Login with Kanidm";
      autoLaunch = true;
      mobileOverrideEnabled = true;
      mobileRedirectUri = "https://${immichUrl}/api/oauth/mobile-redirect/";
    };
    job = {
      faceDetection = {
        concurrency = 3;
      };
      metadataExtraction = {
        concurrency = 8;
      };
      thumbnailGeneration = {
        concurrency = 8;
      };
    };
    passwordLogin = {
      enabled = false;
    };
    image = {
      extractEmbedded = true;
    };
    newVersionCheck = {
      enabled = false;
    };
    machineLearning = {
      enabled = true;
      urls = [
        "http://calcite.coho-tet.ts.net:3003"
        "http://127.0.0.1:3003"
      ];
      clip = {
        enabled = true;
        modelName = "nllb-clip-large-siglip__v1";
      };
      facialRecognition = {
        maxDistance = 0.35;
        minFaces = 10;
      };
    };
  };
in
# t3aq1iDy28591FZ72ZvMRhlNYww3trgva4ogWS-3
{
  config = {
    sops.secrets = {
      "immich/oauth_client_secret" = { };
      "immich/auto_stack_apikey" = { };
    };

    sops.templates."immich/config.json" = {
      owner = user; # Read when running
      content = builtins.toJSON jsonSettings;
    };

    sops.templates."immich/auto_stack.env" = {
      owner = "immich_auto_stack";
      content = ''
        API_KEY=${config.sops.placeholder."immich/auto_stack_apikey"}
      '';
    };

    systemd.mounts = [
      {
        what = "/storage/nixos/immich";
        where = "/var/lib/immich";
        options = "bind";
        before = [ "immich-server.service" ];
        wantedBy = [ "immich-server.service" ];
      }
    ];

    systemd.timers.immich-auto-stack = {
      enable = true;
      wantedBy = [ "immich-server.service" ];
      timerConfig = {
        Unit = "immich-auto-stack.service";
        OnCalendar = "*-*-* 4:00:00";
      };
    };

    systemd.services.immich-auto-stack =
      let
        python = pkgs.python3.withPackages (
          ps: with ps; [
            requests
          ]
        );
        immich_auto_stack = pkgs.fetchurl {
          url = "https://gist.githubusercontent.com/xinyangli/39de5979e72d81af6fe9ddb7d1805df4/raw/805beab14eb9160713b14e1da4d0d5922816d988/immich_auto_stack.py";
          hash = "sha256-vWbw2iFkSD5jLM95Dmk7Kdb2iSI1gd4RexIGG37dm90=";
        };
      in
      {
        environment = {
          SKIP_MATCH_MISS = "true";
          DRY_RUN = "false";
          API_URL = "http://127.0.0.1:${toString config.services.immich.port}/api";
          PARENT_PROMOTE = "hdr,edit,export,selects,output";
        };
        serviceConfig = {
          ExecStart = "${lib.getExe python} ${immich_auto_stack}";
          EnvironmentFile = config.sops.templates."immich/auto_stack.env".path;
          WorkingDirectory = "%t/immich-auto-stack";
          RuntimeDirectory = "immich-auto-stack";
          User = "immich_auto_stack";
          Group = "immich_auto_stack";
        };
      };

    systemd.services.immich-server = {
      serviceConfig = {
        BindReadOnlyPaths = [
          "/storage/pictures/xin/originals:/mnt/immich/external-library/xin"
        ];
        Environment = "IMMICH_CONFIG_FILE=${config.sops.templates."immich/config.json".path}";
      };
    };

    services.immich = {
      enable = true;
      host = "127.0.0.1";
      port = 3001;
      openFirewall = true;
      machine-learning = {
        enable = true;
        environment = {
          MACHINE_LEARNING_ANN = "False";
          MACHINE_LEARNING_MODEL_INTRA_OP_THREADS = "16";
          MACHINE_LEARNING_MODEL_INTER_OP_THREADS = "4";
          ORT_EXECUTION_PROVIDERS = "CPUExecutionProvider";
        };
      };
      environment = {
        IMMICH_MACHINE_LEARNING_ENABLED = "true";
      };
      database.enable = true;
    };

    nixpkgs.overlays = [
      (final: prev: {
        onnxruntime = onnxruntime-1_17_0.overrideAttrs (
          finalAttrs: prevAttrs: {
            pname = prevAttrs.pname + "-no_neon_bf16";
            patches = prevAttrs.patches ++ [
              ./fix_invalid_instruction_arm64_nobf16.patch
            ];
          }
        );
      })
    ];

    users.users.immich.extraGroups = [ "privimg" ];

    users.groups.privimg = { };

    users.groups.immich_auto_stack = { };
    users.users.immich_auto_stack = {
      isSystemUser = true;
      group = "immich_auto_stack";
    };

    services.immich.redis.host = "/run/redis-immich/redis.sock";

    services.caddy.virtualHosts."immich.xiny.li:8443".extraConfig = ''
      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }
      reverse_proxy 127.0.0.1:${toString config.services.immich.port}
    '';
  };
}
