---
name: ocr-recaption-pipeline
description: Run HunyuanOCR on text-bearing images or layer-detection outputs, submit OCR-aware single-image recaption, build an index, and merge OCR/recaption results into final sidecar Parquet.
---

# OCR Recaption Pipeline

## Purpose

Use this skill when a dataset already has caption or layer-detection output and
some images contain text that needs OCR-aware correction. The pipeline is:

```text
caption / layer detection sidecar
  -> select OCR candidates
  -> HunyuanOCR
  -> OCR-aware single-image JSON recaption
  -> recaption index
  -> final sidecar merge
```

This is not a replacement for the base caption. It selectively improves rows
where OCR text matters.

## Candidate Selection

Select rows for HunyuanOCR if any of these are true:

- `ocr_text` is non-empty.
- `ocr_list` is non-empty.
- layer detection has text-bearing elements.
- the 2x2/grid caption reports visible text, watermark text, or text overlay.

Do not require high-confidence OCR before running HunyuanOCR; HunyuanOCR is the
stage that should clarify text.

Verifier:

- Report total rows and selected OCR candidate rows.
- Sample selected and non-selected rows visually.
- Confirm selected rows preserve the original key and image path.

## HunyuanOCR Inputs

Each OCR input record should include:

- stable key (`image_key` or `s3_image_path`)
- image path or image bytes source
- width and height
- optional layer bboxes from layer detection
- source sidecar relative shard path for row-aligned merge

HunyuanOCR output should preserve:

- raw OCR response
- parsed text
- OCR boxes
- error field
- model/version metadata

Normalize OCR boxes to the project coordinate convention before downstream
merge. For JSON caption sidecars, normalized `0-1000` yxyx bboxes are preferred.

Verifier:

- OCR output row count equals candidate count, unless failures are explicitly
  represented as error rows.
- `has_text`, OCR text length, and `num_boxes` distributions are recorded.
- Bbox coordinates are in range and have positive area.
- Failed rows have an error reason.

## OCR-Aware Recaption

Submit single-image JSON recaption using OCR text and OCR boxes. The prompt
should instruct the model to use OCR evidence for visible text while preserving
visual description and layout.

Inputs should include:

- image
- previous caption fields if available
- HunyuanOCR text
- HunyuanOCR boxes
- layer detection elements if available

Outputs should include:

- `structured_description`
- `full_description`
- `short_description`
- `user_prompt`
- `ocr_text`
- `ocr_bbox`
- optional watermark/text overlay flags if the prompt produces them

Guardrail:

- Do not overwrite `image_type` unless the recaption prompt explicitly asks for
  `image_type` and the schema is known-good.

Verifier:

- Vertex/Gemini submitted shard count equals completed shard count.
- JSON parse valid rate is reported.
- Schema valid rate is reported.
- OCR candidate rows with OCR text show that OCR text was included in prompt
  payload.
- Sample before/after rows verify text correction without layout regression.

## Build Recaption Index

Build a keyed index from recaption outputs for sidecar merge.

Key strategy:

- Use full `s3_image_path` when basenames are not unique.
- Use basename only when filenames are globally unique and this has been
  verified.
- Prefer dataset primary key when both OCR and sidecar preserve it.

Verifier:

- Index row count equals valid recaption row count.
- Key uniqueness is verified.
- Duplicate keys are reported and resolved before merge.

## Sidecar Merge

Merge recaption fields back into a row-aligned sidecar. For rows without OCR
recaption, preserve the existing caption fields.

Expected merge behavior:

- replace `full_description` when recaption exists
- append or replace `short_description` / `user_prompt` according to dataset
  policy
- write `ocr_text` and `ocr_bbox`
- write `was_recaptioned` when the schema has it
- preserve old fields in `meta_info` when replacing important user-facing text

Verifier:

- Final sidecar row count equals main row count.
- `was_recaptioned` count equals matched index count.
- Rows without recaption remain unchanged.
- Rows with recaption have non-empty caption fields and OCR metadata.
- `sidecar-ops verify` passes.

## Operational Notes

- Use UTP for bucket access when devbox credentials cannot read the dataset.
- For Vertex/Gemini from UTP, use `utp-vertex-wif`.
- For very large recaption indexes, use an actor-based merge so each actor
  loads the index once.
- Keep job names short enough for Kubernetes pod DNS labels.
- Use `--skip-existing` for shard-based resume when the merge op supports it.

## Stop Conditions

Stop before merge if:

- OCR candidate count is unexpectedly zero.
- HunyuanOCR output lacks keys or coordinate metadata.
- Recaption output JSON parse failures are high.
- Key uniqueness is not guaranteed.
- The active prompt has incorrect schema instructions for fields being merged.
