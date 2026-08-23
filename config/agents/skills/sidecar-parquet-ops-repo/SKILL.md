---
name: sidecar-parquet-ops-repo
description: Work in the sidecar-parquet-ops repo for YAML-driven sidecar datasets, ops, schemas, runtimes, Docker builds, and runtime selection. Use before adding datasets, pipelines, filters, side-input joins, or recaption ops.
---

# sidecar-parquet-ops (generic repo)

Companion to `sidecar-parquet-enrichment` (the runbook for the one-off script). This skill is about the **reusable abstraction**: datasets declared in YAML, pipelines as ordered op lists, a registry pattern for ops, and runtimes that consume the same pipeline YAML.

## When to use which

| Need                                                    | Use                                                      |
| ------------------------------------------------------- | -------------------------------------------------------- |
| One-off: existing shutterstock-style 2-stage pipeline   | `sidecar-parquet-enrichment` skill + annotation_batch_infer scripts |
| New dataset, same filter schema                         | sidecar-parquet-ops: add `datasets/<name>.yaml` only     |
| New op type (e.g. `join_from_parquet` / `recaption`)    | sidecar-parquet-ops: add `sidecar_ops/ops/<name>.py` + `@register_op` |
| Side-input (loaded-once-per-worker blob)                | op declares `declare_side_inputs()`; actor runtime loads via registry |

## Core abstractions (load these when editing)

- **Op registry** (`sidecar_ops/core/operation.py`): `@register_op` decorator populates `_REGISTRY`, pipelines resolve ops by `type_name`. An op is `apply(table, ctx) → table` with optional `validate(dataset)` and `declare_side_inputs(dataset)`.
- **Schema registry** (`sidecar_ops/core/schema.py`): primitives + YAML-declared structs in `sidecar_ops/schemas/*.yaml`. Datasets reference struct types by name (e.g. `filter_clarity_v1`). `null_scalar_for(dtype)` builds a recursive-null dict for struct types.
- **Pipeline loader**: `load_pipeline(yaml_path)` resolves the dataset ref either by absolute path or by walking up from the pipeline file for `datasets/<name>.yaml`.
- **Runtimes**: `runtime_local` (single-process), `runtime_ray` (stateless `@ray.remote` sliding window, side-inputs NOT supported — raises `NotImplementedError`), and `runtime_actor` (actor-per-slot pool with `max_concurrency = per_actor_inflight`, side-inputs loaded once per actor in `__init__`). Driver dispatches round-robin across actors, picking the actor with the fewest in-flight calls each submit tick.

## Non-obvious behaviors worth remembering

**Struct "null" is nested dict, not column null.** `null_scalar_for(pa.struct(...))` returns `{field: None, ...}` so `pa.array([val] * n, type=struct)` yields a row with `null_count == 0` at the column level but every child field null. Tests should assert child-field nullness, not column nullness. Same pattern as the one-off `EMPTY` dict in `build_sidecar_parquet.py` — do not "fix" this to return a truly null struct.

**Ray workers re-load pipeline YAML per task.** `runtime_ray` passes the pipeline's **path** (not the Pipeline object) to `@ray.remote` workers to avoid pickling BaseOp instances. Each shard reparses 4 YAML files (~<10ms). Fine for S3-IO-bound work, **not** for tasks <100ms. If you ever hit that regime, cache the Pipeline as a Ray object ref.

**`image_column` is dropped inside the runtime, not by any op.** The runtime drops the dataset's `image_column` from the main shard before invoking the first op, because image bytes are the biggest column and no sidecar op needs them. Don't add a redundant `drop_column` op for it.

**`dataset.main_prefix` and `sidecar_prefix` are normalized to end with `/` in `load_dataset`.** If you build S3 URIs by string-concat, trust the trailing slash is there.

## Alignment check handles null-vs-null correctly

`assert_alignment` treats null↔null in the key column as a **mismatch** — otherwise a key-column bug could slip through by producing nulls on both sides. Implementation computes a fail mask via `pc.fill_null(pc.invert(pc.equal(m, s)), True)` and reads the first true index. This caught a bug during bootstrapping where the original slow path assumed nulls compare equal and crashed on `None != None`.

