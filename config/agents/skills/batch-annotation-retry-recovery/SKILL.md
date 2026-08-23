---
name: batch-annotation-retry-recovery
description: Recover and retry failed records from Gemini batch annotation jobs. Covers grid-level retry (no re-concat), full re-concat retry pipelines, and after concat — how to upload manifest to S3, split shard ranges across teammates, run with --use-concat, postprocess, and use the Streamlit dashboard. Use when handling failed Vertex AI batch predictions, shutterstock retry jobs, or distributing annotation work to a team.
---

# Batch Annotation Retry & Recovery

Two strategies depending on failure scale and type.

## Strategy 1: Grid-Level Retry (No Re-Concat)

Best when: a few grids failed per shard (Gemini errors, safety filters, partial uploads). Concat images already exist.

**Do NOT re-concatenate.** Re-submit only failed `concat_gcs_uri` to a new Gemini batch job targeting the same GCS output dir. Postprocess merges and dedupes.

```bash
# Dry-run
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/retry_failed_grids.py \
  --work-dir /mnt/ephemeral/my_task/ --shards 0-9 --no-submit

# Submit
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/retry_failed_grids.py \
  --work-dir /mnt/ephemeral/my_task/ --shards 0-9
```

Then re-postprocess with `--force`.

## Strategy 2: Full Re-Concat Retry (New Pipeline)

Best when: many failed records across multiple datasets, or the original concat images are no longer usable. Creates a brand new task from collected failed records.

### Step-by-Step

#### 1. Collect Failed Records

After postprocessing, each shard has `failed/shard_XXXX.jsonl` containing records that had no valid caption. Verify:

```bash
# Count failed records per dataset
for dir in /mnt/ephemeral/dataset1/ /mnt/ephemeral/dataset2/; do
    name=$(basename "$dir")
    total=$(find "${dir}failed" -name "shard_*.jsonl" -exec wc -l {} + | tail -1 | awk '{print $1}')
    size=$(du -sh "${dir}failed" | awk '{print $1}')
    echo "$name: $total failed records, $size"
done
```

#### 2. Upload Failed Records to S3 as New Input

Upload all failed JSONLs to a unified S3 prefix. Add dataset prefix to avoid filename collisions:

```bash
S5CMD="$(command -v s5cmd)"
S3_INPUT="s3://core-cn-oss.canva.com/dataset/shutterstock_4K_webp/retry_v2_caption_input/"

# Per dataset — add prefix to shard names
for f in /mnt/ephemeral/dataset1/failed/shard_*.jsonl; do
    AWS_PROFILE="${AWS_PROFILE_NAME}" "$S5CMD" cp "$f" "${S3_INPUT}dataset1_$(basename "$f")" &
done
wait
```

#### 3. Prepare (Create Manifest + Shards)

```bash
cd "${ANNOTATION_BATCH_INFER_REPO}"
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py prepare \
  --s3-input "$S3_INPUT" \
  --s3-output s3://core-cn-oss.canva.com/dataset/.../retry_v2_caption/ \
  --template configs/shutterstock_caption_long/caption.yaml \
  --task-name shutterstock_retry_v2_caption \
  --shard-size 1000000 \
  --work-dir /mnt/ephemeral/shutterstock_retry_v2_caption/
```

#### 4. Generate Concat Manifest

```bash
python3 tools/dispatcher.py concat \
  --work-dir /mnt/ephemeral/shutterstock_retry_v2_caption/
```

#### 5. Upload Worker Script to S3

UTP entrypoints download the worker script at runtime:

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" s5cmd cp tools/workers/concat_worker_utp.py \
  's3://.../retry_v2_caption/_scripts/concat_worker_utp.py'
```

#### 6. Build Docker Image (if base image changed)

The UTP framework starts Ray before the entrypoint runs. The image **must** have `ray` pre-installed. If using a new base image:

```dockerfile
# tools/deploy/Dockerfile.utp
FROM 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-template-trainer:training-base-pt210-cu130-py312-HASH

