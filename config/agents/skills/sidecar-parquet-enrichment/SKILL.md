---
name: sidecar-parquet-enrichment
description: Build row-aligned sidecar Parquet for large image datasets without rewriting image bytes. Use for merge-then-join enrichment, Ray actor distribution, 1:1 shard alignment, resume, and pyarrow offset-overflow pitfalls.
---

# Sidecar Parquet Enrichment

## Why sidecar (vs. rewriting main)

Main parquet has one huge column (image bytes, webp/jpeg) that dominates size — rewriting to add 6 small filter structs would re-shuffle TBs. A sidecar parquet with the SAME shard layout (same path suffix, same row count & order) lets training consumers do `zip(main_rows, sidecar_rows)` with zero join cost.

**Invariants that must hold**:
1. `sidecar_shards == main_shards` (1:1 mapping by path suffix)
2. `sidecar_shard.num_rows == main_shard.num_rows`
3. Row ordering is preserved (row i in sidecar ↔ row i in main)

Unmatched rows keep the slot but with NULL/default struct values.

## 2-stage pipeline

```
                      Stage A                           Stage B
filter JSONL        merge per source              join into main shards
outputs (~100K  ─►  sorted parquet with     ─►    sidecar parquet with
 shards × 6      │  {s3_path, filter_*}      │    identical shard layout
 filter types)   │  one file per source      │    (same rel path as main)
                 │                           │
                 ▼                           ▼
           s3://…/filter_merged/       s3://…/main_sidecar/
           bigstock.parquet            scale/ar_id/shard-NNNNNN.parquet
           sstk.parquet
           pond5_0131.parquet
           pond5_0204.parquet
```

**Stage A** reduces M shards × K filter types → 1 parquet per source. Keyed by `s3_path`. Run once; keep for reuse.

**Stage B** joins main parquet (non-image cols) × stage A output → sidecar. Reads main shard, looks up each row's `s3_image_path` in the merged index, batch-takes the filter columns, writes sidecar with SAME relative path.

## Source inference from s3 path

Main parquet rows come from multiple sources, but each shard's rows all belong to a single source (sampled to confirm). Group-by-source + batch-take is much faster than per-row dict lookup.

```python
SOURCE_PATH_MARKERS = [
    ("raw/20250203/bigstock", "bigstock"),
    ("raw/20250130/sstk", "sstk"),
    ("raw/20250131/pond5", "pond5_0131"),
    ("raw/20250204/pond5", "pond5_0204"),
    # ...add markers for any 5th, 6th source
]

def infer_source(s3_path: str) -> str | None:
    for marker, source in SOURCE_PATH_MARKERS:
        if marker in s3_path:
            return source
    return None
```

**Gotcha**: a path that matches NO marker (e.g. a 5th source not in stage A) produces `None` → all rows in that shard end up as unmatched sidecar rows (source=NULL, filters=NULL). This is fine for train-time filtering but surprising — audit match rates per path prefix to catch missed sources.

## Architecture: actor-per-node with in-actor thread pool

Avoid stateless Ray tasks for this pattern. The merged index (path→row_idx dict) is ~30GB for 262M paths; every task pulling it via `ray.get()` OOMs workers.

**Correct pattern** (`@ray.remote` actor holds the state):

```python
@ray.remote(
    num_cpus=args.actor_cpus,            # 40 on r5.12xlarge
    memory=args.actor_memory_gb * 1024**3,  # 240 (NOT 300 — leaves headroom)
    max_concurrency=args.per_actor_inflight,  # 12 — actor thread pool size
)
class ShardProcessor:
    def __init__(self, merged_base, in_bucket, in_prefix, out_bucket, out_prefix):
        self.merged = load_merged_tables(merged_base)  # loaded ONCE per actor
        # ... store paths
    def ready(self) -> bool: return True
    def process(self, shard_key: str) -> dict:
        return process_shard(shard_key, self.in_bucket, ..., self.merged)

actors = [ShardProcessor.remote(...) for _ in range(num_actors)]
ray.get([a.ready.remote() for a in actors])   # wait ~15min for table load
```

**Why `max_concurrency=12`**: without it, an actor serializes all `.process.remote()` calls to ONE at a time (actor default). With it, Ray dispatches into an in-actor thread pool — `pyarrow.take`, `boto3 put/get`, `pq.read_table`, `pq.write_table` all release the GIL, so 12 shards truly run in parallel inside one actor. In our run: `max_concurrency=1` → 1.1 shards/s cluster-wide; `max_concurrency=12` → 12 shards/s (at best — settles at ~5 when the harder sources dominate).