## `--output-prefix` is the anti-overwrite switch

`sidecar-ops run` has an `--output-prefix <uri>` flag that overrides `dataset.sidecar_prefix` for writes only (the dataset YAML itself is never mutated). If the flag is NOT passed, the CLI auto-generates a timestamped sibling `<sidecar_prefix>_run_YYYYMMDD_HHMMSS/` and prints a prominent stderr warning — this is deliberate so that `sidecar-ops run pipelines/foo.yaml` never silently overwrites a production folder.

Behavioral rules:
- Pass an explicit `--output-prefix s3://.../folder/` for scheduled / production runs. UTP templates in `deploy/*.yaml` already do this.
- The `--skip-existing` scan uses the **effective** output prefix (not `dataset.sidecar_prefix`), so resuming a partial run with the same `--output-prefix` works as expected.
- `sidecar-ops verify` also accepts `--output-prefix` to point the alignment check at a specific run's folder.
- `--dry-run` prints both `sidecar_prefix (yaml)` and `effective output` so you can confirm what would be written before dispatching.

Implementation: `_resolve_output_prefix` in `cli.py` is the single source of truth; each runtime (`runtime_local` / `runtime_ray` / `runtime_actor`) accepts `output_prefix` kwarg and threads it through to `write_parquet` + skip-existing listing. `runtime_ray` passes it as a per-task arg (workers re-parse the pipeline YAML but write to the driver-chosen prefix); `runtime_actor` passes it to `_ShardActor.__init__` once per actor.

## Dry-run CLI is not just cosmetic

`sidecar-ops run <pipeline> --dry-run` runs the full `load_pipeline` → `collect_specs` → `list_keys` chain without reading shards. Use this as **step 1** of any debug (cheap, verifies YAML + registry + S3 listing + side-input specs in one shot). Added while bootstrapping getty_retry — the 1509-shard listing takes ~2s and immediately tells you if prefix/profile/region are wrong.

## Docker: `pip install --no-deps /app`

The CLI is wired via `pyproject.toml` → `[project.scripts] sidecar-ops = sidecar_ops.cli:main`. `pip install --no-deps /app` installs the wheel into the base image's site-packages and exposes `/usr/local/bin/sidecar-ops`, **without** re-resolving deps that are already in the base image. We pin required deps manually with a separate `pip install --no-cache-dir pyarrow zstandard click pyyaml` **above** the install step. Skipping `--no-deps` would pull torch/cuda wheels from PyPI and explode the image.

Schemas live under `sidecar_ops/schemas/*.yaml` — the hatch wheel config (`packages = ["sidecar_ops"]`) automatically bundles them. `datasets/` and `pipelines/` live at repo root; the Dockerfile copies them explicitly into `/app/` so the UTP entrypoint `sidecar-ops run /app/pipelines/...` resolves.

**New pipelines / datasets require an image rebuild.** Adding a new file under `pipelines/` or `datasets/` is not auto-deployed — the running UTP image is whatever tag was last pushed to ECR. Submitting an arnold job that points at a not-yet-shipped yaml fails fast with `Error: Invalid value for 'PIPELINE_PATH': File '/app/pipelines/...yaml' does not exist`; this has been observed to exit the head pod within ~10s. Run `bash deploy/build_and_push.sh <new-tag>` and bump the deploy yaml's `image_uri` before submitting. The op registry (`@register_op`) and schema yaml are bundled into the wheel via hatch, so adding a new op or struct also needs a rebuild — only adding rows to `datasets/<existing>.yaml` for an already-shipped dataset can skip rebuild (it's CLI-arg-driven via `--input-subprefix`).

## UTP verify pattern

Single-head `compute_config` with no `worker_nodes` is the cheapest way to run a verify/audit script on UTP. The jobset will show `status: Failed` at the end (no worker pods = failure policy triggers) even though the head exited 0 with "All N sampled shards aligned" in the log. Look at the log, not the jobset status. If you need a clean UI, add a dummy worker (`min_nodes: 1, max_nodes: 1`) or have the entrypoint touch an S3 sentinel on success and check for it.