RUN PIP_CONSTRAINT="" pip install --no-cache-dir \
    "Pillow>=10.0" "numpy>=1.24" "boto3>=1.28" "ray[default]>=2.9"

WORKDIR /app
```

Build and push:

```bash
cd tools/deploy
DOCKER_CONFIG_DIR="$(mktemp -d /tmp/ecr-push.XXXXXX)"
AWS_PROFILE=deploy aws ecr get-login-password --region us-east-1 | \
  docker --config "$DOCKER_CONFIG_DIR" login --username AWS --password-stdin 699983977898.dkr.ecr.us-east-1.amazonaws.com
docker build --platform linux/amd64 -t 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-omra-trainer:concat-utp-v1 -f Dockerfile.utp .
docker --config "$DOCKER_CONFIG_DIR" push 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-omra-trainer:concat-utp-v1
```

**Critical**: if the image lacks `ray`, the head node fails with `ray: command not found` and health check timeout kills all pods within ~2 minutes.

#### 7. Create UTP Job YAML

```yaml
name: ${arnold_job_name}
max_retries: 1
image_uri: 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-omra-trainer:concat-utp-v1

entrypoint: >
  python -c "import boto3; s3=boto3.client('s3',region_name='us-east-1'); s3.download_file('core-cn-oss.canva.com','dataset/.../retry_v2_caption/_scripts/concat_worker_utp.py','/tmp/concat_worker_utp.py')" &&
  python /tmp/concat_worker_utp.py
  --manifest s3://.../retry_v2_caption/_concat_meta/concat_manifest.json
  --output-prefix s3://.../retry_v2_caption/_concat_meta
  --source-key s3_path
  --batch-size 100

env_vars:
  CANVA_FLAVOR: prod
  FLAVOR: prod
  CANVA_PLATFORM: eks
  PIP_CONSTRAINT: ""
  RAY_SCHEDULER_EVENTS: '0'
  RAY_OBJECT_STORE_MEMORY: '21474836480'

compute_config:
  head_node:
    instance_type: m5.4xlarge
  worker_nodes:
    - name: cpu_worker
      instance_type: m5.8xlarge
      min_nodes: 40
      max_nodes: 40
      market_type: 'ON_DEMAND'
  flags:
    workload_starting_timeout: 1h
```

#### 8. Submit UTP Job

```bash
FORCE_NO_BAZEL_REMOTE_EXECUTION=true arnold -x submit --no-login \
  --job-name "retry-concat-$(date +%s)" \
  --compute-config tools/deploy/utp_retry_v2_concat_job.yaml \
  --application-id core-cn
```

Monitor: `arnold -x list --application-id core-cn | grep retry`

#### 9. Run Gemini Batch (after concat completes)

Usually **split shard ranges** across people (see "Distribute work to the team" below), not all shards on one host.

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py run \
  --work-dir /mnt/ephemeral/shutterstock_retry_v2_caption \
  --shards 0-19 --use-concat
```

#### 10. Postprocess (coordinator, after all Vertex jobs finish)

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py postprocess \
  --work-dir /mnt/ephemeral/shutterstock_retry_v2_caption --shards all
