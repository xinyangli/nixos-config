{ lib, ... }:
let
  fix-folly-build = (
    final: prev: {
      folly =
        let
          lib = prev.lib;
          stdenv = prev.stdenv;
        in
        prev.folly.overrideAttrs {
          checkPhase = ''
            runHook preCheck

            ctest -j $NIX_BUILD_CORES --output-on-failure --exclude-regex ${
              lib.escapeShellArg (
                lib.concatMapStringsSep "|" (test: "^${lib.escapeRegex test}$") (
                  [
                    "concurrency_concurrent_hash_map_test.*/ConcurrentHashMapTest/*.StressTestReclamation"
                    "io_async_ssl_session_test.SSLSessionTest.BasicTest"
                    "io_async_ssl_session_test.SSLSessionTest.NullSessionResumptionTest"
                    "singleton_thread_local_test.SingletonThreadLocalDeathTest.Overload"

                    # very strict timing constraints, will fail under load
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.CancelTimeout"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.DefaultTimeout"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.DeleteWheelInTimeout"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.DestroyTimeoutSet"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.FireOnce"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.GetTimeRemaining"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.IntrusivePtr"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.Level1"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.NegativeTimeout"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.ReschedTest"
                    "io_async_hh_wheel_timer_test.HHWheelTimerTest.SlowFast"
                    "concurrent_skip_list_test.ConcurrentSkipList.ConcurrentAdd"
                  ]
                  ++ lib.optionals stdenv.hostPlatform.isLinux [
                    "concurrency_cache_locality_test.CacheLocality.BenchmarkSysfs"
                    "concurrency_cache_locality_test.CacheLocality.LinuxActual"
                    "futures_future_test.Future.NoThrow"
                    "futures_retrying_test.RetryingTest.largeRetries"
                  ]
                  ++ lib.optionals stdenv.hostPlatform.isDarwin [
                    "buffered_atomic_test.BufferedAtomic.singleThreadUnguardedAccess"
                    "io_async_notification_queue_test.NotificationQueueTest.UseAfterFork"
                    "container_heap_vector_types_test.HeapVectorTypes.SimpleSetTes"
                  ]
                )
              )
            }

            runHook postCheck
          '';
        };
    }
  );
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./services
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = lib.mkForce [ ];
    mirroredBoots = [
      {
        devices = [
          "/dev/disk/by-partlabel/disk-ssd1-system_p1"
        ];
        path = "/boot0";
      }
      {
        devices = [
          "/dev/disk/by-partlabel/disk-ssd2-system_p2"
        ];
        path = "/boot1";
      }
    ];
  };

  users.users.root.hashedPassword = "$y$j9T$vgLUF3/R0RJpDu7e22fSW.$CPomHsuRziERtNGUnnMZZDQG.Vj7LCe5PUOSbvkwSV3";

  commonSettings = {
    auth.enable = true;
    nix = {
      enable = true;
    };
    comin.enable = true;
    network.localdns.enable = true;
  };
  system.stateVersion = "25.05";
  time.timeZone = "Asia/Shanghai";

  nix.settings = {
    max-jobs = 8;
    cores = 16;
    substituters = [ "https://cache.ngi0.nixos.org/" ];
    trusted-public-keys = [ "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA=" ];
  };

  nixpkgs.config.contentAddressedByDefault = true;
  nixpkgs.overlays = [ fix-folly-build ];

  custom.prometheus.exporters = {
    enable = true;
    blackbox = {
      enable = true;
    };
    node = {
      enable = true;
    };
  };

  custom.monitoring = {
    promtail.enable = true;
  };
}
