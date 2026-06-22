#!/usr/bin/env bash
#==============================================================================
# CodeGraph 数据库更新脚本
# 用法: bash CodeGraph/update_graph.sh
#==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEGRAPH_HOME="$HOME/AppData/Local/codegraph/current/codegraph-win32-x64"
NODE_EXE="$CODEGRAPH_HOME/node.exe"
CODEGRAPH_JS="$CODEGRAPH_HOME/lib/dist/bin/codegraph.js"

# 检查安装
if [ ! -f "$NODE_EXE" ] || [ ! -f "$CODEGRAPH_JS" ]; then
    echo "[错误] CodeGraph 未安装，请先运行:"
    echo '  powershell -Command "irm https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1 | iex"'
    exit 1
fi

echo "============================================"
echo "  CodeGraph 数据库更新"
echo "  项目: $PROJECT_ROOT"
echo "============================================"
echo ""

# 增量同步
echo "[1/2] 增量同步索引..."
cd "$PROJECT_ROOT"
"$NODE_EXE" --liftoff-only "$CODEGRAPH_JS" sync

echo ""

# 显示状态
echo "[2/2] 当前索引状态..."
"$NODE_EXE" --liftoff-only "$CODEGRAPH_JS" status

echo ""
echo "更新完成!"
