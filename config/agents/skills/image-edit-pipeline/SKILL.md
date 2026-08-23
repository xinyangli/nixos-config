---
name: image-edit-pipeline
description: Build image editing dataset pipelines using third-party APIs (OpenAI gpt-image-1.5/bluefire-alpha, Google Gemini). Covers generating edit instructions via Vertex AI batch, executing image edits via OpenAI Batch API or local concurrent API calls, postprocessing results, and exporting canonical JSONL datasets. Use when building image editing datasets, calling OpenAI images/edits API, submitting Vertex AI batch jobs for image generation, or processing VLM-generated edit instructions.
---

# Image Edit Pipeline

## Overview

End-to-end pipeline for constructing large-scale image editing datasets:
1. Sample source images from multiple sources (S3, local, GCS)
2. Generate structured edit instructions via Gemini Flash (Vertex AI batch)
3. Execute image edits via OpenAI API (batch or local concurrent)
4. Postprocess and export canonical JSONL dataset

## Architecture

```
Source Images (S3/local)
    |
    v
[Gemini Flash Batch] -- generate 5 edit instructions per image
    |
    v
Exploded Edit Pairs (image + instruction)
    |
    v
[OpenAI Image Edit] -- gpt-image-1.5 / bluefire-alpha
    |
    v
Canonical JSONL Dataset + images on S3
```

## OpenAI Image Edit API (JSON mode)

The `/v1/images/edits` endpoint for GPT image models uses JSON body (not multipart):

```python
payload = {
    "model": "gpt-image-1.5",  # or "bluefire-alpha"
    "images": [{"image_url": f"data:{mime};base64,{img_b64}"}],  # array of objects, NOT strings
    "prompt": "Edit instruction text",
    "quality": "medium",        # low | medium | high | auto
    "size": "1536x1024",        # auto | 1024x1024 | 1024x1536 | 1536x1024
    "background": "opaque",     # opaque | transparent | auto
    "output_format": "webp",    # webp | jpeg | png
}
```

**Critical gotchas:**
- `images` must be an array of **objects** `[{"image_url": "data:..."}]`, NOT strings
- For batch API: parameter is `images` (array), not `image` (string). JSON edits use `images`; multipart uses `image[]`
- `background: "opaque"` prevents transparent layers (combine with `output_format: "webp"` or `"jpeg"`)
- Auto size: match source aspect ratio to nearest option (1:1, 3:2, 2:3)

## OpenAI Batch API for Image Edits

Supported endpoint: `/v1/images/edits` (confirmed working with gpt-image-1.5).

**File size limit: 200MB per batch input file.** With base64 images averaging ~250KB each, max ~700-800 items per batch. Use 500 to be safe.

```python
ITEMS_PER_OPENAI_BATCH = 500  # NOT 2000+, will exceed 200MB

batch_line = {
    "custom_id": pair_id,
    "method": "POST",
    "url": "/v1/images/edits",
    "body": {
        "model": "gpt-image-1.5",
        "images": [{"image_url": f"data:{mime};base64,{b64}"}],
        "prompt": instruction,
        "quality": "medium",
        "size": size,
        "background": "opaque",
        "output_format": "webp",
    },
}
```

**Model support:** Not all models work with Batch API. `gpt-image-1.5` works; `bluefire-alpha` does NOT (returns `model_not_found`). Custom/internal models typically need online concurrent calls instead.

## Local Concurrent API Calls (for unsupported batch models)

When Batch API doesn't support a model, use ThreadPoolExecutor:

```python
# 32 threads, ~1850 images/hour with bluefire-alpha
python tools/design_edit_pipeline/run_image_edit_openai.py \
    --input-jsonl edit_pairs.jsonl \
    --output-jsonl results.jsonl \
    --output-image-dir ./images \
    --model bluefire-alpha \
    --concurrency 32 \
    --resume  # skip already-done pair_ids
```

Key design:
- `--resume` reads existing output JSONL, skips completed pair_ids
- 3 retries with exponential backoff per request
- Thread-safe JSONL writing with lock + flush
- Progress logging every 100 records with ETA

## Vertex AI Batch for Instruction Generation

Generate edit instructions at scale using Gemini Flash:

```yaml
# Config for main.py
model: "gemini-3-flash-preview"
image_keys: ["source_image"]
upload_files: true
response_modalities: null  # text response (not IMAGE)
```

