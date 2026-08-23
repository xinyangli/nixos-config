---
name: canva-model-weights-deploy
description: Update Canva ML model weights through W&B registry upload, artifact mirroring, model lockfile PRs, and staged deployment PRs. Use when updating ingredient-generation/media-transformation model checkpoints, running arnold registry upload, following Canva artifact mirroring, fixing W&B artifact upload issues, or changing Platy ARTIFACT_ID variants.
---

# Canva Model Weights Deploy

## Scope

Use this for the two-PR Canva model update flow:

1. **Artifact PR**: add/mirror the new model artifact into `tools/build/python/model_artifacts`.
2. **Deployment PR**: after the artifact PR merges to `master`, update the worker config, usually `ARTIFACT_ID`, for the target variant.

Keep these steps separate. Do not deploy a worker variant in the artifact PR.

## Key Rules

- Never paste W&B API keys, AWS credentials, or signed URLs into chat or committed files.
- Use service-level W&B entities and registries, not old global `canva` / migrated registries unless already required by the model.
- Check which W&B registry version is complete before creating PRs. Do not assume `latest`, `v9`, or a business label points to the final successful upload.
- Artifact PRs should include exactly the generated model artifact files:
  - `tools/build/python/model_artifacts/model_manifest.toml`
  - `tools/build/python/model_artifacts/models.lock.json`
  - `tools/build/python/model_artifacts/models.MODULE.bazel`
- Deployment PRs should touch only deployment config unless there is a clear extra need.

## Upload To W&B Registry

Use `arnold registry upload` for a local checkpoint folder:

```bash
arnold registry upload \
  --folder /mnt/ephemeral/ckpts/MODEL_DIR/ \
  --wandb-entity canva-ingredient-generation \
  --wandb-project-name ingredient-generation-image-edit-proteus-pstyle \
  --aliases "v12,latest" \
  --registry-target wandb-registry-ingredient-generation
```

If `arnold` prompts for W&B login in a noninteractive shell, set `WANDB_API_KEY` from a safe local source such as `~/.netrc`; do not echo the key into logs.

### W&B Large Artifact Failure Workaround

Symptoms:

```text
ArtifactSaver.uploadFiles: most remaining uploads have failed, giving up
gorilla-files-url-signer@wandb-production.iam.gserviceaccount.com does not have storage.multipartUploads.create
gorilla-files-url-signer@wandb-production.iam.gserviceaccount.com does not have storage.objects.delete
```

Recommended workaround:

1. Re-shard large `.safetensors` files to `<2GiB` so W&B avoids multipart uploads.
2. Avoid duplicate content hashes within the same artifact. In practice, duplicate tokenizer/processor files can trigger same-object overwrites in W&B/GCS and require `storage.objects.delete`.
3. Use `_WANDB_USE_V1_ARTIFACTS=true` if V2 artifact storage keeps hitting GCS signer bugs.
4. Validate the resulting artifact contains all files and index references before creating PRs.

Lightweight artifact completeness check:

```bash
WANDB_API_KEY="$(python3 - <<'PY'
import netrc
print(netrc.netrc().authenticators("api.wandb.ai")[2])
PY
)" python3 - <<'PY'
import json
from pathlib import Path
import tempfile
import wandb

api = wandb.Api()
name = "canva_LAHXJJZ2L2BAE/wandb-registry-ingredient-generation/ingredient-generation-image-edit-proteus-pstyle:v12"
art = api.artifact(name, type="model")
names = {f.name for f in art.files()}
root = Path(tempfile.mkdtemp(prefix="artifact-check-"))

for idx_name in [
    "text_encoder/model.safetensors.index.json",
    "transformer/diffusion_pytorch_model.safetensors.index.json",
]:
    idx_path = Path(art.get_entry(idx_name).download(root=str(root)))
    idx = json.loads(idx_path.read_text())
    prefix = str(Path(idx_name).parent)
    referenced = {f"{prefix}/{p}" for p in set(idx["weight_map"].values())}
    missing = sorted(referenced - names)
    print(idx_name, "shards:", len(referenced), "missing:", missing[:5])
PY
```

## Artifact PR

Create a clean branch from latest `master`:

```bash
git fetch origin master
git checkout -b update-model-weights origin/master
```

Append a model entry to `tools/build/python/model_artifacts/model_manifest.toml`.

Example:

```toml
[[models.ingredient-generation-image-edit-proteus-pstyle]]
version = "v12"
owners = [
  "<primary-owner@canva.com>",
  "<secondary-owner@canva.com>",
]
remote_artifact_globs = [
  "**/*.safetensors",
]
registry = "ingredient-generation"
```

Prefer the real W&B registry version (`v12`) over a business nickname (`v9`). Only use `identifier` when the consuming system explicitly requires a stable logical ID and the team agrees.

Commit and open the PR:

```bash
git add tools/build/python/model_artifacts/model_manifest.toml
git commit -m "Update pstyle model weights to v12"
git push -u origin HEAD
gh pr create --title "Update pstyle model weights to v12" --body "..."
```

Trigger artifact mirroring on the PR:

```text
@canva-ci-bot trigger ml-platform-mirror-model-artifacts
```

```ini
ARTIFACT_NAME=ingredient-generation-image-edit-proteus-pstyle
```

Wait for Buildkite to push the automatic lockfile commit. Completion signs:

- The `ml-platform-mirror-model-artifacts` Buildkite build succeeds.
- The PR branch gets an automatic commit like `Updating model lockfile for Canva/canva commit ...`.

Then pull, tidy, and push:

```bash
git pull --ff-only
FORCE_NO_BAZEL_REMOTE_EXECUTION=true bazel mod tidy
git status --short
```

If `bazel mod tidy` changes `models.MODULE.bazel`, commit it:

```bash
git add tools/build/python/model_artifacts/models.MODULE.bazel
git commit -m "bazel mod tidy"
git push
```

Before merge, the artifact PR should match the reference pattern:

```text
tools/build/python/model_artifacts/model_manifest.toml
tools/build/python/model_artifacts/models.lock.json
tools/build/python/model_artifacts/models.MODULE.bazel
```

After checks and owners pass:

```text
@canva-ci-bot merge
```

Wait until the PR is merged to `master` before starting the deployment PR.

## Deployment PR

Start from latest `master` after the artifact PR merges:

```bash
git fetch origin master
git checkout -b deploy-pstyle-v12-variant-a origin/master
```

Update only the target worker config. Example:

```python
"ARTIFACT_ID": select_variant(
    a = "v12",
    b = "v6",
),
```

For pstyle this file is:

```text
backend/ingredient_generation_image_edit_proteus_pstyle_ml_worker/config/platy_intent.star
```

Keep unrelated variants unchanged. For a variant A rollout, leave variant B exactly as-is.

Also update the model server bundle so the new `ARTIFACT_ID` exists in `models.manifest`. For pstyle this is:

```text
ingredient_generation_server/models/image_edit_proteus_pstyle_server/BUILD.bazel
```

Example for rolling variant A from `v4` to `v12` while keeping variant B on `v6`:

```python
model_artifact(
    name = "image_edit_proteus_pstyle_v12",
    alias = "v12",
    artifact_name = "ingredient_generation_image_edit_proteus_pstyle",
)

model_server_lib(
    # ...
    model_artifacts = [
        ":image_edit_proteus_pstyle_v12",
        ":image_edit_proteus_pstyle_v6",
    ],
)
```

Do not leave the server bundle with only `v4`/`v6` if `platy_intent.star` sets `ARTIFACT_ID=v12`; the worker may fail to resolve the artifact at runtime.

Commit and create PR:

```bash
git add \
  backend/ingredient_generation_image_edit_proteus_pstyle_ml_worker/config/platy_intent.star \
  ingredient_generation_server/models/image_edit_proteus_pstyle_server/BUILD.bazel
git commit -m "Deploy pstyle v12 weights to variant A"
git push -u origin HEAD
gh pr create --title "Deploy pstyle v12 weights to variant A" --body "..."
```

Recommended PR summary:

```markdown
## Summary
- Roll `ingredient-generation-proteus-pstyle-ml-worker` variant A to `ARTIFACT_ID=v12`.
- Leave variant B on `v6`.

## Test plan
- Verified the artifact PR has merged and `v12` is available in the model artifact closure.
- Checked the Starlark and BUILD config diffs and lints.
```

## Staging Before Master

If the team wants staging validation before merging deployment:

1. Keep the deployment PR open.
2. Deploy/test the PR branch in staging using the team's Platy/component deployment workflow.
3. Only merge the deployment PR after staging confirms model load and inference are healthy.

## Common Pitfalls

- **Branch too old**: If CI precheck pipeline generation fails, compare against `origin/master`. Rebase if the branch is thousands of commits behind.
- **Mirror triggered on old head**: If you push after triggering mirror, retrigger `ml-platform-mirror-model-artifacts` for the latest commit.
- **Local mirror fails**: Devboxes may lack GCS Workload Identity for `ml-artifact-mirror`; use Buildkite mirror pipeline instead.
- **`git pull` hangs on Watchman**: Use `git -c core.fsmonitor=false fetch` and `git -c core.fsmonitor=false merge --ff-only`.
- **Squashing after mirror**: If you squash/rebase after the mirror commit, verify final diff still has all three artifact files and rerun `bazel mod tidy`.
- **Deployment mixed into artifact PR**: Revert it and create a separate deployment PR after the artifact PR merges.
- **Missing server artifact target**: If deployment sets `ARTIFACT_ID=v12`, ensure the server `BUILD.bazel` includes a `model_artifact` target for `v12` and lists it in `model_artifacts`. Updating only `platy_intent.star` is not enough.