```

## Distribute work to the team (after UTP concat)

Use this once distributed concat has written `mapping/shard_*.jsonl` under the task’s `s3_output_prefix/_concat_meta/`.

### 1. Verify concat is complete

Count mapping files on S3 vs `total_shards` in `manifest.json` (e.g. 78 shards → expect 78 `mapping/*.jsonl` files).

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" s5cmd ls 's3://BUCKET/.../retry_v2_caption/_concat_meta/mapping/*.jsonl' | wc -l
```

### 2. Publish `manifest.json` to S3

Team members need the same static plan. Upload local `manifest.json` next to the concat metadata:

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" s5cmd cp /path/to/retry_task/manifest.json \
  's3://core-cn-oss.canva.com/dataset/shutterstock_4K_webp/retry_v2_caption/_concat_meta/manifest.json'
```

### 3. Instructions for each teammate

They clone or use the `annotation_batch_infer` repo, create a work dir, pull manifest, then run **only their shard range** with `--use-concat`:

```bash
mkdir -p /mnt/ephemeral/shutterstock_retry_v2_caption
AWS_PROFILE="${AWS_PROFILE_NAME}" s5cmd cp \
  's3://core-cn-oss.canva.com/dataset/shutterstock_4K_webp/retry_v2_caption/_concat_meta/manifest.json' \
  /mnt/ephemeral/shutterstock_retry_v2_caption/manifest.json

cd "${ANNOTATION_BATCH_INFER_REPO}"
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py run \
  --work-dir /mnt/ephemeral/shutterstock_retry_v2_caption \
  --shards <START>-<END> --use-concat
```

**Requirements:** `gcloud` ADC for GCS, `AWS_PROFILE_NAME` for S3, and enough disk under the work directory for per-shard downloads and merged outputs.

### 4. Example 4-way split (78 shards: 0–77)

| Person | `--shards` | Approx. load (plan evenly) |
|--------|------------|----------------------------|
| A | 0-19 | ~¼ of 53.7M records |
| B | 20-39 | ~¼ |
| C | 40-59 | ~¼ |
| D | 60-77 | ~¼ |

Adjust ranges if one person has a smaller machine; avoid overlapping ranges.

### 5. Monitor progress (optional)

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" streamlit run tools/dashboard.py --server.port 8510 -- \
  --work-dir /mnt/ephemeral/shutterstock_retry_v2_caption/
```

Per-shard state is in `shards/shard_XXXX/status.json` (and merged into manifest reads); the dashboard can show Vertex status when credentials work.

### 6. When everyone’s Vertex jobs show completed: coordinator postprocess

One machine, after all assigned shards are done:

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py postprocess \
  --work-dir /mnt/ephemeral/shutterstock_retry_v2_caption --shards all
```

This merges Gemini output with originals, filters valid captions, writes `failed/`, and uploads to `s3_output_prefix` in the manifest.

### Example: `retry_v2_caption` task (reference)

| Item | Value |
|------|--------|
| `s3_output_prefix` | `s3://core-cn-oss.canva.com/dataset/shutterstock_4K_webp/retry_v2_caption/` |
| Concat + mapping | `.../retry_v2_caption/_concat_meta/` (manifest, `concat_manifest.json`, `mapping/`, `concat/`) |
| Input JSONLs (failed pool) | `s3://.../retry_v2_caption_input/` |
| `task_name` in manifest | `shutterstock_retry_v2_caption` |

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `ray: command not found` on UTP | Base image has no ray | Build custom image with ray pre-installed (Step 6) |
| `JSONDecodeError: Expecting value` | Empty `status.json` / `config.yaml` from disk-full | Code checks `os.path.getsize() == 0`, delete and re-run |
| `Total original: 0` in merger | Empty `input.jsonl` exists, download skipped | Check `os.path.getsize()` not just `os.path.exists()` |
| `AttributeError: NoneType has no get` | `yaml.safe_load()` on empty config returns None | Use `yaml.safe_load(f) or {}` |
| S3 mv fails for large files | S3 CopyObject limit is 5GB | Re-upload with new name, delete old |

## Robustness Fixes Applied to `dispatcher.py`

These guard against disk-full aftermath (empty files):

```python
# load_shard_status: handle empty/corrupted JSON
content = f.read().strip()
if not content:
    return {}
return json.loads(content)

# postprocess: re-download if input.jsonl is empty
if not os.path.exists(input_jsonl) or os.path.getsize(input_jsonl) == 0:

# postprocess: re-generate if config.yaml is empty
if not os.path.exists(config_path) or os.path.getsize(config_path) == 0:

# yaml.safe_load returns None for empty files
cfg = yaml.safe_load(f) or {}
```

## Reference

- `annotation_batch_infer/tools/dispatcher.py` — prepare/concat/run/postprocess
- `annotation_batch_infer/tools/workers/concat_worker_utp.py` — Ray concat worker for UTP
- `annotation_batch_infer/tools/deploy/Dockerfile.utp` — UTP image with ray
- `annotation_batch_infer/tools/deploy/utp_retry_v2_concat_job.yaml` — example UTP job config
