---
name: utp-vertex-wif
description: Use when running Vertex AI or Gemini jobs from Arnold/UTP, especially from AWS/EKS with Workload Identity Federation, Google GenAI clients, GCS upload/download, Vertex batch submission, and UTP monitoring.
---

# UTP Vertex WIF

Use this workflow when a UTP/Arnold job must call Vertex AI/Gemini or read/write GCS from Canva AWS infrastructure.

## Core Pattern

1. Run the actual work inside an Arnold/UTP Ray JobSet.
2. Use the pod's AWS role as the source identity.
3. Exchange AWS credentials for Google credentials via AWS Workload Identity Federation.
4. Pass those credentials explicitly to Vertex/Gemini and GCS clients.
5. Submit Arnold with `--no-watch` for fan-out jobs so local processes do not block.

## Required Environment

Set these in the UTP compute YAML:

```yaml
env_vars:
  CANVA_FLAVOR: prod
  FLAVOR: prod
  CANVA_PLATFORM: eks
  PIP_CONSTRAINT: ""
  AWS_REGION: us-east-1
  AWS_DEFAULT_REGION: us-east-1
  GOOGLE_CLOUD_PROJECT: cnvprd-core-cn-npd
  GOOGLE_CLOUD_LOCATION: global
  GOOGLE_GENAI_USE_VERTEXAI: 'True'
  GOOGLE_WIF_AUDIENCE: //iam.googleapis.com/projects/653103247366/locations/global/workloadIdentityPools/vertex-wif/providers/wif-provider
  GOOGLE_WIF_SERVICE_ACCOUNT: vertex@cnvprd-core-cn-npd.iam.gserviceaccount.com
```

Install Python deps in the image or entrypoint:

```bash
PIP_CONSTRAINT="" pip install google-auth google-genai google-cloud-storage google-cloud-aiplatform boto3
```

For Arnold/Ray jobs, the image must already contain `ray`; installing Ray in the entrypoint is too late for Arnold health checks.

## WIF Credentials Helper

Prefer a repo helper such as `src.gcp_auth.get_google_credentials()`. If absent, use this minimal helper:

```python
import os
import boto3.session
import google.auth.aws as google_auth_aws

SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]


class AwsCredentialsSupplier(google_auth_aws.AwsSecurityCredentialsSupplier):
    def __init__(self, session: boto3.session.Session):
        self._session = session

    def get_aws_security_credentials(self, context, request):
        credentials = self._session.get_credentials()
        if credentials is None:
            raise RuntimeError("No AWS credentials available for Google WIF")
        frozen = credentials.get_frozen_credentials()
        return google_auth_aws.AwsSecurityCredentials(
            access_key_id=frozen.access_key,
            secret_access_key=frozen.secret_key,
            session_token=frozen.token,
        )

    def get_aws_region(self, context, request):
        return self._session.region_name or os.environ.get("AWS_REGION", "us-east-1")


def get_google_wif_credentials():
    session = boto3.session.Session(region_name=os.environ.get("AWS_REGION", "us-east-1"))
    service_account = os.environ["GOOGLE_WIF_SERVICE_ACCOUNT"]
    credentials = google_auth_aws.Credentials(
        audience=os.environ["GOOGLE_WIF_AUDIENCE"],
        subject_token_type="urn:ietf:params:aws:token-type:aws4_request",
        token_url="https://sts.googleapis.com/v1/token",
        service_account_impersonation_url=(
            "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/"
            f"{service_account}:generateAccessToken"
        ),
        aws_security_credentials_supplier=AwsCredentialsSupplier(session),
        scopes=SCOPES,
    )
    return credentials, os.environ.get("GOOGLE_CLOUD_PROJECT")
```

## Client Initialization

Check AWS identity first; this catches missing UTP/AWS auth early:

```python
import boto3

print(boto3.client("sts", region_name="us-east-1").get_caller_identity())
```

Initialize Google clients with explicit WIF credentials:

```python
from google import genai
from google.cloud import storage
from google.genai.types import HttpOptions

credentials, project = get_google_wif_credentials()
location = os.environ.get("GOOGLE_CLOUD_LOCATION", "global")

genai_client = genai.Client(
    vertexai=True,
    project=project,
    location=location,
    credentials=credentials,
    http_options=HttpOptions(api_version="v1"),
)

gcs_client = storage.Client(project=project, credentials=credentials)
```

For one-off online smoke tests:

```python
response = genai_client.models.generate_content(
    model="gemini-2.0-flash",
    contents="Say hello",
)
print(response.text)
```

For Vertex batch jobs:

```python
job = genai_client.batches.create(
    model="publishers/google/models/gemini-2.0-flash",
    src="gs://bucket/path/batch_input.jsonl",
    config={
        "display_name": "my-batch-job",
        "dest": "gs://bucket/path/output/",
    },
)
print(job.name)
```

## GCS IO

Prefer the Python GCS client under WIF. Do not rely on `gsutil` or local ADC inside UTP pods.

```python
bucket = gcs_client.bucket("core-cn-storage-bucket")
bucket.blob("path/to/file.jsonl").upload_from_filename("/tmp/file.jsonl")
bucket.blob("path/to/file.jsonl").download_to_filename("/tmp/file.jsonl")
```

For existing annotation repos, set:

```yaml
env_vars:
  GCS_UPLOAD_BACKEND: python
  GCS_DOWNLOAD_BACKEND: python
```

## Arnold YAML Shape

Use head-only jobs for single-shard postprocess or submission workers; use worker nodes only when the application actually schedules Ray tasks.

```yaml
name: ${arnold_job_name}
max_retries: 0
image_uri: 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-omra-trainer:TAG_WITH_RAY
entrypoint: >
  python /app/worker.py
compute_config:
  head_node:
    instance_type: m5.8xlarge
  worker_nodes: []
  flags:
    workload_starting_timeout: 1h
```

Submit without watching for large fan-out:

```bash
FORCE_NO_BAZEL_REMOTE_EXECUTION=true arnold -x submit --no-login --no-watch -o name \
  --job-name "my-job-$(date +%s)" \
  --compute-config path/to/job.yaml \
  --application-id core-cn
```

## Monitoring

```bash
arnold -x list --application-id core-cn --no-login | rg 'JOB_PREFIX'
kubectl get pods -n b-core-cn-prod --no-headers -o wide | rg 'JOB_PREFIX'
kubectl exec -n b-core-cn-prod HEAD_POD -- ray job list --address http://localhost:8265
kubectl exec -n b-core-cn-prod HEAD_POD -- ray status
kubectl exec -n b-core-cn-prod HEAD_POD -- sh -lc 'ray job logs JOB_NAME --address http://localhost:8265 | tail -100'
```

If `arnold` or `kubectl` returns 403, ask the user to re-authenticate or run:

```bash
infra_access infra_login
```

This fixes UTP/k8s auth; it is separate from AWS SSO/S3 auth.

## Practical Notes

- Use `--no-watch`; otherwise `arnold submit` stays attached until the remote job finishes.
- For one shard per node, create one head-only YAML per shard and submit one JobSet per shard.
- For long output logs, suppress noisy expected parser warnings in the worker instead of changing merge behavior.
- Verify completion by checking both Arnold `Completed/succeeded:1` and the expected S3/GCS output object size.
