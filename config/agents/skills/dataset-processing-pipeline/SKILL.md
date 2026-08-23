---
name: dataset-processing-pipeline
description: Orchestrate Core CN image dataset processing from raw assets through CPU filtering, dedup, main/sidecar Parquet packaging, 512/1024 resized Parquet, layer detection, HunyuanOCR, JSON captioning, score enrichment, and verifier gates. Use when planning or executing an end-to-end training dataset build.
---

# Dataset Processing Pipeline

## Purpose

Use this skill as the top-level runbook for a new Core CN image training
dataset. It defines the required stages, output contracts, schema constraints,
and verifier gates. Each heavy stage should delegate to a narrower skill or
repo-specific workflow.

This is a YAML-first pipeline. For a normal new dataset, copy the templates in
`sidecar_parquet_ops/examples_YAMLS/`, fill dataset-specific prefixes and
compute sizing, render the selected stages, submit the generated jobs, and run
the verifier block after each stage. The agent's default role is inspection,
submission, monitoring, and verifier reporting. Do not make code changes for
dataset-specific values.

Final required deliverables:

- **Main Parquet**: original image bytes plus canonical training columns.
- **512 area image Parquet**: resized image bytes, stored separately.
- **1024 area image Parquet**: resized image bytes, stored separately.
- **Final sidecar Parquet**: row-aligned to main, containing all filters,
  layer detection, OCR, JSON caption, crop-adjusted JSON caption, and optional
  DQM / ERNIE-Image-Aes scores.

Do not rewrite the source data in place. Every stage writes to a new explicit
S3 prefix and supports resume with skip-existing semantics where possible.

## Code Change Gate

Only modify pipeline code when one of these is true:

- a reusable operator is missing
- a shared schema field must be added or renamed
- a reusable verifier is missing
- the runtime has a bug or missing resume/slicing behavior
- the raw source format has no supported importer

Otherwise, restrict changes to dataset YAMLs, UTP compute YAMLs, and verifier
YAMLs. If a code change is needed, land it as reusable infrastructure, not a
one-off dataset patch.

## Example YAMLs

Use these `sidecar_parquet_ops` examples as the fixed stage contract:

- `examples_YAMLS/00_dataset_context.yaml`
- `examples_YAMLS/01_verify_entry_jsonl.yaml`
- `examples_YAMLS/02_cpu_filter.yaml`
- `examples_YAMLS/03_filter_candidate_jsonl.yaml`
- `examples_YAMLS/04_dedup.yaml`
- `examples_YAMLS/05_pack_main_sidecar.yaml`
- `examples_YAMLS/06_resize_512.yaml`
- `examples_YAMLS/07_resize_1024.yaml`
- `examples_YAMLS/08_layer_detection.yaml`
- `examples_YAMLS/09_hunyuan_ocr.yaml`
- `examples_YAMLS/10_json_caption.yaml`
- `examples_YAMLS/11_merge_final_sidecar.yaml`
- `examples_YAMLS/12_dqm_score.yaml`
- `examples_YAMLS/13_ernie_image_aes_score.yaml`
- `examples_YAMLS/14_final_verify.yaml`

Each stage YAML includes inputs, outputs, job submit shape, verifier checks, and
agent rules. Keep verifier blocks attached to the stage; a node is not complete
until the verifier result is recorded.

## YAML Renderer Contract

Treat `00_dataset_context.yaml` as the dataset-level form and the numbered
stage YAMLs as reusable workflow nodes. Render them with the repository tool:

```bash
cd "${SIDECAR_PARQUET_OPS_REPO}"
uv run python scripts/render_dataset_pipeline.py \
  --context path/to/my_dataset_context.yaml \
  --stage-dir examples_YAMLS \
  --output-dir generated/my_dataset \
  --stages 01_verify_entry_jsonl,02_cpu_filter \
  --validate-only

uv run python scripts/render_dataset_pipeline.py \
  --context path/to/my_dataset_context.yaml \
  --stage-dir examples_YAMLS \
  --output-dir generated/my_dataset \
  --stages 01_verify_entry_jsonl,02_cpu_filter
```