**Critical: local paths must be mapped to GCS URIs before submission.** The TaskConverter only handles S3->GCS mapping, not local paths. Either:
1. Upload local images to GCS upfront in data prep, write GCS URIs directly
2. Or use `fix_local_batch.py` post-hoc to patch fileUri in batch_input.jsonl

## Canonical Output Format

```json
{
    "input_images": ["s3://bucket/source/image.png"],
    "edit_instructions": ["Change the background to blue"],
    "output_images": ["s3://bucket/output/pair_id.webp"],
    "metadata": {
        "pair_id": "record_001_inst1",
        "edit_type": "background_modification",
        "edit_category": "Visual Adjustments",
        "difficulty": "simple",
        "design_type": "poster",
        "edit_model": "gpt-image-1.5",
        "output_format": "webp"
    }
}
```

## Speed & Cost Reference

| Method | Model | Speed | Cost per image |
|--------|-------|-------|---------------|
| OpenAI Batch API | gpt-image-1.5 | ~50K/day (potential) | ~$0.029 (50% batch discount) |
| Local concurrent (32 threads) | bluefire-alpha | ~44K/day | ~$0.058 (no discount) |
| Vertex AI Batch | gemini-3-pro-image-preview | ~460K/day | ~$0.072 |

## Prompt Design for Edit Instructions

Two prompt types based on image content:

**Real photos** (`real_photo_edit_5inst.txt`): 10 categories including object editing, style transfer, scene transformation, identity-preserving edits, inpainting/outpainting.

**Design/chart** (`design_edit_user.txt`): 6 categories with emphasis on layout adjustments (spatial, alignment, spacing, hierarchy) and variant generation (style, color, theme, format adaptation).

Both generate exactly 5 instructions per image with difficulty progression: simple -> simple -> medium -> medium-complex -> complex.

## Gemini Image Edit (API Key mode)

Gemini image edit uses `generativelanguage.googleapis.com` (not Vertex AI endpoint):

```python
url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
payload = {
    "contents": [{"role": "user", "parts": [
        {"inlineData": {"mimeType": mime, "data": img_b64}},
        {"text": instruction},
    ]}],
    "generationConfig": {
        "responseModalities": ["IMAGE"],
        "imageConfig": {"imageSize": "2K"},  # "1K", "2K", "4K"
    },
}
```

**Resolution gotchas:**
- `imageSize: "2K"` → ~2528×1686 (long side 2K+, short side ~1686, NOT both >=2048)
- `imageSize: "4K"` → ~4780×3584 (true high-res but 17MP, much slower)
- `imageOutputOptions` is NOT supported on API key endpoint (Vertex AI only)

**Auto aspect ratio matching for OpenAI:**
```python
def pick_openai_size(local_path):
    w, h = Image.open(local_path).size
    ratio = w / h
    if abs(ratio - 1.5) < abs(ratio - 1.0) and abs(ratio - 1.5) < abs(ratio - 0.667):
        return "1536x1024"
    elif abs(ratio - 0.667) < abs(ratio - 1.0):
        return "1024x1536"
    return "1024x1024"
```

## Data Cleaning (post-generation)

After generating edits, run quality assessment. See skill: **image-edit-quality-judge**

Key pipeline: `prepare_edit_judge.py` → Gemini batch judge + OpenAI online judge → `export_clean_dataset.py`

Typical pass rates: 92.6% (all>=4), 84.6% (all>=5) across 634k records.

## Reference Implementation

- Edit pipeline v1: `annotation_batch_infer/tools/edit_pipeline/` (generate_edit_instructions, run_image_edit, visualize)
- Edit pipeline v2: `annotation_batch_infer/tools/design_edit_pipeline/` (design-focused, OpenAI batch)
- Quality judge: `annotation_batch_infer/tools/edit_pipeline/` (prepare_edit_judge, run_openai_judge, export_clean_dataset)
- Workers: `annotation_batch_infer/tools/workers/`
- Configs: `annotation_batch_infer/configs/edit_judge/`, `configs/edit_instructions/`, `configs/design_edit/`, `configs/design_edit_v2/`
- Prompts: `annotation_batch_infer/prompts/edit_judge.txt`, `edit_instructions_*.txt`, `design_edit_*.txt`
- Data card: `all_visual_demo/all_reports/image_edit_dataset_card.md`
