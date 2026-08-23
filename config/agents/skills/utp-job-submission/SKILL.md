---
name: utp-job-submission
description: Submit and monitor distributed Ray jobs on Arnold/UTP. Use for compute YAMLs, Arnold Docker builds, Ray preinstall requirements, CPU worker sizing, Kueue/Karpenter scheduling, pod quota/count checks, Ray parallelism, job logs, and auth troubleshooting.
---

# UTP/Arnold Job Submission

## Overview

Arnold is Canva's job submission tool wrapping Kubernetes JobSets. UTP is a convenience CLI on top of Arnold. Jobs run as Ray clusters with a head node + worker nodes.

## Compute Config YAML Format

```yaml
name: ${arnold_job_name}
max_retries: 1

# Use pre-built image URI or arnold_docker_build macro
image_uri: 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-omra-trainer:my-tag-v1

entrypoint: >
  python /app/my_script.py --arg1 value1

env_vars:
  CANVA_FLAVOR: prod
  FLAVOR: prod
  CANVA_PLATFORM: eks
  PIP_CONSTRAINT: ""
  RAY_SCHEDULER_EVENTS: '0'
  RAY_OBJECT_STORE_MEMORY: '10737418240'

compute_config:
  head_node:
    instance_type: m5.4xlarge
  worker_nodes:
    - name: cpu_worker
      instance_type: m5.8xlarge
      min_nodes: 20
      max_nodes: 20
      market_type: 'ON_DEMAND'
  flags:
    workload_starting_timeout: 1h
```

## Submission Commands

```bash
# Via Arnold (preferred)
FORCE_NO_BAZEL_REMOTE_EXECUTION=true arnold -x submit --no-login \
  --job-name "my-job-$(date +%s)" \
  --compute-config path/to/config.yaml \
  --application-id core-cn

# Via UTP (wrapper)
/path/to/utp s my-job path/to/config.yaml
```

## Docker Build Flow

For Core CN team jobs, assume team members cannot push to ECR directly. Do not spend time trying local `docker push` or manual ECR login unless the user explicitly says they have unusual push access. Use Arnold's Docker build macro instead.

Use this in the Arnold compute config or generated JobSet:

```yaml
image_uri: "${arnold_docker_build:ds-core-cn-omra-trainer,.,Dockerfile,deploy_core-cn-readwrite}"
```

Arnold resolves this as:

```text
repo_name=ds-core-cn-omra-trainer
context_path=.
dockerfile_path=Dockerfile
aws_profile=deploy_core-cn-readwrite
```

`arnold_docker_build` runs during `arnold submit` or `arnold migrate`, builds from the local source tree, and pushes through Arnold's permitted path. Local `docker build` is still useful for debugging Dockerfile syntax, but it is not the production submission path for this team.

### Critical: Ray Must Be Pre-Installed

UTP/Arnold starts Ray health checks **before** the entrypoint runs. If the image lacks `ray`, the head node fails with `ray: command not found` and all pods are killed within ~2 minutes.

For CPU-only workloads on a new base image:

```dockerfile
FROM 699983977898.dkr.ecr.us-east-1.amazonaws.com/ds-core-cn-template-trainer:training-base-pt210-cu130-py312-HASH

RUN PIP_CONSTRAINT="" pip install --no-cache-dir \
    "ray[default]>=2.9" "boto3>=1.28" "Pillow>=10.0" "numpy>=1.24"
```

Do **not** rely on `pip install ray` in the entrypoint — it runs too late.

## Monitoring

```bash
# List jobs
arnold -x list --application-id core-cn --no-login

# Pod status
kubectl get pods -n b-core-cn-prod -l jobset.sigs.k8s.io/jobset-name=JOB_NAME --no-headers

# Head pod logs
kubectl logs -n b-core-cn-prod HEAD_POD_NAME --tail=30

# Ray job logs (exec into head)
kubectl exec -n b-core-cn-prod HEAD_POD -- ray job logs JOB_NAME --address http://localhost:8265

# Ray cluster status
kubectl exec -n b-core-cn-prod HEAD_POD -- ray status

# Delete job
arnold -x delete JOB_NAME --application-id core-cn --no-login
```

## CPU Ray Jobs

Use CPU jobs as Ray clusters with a zero-CPU head and one or more worker pods. Kubernetes CPU requests and Ray CPU capacity are different: a worker pod can request `cpu: "1"` for Kueue accounting while Ray exposes the node's actual CPUs if the container has no CPU limit and `ray start` is not passed a restrictive `--num-cpus`.

### Submission shape

