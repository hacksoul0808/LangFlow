#!/usr/bin/env bash
#===============================================================================
# LangFlow 启动脚本 (仅启动服务)
# 用法: bash Start.sh
#===============================================================================

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

BACKEND_FRONTEND_DIR="$PROJECT_DIR/src/backend/base/langflow/frontend"
ENV_FILE="$PROJECT_DIR/.env"

echo "LangFlow 启动中..."
echo "地址: http://localhost:7860"
echo "按 Ctrl+C 停止"
echo ""

if [ -f "$BACKEND_FRONTEND_DIR/index.html" ]; then
    uv run langflow run \
        --frontend-path "$BACKEND_FRONTEND_DIR" \
        --host 0.0.0.0 \
        --port 7860 \
        --log-level info \
        --env-file "$ENV_FILE"
else
    uv run langflow run \
        --host 0.0.0.0 \
        --port 7860 \
        --log-level info \
        --env-file "$ENV_FILE"
fi

echo ""
echo "LangFlow 服务已停止"
echo ""
read -p "按 Enter 键退出..."
