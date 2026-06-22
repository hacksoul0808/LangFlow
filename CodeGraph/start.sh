#!/usr/bin/env bash
#==============================================================================
# CodeGraph MCP 服务启动脚本
# 用途: 启动 CodeGraph 作为 MCP 服务器，供 AI Agent (Trae/Claude/Cursor 等) 连接
# 用法: bash start_codegraph.sh [选项]
#==============================================================================

set -e

# --- 路径配置 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEGRAPH_HOME="$HOME/AppData/Local/codegraph/current/codegraph-win32-x64"
NODE_EXE="$CODEGRAPH_HOME/node.exe"
CODEGRAPH_JS="$CODEGRAPH_HOME/lib/dist/bin/codegraph.js"

# --- 颜色输出 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_title() { echo -e "${CYAN}$*${NC}"; }

# --- 检查 CodeGraph 是否已安装 ---
check_installed() {
    if [ ! -f "$NODE_EXE" ]; then
        log_error "未找到 CodeGraph 运行时: $NODE_EXE"
        log_info "请先运行以下命令安装:"
        echo "  powershell -Command \"irm https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1 | iex\""
        exit 1
    fi

    if [ ! -f "$CODEGRAPH_JS" ]; then
        log_error "未找到 CodeGraph 入口文件: $CODEGRAPH_JS"
        exit 1
    fi

    log_info "CodeGraph 已安装"
}

# --- 运行 codegraph 命令 ---
run_codegraph() {
    "$NODE_EXE" --liftoff-only "$CODEGRAPH_JS" "$@"
}

# --- 查看状态 ---
show_status() {
    log_title "============================================"
    log_title "  CodeGraph 项目状态"
    log_title "============================================"
    run_codegraph status || true
}

# --- 同步索引 (增量更新) ---
do_sync() {
    log_info "正在增量同步索引..."
    run_codegraph sync
    log_info "同步完成"
}

# --- 全量重建索引 ---
do_reindex() {
    log_info "正在全量重建索引..."
    run_codegraph index
    log_info "索引完成"
}

# --- 启动 MCP 服务器 (stdio 模式) ---
start_mcp() {
    log_title "============================================"
    log_title "  CodeGraph MCP 服务器启动中..."
    log_title "  项目路径: $PROJECT_ROOT"
    log_title "  模式: stdio (MCP 协议)"
    log_title "============================================"
    echo ""

    # 先同步最新改动
    log_info "同步最新改动..."
    run_codegraph sync 2>/dev/null || true

    # 启动 MCP 服务器
    cd "$PROJECT_ROOT"
    exec run_codegraph serve --mcp
}

# --- 启动守护进程 (多客户端共享模式) ---
start_daemon() {
    log_title "============================================"
    log_title "  CodeGraph 守护进程启动中..."
    log_title "  项目路径: $PROJECT_ROOT"
    log_title "  模式: daemon (多客户端共享)"
    log_title "============================================"
    echo ""

    log_info "同步最新改动..."
    run_codegraph sync 2>/dev/null || true

    # 守护进程由 MCP 客户端自动管理
    # 这里先确保索引是最新的
    log_info "守护进程将由 MCP 客户端自动管理"
    log_info "请在你的 MCP 客户端配置中添加 CodeGraph 服务器"
    echo ""
    log_info "MCP 客户端配置示例 (json):"
    echo ""
    echo '{'
    echo '  "mcpServers": {'
    echo '    "codegraph": {'
    echo "      \"command\": \"$(cygpath -w "$NODE_EXE" 2>/dev/null || echo "$NODE_EXE")\","
    echo '      "args": ['
    echo '        "--liftoff-only",'
    echo "        \"$(cygpath -w "$CODEGRAPH_JS" 2>/dev/null || echo "$CODEGRAPH_JS")\","
    echo '        "serve",'
    echo '        "--mcp"'
    echo '      ],'
    echo "      \"cwd\": \"$(cygpath -w "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")\""
    echo '    }'
    echo '  }'
    echo '}'
}

# --- 管理守护进程 ---
manage_daemons() {
    log_info "管理运行中的 CodeGraph 守护进程..."
    run_codegraph daemon
}

# --- 显示帮助 ---
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  start       启动 MCP 服务器 (stdio 模式，默认)"
    echo "  daemon      显示守护进程配置信息"
    echo "  status      查看索引状态"
    echo "  sync        增量同步索引"
    echo "  reindex     全量重建索引"
    echo "  manage      管理运行中的守护进程"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  bash $0              # 启动 MCP 服务器"
    echo "  bash $0 start        # 同上"
    echo "  bash $0 daemon       # 查看守护进程配置"
    echo "  bash $0 status       # 查看索引状态"
    echo "  bash $0 sync         # 增量同步"
}

# --- 主入口 ---
main() {
    check_installed

    local cmd="${1:-start}"

    case "$cmd" in
        start)
            show_status
            start_mcp
            ;;
        daemon)
            show_status
            start_daemon
            ;;
        status)
            show_status
            ;;
        sync)
            do_sync
            show_status
            ;;
        reindex)
            do_reindex
            show_status
            ;;
        manage)
            manage_daemons
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知选项: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
