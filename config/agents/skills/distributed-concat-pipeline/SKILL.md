---
name: distributed-concat-pipeline
description: Build 2x2 grid concat images from S3 image datasets for batch Gemini captioning. Use when creating concat grids, running the annotation batch infer pipeline, generating concat manifests, managing the prepare→concat→worker→run→postprocess workflow, or coordinating multi-person shard-based annotation tasks.
---

# Distributed Concat Pipeline

## End-to-End Flow

```
prepare → concat → concat_worker (Ray) → run --use-concat → postprocess
                                              ↑
                                    team members parallelize here
```

## Step 1: `dispatcher.py prepare`

Scans S3 catalog JSONL files, packs them into shards of ~1M records. Outputs `manifest.json` (static plan — write-once).

```bash
python3 tools/dispatcher.py prepare \
  --s3-input s3://bucket/catalog/ \
  --s3-output s3://bucket/catalog_caption/ \
  --template configs/shutterstock_caption_long/caption.yaml \
  --shard-size 1000000 \
  --work-dir /mnt/ephemeral/my_task/ \
  --task-name my_task
```

Big source files are automatically split by `offset`/`limit`. Small files are packed together.

## Step 2: `dispatcher.py concat`

Generates `concat_manifest.json` from `manifest.json`, uploads to S3. Also uploads `manifest.json` to S3 for team members.

```bash
python3 tools/dispatcher.py concat --work-dir /mnt/ephemeral/my_task/
aws s3 cp /mnt/ephemeral/my_task/manifest.json \
  s3://bucket/catalog_caption/_concat_meta/manifest.json
```

## Step 3: `concat_worker.py` (Ray on Anyscale or UTP)

Builds 2×2 grids. Key design points:

- Each shard = one Ray remote task with `num_cpus=8, memory=20GB`
- `ThreadPoolExecutor(max_workers=16)` inside each task for parallel image download
- **Don't return webp bytes** from the per-grid function — `del webp_data, grid, images` after upload. Returning bytes accumulates 50-100 GB of RAM across futures and OOMs the worker.
- **Skip already-done shards**: `s3.head_object` on `mapping/{tag}.jsonl` — if exists, skip the shard
- **Batched shard submission**: process shards in groups of 40 to get ordered completion logs so coordinator can hand out ready shards early

**Outputs per shard:**
- `concat/shard_XXXX/concat_NNNNNNNN.webp` — grid images
- `mapping/shard_XXXX.jsonl` — slot-to-original mapping (contains `concat_s3_uri`, `slot`, `original_index`, `original_image`)

## Step 4: `dispatcher.py run --use-concat`

Team members download mapping + concat images, upload to GCS, submit Gemini batch job.

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py run \
  --work-dir /mnt/ephemeral/my_task/ \
  --shards 0-39 --use-concat
```

Pass `--no-wait` to `main.py` so each shard submits a batch job and immediately proceeds to next (non-blocking). Actual Gemini completion happens in background on Vertex AI.

## Step 5: `dispatcher.py postprocess` (coordinator)

Merges Gemini responses back to records using mapping. Filters to valid captions, deduplicates by `s3_path`, uploads to S3.

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py postprocess \
  --work-dir /mnt/ephemeral/my_task/ --shards all
```

**Auto-sync**: at startup, queries Vertex AI and promotes `pending` shards to `completed` if Vertex reports success. Never overwrites `postprocessed` status.

## File Relationships

| File | Created By | Purpose |
|------|-----------|---------|
| `manifest.json` | `prepare` | Static shard plan (files, records, offsets) — **write-once** |
| `shards/shard_XXXX/status.json` | `run` / `postprocess` | **Per-shard** dynamic state, safe for concurrent writes |
| `concat_manifest.json` | `concat` | Passed to Anyscale worker |
| `mapping/shard_XXXX.jsonl` | `concat_worker` | Grid slot → original image mapping |
| `concat/shard_XXXX/*.webp` | `concat_worker` | 2×2 grid images |
| `shards/shard_XXXX/merged_output.jsonl` | `postprocess` | Valid captions merged with originals |
| `failed/shard_XXXX.jsonl` | `postprocess` | Records that failed (missing or invalid caption) |

## Grid Constants

```python
GRID_ROWS = 2
GRID_COLS = 2
CELL_SIZE = 1024
GAP = 12
LABEL_FONT_SIZE = 52
WEBP_QUALITY = 90
```

## Concurrent State Management (Critical)

**Never write dynamic state to `manifest.json`** — it's read-modify-write which causes race conditions when multiple postprocess processes run in parallel.

Use **per-shard `status.json` files**:

```python
def save_shard_status(work_dir: str, shard_id: int, data: dict):
    path = os.path.join(work_dir, "shards", shard_tag(shard_id), "status.json")
    with open(path, "w") as f:
        json.dump(data, f)

def load_manifest(work_dir: str) -> dict:
    data = json.load(open(manifest_path))
    for s in data["shards"]:
        ss = load_shard_status(work_dir, s["shard_id"])
        if ss:
            s.update(ss)  # overlay per-shard state
    return data
```

Migration: `load_manifest` detects old manifests with embedded status and writes them to `status.json` on first call.

## Ray Task Sizing

For I/O-bound concat (downloading images from S3):