- Prefer `arnold_docker_build` for Core CN team jobs. Team members generally cannot push to ECR directly, so do not try local ECR push as a normal path.
- If the job needs manual JobSet details such as a broad worker `node.kubernetes.io/instance-type` affinity list, submit the generated JobSet with `arnold submit -f ... --no-watch` rather than resubmitting the original compute config. A compute config may collapse workers back to one `instance_type`.
- Keep job names user-prefixed when that is the local convention, for example `cyrusli-...`, so Arnold/Kueue/pod queries are easy to filter.
- Use `arnold submit --no-watch` for long-running jobs unless the user explicitly wants a local watcher. The submitted JobSet continues running after the local command exits.
- Delete with `arnold delete --job-name JOB --application-id core-cn --no-login`; positional `arnold delete JOB` is not accepted by newer Arnold.

### Worker placement and instance types

- For CPU jobs, do not reason from currently alive nodes as the capacity limit. Karpenter creates nodes on demand; after Kueue admits the workload, AWS instance availability/offering is usually the practical limiter.
- A single requested instance type can still leave workers Pending if AWS cannot currently provide that type or offering. Check pod events for Karpenter messages like "no instance type which met the scheduling requirements" or missing offerings.
- Retry can help when an AWS offering is temporarily unlucky. If a retry still stalls on one instance type, broaden the allowed CPU worker choices instead of reducing the job unnecessarily.
- For large CPU jobs, prefer the largest instance type the code can actually use. Fewer large nodes leave more pod slots and scheduling room for other jobs, and they reduce Ray/node-management overhead. This only works if the code can parallelize across all CPUs on each node.
- Broaden CPU worker choices when AWS capacity for the preferred large type is uncertain. For large x86 CPU Ray jobs on the EFA nodepool, a useful fallback mix has included:
  - `m8in.32xlarge`
  - `m8in.48xlarge`
  - `r6i.32xlarge`
  - `r5.24xlarge`
  - `c7a.32xlarge`
- Keep the dedicated EFA nodepool selector/toleration when the workload depends on UTP's EFA-backed worker pool. Do not remove it just to make scheduling easier unless the user explicitly wants a different pool.
- `arnold list` reports JobSet pod readiness, not Ray worker registration. `active:97, ready:97` means Kubernetes pods are ready; Ray may still show fewer CPUs while workers stagger and run `ray start`.

### Parallelism and resource use

- For many small objects, batch work before submitting Ray tasks. Per-object tasks can create huge Ray task histories, stress GCS/dashboard subscribers, and trigger protobuf-size failures such as `GcsSubscriberPollReply exceeded maximum protobuf size of 2GB`.
- Prefer a driver-side pending-task window around current Ray CPU capacity, not unbounded `ray.remote` submission. If auto parallelism starts before all workers join, periodically recompute `ray.cluster_resources()["CPU"]` and only raise the pending window as CPUs appear.
- Use a timed wait in the driver, for example `ray.wait(pending, timeout=30)`, so auto parallelism can grow even when the first wave of tasks is still running.
- If `ray status` shows `Usage: N/M CPU` and no resource demands, the driver only has `N` runnable tasks queued. This is a driver window issue, not a Ray scheduling backlog.
- Add task memory reservations for memory-spiky CPU parsing jobs, for example an application flag that maps to Ray `memory=3 * 1024**3`. Prefer larger-memory instances over reducing parallelism when CPU utilization must stay high.

### Ray/GCS stability knobs

Use these for high-task-count CPU jobs unless the project has a better local default:

```yaml
env_vars:
  RAY_SCHEDULER_EVENTS: "0"
  REPORTER_UPDATE_INTERVAL_MS: "60000"
  RAY_task_events_report_interval_ms: "60000"
```

These reduce dashboard/reporter/task-event pressure. They do not replace batching; if task counts are in the hundreds of thousands or millions, increase batch size first.

### Pod limits and live pod counts

Find the configured Kueue pod limit from the k8s repo first, then confirm live state from the cluster. The local path is usually `~/work/k8s`; if it is not available, use `github.com/Canva/k8s` as the source of truth.

```bash
# Source config: core-cn pod quota definitions and region-specific overrides.
rg -n "coreCn.*BoundedQuotas|core-cn-cq|pods" \
  ~/work/k8s/manifests/src/libs/addons/kueue/resources.libsonnet
sed -n '420,470p' ~/work/k8s/manifests/src/libs/addons/kueue/resources.libsonnet
sed -n '688,795p' ~/work/k8s/manifests/src/libs/addons/kueue/resources.libsonnet
```

Interpret the current config in that file:

- `coreCnBoundedQuotas` is the base `core-cn-cq` pod cap: `pods nominalQuota: "500", borrowingLimit: "0"`.
- `coreCnUsw2BoundedQuotas` raises `core-cn-cq` pods to `800` in `usw2`.
- `coreCnUse1BoundedQuotas` raises `core-cn-cq` pods to `1150` in `use1`.
- `borrowingLimit: "0"` means the pod cap is a hard queue ceiling rather than borrowable cohort capacity.

