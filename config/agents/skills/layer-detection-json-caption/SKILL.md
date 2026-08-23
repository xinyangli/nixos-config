---
name: layer-detection-json-caption
description: Run layer detection, identify text-bearing elements, hand layer detection plus HunyuanOCR outputs to JSON caption jobs, and validate structured_description bbox outputs for final sidecar merge.
---

# Layer Detection JSON Caption

## Purpose

Use this skill for the annotation portion of the dataset pipeline:

```text
main / resized image parquet
  -> layer detection
  -> text-bearing row selection
  -> HunyuanOCR
  -> JSON caption
  -> structured_description sidecar fields
```

Layer detection provides layout and element bboxes. HunyuanOCR provides better
text recognition for rows with text. JSON caption combines both into
schema-valid captions for training.

## Layer Detection Inputs

Required:

- image source: main Parquet, resized Parquet, or materialized image URI
- stable key: `image_key` or `s3_image_path`
- width and height
- data source / dataset version

Record which image version was used for inference. If layer detection runs on a
resized image, the bbox coordinate frame must be documented before merging into
the final sidecar.

## Layer Detection Outputs

Preserve:

- element type
- bbox in normalized `0-1000` coordinates
- text-bearing indicator or parsed text if available
- confidence / parser error if available
- raw model response for debug, stored under `meta_info` or a namespaced column

Use yxyx normalized bboxes for sidecar `structured_description` compatibility.

Verifier:

- Row coverage and output count.
- Bbox range and positive area checks.
- Type distribution, including text/image/table/chart/header/footer.
- Sample HTML overlay with original image and bboxes.
- Text-bearing candidate count for OCR.

## HunyuanOCR Handoff

Rows need HunyuanOCR when layer detection indicates any visible text. Treat
non-empty `ocr_text`, `ocr_list`, or text-bearing layer elements as sufficient.

Handoff payload should include:

- key
- image URI or image bytes source
- layer text bboxes when available
- existing caption fields when available

Verifier:

- Candidate count is reported before OCR submit.
- OCR output count matches candidate count or failures are explicit.
- OCR boxes are normalized and coordinate order is documented.

## JSON Caption Inputs

JSON caption should receive:

- image
- layer detection elements and bboxes
- HunyuanOCR text and OCR boxes for text-bearing rows
- source metadata needed for prompt context
- previous captions only when the prompt is designed to revise them

The prompt should produce structured JSON, not prose-only captions.

Expected fields:

- `structured_description`
- `full_description`
- `short_description`
- `user_prompt`
- `objects`
- `ocr_text`
- `ocr_bbox`
- watermark / artifact / text overlay fields when prompt supports them

Guardrail:

- Do not merge `image_type` from a JSON caption run if the prompt did not define
  `image_type` correctly. Preserve the existing `image_type` instead.

## JSON Caption Outputs

The sidecar merge should produce:

- `structured_description`
- `full_description`
- `short_description`
- `user_prompt`
- `objects`
- `ocr_text`
- `ocr_bbox`
- prompt/model metadata under `meta_info`

The crop-aware fields are added later after 512/1024 resized Parquet exists:

- `structured_description_crop_512`
- `structured_description_crop_1024`
- `bbox_resize_meta`

Verifier:

- Submitted shard count equals completed annotation shard count.
- JSON parse valid rate.
- Schema valid rate.
- Required field non-null rates.
- OCR rows confirm OCR text was included and used.
- Sample visualization overlays `structured_description` bboxes.

## Merge Into Sidecar

Merge caption output into the final sidecar by stable key and row-aligned shard
where possible.

Do:

- preserve row order
- preserve old fields in `meta_info` if replacing
- keep failed caption rows with error metadata
- verify Arrow types match the all-in-one sidecar schema

Do not:

- join by basename unless uniqueness is proven
- silently drop rows without caption
- add arbitrary top-level columns for prompt-specific debug data
- overwrite known-bad fields from a prompt

## Stop Conditions

Stop before final merge when:

- bbox coordinate order is ambiguous
- JSON parse failures are high
- OCR output was not connected to caption input
- field schema differs from final sidecar expectations
- sampled overlays show systematic bbox shift or scale errors