| Parameter | Recommended | Notes |
|-----------|-------------|-------|
| `num_cpus` | 8 | Limits per-machine concurrency to control RAM |
| `memory` | 20GB | Per-shard record buffer + image cache |
| `CONCAT_WORKERS` | 16 | Download+resize threads per task |
| `batch_size` | 40 | Ordered batch completion for progressive assignment |
| `max_retries` | 3 | OOM auto-retries infinitely otherwise |

With 40× `m5.8xlarge` workers: ~5 concurrent tasks/node × 40 nodes = 200 concurrent task slots.

## Team Distribution

Once concat is done:

```bash
# Coordinator uploads manifest to S3
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 cp /mnt/ephemeral/my_task/manifest.json \
  s3://bucket/catalog_caption/_concat_meta/manifest.json

# Team members download and run assigned shards
mkdir -p /mnt/ephemeral/my_task
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 cp \
  s3://bucket/catalog_caption/_concat_meta/manifest.json \
  /mnt/ephemeral/my_task/manifest.json

AWS_PROFILE="${AWS_PROFILE_NAME}" python3 tools/dispatcher.py run \
  --work-dir /mnt/ephemeral/my_task/ --shards 8-15 --use-concat
```

**Partial concat handoff**: team members can start with already-completed shards via `dispatcher.py status --check-concat`, which lists ready shard IDs.

## Cross-Bucket Images (Getty)

For images in a different bucket than the catalog (e.g. `design-generation-core-oss.canva.com`), use `RefreshableCredentials` with S3 Access Grants. See the `s3-access-grants` skill. **Critical**: tokens expire after 1 hour; without auto-refresh, >90% images fail silently during long concat jobs.

## Verification

```bash
# Count completed shards on S3
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://bucket/catalog_caption/_concat_meta/mapping/ | wc -l

# Verify a shard's mapping line count matches manifest.shards[N].records
AWS_PROFILE="${AWS_PROFILE_NAME}" s5cmd cat s3://bucket/.../mapping/shard_0009.jsonl | wc -l

# Local dashboard with multi-dataset view
streamlit run tools/dashboard.py --server.port 8510 -- \
  --work-dir /mnt/ephemeral/dataset1/ /mnt/ephemeral/dataset2/
```

## Team handoff after UTP concat

When concat has finished and `mapping/shard_*.jsonl` live on S3, **Gemini `run` / `postprocess` is usually split across people** (shard ranges+`--use-concat`), with one coordinator for final `postprocess --shards all` after all Vertex jobs complete. Upload `manifest.json` to `_concat_meta/manifest.json` on S3, share bucket paths, and use the runbook in **`batch-annotation-retry-recovery`** (section *Distribute work to the team*) for exact commands, example 4-way splits, and the `shutterstock_retry_v2_caption` reference table.

## Common Pitfalls (Learned the Hard Way)

1. **Path double-nesting**: `s3_output_prefix` in config is a full URI (`s3://bucket/path/`). Don't wrap it again — use `parse_s3_uri()` to extract bucket+key.

2. **Surrogate characters in Gemini output**: emoji halves like `\ud83c` crash `json.dumps(ensure_ascii=False)`. Write with `encode("utf-8", errors="replace").decode("utf-8")`.

3. **Empty files from disk-full incidents**: "No space left on device" leaves 0-byte `input.jsonl`, `status.json`, `config.yaml`. **Always check `os.path.getsize() > 0`**, not just `os.path.exists()`:
   ```python
   # Bad — 0-byte file passes this check
   if os.path.exists(path): ...
   # Good
   if os.path.exists(path) and os.path.getsize(path) > 0: ...
   ```
   Also: `yaml.safe_load()` returns `None` on empty files → use `yaml.safe_load(f) or {}`. And `json.load()` on empty files raises `JSONDecodeError` → catch and return `{}`.

4. **Incomplete local mapping**: S3 always has the authoritative mapping. Always re-download in coordinator workflows instead of trusting local cache.

5. **Merger duplicates on retry**: when same `concat_gcs_uri` has multiple predictions files (original + retry), merger produces duplicate records. Postprocess deduplicates by `s3_path` after filtering, preferring records with valid captions.

6. **Merger "Total Gemini" count in concat mode**: logs show Gemini count at the concat-image level (e.g. 227K), not per-slot (e.g. 910K). This looks like records are missing but coverage is actually ~99.8%. Check `Merged (after filter)` vs `Total original` for the real picture.

7. **concat_mapping has more entries than input.jsonl**: if the concat was done from a broader S3 source than what's in the shard's `input.jsonl` (e.g. shard files had offset/limit but concat didn't), `original_index` values in the mapping exceed the input line count. Fix: ensure `input.jsonl` is regenerated from the correct source files with matching offset/limit.

8. **GCS auth / AWS access expires every 4-6 hours**. Add to runbook:
   ```bash
   gcloud auth application-default login
   infra access aws_cli core-cn-readwrite --reason "..."
   ```

9. **S3 CopyObject 5GB limit**: `s5cmd mv` on files >5GB fails. Use `s5cmd cp` with new name + `s5cmd rm` old, or just re-upload.

## Reference Implementation

- `annotation_batch_infer/tools/dispatcher.py` — pipeline orchestrator (prepare/concat/run/status/postprocess/retry)
- `annotation_batch_infer/tools/concat_worker.py` — Ray remote worker
- `annotation_batch_infer/tools/dashboard.py` — Streamlit monitoring
- `annotation_batch_infer/tools/retry_failed_grids.py` — see `batch-annotation-retry-recovery` skill
