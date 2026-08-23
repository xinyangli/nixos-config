---
name: dataset-pipeline-verifiers
description: "Run verifier gates for Core CN dataset processing stages: S3 counts, parquet schema, row alignment, metadata naming, bbox validity, OCR/caption validity, resized image audits, and final sidecar quality."
---

# Dataset Pipeline Verifiers

When jobs are generated from `sidecar_parquet_ops/examples_YAMLS/`, use the
resolved files under `generated/<dataset>/stages/` as the immutable verifier
input recorded by CI. Renderer success proves template completeness only; it
does not prove data quality or stage completion. A controller must still run
the verifier block after each job and persist pass/fail evidence before
advancing the workflow.

## Purpose

Use this skill after every dataset processing node. A node is not complete until
its verifier result is recorded with counts, sampled evidence, and output
prefixes.

Use the verifier blocks in `sidecar_parquet_ops/examples_YAMLS/` as the default
contract. The agent may tune prefixes and sample sizes, but should not replace
fixed gates with ad-hoc checks. If a durable gate is missing, add a reusable
verifier under `sidecar_parquet_ops/verifiers/` and reference it from the stage
YAML.

Verifier output should include:

- input prefix
- output prefix
- shard count
- row count
- key column
- schema summary
- sampled evidence path or HTML demo when visual validation matters
- pass/fail and blocker notes

## S3 Prefix Count

Use for every S3-backed stage.

```bash
AWS_PROFILE="${AWS_PROFILE_NAME}" aws s3 ls s3://.../prefix/ --recursive --summarize
```

Pass criteria:

- expected parquet objects exist
- total size is non-zero
- object count is plausible compared with input

Fail if a job says completed but expected S3 outputs are missing.

## Input Format Gate

Run before CPU filtering, dedup, or Parquet packaging. This gate proves that
the JSONL entry manifest can be normalized into one canonical row schema.

Check every JSONL shard / partition:

- manifest object count
- record count
- image S3 path field
- required key field
- image extension / MIME type
- width and height availability
- duplicate keys
- missing required fields
- decode probe failures
- metadata keys discovered

Pass criteria:

- all accepted rows map to one canonical schema
- every accepted row has a stable key or can use normalized `s3_image_path` as
  the key
- every accepted row has a readable image S3 URI
- width and height are present or probeable
- duplicate keys are zero or resolved by an explicit policy
- source-specific metadata is routed into `meta_info`
- quarantined rows are counted and sampled

Fail if rows use incompatible schemas and there is no normalization rule. Do
not start downstream jobs until the input format report is clean.

## Parquet Footer And Schema

Sample multiple shards across buckets.

```python
import pyarrow.parquet as pq
tab = pq.read_table("sample.parquet")
print(tab.num_rows)
print(tab.schema)
```

Pass criteria:

- required columns exist
- Arrow types match expected schema
- sampled row count is non-zero except known empty tail shards
- no unexpected image bytes in sidecar parquet

## Main / Sidecar Alignment

For row-aligned sidecars, verify:

- same relative shard path
- same row count
- same key column values in row order

Prefer `sidecar-ops verify` when working in `sidecar_parquet_ops`:

```bash
sidecar-ops verify pipelines/<pipeline>.yaml \
  --output-prefix s3://.../sidecar_output/ \
  --samples 50
```

Pass criteria:

- sampled shards all align
- null-vs-null keys are treated as mismatch, not pass

## Metadata Naming Gate

For final all-in-one sidecars:

- compare first-level column names against the current all-in-one reference
- keep dataset-specific source fields in `meta_info`
- do not add one-off top-level columns for source metadata

Reference family:

```text
s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/getty_vtx_blip_sd_new_20260701_crop_512_1024/
```

Pass criteria:

- required top-level columns exist
- extra source metadata lives under `meta_info`
- `meta_info` is parseable JSON or a documented string format

## CPU Filter Gate

Check:

- filter struct columns exist
- pass/reject/null rates by filter
- no unexpected all-null filter
- no unexpected all-reject filter
- sampled rejected images are actually bad or explainable

Pass criteria:

- filter outputs are populated
- retained/rejected counts are recorded
- filter-pair row accounting closes:

```text
filtered_rows + rejected_rows == input_rows
```

## Dedup Gate

Dedup gate applies only after CPU filtering and filter-pair handoff. Its input
must be the filtered main Parquet plus aligned filtered sidecar, not the raw
dataset.

Check:

- input rows
- output rows
- removed rows
- duplicate cluster count if available
- key uniqueness in output

Pass criteria:

- no duplicate output keys
- main/sidecar alignment preserved
- dedup metadata retained under `meta_info` when available

## Image Decode Gate

For main, 512, and 1024 image Parquet:

- sample image bytes
- decode with PIL
- validate width and height
- validate expected area for resized outputs

Pass criteria:

- sampled images decode
- dimensions are plausible
- 512/1024 outputs preserve aspect ratio unless crop was explicitly requested

## Bbox Gate

For layer detection and structured descriptions:

- bbox has four numbers
- coordinate order is documented
- normalized range is `[0, 1000]`
- area is positive
- sampled overlays render on real image

Pass criteria:

- invalid bbox rate is recorded and low
- no systematic coordinate swap or scale shift

For crop-aware fields:

- compare original vs `structured_description_crop_512`
- compare original vs `structured_description_crop_1024`
- cropped-out element count matches `bbox_resize_meta`

## OCR Gate

Check:

- OCR candidate count
- OCR completed count
- OCR text non-empty count
- OCR bbox count
- OCR error count

Pass criteria:

- every candidate has either OCR output or an explicit error
- bbox coordinate frame is normalized before merge
- OCR output keeps original key

## JSON Caption Gate

Check:

- submitted annotation shards
- completed annotation shards
- JSON parse valid count
- schema valid count
- required field non-null rates
- OCR rows received OCR context

Pass criteria:

- valid rate is high enough for the dataset
- invalid rows are retained with error metadata or explicitly retried
- known bad prompt fields are not merged

## Score Gate

For DQM and ERNIE-Image-Aes:

- score sidecar count
- score row coverage
- `raw_score` / `score` null rate
- `error` rate

Pass criteria:

- score sidecars align by key or relative shard
- final merged sidecar alignment passes after score merge

## Final Handoff Gate

Before declaring a dataset ready, verify:

- main Parquet prefix exists
- 512 image Parquet prefix exists
- 1024 image Parquet prefix exists
- final sidecar prefix exists
- all four row counts match unless invalid rows are explicitly retained in a
  documented way
- final sidecar contains filter, OCR, caption, crop caption, and optional score
  columns
- browse/demo page exists for sampled rows when visual inspection is useful

Record final paths:

```text
MAIN_PARQUET=
PARQUET_512=
PARQUET_1024=
FINAL_SIDECAR=
VERIFIER_SUMMARY=
DEMO_URL=
```
