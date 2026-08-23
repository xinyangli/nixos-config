{ pkgs, lib, ... }:

let
  nodes = {
    alpha = { underlay = "192.168.1.1"; announced = "fd00:42::1"; };
    beta  = { underlay = "192.168.1.2"; announced = "fd00:42::2"; };
    gamma = { underlay = "192.168.1.3"; announced = "fd00:42::3"; };
  };

  mkNode = hostname: spec: _: {
    imports = [
      (import ./common.nix {
        inherit hostname;
        underlayAddr = spec.underlay;
        announcedAddr = spec.announced;
      })
    ];

    # This fixture exercises IPsec/Babel only and does not provide a host sshd.
    custom.mesh-network.sshd.enable = false;
  };
in
{
  name = "ipsec-mesh-babel-rtt";

  nodes = lib.mapAttrs mkNode nodes;

  testScript = ''
    import json
    import re
    import time

    start_all()

    # ---------- Phase 1: services up ----------
    for m in (alpha, beta, gamma):
        m.wait_for_unit("strongswan-swanctl.service")
        m.wait_for_unit("gravity-ipsec.service")
        m.wait_for_unit("bird.service")

    # ---------- Phase 2: 2 ESTABLISHED IKE_SAs per node ----------
    for m in (alpha, beta, gamma):
        m.wait_until_succeeds(
            "test \"$(swanctl --list-sas | grep -c ESTABLISHED)\" -ge 2",
            timeout=60,
        )

    # ---------- Phase 3: at least one xfrm per peer, all in vrf gravity ----------
    # Exact count varies: simultaneous IKE_SA_INIT from both sides of a
    # peer pair (likely on cold boot) can establish two SAs with default
    # charon.unique=no, yielding two xfrm devices per peer. babel handles
    # the extra paths fine, so we only require >=2 ifaces and that every
    # xfrm device is enslaved to the gravity VRF (otherwise bird wouldn't
    # see them and later phases would fail confusingly).
    for m in (alpha, beta, gamma):
        n_xfrm = int(m.succeed("ip -j link show type xfrm | jq 'length'").strip())
        assert n_xfrm >= 2, f"{m.name}: expected >=2 xfrm ifaces, got {n_xfrm}"
        n_in_vrf = int(m.succeed(
            "ip -d -j link show vrf gravity "
            "| jq '[.[] | select(.linkinfo.info_kind==\"xfrm\")] | length'"
        ).strip())
        assert n_in_vrf == n_xfrm, (
            f"{m.name}: {n_xfrm - n_in_vrf} xfrm iface(s) outside vrf gravity "
            f"({n_in_vrf}/{n_xfrm} enslaved)"
        )

    # ---------- Phase 4: babel sees 2 neighbors per node ----------
    for m in (alpha, beta, gamma):
        m.wait_until_succeeds(
            "test \"$(birdc show babel neighbors 2>/dev/null "
            "| awk '$2 ~ /^gn/ {c++} END{print c+0}')\" -ge 2",
            timeout=30,
        )

    # gn<8-hex> is hashed from PLUTO_IF_ID_OUT, so we cannot pin the
    # name at config time. Discover it by correlating the `if_id` field
    # of each xfrm interface with the `if_id` of an SA whose `dst` is
    # the peer's underlay address. `ip xfrm state` is the authoritative
    # source — swanctl plain output omits if_id and `--raw` uses vici
    # hyphenated keys (`if-id-out`) that are easy to mis-parse.
    def peer_iface_map(m, peer_underlays):
        xfrm = json.loads(m.succeed("ip -d -j link show type xfrm"))
        ifid_to_name = {}
        for link in xfrm:
            info = link.get("linkinfo", {}).get("info_data", {})
            ifid = info.get("if_id")
            if ifid is None:
                continue
            if isinstance(ifid, str):
                ifid = int(ifid, 0)
            ifid_to_name[ifid] = link["ifname"]

        # Text-parse `ip xfrm state` because JSON support for xfrm in
        # iproute2 doesn't always include `if_id`. Each SA block starts
        # with `src <ip> dst <ip>` and later contains `if_id 0x..`.
        states = m.succeed("ip xfrm state")
        result = {}
        current_dst = None
        for raw in states.splitlines():
            line = raw.strip()
            if line.startswith("src "):
                toks = line.split()
                # toks: ["src", "<ip>", "dst", "<ip>"]
                if len(toks) >= 4 and toks[2] == "dst":
                    current_dst = toks[3]
                else:
                    current_dst = None
            elif "if_id" in line and current_dst is not None:
                idx = line.find("if_id")
                rest = line[idx:].split()
                if len(rest) >= 2:
                    try:
                        ifid = int(rest[1], 0)
                    except ValueError:
                        continue
                    if ifid in ifid_to_name and current_dst in peer_underlays:
                        result[current_dst] = ifid_to_name[ifid]
        return result

    # ---------- Phase 5: baseline ping6 + record route to gamma ----------
    for src, dsts in [
        (alpha, ["fd00:42::2", "fd00:42::3"]),
        (beta,  ["fd00:42::1", "fd00:42::3"]),
        (gamma, ["fd00:42::1", "fd00:42::2"]),
    ]:
        for d in dsts:
            src.wait_until_succeeds(
                f"ip -6 route show vrf gravity {d}/128 | grep -q .",
                timeout=120,
            )
            src.succeed(f"ip vrf exec gravity ping -6 -c 3 -W 2 {d}")

    # SADR: routes live in `sadr6`, and bird's `<dst>/N` prefix arg is
    # rejected against an SADR table ("Incompatible type of prefix/ip
    # for table sadr6") — it would need source-aware syntax. Easier to
    # dump the whole table and slice in Python.
    sadr_head_re = re.compile(r"^([0-9a-fA-F:]+/\d+) from ", re.MULTILINE)

    def sadr_block(out, prefix):
        # Find the route block headed by `<prefix> from ...` and return
        # the lines belonging to it (up to the next top-level header).
        for mo in sadr_head_re.finditer(out):
            if mo.group(1) != prefix:
                continue
            start = mo.start()
            nxt = sadr_head_re.search(out, mo.end())
            return out[start:nxt.start() if nxt else len(out)]
        return None

    baseline_route = sadr_block(
        alpha.succeed("birdc show route table sadr6 all"),
        "fd00:42::3/128",
    )
    assert baseline_route, "alpha: no sadr6 route block for fd00:42::3/128"
    print("BASELINE alpha->gamma route:\n" + baseline_route)

    alpha_ifaces = peer_iface_map(alpha, {"192.168.1.2", "192.168.1.3"})
    print(f"alpha peer->iface map: {alpha_ifaces}")
    assert "192.168.1.2" in alpha_ifaces, "alpha has no xfrm to beta"
    assert "192.168.1.3" in alpha_ifaces, "alpha has no xfrm to gamma"
    iface_to_beta  = alpha_ifaces["192.168.1.2"]
    iface_to_gamma = alpha_ifaces["192.168.1.3"]

    # ---------- Phase 6: inject one-way 300ms latency alpha->gamma ----------
    # One-way egress shaping is enough — babel-rtt takes the max of the
    # two half-RTTs from timestamped Hello/IHU, so penalising one
    # direction is sufficient to flip the metric.
    alpha.succeed(
        "tc qdisc add dev eth1 root handle 1: prio && "
        "tc qdisc add dev eth1 parent 1:3 handle 30: netem delay 300ms && "
        "tc filter add dev eth1 protocol ip parent 1:0 prio 1 u32 "
        "match ip dst 192.168.1.3/32 flowid 1:3"
    )

    # ---------- Phase 7: alpha re-routes to gamma via beta ----------
    # Recompute the peer→iface mapping each iteration: strongSwan
    # rekey (or any IKE event) replaces the gn* interface names, so a
    # name captured pre-netem can go stale within ~30 s. We re-derive
    # the *current* iface for each peer, then read the selected
    # nexthop interface from `birdc show route` and compare.
    nexthop_iface_re = re.compile(r"\bon\s+(\S+)")

    def selected_nexthop_iface(m, prefix):
        # Dump the whole sadr6 table (avoiding the SADR prefix-syntax
        # issue) and slice out the block for `prefix`. `show route`
        # without `all` returns only the selected route per dst, so the
        # `on <iface>` line in our block is unambiguous.
        out = m.succeed("birdc show route table sadr6")
        block = sadr_block(out, prefix)
        if block is None:
            return None
        mo = nexthop_iface_re.search(block)
        return mo.group(1) if mo else None

    def wait_for_route_via(m, prefix, peer_addr, timeout):
        deadline = time.monotonic() + timeout
        last_want = None
        last_got = None
        while time.monotonic() < deadline:
            ifaces = peer_iface_map(m, {peer_addr})
            last_want = ifaces.get(peer_addr)
            last_got = selected_nexthop_iface(m, prefix)
            if last_want is not None and last_got == last_want:
                return
            time.sleep(2)
        raise Exception(
            f"timed out waiting for {prefix} via peer {peer_addr}: "
            f"want iface {last_want}, got {last_got}"
        )

    wait_for_route_via(alpha, "fd00:42::3/128", "192.168.1.2", timeout=120)

    new_route = sadr_block(
        alpha.succeed("birdc show route table sadr6 all"),
        "fd00:42::3/128",
    )
    print("POST-NETEM alpha->gamma route:\n" + new_route)

    # ---------- Phase 8: end-to-end traffic over the new path ----------
    alpha.succeed("ip vrf exec gravity ping -6 -c 3 -W 2 fd00:42::3")
    current_iface_to_beta = peer_iface_map(alpha, {"192.168.1.2"}).get("192.168.1.2")
    route_get = alpha.succeed("ip -6 route get fd00:42::3 vrf gravity")
    assert current_iface_to_beta and current_iface_to_beta in route_get, (
        f"expected route via {current_iface_to_beta}, got: {route_get}"
    )

    # ---------- Phase 9 (optional): remove latency, observe re-flip ----------
    # Comment out this block if CI flakes on the second convergence.
    alpha.succeed("tc qdisc del dev eth1 root")
    wait_for_route_via(alpha, "fd00:42::3/128", "192.168.1.3", timeout=120)
  '';
}
