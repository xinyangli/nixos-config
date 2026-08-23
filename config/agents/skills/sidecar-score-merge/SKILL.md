---
name: "sidecar-score-merge"
description: "Merge DQM-d1-V6.1 and ERNIE-Image-Aes score sidecar Parquet outputs into an existing row-aligned sidecar Parquet dataset. Use when Codex needs to create an all-in-one sidecar from filter sidecars plus DQM/AES key-score sidecars, add merge_from_sidecar dataset and pipeline YAMLs, submit CPU-only UTP merge jobs, or validate merged score sidecar schemas and shard alignment."
---

# Sidecar Score Merge

## Overview

Use this skill to combine already-computed GPU score sidecars with an existing
row-aligned sidecar dataset. This is a CPU-only parquet merge; do not rerun DQM
or ERNIE-Image-Aes inference for this step.

Work in the checkout identified by `${SIDECAR_PARQUET_OPS_REPO}`. Also use
`sidecar-parquet-ops-repo` for repo patterns and `utp-job-submission` when
submitting or monitoring jobs.

## Inputs

Collect these values before editing files:

- Base sidecar prefix: the existing row-aligned sidecar to preserve, usually a
  filters sidecar.
- DQM sidecar prefix: contains `dqm_d1_v6_1`.
- AES sidecar prefix: contains `ernie_image_aes`.
- Output prefix: normally under
  `s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/.../`.
- Key columns: DQM is usually keyed by `image_key`; AES may be keyed by
  `s3_image_path`. Check actual columns before assuming.

The merge expects the source sidecars to share the same relative parquet shard
paths as the base sidecar. `merge_from_sidecar` reads each sibling shard and
asserts row count and key equality before copying columns.

## File Pattern

Add a dataset YAML under `datasets/` whose `main_prefix` is the base sidecar and
whose `sidecar_prefix` is the final all-in-one output:

```yaml
name: example_filters_dqm_ernie_image_aes
browse: false

main_prefix: s3://.../example_sidecar_filters/
sidecar_prefix: s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/example/

key_column: image_key
image_column: image

source_inference:
  default: example

schema_extensions:
  - { name: filter_clarity, type: filter_clarity_v1 }
  - { name: filter_texture, type: filter_texture_v1 }
  - { name: filter_saturation, type: filter_saturation_v1 }
  - { name: filter_luma, type: filter_luma_v1 }
  - { name: filter_color_entropy, type: filter_color_entropy_v1 }
  - { name: filter_edge_density, type: filter_edge_density_v1 }
  - { name: dqm_d1_v6_1, type: dqm_score_v1 }
  - { name: ernie_image_aes, type: ernie_image_aes_score_v1 }
```

Match the existing filter columns to the real base sidecar schema. Do not add
image bytes; this flow works on sidecar parquet.

Add a pipeline YAML under `pipelines/`:

```yaml
dataset: example_filters_dqm_ernie_image_aes

operations:
  - type: merge_from_sidecar
    source_prefix: s3://.../example_sidecar_dqm_key_score_v1/
    columns: [dqm_d1_v6_1]
    mode: prefer_sidecar

  - type: merge_from_sidecar
    source_prefix: s3://.../example_sidecar_ernie_image_aes_v1/
    columns: [ernie_image_aes]
    target_key_column: s3_image_path
    source_key_column: s3_image_path
    mode: prefer_sidecar
```

Only set `target_key_column` and `source_key_column` when the score sidecar is
aligned by a non-dataset key such as `s3_image_path`. If both sides use
`image_key`, omit these two fields.

Add a CPU UTP YAML under `deploy/`:

```yaml
name: ${arnold_job_name}
max_retries: 1

image_uri: "${arnold_docker_build:ds-core-cn-omra-trainer,.,deploy/Dockerfile,deploy_core-cn-readwrite}"

entrypoint: >
  sidecar-ops run /app/pipelines/example_merge_filters_dqm_ernie_image_aes.yaml
  --use-ray
  --skip-existing
  --debug
  --output-prefix s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/example/
  --max-inflight 128
  --task-cpus 1
  --task-memory-gb 4

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
      min_nodes: 4
      max_nodes: 4
      market_type: 'ON_DEMAND'
  flags:
    workload_starting_timeout: 1h
```

Use more CPU nodes for large shard counts, but keep this GPU-free.

## Run

First do a cheap local config check:

```bash
sidecar-ops run pipelines/example_merge_filters_dqm_ernie_image_aes.yaml \
  --dry-run \
  --output-prefix s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/example/
```

Submit with Arnold:

```bash
FORCE_NO_BAZEL_REMOTE_EXECUTION=true arnold -x submit --no-login \
  --job-name "example-merge-dqm-aes-$(date +%s)" \
  --compute-config deploy/utp_example_merge_filters_dqm_ernie_image_aes.yaml \
  --application-id core-cn
```

If YAML files were newly added to the repo, ensure the deploy image is rebuilt
or use the `arnold_docker_build` macro in the UTP YAML so `/app/pipelines/...`
and `/app/datasets/...` exist inside the job image.

## Validate

Compare shard counts:

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../base_sidecar/ --recursive --summarize
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../dqm_sidecar/ --recursive --summarize
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../ernie_image_aes_sidecar/ --recursive --summarize
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../all_in_one_output/ --recursive --summarize
```

Verify base-to-output alignment:

```bash
sidecar-ops verify pipelines/example_merge_filters_dqm_ernie_image_aes.yaml \
  --output-prefix s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/example/ \
  --samples 50
```

Sample schema and score errors:

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" python - <<'PY'
from urllib.parse import urlparse
import boto3
import pyarrow.fs as pafs
import pyarrow.parquet as pq

uri = "s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/example/"
bucket = urlparse(uri).netloc
prefix = urlparse(uri).path.lstrip("/")
s3 = boto3.client("s3")
resp = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
key = next(o["Key"] for o in resp.get("Contents", []) if o["Key"].endswith(".parquet"))
tab = pq.read_table(f"{bucket}/{key}", filesystem=pafs.S3FileSystem(region="us-east-1"))
print(tab.schema)
for col in ["dqm_d1_v6_1", "ernie_image_aes"]:
    if col in tab.column_names:
        vals = tab[col].to_pylist()
        errors = sum(1 for v in vals if isinstance(v, dict) and v.get("error"))
        null_scores = sum(1 for v in vals if isinstance(v, dict) and v.get("raw_score") is None)
        print(col, "rows", len(vals), "errors", errors, "null_raw_score", null_scores)
PY
```

Expected score columns:

- `dqm_d1_v6_1`: struct with at least `raw_score` and `error`.
- `ernie_image_aes`: struct with at least `raw_score`, `score`, and `error`.

## Guardrails

- Do not use filename joins or global indexes when the sidecars are row-aligned;
  use `merge_from_sidecar` so every shard asserts alignment.
- Do not rewrite or move the original base sidecar. Write to a new explicit
  `--output-prefix`.
- Do not omit `--skip-existing`; resume should be shard-based.
- If the AES sidecar has `s3_image_path` but the base sidecar lacks it, stop and
  inspect the upstream sidecar. Do not silently fall back to basename matching.
