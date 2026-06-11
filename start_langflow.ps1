#===============================================================================
# LangFlow 启动脚本 (PowerShell)
# 用途: 检查依赖、安装缺失依赖、构建前端并启动 LangFlow 网页服务
# 用法: .\start_langflow.ps1
# 如果遇到执行策略错误，请运行:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# 或直接使用:
#   powershell -ExecutionPolicy Bypass -File start_langflow.ps1
#===============================================================================

$ErrorActionPreference = "Stop"

try {
    $ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $ProjectDir

$FrontendDir = "$ProjectDir\src\frontend"
$BackendFrontendDir = "$ProjectDir\src\backend\base\langflow\frontend"
$VenvDir = "$ProjectDir\.venv"
$EnvFile = "$ProjectDir\.env"
$PythonDir = "C:\Users\topjoy\AppData\Local\Programs\Python\Python313"
$NodejsDir = "C:\Program Files\nodejs"

Write-Host "================================================" -ForegroundColor Blue
Write-Host "       LangFlow 网页服务启动脚本" -ForegroundColor Blue
Write-Host "================================================" -ForegroundColor Blue
Write-Host ""

# ======================== 设置 PATH ========================
Write-Host "[0/6] 配置环境变量..." -ForegroundColor Yellow
$env:Path = "$PythonDir;$PythonDir\Scripts;$NodejsDir;" + $env:Path
Write-Host "  PATH 已配置" -ForegroundColor Green
Write-Host ""

# ======================== 1. 检查前置工具 ========================
Write-Host "[1/6] 检查前置工具..." -ForegroundColor Yellow

# 检查 Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    throw "未找到 Python"
}
Write-Host "  Python: $(python --version)"

# 检查 uv
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uvCmd) {
    Write-Host "  uv 未安装，正在安装..." -ForegroundColor Yellow
    pip install uv
    if ($LASTEXITCODE -ne 0) {
        throw "uv 安装失败"
    }
}
Write-Host "  uv: $(uv --version)"

# 检查 Node.js
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    throw "未找到 Node.js，请安装 Node.js >=20.19.0 (推荐 v22.13+)"
}
Write-Host "  Node.js: $(node -v)"

# 检查 npm (使用 .cmd 避免 PowerShell 执行策略问题)
$npmCmd = Join-Path $NodejsDir "npm.cmd"
$npxCmd = Join-Path $NodejsDir "npx.cmd"
if (-not (Test-Path $npmCmd)) {
    throw "未找到 npm"
}
Write-Host "  npm: $(& $npmCmd --version)"
Write-Host "  前置工具检查完成！" -ForegroundColor Green
Write-Host ""

# ======================== 2. 安装 Python 依赖 ========================
Write-Host "[2/6] 安装 Python 依赖..." -ForegroundColor Yellow
uv sync --frozen --extra "postgresql"
if ($LASTEXITCODE -ne 0) {
    throw "Python 依赖安装失败"
}
Write-Host "  Python 依赖安装完成！" -ForegroundColor Green
Write-Host ""

# ======================== 3. 安装前端依赖 ========================
Write-Host "[3/6] 安装前端依赖..." -ForegroundColor Yellow
Set-Location $FrontendDir

$needInstall = $false
if (-not (Test-Path "node_modules")) {
    $needInstall = $true
} elseif (-not (Test-Path "node_modules\vite\package.json")) {
    Write-Host "  前端依赖不完整，需要重新安装..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "node_modules" -ErrorAction SilentlyContinue
    $needInstall = $true
}

if ($needInstall) {
    Write-Host "  正在安装前端 npm 依赖..."
    & $npmCmd install --ignore-engines
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  前端依赖安装可能不完整，尝试继续..." -ForegroundColor Yellow
    }
} else {
    Write-Host "  前端依赖已存在，跳过安装。"
}
Write-Host "  前端依赖安装完成！" -ForegroundColor Green
Write-Host ""

# ======================== 4. 构建前端 ========================
Write-Host "[4/6] 构建前端..." -ForegroundColor Yellow
$viteInstalled = Test-Path "node_modules\vite\package.json"
if ($viteInstalled) {
    & $npmCmd run build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  npm run build 失败，尝试使用 npx..." -ForegroundColor Yellow
        & $npxCmd vite build
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  警告: 前端构建失败" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  警告: vite 未安装，跳过前端构建" -ForegroundColor Yellow
    Write-Host "  请确保运行 'npm install' 安装前端依赖" -ForegroundColor Yellow
}
if (Test-Path "$FrontendDir\build") {
    Write-Host "  前端构建完成！" -ForegroundColor Green
}
Write-Host ""

# ======================== 5. 复制前端构建产物 ========================
Write-Host "[5/6] 复制前端构建产物..." -ForegroundColor Yellow
Set-Location $ProjectDir

if (Test-Path "$FrontendDir\build") {
    New-Item -ItemType Directory -Force -Path $BackendFrontendDir | Out-Null
    Remove-Item -Recurse -Force "$BackendFrontendDir\*" -ErrorAction SilentlyContinue
    Copy-Item -Recurse "$FrontendDir\build\*" "$BackendFrontendDir\"
    Write-Host "  前端构建产物已复制到 $BackendFrontendDir" -ForegroundColor Green
} else {
    Write-Host "  前端构建目录不存在，将使用后端默认前端（如有）" -ForegroundColor Yellow
}
Write-Host ""

# ======================== 6. 启动 LangFlow 服务 ========================
Write-Host "[6/6] 启动 LangFlow 网页服务..." -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Blue
Write-Host "  LangFlow 启动中..." -ForegroundColor Green
Write-Host "  后端地址: http://localhost:7860" -ForegroundColor Green
Write-Host "  按 Ctrl+C 停止服务" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Blue
Write-Host ""

Set-Location $ProjectDir
$frontendPath = if (Test-Path "$BackendFrontendDir\index.html") { $BackendFrontendDir } else { "" }

$args = @("run", "langflow", "run", "--host", "0.0.0.0", "--port", "7860", "--log-level", "info", "--env-file", $EnvFile)
if ($frontendPath) {
    $args += "--frontend-path"
    $args += $frontendPath
}

& uv $args
} catch {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "  脚本执行出错！" -ForegroundColor Red
    Write-Host "  错误信息: $_" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
} finally {
    Write-Host ""
    Write-Host "按任意键退出..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}
