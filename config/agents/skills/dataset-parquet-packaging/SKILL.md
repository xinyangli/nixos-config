---
name: dataset-parquet-packaging
description: Package image datasets into bucketed Parquet shards with resolution and aspect ratio bucketing. Use when converting JSONL+image datasets to Parquet format, creating training-ready datasets, or when the user mentions parquet, packaging, bucketing, sharding, or dataset preparation.
---

# Dataset Parquet Packaging

## Overview

Convert image datasets from a JSONL entry manifest into zstd-compressed
Parquet shards, bucketed by resolution and aspect ratio. Each JSONL row must
point to an image with an S3 path, normalized to `s3_image_path`. Designed for
large-scale distributed processing with Ray.

The JSONL row may contain arbitrary source metadata. Canonical fields become
top-level parquet/sidecar fields; all dataset-specific extra metadata should be
serialized into `meta_info`.

## Resolution Bucketing (by pixel area w×h)

| Area Range | Scale Directory |
|------------|----------------|
| ≤ 512² (262,144) | `0_512` |
| ≤ 1024² (1,048,576) | `512_1024` |
| ≤ 1536² (2,359,296) | `1024_1536` |
| ≤ 2048² (4,194,304) | `1536_2048` |
| > 2048² | `2048_inf` |

## Aspect Ratio Bucketing

27 target ARs (w/h). Find nearest target by minimum absolute difference:

```
0.3333, 0.4000, 0.4348, 0.5000, 0.5625, 0.6316, 0.6667, 0.7059,
0.7500, 0.7778, 0.8000, 1.0000, 1.1930, 1.2500, 1.2857, 1.3333,
1.4167, 1.5000, 1.7500, 1.7778, 1.9091, 2.0000, 2.3000, 2.6667,
3.0000, 3.3750, 4.0000
```

AR ID = `int(round(target_ar × 10000))`, e.g. 3333, 10000, 17778.

## Output Structure

```
{output_prefix}/{scale}/{ar_id}/shard-NNNNNN.parquet
```

Example: `s3://bucket/pexels_parquet/1536_2048/15000/shard-000000.parquet`

## Parquet Schema

Required: `image_key`, `image` (binary, original file bytes), `width`, `height`, `s3_image_path`, `is_rgba`, `task`, `data_source`, `ocr_text`.

Optional (null placeholders for future enrichment): `detailed_description`, `structured_description`, `full_description`, `short_description`, `user_prompt`, `keywords`, `style`, `image_type`, quality scores, detection flags.

## Metadata and Sidecar Naming Rules

Keep main Parquet focused on canonical training columns and image bytes. For
sidecar Parquet, first-level column names must follow the established
all-in-one sidecar schema. Use this reference family when checking names:

```
s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/getty_vtx_blip_sd_new_20260701_crop_512_1024/
```

Rules:

1. Do not add dataset-specific metadata as arbitrary top-level sidecar columns.
2. Put extra source metadata into `meta_info`.
3. Preserve the raw field names and values inside `meta_info` when practical.
4. Keep final crop-aware caption fields named exactly:
   `structured_description_crop_512`, `structured_description_crop_1024`, and
   `bbox_resize_meta`.
5. Verify sidecar first-level names before handoff.

## Key Design Decisions

1. **Store original file bytes**, not decoded numpy arrays. Keeps file sizes manageable.
2. **Verify integrity** with `img.load()` — full pixel decode catches corrupt/truncated files before writing.
3. **Stream + dispatch**: Don't load all records into memory. Stream JSONL → bucket → submit Ray task when buffer full. Keeps memory bounded.
4. **Strip unused fields** from JSONL during loading (e.g. `gemini_response_full`) to prevent OOM.
5. **Per-bucket sharding**: Each (scale, ar_id) combination gets its own sequence of shard files.

## Memory Optimization for Large JSONL

When loading JSONL with large text fields (e.g. Pexels 7.5M records with caption data):

```python
KEEP_FIELDS = frozenset({"s3_image_path", "width", "height", ...})

def _strip_record(rec):
    return {k: v for k, v in rec.items() if k in KEEP_FIELDS}
```

This reduces Python heap from ~100GB to ~10GB for 7.5M records.

## Reference Implementation

Use the `sidecar_parquet_ops` pack runtime and the examples under
`sidecar_parquet_ops/examples_YAMLS/` for streaming bucketed dispatch, S3
Access Grants support, and distributed processing.
