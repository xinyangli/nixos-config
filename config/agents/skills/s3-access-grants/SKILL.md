---
name: s3-access-grants
description: Access S3 buckets across accounts using S3 Access Grants (s3control GetDataAccess). Use when reading from cross-account S3 buckets like design-generation-core-oss.canva.com, or when encountering AccessDenied errors on S3 operations requiring temporary credentials.
---

# S3 Access Grants (Cross-Bucket Access)

## When to Use

Some S3 buckets (e.g. `design-generation-core-oss.canva.com`) require S3 Access Grants instead of direct IAM role access. This provides scoped, temporary credentials for a specific prefix.

## CLI Usage

```bash
BUCKET="design-generation-core-oss.canva.com"
PREFIX="datasets/getty-images/"

creds=$(aws s3control --profile "${AWS_PROFILE_NAME}" get-data-access \
    --account-id "051687089423" \
    --target "s3://${BUCKET}/${PREFIX}" \
    --permission READ \
    --privilege Default \
    --region "us-east-1" \
    --query 'Credentials.[join(`=`, [`AWS_ACCESS_KEY_ID`, AccessKeyId]), join(`=`, [`AWS_SECRET_ACCESS_KEY`, SecretAccessKey]), join(`=`, [`AWS_SESSION_TOKEN`, SessionToken])]' \
    --output text)

IFS=$'\t' read -r key_id secret_key session_token <<< "${creds}"
export "${key_id}" "${secret_key}" "${session_token}"

# Now use aws s3api commands normally
aws s3api list-objects-v2 --bucket "${BUCKET}" --prefix "${PREFIX}" --region "us-east-1"
```

## Python (boto3) — One-Shot

```python
def get_s3ag_creds(account_id, target, region="us-east-1"):
    s3ctrl = boto3.Session().client("s3control", region_name=region)
    resp = s3ctrl.get_data_access(
        AccountId=account_id, Target=target,
        Permission="READ", Privilege="Default",
    )
    c = resp["Credentials"]
    return c["AccessKeyId"], c["SecretAccessKey"], c["SessionToken"]

key_id, secret, token = get_s3ag_creds("051687089423", "s3://bucket/prefix/")
s3 = boto3.client("s3", region_name="us-east-1",
    aws_access_key_id=key_id, aws_secret_access_key=secret,
    aws_session_token=token)
```

## Python — Auto-Refreshing Credentials

**Critical for long-running jobs.** Access Grants tokens expire after ~1 hour. Use `RefreshableCredentials` for automatic renewal:

```python
from botocore.credentials import RefreshableCredentials
from botocore.session import get_session
from datetime import datetime, timezone, timedelta

def create_refreshable_s3_client(account_id, target, region="us-east-1"):
    def _fetch():
        s3ctrl = boto3.Session().client("s3control", region_name=region)
        resp = s3ctrl.get_data_access(
            AccountId=account_id, Target=target,
            Permission="READ", Privilege="Default",
        )
        c = resp["Credentials"]
        expiry = datetime.now(timezone.utc) + timedelta(minutes=50)
        return {
            "access_key": c["AccessKeyId"],
            "secret_key": c["SecretAccessKey"],
            "token": c["SessionToken"],
            "expiry_time": expiry.isoformat(),
        }

    bs = get_session()
    bs._credentials = RefreshableCredentials.create_from_metadata(
        metadata=_fetch(), refresh_using=_fetch, method="s3-access-grants",
    )
    return boto3.Session(botocore_session=bs).client("s3", config=boto_config)
```

## Known Access Grants Targets

| Bucket | Target | Account ID |
|--------|--------|-----------|
| `design-generation-core-oss.canva.com` | `s3://design-generation-core-oss.canva.com/datasets/getty-images/` | `051687089423` |

## Common Pitfalls

1. **Token expiry in long jobs**: Always use `RefreshableCredentials` for jobs > 30 minutes.
2. **Caller permissions**: The service role calling `GetDataAccess` needs `s3:GetDataAccess` IAM permission.
3. **CLI fallback**: If boto3 fails, try AWS CLI with `--profile "${AWS_PROFILE_NAME}"`.
4. **Thread safety**: Create per-thread S3 clients; don't share across threads.