The renderer emits resolved stage records, Arnold compute YAMLs,
`workflow_manifest.yaml`, and `submit_commands.sh`. Use environment variables
for shared deployment settings and `--set KEY=VALUE` for CI form values or
one-off overrides. Do not manually patch generated compute YAMLs; change the
context or stage YAML and render again so the configuration remains auditable.

For a CI/CD-style frontend:

- parse `00_dataset_context.yaml` for dataset, environment, image, output, and
  variable fields
- parse `workflow.stages` for ordering
- parse each stage's `inputs`, `outputs`, `agent_rules`, and `verifier` blocks
- call the renderer in `--validate-only` mode before enabling submit
- submit one stage at a time and persist the generated manifest
- require the stage verifier to pass before unlocking the next stage

The generated `submit_commands.sh` requires a `stage-id/job-id` selector and
submits exactly one job. It does not monitor completion or replace verifier
gating.

## Stage Graph

```text
raw dataset
  -> inventory / catalog
  -> input format validation
  -> CPU filter sidecar
  -> filter-pair main + sidecar
  -> dedup handoff / dedup-filtered main
  -> canonical main parquet + base sidecar
  -> 512 resized image parquet
  -> 1024 resized image parquet
  -> layer detection
  -> HunyuanOCR for text-bearing layer outputs
  -> JSON caption using layer detection + OCR
  -> final sidecar merge
  -> optional DQM + ERNIE-Image-Aes scoring
  -> final all-in-one sidecar
```

## Stage 0 - Dataset Intake

Collect and freeze these inputs before submitting jobs:

- Dataset name, version, owner, license/confidentiality, expiry.
- Entry manifest: JSONL, one image record per line.
- Source S3 bucket/prefix and access method, including S3 Access Grants if used.
- Stable primary key: prefer `s3_image_path` for external image paths and
  `image_key` for canonical packed rows. Do not infer keys from basenames unless
  filenames are globally unique.
- Expected row count, source object count, and meta fields discovered from
  manifests or side files.

Canonical entry contract:

- The pipeline entrypoint is a JSONL manifest.
- Each JSONL row must point to the source image with an S3 path field.
- Recommended image field name: `s3_image_path`.
- Acceptable aliases such as `s3_path`, `image_s3_uri`, `image_uri`, or `url`
  must be normalized to `s3_image_path` before downstream stages.
- Each row may contain arbitrary metadata fields.
- Metadata fields that are not canonical top-level fields must be serialized
  into sidecar `meta_info`.
- If the raw source is tar/zip/webdataset/parquet/CSV, first materialize or
  derive this JSONL manifest, then run the standard pipeline.

Verifier:

- S3 listing or inventory count exists and is recorded.
- 20 random objects can be read in the same environment that will run the job
  (usually UTP, not only devbox).
- Source metadata keys are enumerated. No known metadata is dropped without an
  explicit decision.

## Stage 0.5 - Input Format Validation

Run this as a hard gate before CPU filtering or packaging. The goal is to prove
that every source record can be normalized into one canonical row contract,
even if the raw dataset originally came from multiple files, archives, or
metadata formats.

Validate these record-level fields:

- stable key: `image_key` or derivable `s3_image_path`
- image locator: required S3 URI field, normalized to `s3_image_path`
- image format: jpg/jpeg/png/webp or explicitly supported format
- width and height: present or probeable from image bytes
- metadata container: JSON object from the JSONL row
- required text fields: present, nullable, or explicitly defaulted
- source provenance: dataset name, version, manifest path, source row id, and
  original raw file/archive/member id when applicable

Normalization rules:

- Convert all records to the same canonical field names before downstream jobs.
- Convert scalar text to list-string only where the target schema expects
  list-string.
- Serialize dataset-specific metadata into `meta_info`.
- Preserve raw source metadata keys inside `meta_info` when practical.
- Reject or quarantine rows whose image bytes cannot be decoded or whose key is
  missing.

Verifier:

- Sample every JSONL shard/partition, not just the first file.
- Produce a format report with counts by input format, image extension, metadata
  schema version, missing required fields, decode failures, duplicate keys, and
  quarantined rows.
- Confirm all accepted rows map to the same canonical schema.
- Confirm no source metadata keys are silently dropped.
- Stop downstream execution if the accepted-row schema is not uniform.