**Why actor-per-node, not many small tasks**: the merged index must be resident in memory. One big actor per worker node amortizes the 15min table-load cost across all of that node's work.

**Cluster shape** (10 nodes, ~323K shards, ~330M rows):
- head: `r5.4xlarge` — does not load merged tables, just lists shards + dispatches
- workers: 10 × `r5.12xlarge` (48 vCPU, 384GB) — 1 actor each, 240GB reserved, 40 CPU reserved

## Head-node dispatch loop (in-flight limit + round-robin)

Don't submit all 323K `.process.remote()` calls upfront — blows up Ray's queue. Round-robin + per-actor in-flight cap:

```python
per_actor_inflight = args.per_actor_inflight   # same as actor max_concurrency
pending = list(reversed(shard_keys))
inflight: list = []   # (future, actor_idx)
actor_load = [0] * num_actors

def submit():
    while pending:
        idx = min(range(num_actors), key=lambda i: actor_load[i])
        if actor_load[idx] >= per_actor_inflight:
            break
        fut = actors[idx].process.remote(pending.pop())
        inflight.append((fut, idx))
        actor_load[idx] += 1

submit()
while inflight:
    ready, _ = ray.wait([f for f, _ in inflight], num_returns=min(20, len(inflight)))
    ready_set = set(ready)
    new = []
    for fut, idx in inflight:
        if fut in ready_set:
            r = ray.get(fut)
            actor_load[idx] -= 1
        else:
            new.append((fut, idx))
    inflight = new
    submit()
```

## Fatal pitfall: pyarrow `offset overflow` on take()

When your stage A merged table has a string column with combined bytes > 2GB (e.g. 130M × 20-byte `s3_path` = 2.6GB), `pa.Table.take()` **crashes** with:

```
pyarrow.lib.ArrowInvalid: offset overflow while concatenating arrays,
consider casting input from `string` to `large_string` first.
```

This surfaces at the FIRST `take()` call — after actors have happily loaded for 15min. Fix: drop the string column from the table after building the index (you only need it once to build `{s3_path: row_idx}`).

```python
table = pq.read_table(...)
s3_paths = table.column("s3_path").to_pylist()
index = {path: i for i, path in enumerate(s3_paths)}
del s3_paths
table = table.drop(["s3_path"])   # ← required, else take() blows up
result[source] = {"table": table, "index": index}
```

Alternative (if you genuinely need `s3_path`): cast to `large_string` before store, but the memory cost of int64 offsets is worse than just keeping the dict.

## Per-shard join (group-by-source + batch-take)

Each main shard's rows all belong to one source (empirically). But the code groups by source anyway so mixed-source shards would still work.

```python
def process_shard(shard_key, in_bucket, in_prefix, out_bucket, out_prefix, merged):
    data = read_s3_bytes(s3, in_bucket, shard_key)
    pf = pq.ParquetFile(io.BytesIO(data))
    read_cols = [c for c in pf.schema_arrow.names if c != "image"]   # drop heavy col
    main_table = pf.read(columns=read_cols)
    num_rows = main_table.num_rows
    s3_paths = main_table.column("s3_image_path").to_pylist()

    # group row indices by source
    by_source = {}
    row_src = [None] * num_rows
    row_merged_idx = [-1] * num_rows
    for i, path in enumerate(s3_paths):
        src = infer_source(path)
        if src and src in merged:
            idx = merged[src]["index"].get(path, -1)
            if idx >= 0:
                row_src[i] = src
                row_merged_idx[i] = idx
                by_source.setdefault(src, []).append((i, idx))

    # batch-take per source
    filter_arrays = {n: [None] * num_rows for n in FILTER_COL_NAMES}
    sources_out = [None] * num_rows
    file_sizes_out = [None] * num_rows
    for src, pairs in by_source.items():
        sub = merged[src]["table"].take(pa.array([p[1] for p in pairs], type=pa.int64()))
        sub_src = sub.column("source").to_pylist()
        sub_fs = sub.column("file_size").to_pylist()
        sub_f = {n: sub.column(n).to_pylist() for n in FILTER_COL_NAMES}
        for out_i, (main_row, _) in enumerate(pairs):
            sources_out[main_row] = sub_src[out_i]
            file_sizes_out[main_row] = sub_fs[out_i]
            for n in FILTER_COL_NAMES:
                filter_arrays[n][main_row] = sub_f[n][out_i]

    # fill null for unmatched rows
    for n in FILTER_COL_NAMES:
        for i in range(num_rows):
            if filter_arrays[n][i] is None:
                filter_arrays[n][i] = EMPTY[n]

    # build sidecar: main's non-image cols + source + file_size + filter structs
    arrays = {name: main_table.column(name) for name in main_table.column_names}
    arrays["source"] = pa.array(sources_out, type=pa.string())
    arrays["file_size"] = pa.array(file_sizes_out, type=pa.int64())
    for n in FILTER_COL_NAMES:
        arrays[n] = pa.array(filter_arrays[n], type=FILTER_STRUCTS.field(n).type)
    sidecar = pa.table(arrays)

    # write to sidecar prefix with IDENTICAL relative path
    rel = shard_key[len(in_prefix):]
    buf = io.BytesIO()
    pq.write_table(sidecar, buf, compression="zstd", row_group_size=10000)
    write_s3_bytes(s3, out_bucket, f"{out_prefix}{rel}", buf.getvalue())
    return {"num_rows": num_rows, "matched": sum(1 for s in row_src if s)}
```