## Historical performance (getty_retry, Phase 2)

- 1509 main shards, 229,210 rows total (avg ~150 rows/shard, many are 1 row)
- Local single-process: ~40s/shard (S3 IO dominated, 1-row shards are the worst case)
- UTP 4 × m5.4xlarge × 16 vCPU = 64 stateless Ray tasks: **88.4s total**, ~17 shards/s, ~170× speedup
- Verify 50 random samples: <60s

## Extending

- **New primitive/struct**: add to `sidecar_ops/schemas/*.yaml`, reference by `type_ref` in dataset YAML.
- **New op with no side-input**: new file under `sidecar_ops/ops/`, decorate with `@register_op`, import from `sidecar_ops/ops/__init__.py`. Works with `runtime_local` and `runtime_ray`.
- **New op with side-input**: implement `declare_side_inputs` returning `{name: SideInputSpec(loader=..., params=...)}`; register a loader via `@register_side_input_loader(name)`. Must be driven by `runtime_actor` — `runtime_ray` raises `NotImplementedError` when any op declares side-inputs. The built-in `join_from_parquet` (with `parquet_index` loader) is the reference implementation.
- **New dataset**: add `datasets/<name>.yaml`, pick `main_prefix`/`sidecar_prefix`/`key_column`, declare `schema_extensions` referencing types from `sidecar_ops/schemas/`. Pipelines just reference the dataset by name.

## join_from_parquet + runtime_actor usage pattern

- Pipeline YAML:
  ```yaml
  dataset: getty
  operations:
    - type: extract_scaffold   # fill all sidecar cols with null-struct defaults
    - type: join_from_parquet
      source: s3://.../merged_filter_index.parquet
      columns: [filter_clarity, filter_texture, filter_saturation, filter_luma, filter_exif_rotation, filter_color_entropy]
      mode: overwrite_all       # or update_if_null to keep existing non-null structs
  ```
- CLI: `sidecar-ops run pipelines/<name>.yaml --use-actor --num-actors 4 --actor-cpus 16 --actor-memory-gb 48 --per-actor-inflight 16 --skip-existing`
- `mode: update_if_null` treats a struct row as "null" when **every** child field is null (matches the `_is_struct_row_null` helper) — this mirrors the production scaffold `EMPTY` dict.
- The `parquet_index` loader pulls the full index into a Python dict `{key: {col: scalar_or_struct_dict}}`. For 100M-key indices, consider sharding the index by hash or using a keyed-lookup backend before scaling beyond memory.

## Gotchas from bootstrap

- **Non-interactive shell + a credential-process AWS profile** → Roo stepup can fail because there is no TTY. Work around by submitting verify/audit jobs to UTP (IRSA, no `credential_process`) instead of looping on local prompts.
- **`ray.wait(inflight, num_returns=min(50, len(inflight)))`** is the canonical sliding-window idiom. `num_returns=1` makes the driver chatty; larger batches amortize Python-side overhead without losing fairness.

## merge_from_sidecar op

