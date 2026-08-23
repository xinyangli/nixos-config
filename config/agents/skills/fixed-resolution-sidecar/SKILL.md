---
name: fixed-resolution-sidecar
description: Build 512-area and 1024-area resized image Parquet datasets, preserve row keys, audit valid/invalid rows, and feed crop metadata back into structured_description bbox columns.
---

# Fixed Resolution Sidecar

## Purpose

Build resized image Parquet datasets from a canonical main Parquet without
rewriting the original dataset. The common Core CN outputs are:

- `0_262mp_version_all_in_one/<dataset>/` for 512-area images.
- `1_05mp_version_all_in_one/<dataset>/` for 1024-area images.

These are image Parquet datasets. They contain resized image bytes and audit
metadata. The final all-in-one sidecar later uses their resize metadata to
create `structured_description_crop_512`, `structured_description_crop_1024`,
and `bbox_resize_meta`.

## Output Contract

For each resized output:

- Preserve the same relative shard layout as the main Parquet.
- Preserve the row order and key column.
- Preserve aspect ratio. Do not force a square crop unless explicitly required.
- Use WEBP quality 95 unless there is a dataset-specific reason to change it.
- Keep invalid rows with audit metadata when the implementation supports it;
  do not silently drop rows.

Recommended prefixes:

```text
512  -> s3://core-cn-oss.canva.com/dataset/0_262mp_version_all_in_one/<dataset>/
1024 -> s3://core-cn-oss.canva.com/dataset/1_05mp_version_all_in_one/<dataset>/
```

## UTP Pattern

Use `sidecar-ops build-0-262mp` or the current resize op in
`sidecar_parquet_ops`. Keep jobs CPU-only.

Example shape:

```yaml
name: ${arnold_job_name}
max_retries: 1

image_uri: "${arnold_docker_build:ds-core-cn-omra-trainer,.,deploy/Dockerfile.resize_cpu,deploy_core-cn-readwrite}"

entrypoint: >
  sidecar-ops build-0-262mp
  --main-prefix s3://core-cn-oss.canva.com/dataset/<dataset>_parquet/
  --output-prefix s3://core-cn-oss.canva.com/dataset/0_262mp_version_all_in_one/<dataset>/
  --key-column image_key
  --audit-prefix 0_26mp_process
  --patch-size 32
  --use-ray
  --skip-existing
  --max-inflight 32
  --task-cpus 4
  --task-memory-gb 12
  --threads-per-shard 4
  --output-format webp
  --quality 95

env_vars:
  CANVA_FLAVOR: prod
  FLAVOR: prod
  CANVA_PLATFORM: eks
  PIP_CONSTRAINT: ""
  RAY_SCHEDULER_EVENTS: '0'

compute_config:
  head_node:
    instance_type: r5.4xlarge
  worker_nodes:
    - name: cpu_worker
      instance_type: m5.4xlarge
      min_nodes: 8
      max_nodes: 8
      market_type: 'ON_DEMAND'
  flags:
    workload_starting_timeout: 1h
```

For 1024-area output, use the repo's current 1024 resize command or pipeline
variant and set:

```text
--output-prefix s3://core-cn-oss.canva.com/dataset/1_05mp_version_all_in_one/<dataset>/
--audit-prefix 1_05mp_process
```

## Crop Bbox Merge

After both resized image Parquet outputs exist, run a sidecar pipeline that
reads:

- original `structured_description`
- 512 resize audit metadata
- 1024 resize audit metadata

and writes:

- `structured_description_crop_512`
- `structured_description_crop_1024`
- `bbox_resize_meta`

The original `structured_description` stays in the original image coordinate
frame. Crop variants must also use normalized `0-1000` yxyx bboxes.

## Verifier

Run these checks before using the resized outputs downstream:

1. Shard count:

   ```bash
   AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../main/ --recursive --summarize
   AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../0_262mp_version_all_in_one/<dataset>/ --recursive --summarize
   AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../1_05mp_version_all_in_one/<dataset>/ --recursive --summarize
   ```

2. Sample key alignment and decode:

   - same row count as source shard
   - same key column values
   - image bytes decode with PIL
   - dimensions are near target area and preserve aspect ratio

3. Audit columns:

   - count valid and invalid rows
   - report invalid examples
   - verify invalid rows are not silently omitted

4. Crop caption columns:

   - `structured_description_crop_512` exists and has valid bboxes
   - `structured_description_crop_1024` exists and has valid bboxes
   - `bbox_resize_meta` records source and target dimensions
   - sampled overlay visualization renders original, 512, and 1024 bboxes

## Guardrails

- Treat "512" and "1024" as fixed image area unless the project explicitly
  requires square crops.
- Never overwrite the main Parquet.
- Keep resized outputs separate from the all-in-one sidecar.
- Use `--skip-existing` when available.
- Do not proceed to crop-aware JSON caption merge until both resized outputs
  have verifier results.