## Skip-existing (for resume)

Non-negotiable for 10h+ jobs. Scan output prefix once on head, diff against input list:

```python
if args.skip_existing:
    existing = set(list_s3_keys(s3, out_bucket, out_prefix, suffix=".parquet"))
    shard_keys = [k for k in shard_keys
                  if f"{out_prefix}{k[len(in_prefix):]}" not in existing]
```

The S3 list is ~5min for 300K keys. Worth it — it's how we recovered the slow first run's 4660 completed shards instead of redoing them.

## Memory-tuning the actor (r5.12xlarge notes)

| Setting            | Value    | Reason                                                |
|--------------------|----------|-------------------------------------------------------|
| instance           | r5.12xlarge | 48 vCPU / 384GB — 10 of them                       |
| `num_cpus`         | 40       | 8 CPU headroom per node for OS, Ray runtime, raylet   |
| `memory`           | 240GB    | 300GB gets stuck Pending (Ray reserves ~30% of 384GB for object store + system) |
| `max_concurrency`  | 12       | Balances CPU parallelism vs. S3 concurrent reads     |

**Symptom of too-high memory reservation**: `ray status` shows all actors Pending with `Pending Demands: {'CPU': 40.0, 'memory': 322122547200.0}: 10+ pending tasks/actors`. Drop to 240GB.

## Docker image pattern

Prefer baking scripts into the image. Runtime `aws s3 cp` of code can fail if pod startup credentials differ from data-bucket IRSA, even when the job can later read/write data buckets.

```dockerfile
FROM 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-omra-trainer:release-dc1b-extract-v1
RUN PIP_CONSTRAINT="" pip install --no-cache-dir "pyarrow>=14.0" "zstandard>=0.22"
WORKDIR /app
COPY merge_filters_per_source.py /app/tools/merge_filters_per_source.py
COPY build_sidecar_parquet.py /app/tools/build_sidecar_parquet.py
```

Build script (`tools/deploy/build_and_push_sidecar.sh`) is a wrapper around `docker build + ecr push` with `AWS_PROFILE=deploy`. Use a new release tag for changed images and record the digest when reproducibility matters.

## Recipe for re-running

1. If script changed: bump Dockerfile tag, rebuild `bash tools/deploy/build_and_push_sidecar.sh vN`
2. Update YAML's `image_uri` to match
3. Include `--skip-existing` in entrypoint (cheap safety net even on clean runs)
4. Submit: `FORCE_NO_BAZEL_REMOTE_EXECUTION=true arnold -x submit --no-login --job-name "sidecar-b-$(date +%s)" --compute-config … --application-id core-cn`
5. Monitor: `kubectl exec <head-pod> -- ray job logs <job-name>` — watch for `All actors ready in XXXs` then `Progress:` lines
6. On OOM/stuck-Pending: check `ray status` for `Pending Demands` line — it tells you exactly what the scheduler can't fit

## Verification after completion

1. `aws s3 ls --recursive s3://…/sidecar_prefix/ | wc -l` should equal main shard count
2. `pq.read_table(sidecar_shard).num_rows` == `pq.read_table(main_shard).num_rows` for random samples
3. Train-time, enforce `source IS NOT NULL` (or `filter_clarity.passed IS NOT NULL`) to drop unmatched rows

## Historical metrics (part 1, 323K shards / 330M rows)

- actors table-load: ~15 min (sstk is the biggest, 130M rows)
- processing phase: ~10h @ 4.7-12 shards/s (varies with source — sstk shards are denser than bigstock)
- final match rate: 68.7% (100M+ rows were from a 5th path prefix NOT in SOURCES — expected; filled with null)
- cost: 10 × r5.12xlarge × 10h ≈ $300 on-demand
