---
name: slack-job-notifier
description: "Send Slack notifications for long-running jobs, UTP/Arnold/Ray/S3 batch processing, evaluation pipelines, task progress checks, completion/failure alerts, and user-requested Slack messages. Use when Codex should notify a specified Slack channel or user about job start, milestone progress, outputs, failures, retries, or final status using the slack-notify CLI."
---

# Slack Job Notifier

## Overview

Use the `slack-notify` CLI from `PATH` to send concise operational updates.
Credentials must remain outside the skill and repository.

Never print, echo, commit, or copy Slack tokens into commands, logs, repositories, or skill files.

## Destinations

- Require an explicit destination when the user has not already provided one.
- If the user gives a channel ID, use `--channel`.
- If the user gives an email address, use `--to-email`.
- If the user gives a Slack user ID, use `--user-id`.
- If a channel send returns `channel_not_found` or `not_in_channel`, tell the user to invite the bot to that channel with `/invite @<bot-name>` and retry only after they confirm.

## Send Messages

Prefer terse messages with enough operational context to act on:

```bash
slack-notify --to-email "recipient@canva.com" \
  --title "job progress" \
  --status progress \
  --text "120/800 shards done; output: s3://bucket/prefix/"
```

```bash
slack-notify --channel "C0123456789" \
  --title "devbox task monitor" \
  --status info \
  --text "task started: caption_eval_v4"
```

Use `--status` consistently:

- `info`: start notices, neutral notes, configuration checks.
- `progress`: milestone updates and live counters.
- `success`: completed work with final output path.
- `warning`: retryable issues, partial outputs, degraded state.
- `error`: failed jobs, blocked work, unrecoverable errors.

## Notification Policy

Send Slack updates for important transitions, not every loop iteration. Good triggers:

- job submitted or resumed;
- first successful output written;
- progress milestones such as 25%, 50%, 75%, or meaningful shard-count jumps;
- retry started or recovered;
- job failed, including the shortest actionable error summary;
- job completed, including exact output root and verification result.

For long-running jobs, include stable counters over vague elapsed-time summaries: shard coverage, object counts, readable output paths, failed shard IDs, and ETA only when it is evidence-backed.

## Credentials

`slack-notify` reads credentials in this order:

- `SLACK_BOT_TOKEN`, otherwise `~/.config/slack-notify/bot_token`;
- `SLACK_WEBHOOK_URL`, otherwise `~/.config/slack-notify/webhook_url` for `--webhook`.

If credentials are missing, ask the user to provide or rotate the token and store it with:

```bash
mkdir -p ~/.config/slack-notify
chmod 700 ~/.config/slack-notify
read -rsp "SLACK_BOT_TOKEN: " token
echo
printf '%s\n' "$token" > ~/.config/slack-notify/bot_token
chmod 600 ~/.config/slack-notify/bot_token
unset token
```

Required Slack scopes:

- `chat:write` for posting messages;
- `im:write` for direct messages via `--user-id` or `--to-email`;
- `users:read` and `users:read.email` for `--to-email`.

## Verification And Failures

After a successful send, report Slack's returned `channel` and `ts`.

If the sandboxed command fails with DNS/network errors such as `Temporary failure in name resolution`, rerun the same `slack-notify` command with network access outside the sandbox when allowed by the current environment policy.

Use `--dry-run` before sending only when checking formatting or destination selection. Do not treat dry-run as proof that Slack delivery worked.
