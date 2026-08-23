---
name: image-edit-quality-judge
description: Multi-model quality assessment and data cleaning pipeline for image editing datasets. Evaluates (source, instruction, edited) triplets on three dimensions (edit adherence, visual quality, content preservation) using Gemini batch + OpenAI online judges. Exports filtered clean datasets in canonical JSONL format with dual-judge scores. Use when filtering/cleaning image edit data, running VLM-based quality judges, merging multi-model scores, or exporting clean training datasets.
---

# Image Edit Quality Judge & Data Cleaning

## Overview

After generating image edits (via `image-edit-pipeline` skill), this pipeline evaluates quality and filters to keep only high-quality results. It runs two independent VLM judges and exports a canonical dataset.

```
Edit Results (634k records)
    |
    v
[prepare_edit_judge.py] -- Convert to judge-ready JSONL + upload to GCS
    |
    +--> [Gemini Batch Judge] -- gemini-3-flash-preview via Vertex AI
    |         634k records, ~$500 batch pricing
    |
    +--> [OpenAI Online Judge] -- gpt-5.4-mini, 16 concurrent workers
    |         634k records, ~$950
    |
    v
[export_clean_dataset.py] -- Merge scores, filter, export canonical JSONL
    |
    v
clean_dataset.jsonl (587k, all>=4)
clean_dataset_strict5.jsonl (537k, all>=5)
```

## Judge Prompt (3 dimensions in 1 call)

The same prompt is used for both Gemini and OpenAI judges. It evaluates three dimensions in a single API call to save cost:

```
You are an expert image editing quality assessor. You are given:
1. A **source image** (the original, unedited image)
2. An **edited image** (the result of applying an edit)
3. An **edit instruction** that was used to produce the edited image

Evaluate across three dimensions (1-5 scale):

## Edit Adherence
5 = perfectly matches instruction
1 = completely unrelated or no change

## Visual Quality
5 = production-ready, no artifacts
1 = severely broken

## Content Preservation
5 = only instructed change, everything else preserved
1 = almost entirely regenerated

The edit instruction was: "${instruction}"

Return JSON: {"edit_adherence":5,"visual_quality":5,"content_preservation":5,"reasoning":"..."}
```

Full prompt at: `annotation_batch_infer/prompts/edit_judge.txt`

## Step 1: Prepare Judge Input

```bash
python tools/edit_pipeline/prepare_edit_judge.py \
    --input-dir /mnt/ephemeral/gemini_batch/image_edit \
    --output-dir /mnt/ephemeral/gemini_batch/edit_judge \
    --gcs-bucket core-cn-storage-bucket \
    --gcs-prefix dataset/image_edit_results \
    --upload-workers 64
```

This script:
- Reads the 4 edit result JSONLs (gemini_real_photo, gemini_design, openai_real_photo, openai_design)
- Filters to `status == "success"` only
- Writes judge-ready JSONL with `source_image` (GCS), `edited_image` (GCS), `instruction`
- Uploads edited images to GCS (for Vertex AI batch access)
- Supports `--exclude-snapshot judged_snapshot.json` to skip already-judged records (incremental)

**WARNING:** Do NOT use Python GCS client per-file upload — it's ~13 files/sec. Use `gsutil -m rsync` for bulk upload (~200MB/s):

```bash
gsutil -m rsync -r /mnt/ephemeral/gemini_batch/image_edit/gemini_real_photo/ \
    gs://core-cn-storage-bucket/dataset/image_edit_results/gemini_real_photo/
```

## Step 2a: Gemini Batch Judge (Vertex AI)

Configs at: `annotation_batch_infer/configs/edit_judge/{task}.yaml`

```bash
# Convert + submit (images must already be on GCS)
for task in gemini_real_photo gemini_design openai_real_photo openai_design; do
    python3 main.py --config configs/edit_judge/${task}.yaml --skip-upload --no-wait
done
```

Config structure:
```yaml
image_keys: ["source_image", "edited_image"]  # both GCS URIs
text_key: "instruction"
model: "gemini-3-flash-preview"
thinking_level: "LOW"
media_resolution: "high"
```

**CRITICAL: Gemini batch output order != input order.** Must align by extracting `pair_id` from the edited image URI in each prediction's request, NOT by line index.

```python
# Correct alignment
for p in prediction['request']['contents'][0]['parts']:
    if 'fileData' in p and '_inst' in p['fileData']['fileUri']:
        pair_id = os.path.splitext(os.path.basename(p['fileData']['fileUri']))[0]
```