## Stage 1 - CPU Filtering

Run CPU image filters before expensive annotation. Use `sidecar_parquet_ops`
filter pipelines where possible.

Throughput target:

- Full CPU filtering should be sized for **10M rows/hour** when cluster
  capacity is available.
- Do not use small smoke/default UTP templates for full datasets.
- First run a smoke or short full-prefix sample, record observed
  `Shard progress ... rate=<shards/s>`, then scale actor count and worker nodes
  from that measurement.
- For 512-row shards, 10M rows/hour requires about `19,532 shards/hour` or
  `5.43 shards/s`.
- Validate that the requested Ray actor bundle fits the worker fleet. For the
  Infographics 9-filter benchmark, use about 1,500-1,600 one-CPU actors; with
  `actor_memory_gb=6`, start from 40 x `m5.24xlarge` or equivalent capacity
  so all actors can initialize.
- If UTP only admits 32 `m5.24xlarge` workers because of pod anti-affinity or
  queue policy, keep 1536 actors but lower the actor memory reservation to
  5GB and confirm `ray status` has no pending actor bundles before trusting
  the run.
- Keep one writer job per output prefix. To scale up a slow run, cancel it and
  resume the same sidecar prefix with `--skip-existing`.

Typical columns:

- `filter_clarity`
- `filter_texture`
- `filter_saturation`
- `filter_luma`
- `filter_exif_rotation`
- `filter_exif_metadata`
- `filter_jpeg_artifact`
- `filter_color_entropy`
- `filter_edge_density`

Use subprocess isolation for filters that wrap native libraries and can
`SIGABRT` on malformed images.

Verifier:

- Input shard count equals output sidecar shard count.
- Row count and key alignment match for sampled shards.
- Filter struct columns are present and parse as the expected schema.
- Report pass / reject / null rates by filter. Do not proceed if a filter has
  an unexpected 100% null or 100% reject rate.

## Stage 2 - Filter-Pair Handoff

Use the filter sidecar to produce the filtered main Parquet and filtered
sidecar. This is a new dataset; do not delete source rows in place.

Verifier:

- `filtered_main_rows + rejected_rows == input_rows`.
- Filtered main and filtered sidecar have the same shard layout.
- `sidecar-ops verify` passes on sampled shards.
- A small visualization confirms retained images are readable and rejected
  examples match expected bad-image categories.

## Stage 3 - Dedup

Dedup is a downstream operation after CPU filtering. Run it after Stage 1
CPU filters and Stage 2 filter-pair handoff, so dedup consumes the filtered
main / sidecar dataset instead of the raw dataset. It emits a deduped main
Parquet plus aligned sidecar.

Do not run dedup before CPU filtering in the standard pipeline. Bad/corrupt
images should be removed or quarantined by the CPU filter path first; dedup
should spend compute only on the filtered candidate set.

Verifier:

- Report before/after row counts and duplicate clusters removed.
- Verify no output key appears more than once.
- Verify main/sidecar row alignment after dedup.
- Preserve source provenance and dedup cluster metadata in sidecar `meta_info`
  when available.

## Stage 4 - Canonical Main Parquet And Base Sidecar

Package the deduped image rows into canonical bucketed Parquet:

```text
{main_prefix}/{scale}/{ar_id}/shard_000000.parquet
```

The main Parquet stores original image bytes. The sidecar stores metadata and
small enrichment columns; it must not include image bytes.

Required main columns:

- `image_key`
- `image`
- `width`
- `height`
- `s3_image_path`
- `is_rgba`
- `task`
- `data_source`

Sidecar metadata naming constraint:

- First-level sidecar column names must match the established all-in-one schema.
- Use the reference family
  `s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/getty_vtx_blip_sd_new_20260701_crop_512_1024/`
  as the naming baseline.
- Do not add arbitrary top-level columns for one-off source metadata.
- Extra source metadata must be serialized under `meta_info`.

Recommended final sidecar top-level fields include:

- Caption fields: `detailed_description`, `structured_description`,
  `full_description`, `short_description`, `user_prompt`, `objects`,
  `ocr_text`, `keywords`, `style`, `image_type`.