Pull row-aligned columns from a sibling sidecar parquet into the current shard before compute_filters / other ops run. Used when the new sidecar needs to carry every column from an existing sidecar (e.g. getty's `_sidecar_0503_ocrRecaption/` with OCR + recaption columns) without rerunning the upstream logic.

YAML:
```yaml
operations:
  - type: merge_from_sidecar
    source_prefix: s3://.../getty_parquet_sidecar_0503_ocrRecaption/
    mode: prefer_sidecar          # or "fill_missing" (default)
    # columns: optional allow-list; if omitted, pulls every non-key col
    # required: true by default; set false to no-op when the sibling shard is missing
```

Two modes:
- `fill_missing` (default) — only pulls columns the main table doesn't already have. Main wins on overlap.
- `prefer_sidecar` — pulls every requested column; sidecar overwrites main on overlap EXCEPT `key_column` + `image_column` (always kept from main so compute_filters sees the real image and alignment checks work).

Per-shard, reads `{source_prefix}{rel_path}`, asserts `num_rows + key_column` match, then merges columns. Does NOT load the sibling sidecar as a side-input (no global index) — each shard reads its own sibling file.

## Subprocess-isolated filter for cv2/libjpeg

`sidecar_ops/core/subprocess_worker.py` exposes `submit_call(fn, *args, timeout=60) -> result` that runs `fn` in a long-lived worker subprocess managed by pebble.

**Critical config:** the pool must use `multiprocessing.get_context("spawn")`, not the default fork. Fork inherits the threaded parent's OpenCV/libjpeg state and the first cv2 call in the worker crashes or hangs. `max_workers` should match the caller's thread pool (e.g. `compute_filters.threads=4` → pool size 4) — a size-1 pool starves and returns "Unexpected error within the Pool".

Used by `vendor_filters/jpeg_artifact.py`: the whole cv2-heavy detector pipeline lives in a top-level pure function `_run_detectors_isolated(image_data, record, cfg)`. A SIGABRT in the worker becomes `WorkerCallFailed` in the parent → filter returns a null-filled `FilterResult` → just that row is null in the output. Pebble respawns the worker automatically.

Extend this pattern whenever a filter wraps a C library that can `abort()` on bad input. Do not rely on `try/except` for SIGABRT — it bypasses Python's exception machinery.

## Choosing `--use-ray` vs `--use-actor` (single-filter trap)

The two distributed runtimes produce identical output but their concurrency
shapes are very different. Pick wrong on a single-filter pipeline and you get
~20× slowdown. In one pin_91M edge_density run, actor mode estimated ~80h
while ray-task mode finished in 3h47min on 942 shards / 89.25M rows.

**Root cause:** `sidecar_ops/vendor_filters/base.py:_DECODE_LOCK` is a
process-wide `threading.Lock` that serializes `cv2.imdecode` and
`PIL.Image.open` to prevent libjpeg/libpng SIGABRT on malformed images
(Pinterest, Getty raw, DataComp web crawl all have these). The lock is
**per-process**, so:

- `--use-actor` runs one process per actor, so `_DECODE_LOCK` is shared by
  every thread inside that actor (`per_actor_inflight × threads`).
- `--use-ray` runs one process per shard task, so each task has its own
  independent lock — no cross-task contention.

For a multi-filter pipeline (Pinterest / Getty 8-filter `filters_v1`) decode
is ~10-20% of per-row time and the lock isn't the bottleneck. For a
**single-filter** pipeline (e.g. just `edge_density`) decode is ~100% of
per-row CPU and the actor's threads serialize entirely — visible as
N-1 threads parked in `futex_wait_queue` (check via
`cat /proc/PID/task/*/status` or py-spy on a worker pod).

**Decision matrix:**

| Pipeline shape                                 | Runtime              | Why |
|------------------------------------------------|----------------------|------|
| 1-2 filters, no side-inputs                    | `--use-ray --max-inflight 320 --task-cpus 1 --task-memory-gb 4` | bypass `_DECODE_LOCK` via process isolation |
| 8+ filters, no side-inputs                     | `--use-actor`        | actor decodes once per row, shared `DecodeCache` saves cv2.imdecode reuse across filters |
| any side-inputs (`join_from_parquet`, `recaption_merge`) | `--use-actor`  | `runtime_ray` raises `NotImplementedError` when ops declare side-inputs |
| local debug                                    | (no flag)            | `runtime_local` single-process |

**Reference deploy yamls:**
- `deploy/utp_pin_91M_edge_density_ray_tasks.yaml` — ray-task single-filter
- `deploy/utp_pin_91M_compute_filters.yaml` / `utp_getty_main_compute_filters.yaml` — actor 8-filter

**Don't try to fix `_DECODE_LOCK` itself** — it's the SIGABRT-mitigation for
fork-unsafe cv2/libjpeg (see `feedback_cv2_fork_unsafe_use_spawn` memory).
Removing it will reproduce the Pinterest/Getty actor-death storms.

## CPU filter throughput sizing

Do not size full CPU-filter jobs from small default templates. The production
target is **10M accepted input rows/hour** for the standard multi-filter CPU
sidecar pass when resources are available.

Sizing formula:

```text
target_shards_per_hour = target_rows_per_hour / rows_per_shard
target_shards_per_sec = target_shards_per_hour / 3600
required_actors = ceil(target_shards_per_sec / observed_shards_per_sec * observed_actors)
```

For the common 512-row shard size:

```text
10,000,000 rows/hour = 19,532 shards/hour = 5.43 shards/sec
```

Always run a smoke or short full-prefix sample first and use its Ray log rate:

```text
Shard progress: completed=... rate=<observed_shards_per_sec> shards/s
```

Infographics benchmark from 2026-07-09:

- Pipeline: 9 CPU filters (`exif_rotation`, `exif_metadata`, `saturation`,
  `jpeg_artifact`, `clarity`, `texture`, `luma`, `color_entropy`,
  `edge_density`) over 512-row image-byte shards.
- Low-throughput config: 16 x `m5.4xlarge`, 32 actors, `actor_cpus=4`,
  `actor_memory_gb=20`, `per_actor_inflight=3`.
- Observed rate after warmup: about `0.12 shards/s` = about `0.22M rows/hour`.
- To hit 10M rows/hour for this workload, use roughly 45x more actor
  parallelism: about 1,500-1,600 actors.
- A practical starting UTP shape is one job with 40 x `m5.24xlarge`, 1536
  actors, `actor_cpus=1`, `actor_memory_gb=6`, `per_actor_inflight=1`, and
  `SIDECAR_OPS_DEBUG_PROGRESS_ROWS=512`. The extra nodes are needed because
  32 x `m5.24xlarge` exposes only about 8.3TiB to Ray, which cannot fit
  1536 actors at a 6GB memory reservation.
- If UTP pod anti-affinity or queue policy only schedules 32 workers, keep the
  1536-actor target and lower the reservation to `actor_memory_gb=5`; this
  fits about 7.5TiB of actor reservations into the observed 8.3TiB Ray memory.

Rules:

- Keep exactly one writer job per sidecar output prefix. If scaling up a
  running job, cancel the old job and resume the same prefix with
  `--skip-existing`.
- Prefer more actor processes over high `per_actor_inflight` for dirty image
  CPU filters, because the decode lock is per process.
- Before waiting for output, verify `ray status` has no pending actors for the
  requested `CPU`/`memory` bundle. If actors remain pending, increase nodes or
  lower the actor memory reservation and resubmit the same prefix with
  `--skip-existing`.
- Watch actual S3 object growth and Ray `Shard progress`; Kubernetes `Running`
  only proves the cluster exists.
- If the large job cannot be scheduled, reduce actors and nodes together while
  preserving the target math in the handoff note.

## Case study: getty filter stability

First-run pexels (7.5M clean jpegs) passed through the filter pipeline with 0 fail on v21 code. getty main (87M, includes many corrupt/truncated jpegs) failed ~100% on the same code — looked like OOM because Ray surfaces every native-library SIGABRT as "actor died unexpectedly / Worker exit type: SYSTEM_ERROR / exits with connection error code 2". The error text literally lists OOM as option 1.

Earlier attempts tuned `--per-actor-inflight`, `actor-memory-gb`, instance type, S3FS streaming, iter_batches streaming, and explicit `del`/`gc.collect()` without fixing the failures. `kubectl top pods` showed RSS at 6-16 GB on 64 GB nodes the whole time; if it had been real OOM, RSS would have approached the reservation.

The actual issues, fixed in v36:
1. `cv2.Canny` SIGABRT on corrupt jpegs — fixed via subprocess-isolated `jpeg_artifact`.
2. `ExifRotationFilter` returned PIL's raw bytes/tuples for malformed EXIF tags, crashing `pa.array(..., type=int32)` at shard-build time — fixed via defensive coerce to int/None.
3. Top-level `pa.array` build now tries row-by-row on ArrowInvalid and nulls the bad row rather than throwing (in `compute_filters.apply`).

**Lesson for future large/dirty datasets:** a clean small dataset doesn't validate a large dirty one. Before declaring success on a new dataset, grep for `Fatal Python error` / `Traceback` in actor stderr and sample populated vs null rates on the output sidecar. "Clean dataset X passed" ≠ "dataset Y will pass."