## Step 2b: OpenAI Online Judge (Concurrent)

```bash
for task in gemini_real_photo gemini_design openai_real_photo openai_design; do
    python tools/edit_pipeline/run_openai_judge.py \
        --input-jsonl /mnt/ephemeral/gemini_batch/edit_judge/${task}_judge_input.jsonl \
        --output-jsonl /mnt/ephemeral/gemini_batch/edit_judge/${task}_openai_scores.jsonl \
        --model gpt-5.4-mini \
        --concurrency 16 \
        --resume &
done
```

Uses OpenAI Responses API (not Batch API) because:
- Each request has 2 images base64 (~1-5MB) → Batch API 200MB file limit is too restrictive
- `"store": False` → no data stored on OpenAI side
- `--resume` reads existing output, skips completed pair_ids

Speed: ~5-6 records/sec at concurrency 16.

## Step 3: Export Clean Dataset

```bash
python tools/edit_pipeline/export_clean_dataset.py \
    --judge-dir /mnt/ephemeral/gemini_batch/edit_judge \
    --output clean_dataset.jsonl \
    --min-score 4
```

Output format:
```json
{
    "input_images": ["s3://...source.webp"],
    "edit_instructions": ["Remove the fence bars..."],
    "output_images": ["s3://...edited.jpg"],
    "metadata": {
        "pair_id": "MAEPAFh4ch0_inst4",
        "edit_type": "object removal",
        "edit_category": "Object-Level Editing",
        "difficulty": "medium",
        "image_type": "real_photo",
        "edit_provider": "gemini",
        "edit_model": "gemini-3-pro-image-preview"
    },
    "gemini_judge": {"edit_adherence": 5, "visual_quality": 5, "content_preservation": 5, "reasoning": "..."},
    "openai_judge": {"edit_adherence": 5, "visual_quality": 4, "content_preservation": 5, "reasoning": "..."}
}
```

## Snapshot-Based Incremental Dedup

After judging, a `judged_snapshot.json` is saved with all `task::pair_id` entries:

```json
{
    "created_at": "2026-04-13T20:11:06Z",
    "total_judged": 634423,
    "id_format": "task::pair_id",
    "pair_ids": ["gemini_real_photo::MAD--_L1VHg_inst10", ...]
}
```

Next time, use `--exclude-snapshot` to skip already-judged records:

```bash
python tools/edit_pipeline/prepare_edit_judge.py \
    --exclude-snapshot /path/to/judged_snapshot.json
```

## Typical Score Distribution

| Dimension | Score 5 | Score 4 | Score <=3 |
|-----------|---------|---------|-----------|
| Edit Adherence | 94% | 1% | 5% |
| Visual Quality | 91% | 7% | 2% |
| Content Preservation | 92% | 5% | 3% |

Pass rates: all>=4 → 92.6%, all>=5 → 84.6%

## Visualization

```bash
streamlit run tools/edit_pipeline/visualize_clean_dataset.py --server.port 8521
```

Features:
- Browse tab: 4-column grid, lightbox with prev/next, download full-res
- Distribution tab: edit type histograms split by real_photo vs design
- Lazy loading: only reads current page from disk, not full 587k records
- Pre-shuffled JSONL files for random browsing

## Reference Files

- Prepare: `annotation_batch_infer/tools/edit_pipeline/prepare_edit_judge.py`
- OpenAI judge: `annotation_batch_infer/tools/edit_pipeline/run_openai_judge.py`
- Merge/export: `annotation_batch_infer/tools/edit_pipeline/export_clean_dataset.py`
- Score merge: `annotation_batch_infer/tools/edit_pipeline/merge_judge_scores.py`
- Visualize: `annotation_batch_infer/tools/edit_pipeline/visualize_clean_dataset.py`
- Judge prompt: `annotation_batch_infer/prompts/edit_judge.txt`
- Batch configs: `annotation_batch_infer/configs/edit_judge/*.yaml`
- Data card: `all_visual_demo/all_reports/image_edit_dataset_card.md`

## Cost Summary

| Component | Model | Records | Cost |
|-----------|-------|---------|------|
| Gemini batch judge | gemini-3-flash-preview | 634k | ~$500 |
| OpenAI online judge | gpt-5.4-mini | 634k | ~$950 |
| **Total judging** | | | **~$1,450** |
