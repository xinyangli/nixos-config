# nix-tree

Demonstrate disk usage by nix-store path.

## Tools

- new sops key should be added by using `sops updatekeys`

## TODO
- [x] change caddy admin to unix socket 
- [ ] admin config persist = false
- [x] synapse jmalloc
- [ ] backup all directories under /var/lib/forgejo
- [ ] collect caddy access logs with promtail (waiting for caddy v2.9.0 release after which log file mode can be set)
- [ ] update "https" to "https-file" with dae 1.0.0
- [ ] move away from dnspod
- [ ] kanimd does not reload certificate after acme renewal (see [kanidm/kanidm#3378](https://github.com/kanidm/kanidm/issues/3378))
