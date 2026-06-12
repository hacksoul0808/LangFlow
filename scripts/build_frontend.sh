#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# LangFlow 前端构建脚本
# 用法: bash scripts/build_frontend.sh
# ============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

FRONTEND_DIR="src/frontend"
BACKEND_FRONTEND_DIR="src/backend/base/langflow/frontend"

# 1. 清理旧构建产物
echo -e "${GREEN}[1/3] 清理旧构建产物...${NC}"
rm -rf "$FRONTEND_DIR/build" 2>/dev/null || true
rm -rf "$BACKEND_FRONTEND_DIR" 2>/dev/null || true
echo "  清理完成"

# 2. 安装依赖 + 构建
echo -e "${GREEN}[2/3] 构建前端...${NC}"
cd "$FRONTEND_DIR"
CI='' npm run build
cd - > /dev/null
echo "  构建完成"

# 3. 复制构建产物到后端
echo -e "${GREEN}[3/3] 复制构建产物到后端...${NC}"
mkdir -p "$BACKEND_FRONTEND_DIR"
cp -r "$FRONTEND_DIR/build/." "$BACKEND_FRONTEND_DIR"
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}  前端构建完成！${NC}"
echo -e "${GREEN}  产物已复制到 $BACKEND_FRONTEND_DIR${NC}"
echo -e "${GREEN}===========================================${NC}"