- Dataset flags and scores: `is_aigc`, `image_quality_score`,
  `design_quality_score`, `aesthetic_score`, `has_barcode`, `has_watermark`,
  `has_artifact`, `has_mosaic`, `has_rotation`, `text_overlay`.
- Provenance: `meta_info`, `data_source`.
- Score columns: `ernie_image_aes`, `dqm_d1_v6_1`.
- OCR/filter columns: `ocr_bbox`, `filter_*`.
- Crop caption columns: `structured_description_crop_512`,
  `structured_description_crop_1024`, `bbox_resize_meta`.

Verifier:

- Shard count and row count are recorded for main and sidecar.
- Main images can be decoded for a sampled set.
- Sidecar has no `image` binary column.
- First-level sidecar columns are compared against the reference schema; any
  dataset-specific metadata is under `meta_info`.
- Row alignment passes by relative shard path, row count, and key equality.

## Stage 5 - 512 And 1024 Resized Image Parquet

Build two separate resized image Parquet datasets from the main Parquet:

- 512 area output:
  `s3://core-cn-oss.canva.com/dataset/0_262mp_version_all_in_one/<dataset>/`
- 1024 area output:
  `s3://core-cn-oss.canva.com/dataset/1_05mp_version_all_in_one/<dataset>/`

These outputs preserve aspect ratio and use fixed pixel area, not forced square
crop. They are image Parquet datasets, not sidecars.

Verifier:

- Resized output shard count equals main shard count.
- Row counts and keys match main on sampled shards.
- Image bytes decode successfully.
- Audit columns report valid/invalid counts.
- Sampled dimensions have expected area and preserve aspect ratio.

## Stage 6 - Layer Detection

Run layer detection on the main images or on the agreed resized image version.
The output must be row-aligned or keyed so it can be merged into the final
sidecar without basename matching.

Layer detection should preserve:

- Detected elements / layers.
- Bboxes in normalized `0-1000` coordinates.
- Text-bearing element indicators.
- Raw model output or parser diagnostics in `meta_info` or a namespaced
  sidecar column if needed for debugging.

Verifier:

- Output row count and key coverage are reported.
- Bbox ranges are within `[0, 1000]` and have positive area.
- Sample visualization overlays bboxes on real images.
- Text-bearing element rate is plausible for the dataset.

## Stage 7 - HunyuanOCR For Text-Bearing Layer Results

Select only rows / elements from layer detection where text is present or likely
present. Run HunyuanOCR for those images. Preserve OCR boxes and raw OCR output
for downstream JSON caption.

Selection rule:

- If layer detection / 2x2 caption output includes non-empty OCR text or
  `ocr_list`, the image should be eligible for OCR recaption.
- Do not restrict OCR to only high-confidence text when the downstream caption
  needs text correction.

Verifier:

- Report candidate count and OCR completed count.
- OCR output contains key, raw OCR response, text, and bbox fields.
- OCR bboxes use a documented coordinate frame and are normalized before merge.
- Failed OCR rows are retained with error metadata instead of silently dropped.

## Stage 8 - JSON Caption

Submit JSON caption jobs using layer detection output and OCR output as inputs.
The caption output must be schema-valid JSON and include layout-aware
`structured_description`.

Expected JSON caption fields:

- `structured_description`
- `full_description`
- `short_description`
- `user_prompt`
- `objects`
- `ocr_text`
- `ocr_bbox` when OCR is available
- `image_type` only if the prompt and schema for that field are correct
- watermark/artifact/text overlay fields when produced by the prompt

Verifier:

- Vertex/annotation job count equals submitted shard count.
- Postprocess valid rate is reported.
- JSON parse failures and schema failures are counted and sampled.
- For OCR rows, verify OCR text was included in the caption input and reflected
  in the output where appropriate.
- Do not replace existing `image_type` if the active prompt did not ask for it
  correctly.

## Stage 9 - Final Sidecar Merge

Merge CPU filters, dedup metadata, layer detection, OCR, JSON caption, and
score columns into a final row-aligned sidecar. Use shard-relative joins and key
assertions, not filename joins.

The final sidecar must include:

