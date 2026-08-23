---
name: highway-demo-server
description: Start an HTTP service in Devbox and expose it to colleagues via infra highway tunnel. Covers tmux session setup, python http.server, highway tunnel creation, and warp access. Use when needing to share HTML demos, comparison pages, Streamlit/Gradio apps, or any HTTP service with teammates.
---

# Highway Demo Server

## Overview

在 Devbox 中启动 HTTP 服务并通过 infra highway 暴露给同事访问。适用于分享 HTML 对比页面、Streamlit/Gradio 应用、FastAPI 服务等。

## Quick Start

### 1. 在 tmux 中启动 HTTP 服务

```bash
# 创建 tmux session，window 1 运行 http server
tmux new-session -d -s demo 'python3 -m http.server 8080 -d /path/to/your/project'
```

对于其他框架：
```bash
# Streamlit
tmux new-session -d -s demo 'streamlit run app.py --server.port 8080'

# Gradio
tmux new-session -d -s demo 'python3 app.py'  # Gradio 默认 7860

# FastAPI
tmux new-session -d -s demo 'uvicorn main:app --host 0.0.0.0 --port 8080'
```

### 2. 创建 highway tunnel

```bash
# 在同一个 tmux session 的新 window 中启动 tunnel
tmux new-window -t demo
tmux send-keys -t demo 'infra highway http 8080' Enter
```

输出中会包含公开 URL：
```
Go to: https://xxxxx-yyyyy-zzzzz.highway.canva-internal.dev
```

### 3. 允许同事通过 warp 访问

```bash
infra highway allow --route xxxxx-yyyyy-zzzzz.highway.canva-internal.dev --warp
```

### 4. 查看已有的 highway 服务

```bash
infra highway list
```

### 5. 复用之前的 highway 名称

```bash
infra highway run --route xxxxx-yyyyy-zzzzz --port 8080
```

## 注意事项

- `python3 -m http.server` 不支持 `../` 路径穿越，如果 HTML 引用了项目目录外的文件，需要创建 symlink：
  ```bash
  ln -sf /actual/path/to/data /your/project/data
  ```
- highway tunnel 需要在 tmux 中持续运行，关闭 terminal 不会中断
- 默认只有自己可以访问，`--warp` 参数开放给所有使用 Cloudflare WARP 的同事
- 推荐工具选择：
  - 静态 HTML/图片对比 → `python3 -m http.server`
  - 科学绘图 → Dash
  - 交互式 APP → Streamlit / Gradio
  - REST API → FastAPI

## 完整一键脚本示例

```bash
#!/bin/bash
PORT=${1:-8080}
DIR=${2:-.}
SESSION="demo-server"

# 启动 http server
tmux new-session -d -s $SESSION "python3 -m http.server $PORT -d $DIR"

# 启动 highway tunnel
tmux new-window -t $SESSION "infra highway http $PORT"

# 等待 tunnel 启动
sleep 8

# 提取 URL
URL=$(tmux capture-pane -t $SESSION -p -S -50 | grep -oP 'https://\S+\.highway\.canva-internal\.dev')

# 开放 warp 访问
ROUTE=$(echo $URL | sed 's|https://||')
infra highway allow --route $ROUTE --warp

echo "Service running at: $URL"
echo "tmux session: $SESSION (window 1: server, window 2: tunnel)"
```
