#!/usr/bin/env bash
#===============================================================================
# LangFlow 启动脚本
# 用途: 检查依赖、安装缺失依赖、构建前端并启动 LangFlow 网页服务
# 用法: bash start_langflow.sh
#===============================================================================

# ======================== 颜色定义 ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

FRONTEND_DIR="$PROJECT_DIR/src/frontend"
BACKEND_FRONTEND_DIR="$PROJECT_DIR/src/backend/base/langflow/frontend"
VENV_DIR="$PROJECT_DIR/.venv"
ENV_FILE="$PROJECT_DIR/.env"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}       LangFlow 网页服务启动脚本${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ======================== 1. 检查前置工具 ========================
echo -e "${YELLOW}[1/6] 检查前置工具...${NC}"

# ---------- Node.js (优先，因为后面 PATH 设置会影响) ----------
# Git Bash 中 Node.js 通常不在 PATH，手动添加
for node_dir in "/c/Program Files/nodejs" "/c/Program Files (x86)/nodejs"; do
    if [ -f "$node_dir/node.exe" ]; then
        export PATH="$node_dir:$PATH"
        break
    fi
done

# 从 HOME 路径提取用户名 (Git Bash: /c/Users/xxx)
PYTHON_USER="${HOME##*/Users/}"
PYTHON_USER="${PYTHON_USER%%/*}"
[ -z "$PYTHON_USER" ] && PYTHON_USER="$USERNAME"

# ---------- Python (先找真实路径，避免 Windows Store 假 python) ----------
PYTHON=""
for ver in 313 312 311 310; do
    py_path="/c/Users/${PYTHON_USER}/AppData/Local/Programs/Python/Python${ver}/python.exe"
    if [ -f "$py_path" ]; then
        PYTHON="$py_path"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    for ver in 313 312 311; do
        py_path="/c/Python${ver}/python.exe"
        if [ -f "$py_path" ]; then
            PYTHON="$py_path"
            break
        fi
    done
fi
# 最后回退到 PATH 中的 python3/python（排除 Windows Store 空壳）
if [ -z "$PYTHON" ]; then
    for cmd in python3 python; do
        p="$(command -v "$cmd" 2>/dev/null)"
        if [ -n "$p" ] && "$p" --version 2>/dev/null | grep -q "Python"; then
            PYTHON="$p"
            break
        fi
    done
fi

if [ -z "$PYTHON" ]; then
    echo -e "${RED}错误: 未找到 Python，请安装 Python 3.10-3.14${NC}"
    echo -e "${YELLOW}可手动设置 PATH: export PATH=\"/c/Users/${PYTHON_USER}/AppData/Local/Programs/Python/Python313:\$PATH\"${NC}"
    read -p "按 Enter 键退出..."
    exit 1
fi
echo -e "  Python: $("$PYTHON" --version 2>&1)"

# ---------- uv ----------
if ! command -v uv >/dev/null 2>&1; then
    echo -e "${YELLOW}  uv 未安装，正在安装...${NC}"
    "$PYTHON" -m pip install uv --quiet
    if [ $? -ne 0 ]; then
        echo -e "${RED}  uv 安装失败${NC}"
        read -p "按 Enter 键退出..."
        exit 1
    fi
fi
echo -e "  uv: $(uv --version)"

# ---------- Node.js ----------
if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}错误: 未找到 Node.js >=20.19.0${NC}"
    echo -e "${YELLOW}请安装 Node.js 并确保在 PATH 中，或在 Git Bash 中执行:${NC}"
    echo -e "${YELLOW}  export PATH=\"/c/Program Files/nodejs:\$PATH\"${NC}"
    read -p "按 Enter 键退出..."
    exit 1
fi
echo -e "  Node.js: $(node -v)"

# ---------- npm ----------
if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}错误: 未找到 npm${NC}"
    read -p "按 Enter 键退出..."
    exit 1
fi
echo -e "  npm: $(npm -v)"
echo -e "${GREEN}  前置工具检查完成！${NC}"
echo ""

# ======================== 2. Python 依赖 ========================
echo -e "${YELLOW}[2/6] Python 依赖...${NC}"
if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/pyvenv.cfg" ]; then
    echo -e "  虚拟环境已存在，跳过安装。"
else
    echo -e "  正在安装..."
    uv sync --extra "postgresql"
    if [ $? -ne 0 ]; then
        echo -e "${RED}  Python 依赖安装失败${NC}"
        read -p "按 Enter 键退出..."
        exit 1
    fi
fi
echo -e "${GREEN}  Python 依赖就绪！${NC}"
echo ""

# ======================== 3. 前端依赖 ========================
echo -e "${YELLOW}[3/6] 前端依赖...${NC}"
cd "$FRONTEND_DIR"

NEED_NPM_INSTALL=false
if [ ! -d "node_modules" ]; then
    NEED_NPM_INSTALL=true
elif [ ! -d "node_modules/vite" ] || [ ! -f "node_modules/vite/package.json" ]; then
    echo -e "  node_modules 不完整，重新安装..."
    rm -rf node_modules
    NEED_NPM_INSTALL=true
fi

if [ "$NEED_NPM_INSTALL" = true ]; then
    echo -e "  正在安装..."
    npm install
    if [ $? -ne 0 ]; then
        npm install --legacy-peer-deps
    fi
else
    echo -e "  已存在，跳过。"
fi
echo -e "${GREEN}  前端依赖就绪！${NC}"
echo ""

# ======================== 4. 构建前端 ========================
echo -e "${YELLOW}[4/6] 构建前端...${NC}"

if [ -d "build" ] && [ -f "build/index.html" ]; then
    echo -e "  构建产物已存在，跳过。"
    build_success=true
else
    build_success=false
    if [ -f "node_modules/.bin/vite" ]; then
        ./node_modules/.bin/vite build && build_success=true
    elif [ -f "node_modules/.bin/vite.cmd" ]; then
        ./node_modules/.bin/vite.cmd build && build_success=true
    fi

    if [ "$build_success" = false ]; then
        if command -v npx >/dev/null 2>&1; then
            npx vite build && build_success=true
        else
            npm run build && build_success=true
        fi
    fi
fi

if [ "$build_success" = true ]; then
    echo -e "${GREEN}  前端构建完成！${NC}"
else
    echo -e "${YELLOW}  警告: 前端构建失败，服务将以无前端模式运行${NC}"
fi
echo ""

# ======================== 5. 复制构建产物 ========================
echo -e "${YELLOW}[5/6] 复制前端构建产物...${NC}"
cd "$PROJECT_DIR"
if [ -d "$FRONTEND_DIR/build" ]; then
    mkdir -p "$BACKEND_FRONTEND_DIR"
    rm -rf "$BACKEND_FRONTEND_DIR"/*
    cp -r "$FRONTEND_DIR/build/." "$BACKEND_FRONTEND_DIR/"
    echo -e "${GREEN}  已复制到 $BACKEND_FRONTEND_DIR${NC}"
else
    echo -e "${YELLOW}  构建目录不存在，使用默认前端${NC}"
fi
echo ""

# ======================== 6. 启动服务 ========================
echo -e "${YELLOW}[6/6] 启动 LangFlow 网页服务...${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}  LangFlow 启动中...${NC}"
echo -e "  地址: http://localhost:7860"
echo -e "  按 Ctrl+C 停止"
echo -e "${BLUE}================================================${NC}"
echo ""

cd "$PROJECT_DIR"
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
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}  LangFlow 服务已停止${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
read -p "按 Enter 键退出..."
