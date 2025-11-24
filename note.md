# nix-tree

Demonstrate disk usage by nix-store path.

## Tools

- new sops key should be added by using `sops updatekeys`

### Overriding cargoHash of buildRustPackage

See [this post](https://discourse.nixos.org/t/is-it-possible-to-override-cargosha256-in-buildrustpackage/4393/25)

```
package = pkgs.spotifyd.overrideAttrs (
  finalAttrs: prevAttrs: {
    version = "0.4.2";
    src = pkgs.fetchFromGitHub {
      owner = "Spotifyd";
      repo = "spotifyd";
      tag = "v0.4.2";
      hash = "sha256-+t6z2cenw0fU5onl5F5vtk7Hr24IzTCAee+Lcnd7aT4=";
    };
    cargoDeps = prevAttrs.cargoDeps.overrideAttrs (prevAttrs: {
      vendorStaging = prevAttrs.vendorStaging.overrideAttrs {
        inherit (finalAttrs) src version;
        outputHash = "sha256-rv4FWyciv6vDKtD7moJppY3tOJb0B3ezE9HgCLNhIo8=";
      };
    });
  }
);
```

## Waiting for update

### spotifyd

nixpkgs pr: https://github.com/NixOS/nixpkgs/pull/463287

### Niri

- Waiting for [shm screenshare support](https://patch-diff.githubusercontent.com/raw/YaLTeR/niri/pull/1791.diff) to be merged.


## TODO
- [x] change caddy admin to unix socket 
- [ ] admin config persist = false
- [x] synapse jmalloc
- [ ] backup all directories under /var/lib/forgejo
- [ ] collect caddy access logs with promtail (waiting for caddy v2.9.0 release after which log file mode can be set)
- [ ] update "https" to "https-file" with dae 1.0.0
- [ ] move away from dnspod
- [ ] kanimd does not reload certificate after acme renewal (see [kanidm/kanidm#3378](https://github.com/kanidm/kanidm/issues/3378))