- Base metadata and source provenance.
- CPU filter structs.
- Layer detection output.
- OCR text and OCR boxes.
- JSON caption fields.
- `structured_description_crop_512`.
- `structured_description_crop_1024`.
- `bbox_resize_meta`.
- Optional `dqm_d1_v6_1`.
- Optional `ernie_image_aes`.

Verifier:

- Final sidecar shard count equals main shard count.
- Final sidecar row count equals main row count.
- `sidecar-ops verify` passes.
- Required top-level fields exist and use expected Arrow types.
- `meta_info` is valid JSON or a documented string format.
- Sampled `structured_description`, `structured_description_crop_512`, and
  `structured_description_crop_1024` all have bboxes with expected coordinate
  changes.

## Stage 10 - Optional DQM And ERNIE-Image-Aes

Run DQM and ERNIE-Image-Aes on A100/H200/L40S resources as available. These are
GPU scoring jobs that usually produce score sidecars. Merge them into the final
sidecar with a CPU-only sidecar merge.

Verifier:

- Score sidecar shard count and key coverage are reported.
- Score columns have expected struct fields such as `raw_score`, `score`, and
  `error`.
- Error/null score rates are reported.
- Final post-merge sidecar alignment passes again.

## Stage 11 - Crop-Aware Structured Description

After 512 and 1024 resized image Parquet are available, regenerate bbox-adjusted
caption columns:

- `structured_description_crop_512`
- `structured_description_crop_1024`
- `bbox_resize_meta`

These columns are derived from `structured_description` and the resize audit
metadata. The original `structured_description` remains in the original image
coordinate frame.

Verifier:

- For sampled rows, compare element counts between original and crop columns.
  Small differences are allowed when an element is cropped out; they must be
  recorded in `bbox_resize_meta`.
- Bboxes are still `0-1000` normalized yxyx and have positive area.
- Overlay visualizations for original, 512, and 1024 versions render correctly.

## Naming And Output Checklist

Use stable dataset versioning in prefix names. Avoid temporary job names in
final production prefixes.

Required final prefix set:

```text
MAIN_PARQUET=s3://core-cn-oss.canva.com/dataset/<dataset>_parquet/<version>/
PARQUET_512=s3://core-cn-oss.canva.com/dataset/0_262mp_version_all_in_one/<dataset>/
PARQUET_1024=s3://core-cn-oss.canva.com/dataset/1_05mp_version_all_in_one/<dataset>/
FINAL_SIDECAR=s3://core-cn-oss.canva.com/dataset/sidecar_parquet_all_in_one_0529/<dataset>/
```

For experiments, add a date or suffix. For production handoff, record the
prefixes and verifier results in a datacard or run summary.

## Skill Routing

Use these skills for implementation details:

- `dataset-parquet-packaging`: JSONL / manifest image datasets to main Parquet.
- `webdataset-to-parquet`: tar/webdataset sources to main Parquet.
- `sidecar-parquet-ops-repo`: YAML datasets, pipelines, ops, runtimes.
- `fixed-resolution-sidecar`: 512 / 1024 resized image Parquet.
- `distributed-concat-pipeline`: 2x2 grid caption preparation when needed.
- `ocr-recaption-pipeline`: HunyuanOCR and OCR-aware recaption.
- `layer-detection-json-caption`: layer detection and JSON caption handoff.
- `sidecar-score-merge`: merge DQM and ERNIE-Image-Aes score sidecars.
- `dataset-pipeline-verifiers`: reusable checks after every stage.
- `utp-job-submission`: UTP/Arnold submit, monitor, and job troubleshooting.
- `utp-vertex-wif`: Vertex/Gemini/GCS access from UTP.

## Stop Conditions

Stop and inspect before moving downstream if any of these are true:

- Source readable count differs materially from inventory count.
- Input records cannot be normalized to one canonical schema.
- Required keys, image locations, dimensions, or metadata containers are
  inconsistent without an explicit quarantine policy.
- Main and sidecar are not row-aligned.
- A filter, OCR, caption, or score column is unexpectedly all null.
- Bbox coordinates are out of range or use an undocumented order.
- Sidecar introduces arbitrary top-level metadata columns instead of `meta_info`.
- A job completed but expected S3 outputs are missing or undersized.
- A prompt changed `image_type` or other existing fields incorrectly.
