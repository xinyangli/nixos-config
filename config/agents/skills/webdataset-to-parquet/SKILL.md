---
name: webdataset-to-parquet
description: Pack tar or zip webdataset-style sources into canonical bucketed main Parquet, preserve metadata into meta_info, tune writer memory, and verify output shards.
---

# Webdataset To Parquet

## Purpose

Use this skill when the raw dataset is stored in tar/zip/webdataset files rather
than as loose images or a JSONL manifest. Typical inputs are:

- `batch_0000.tar`, `batch_0001.tar`, ...
- image members such as `{key}.png`, `{key}.jpg`, `{key}.webp`
- sidecar members such as `{key}.json` or `{key}.txt`

The output is canonical main Parquet:

```text
s3://core-cn-oss.canva.com/dataset/<dataset>_parquet/<scale>/<ar_id>/shard_000000.parquet
```

For the standard dataset-processing pipeline, prefer first deriving a JSONL
entry manifest with one row per image and a normalized `s3_image_path`. Direct
archive-to-Parquet packing is acceptable only when the pack pipeline also
emits or records the equivalent JSONL manifest contract for audit and replay.

## Intake Checklist

Before a full pack:

1. Inspect at least one archive.
2. Confirm member pairing: image + JSON/TXT.
3. Enumerate all JSON metadata keys.
4. Decide the canonical key and `s3_image_path`.
5. Estimate average image bytes and row count per archive.
6. Pick `shard_size` and `writer_memory_gb`.

Do not assume archive metadata is unimportant. All metadata that is not a
canonical top-level column must go into `meta_info`.

## Schema Mapping

Map known fields into canonical top-level columns:

- `image_key`
- `image`
- `width`
- `height`
- `s3_image_path`
- `is_rgba`
- `task`
- `data_source`
- `ocr_text`
- `full_description`
- `short_description`
- `user_prompt`
- `image_type`

Put all dataset-specific fields into `meta_info`.

Example mapping:

```yaml
mapping:
  constants:
    task: "text to image generation"
    data_source: "<dataset>"
  direct:
    image_key: [__key__]
    s3_image_path: [__url__]
    full_description: { from: [json.caption], cast: list_string }
    ocr_text: { from: [json.text], cast: list_string }
    short_description: { from: [json.title], cast: list_string }
  meta_info:
    column: meta_info
    from_fields:
      - __key__
      - __shard__
      - json.source
      - json.license
      - json.author
      - json.extra_metadata
```

## Writer Sizing

Writer memory is driven by `shard_size * average_row_bytes`, not just by the
Ray memory reservation.

Rules of thumb:

- PNG-heavy or poster-heavy rows: `shard_size: 1000`.
- JPEG/WEBP rows around 200 KB: `shard_size: 5000` can be acceptable.
- Avoid `shard_size: 10000` for PNG-heavy datasets.
- For high bucket counts, set `writer_memory_gb` explicitly to keep writer
  actors schedulable.

Example:

```yaml
packing:
  mode: bucketed
  shard_size: 1000
  image_source: from_record
  image_field: png
  writer_memory_gb: 4
```

## UTP Pack Job

Keep `max_retries: 2` for large archive jobs; Karpenter startup taints can kill
one pod during scale-up.

Example job shape:

```yaml
name: ${arnold_job_name}
max_retries: 2
image_uri: "${arnold_docker_build:ds-core-cn-omra-trainer,.,deploy/Dockerfile,deploy_core-cn-readwrite}"

entrypoint: >
  sidecar-ops pack /app/pipelines/<dataset>_pack.yaml
  --use-ray
  --max-inflight 64
  --task-cpus 4
  --task-memory-gb 24

compute_config:
  head_node:
    instance_type: r5.4xlarge
  worker_nodes:
    - name: cpu_worker
      instance_type: r5.4xlarge
      min_nodes: 6
      max_nodes: 6
      market_type: 'ON_DEMAND'
  flags:
    workload_starting_timeout: 1h
```

Check the actual `sidecar-ops pack --help`; do not copy `--skip-existing` from
`sidecar-ops run` unless the pack subcommand supports it.

## Verifier

After pack:

1. Count archive inputs, parquet shards, and rows.
2. Read a random sample of shard footers.
3. Decode sampled image bytes.
4. Verify all canonical columns exist.
5. Verify source-specific metadata is in `meta_info`.
6. Verify row counts are close to `shard_size` except tail shards.
7. Build a small visualization from random rows.

Useful checks:

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../<dataset>_parquet/ --recursive --summarize
```

```python
import pyarrow.parquet as pq
tab = pq.read_table("sample.parquet")
print(tab.schema)
```

## Stall Debugging

If the pack appears stuck:

- Check `ray status` for pending writer actors.
- If pending memory demand is high, lower `writer_memory_gb` or bucket count.
- Check worker logs for `OOMKilled`.
- Check for PIL decompression warnings on huge images.
- Inspect driver in-flight refs; unbounded refs can crash at final `ray.get`.

## Guardrails

- Do not drop JSON metadata just because it is not a canonical column.
- Do not join image and metadata members by basename without confirming archive
  naming rules.
- Do not full-decode huge images just to get dimensions; header probe is enough
  during inventory.
- Do not proceed to CPU filter until main Parquet decode and schema verifiers
  pass.