Check the live ClusterQueue when exact deployed state matters:

```bash
kubectl get clusterqueue core-cn-cq -o yaml
kubectl describe clusterqueue core-cn-cq
```

Check current pod counts in the core-cn namespace:

```bash
# All pods in namespace.
kubectl get pods -n b-core-cn-prod --no-headers | wc -l

# Active pods only; this is usually the useful pressure signal.
kubectl get pods -n b-core-cn-prod \
  --field-selector=status.phase!=Succeeded,status.phase!=Failed \
  --no-headers | wc -l
```

Group active pods by JobSet/job and include requested CPU:

```bash
kubectl get pods -n b-core-cn-prod \
  --field-selector=status.phase!=Succeeded,status.phase!=Failed \
  -o json \
| jq -r '
    .items[]
    | [
        (.metadata.labels["jobset.sigs.k8s.io/jobset-name"]
          // .metadata.labels["job-name"]
          // "unlabeled"),
        ([.spec.containers[]?.resources.requests.cpu // "0"] | join("+"))
      ]
    | @tsv' \
| awk '
    function cpu(v) { return v ~ /m$/ ? substr(v, 1, length(v)-1) / 1000 : v + 0 }
    {
      pods[$1] += 1
      split($2, c, "+")
      for (i in c) cpus[$1] += cpu(c[i])
    }
    END {
      for (job in pods) printf "%s pods=%d cpu=%.3f\n", job, pods[job], cpus[job]
    }' \
| sort
```

### CPU-job monitoring

```bash
# Arnold/Kueue state
arnold -x list --application-id core-cn --no-login
kubectl get jobset -n b-core-cn-prod JOB -o jsonpath='{.spec.suspend}{"\n"}{.status.conditions[*].type}{"\n"}{.status.conditions[*].status}{"\n"}'

# Pod readiness and placement
kubectl get pods -n b-core-cn-prod -l jobset.sigs.k8s.io/jobset-name=JOB -o wide
kubectl describe pod -n b-core-cn-prod POD

# Ray capacity and demand from the head pod
kubectl exec -n b-core-cn-prod HEAD_POD -- ray status

# Driver logs
kubectl logs -n b-core-cn-prod HEAD_POD --tail=120
kubectl exec -n b-core-cn-prod HEAD_POD -- ray job logs JOB --address http://localhost:8265
```

Interpret common signals:

- `spec.suspend=false` and `QuotaReserved`/`Admitted` means Kueue admitted the workload.
- Pods `Running 1/1` but low Ray CPU means workers are still starting Ray or have not registered with GCS yet.
- `Usage: 0/M CPU` during manifest discovery or S3 listing can be normal if the driver has not submitted Ray tasks yet.
- `Usage: N/M CPU` with no resource demands means Ray has no queued work beyond the driver's current in-flight window.
- `Usage: M/M CPU` means the current registered Ray CPU is fully utilized.

## Auth: re-authenticate when arnold/UTP credentials expire

Symptom: `arnold submit` (or any `arnold` k8s call) fails with HTTP 403 `access denied` from the kubernetes client, OR `arnold list`/`kubectl` returns "Forbidden" / cannot reach the API server. This is usually expired UTP/k8s credentials, not a real RBAC issue.

Fix: re-authenticate via:

```bash
infra_access infra_login
```

This refreshes the UTP/k8s cert chain. Re-run the failed `arnold` command afterward. No need to rebuild the Docker image or change the job-name.

Notes:
- This is distinct from `aws sso login` / Roo SAML stepup (those fix S3 / ECR auth, not k8s).
- If `infra_access` itself isn't installed, install it from the canva infra tooling docs; on a stock devbox it's typically already on PATH.
- If a transient 403 happens *after* a watchdog already submitted, check `arnold list` carefully before resubmitting — your retry may produce a duplicate JobSet (k8s usually 403's the duplicate, but verify).

## Key Notes

- Arnold entrypoint with `&&` chains: only the first command becomes the Ray job entrypoint. Subsequent commands run in the head container directly.
- Base image `release-image-cleaner-v49` lacks `curl` and `aws` CLI. Install in Dockerfile if needed.
- Use `boto3.client('s3').download_file()` instead of `aws s3 cp` in entrypoints.
- Entrypoint using `>` YAML fold: newlines become spaces, forming one command line.
- Instance types: `m5.8xlarge` (32 CPU, 128GB), `m5.24xlarge` (96 CPU, 384GB), `m5.4xlarge` (16 CPU, 64GB).
