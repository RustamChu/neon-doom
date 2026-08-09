# ============================================================
#  NEON DOOM - one-click publish to GitHub
#  Публикация репозитория на github.com/RustamChu одним кликом:
#  ПКМ по файлу -> "Выполнить с помощью PowerShell"
# ============================================================
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$GitHubUser = "RustamChu"
$RepoName   = "neon-doom"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "    $msg" -ForegroundColor Red }

# --- 1. git installed? ----------------------------------------------------
Write-Step "Проверяю git..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err "git не найден. Пробую установить через winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
        Write-Ok "git установлен. ЗАКРОЙТЕ это окно и запустите скрипт ещё раз."
    } else {
        Write-Err "Установите git вручную: https://git-scm.com/download/win"
        Start-Process "https://git-scm.com/download/win"
    }
    Read-Host "Нажмите Enter, чтобы закрыть"
    exit 1
}
Write-Ok "git найден"

# --- 2. git identity ------------------------------------------------------
if (-not (git config user.name))  { git config --global user.name  $GitHubUser }
if (-not (git config user.email)) { git config --global user.email "$GitHubUser@users.noreply.github.com" }

# --- 2.5 restore GitHub Actions workflow (shipped as docs/ci.yml) ---------
if ((Test-Path "docs/ci.yml") -and -not (Test-Path ".github/workflows/ci.yml")) {
    New-Item -ItemType Directory -Force -Path ".github/workflows" | Out-Null
    Move-Item "docs/ci.yml" ".github/workflows/ci.yml" -ErrorAction SilentlyContinue
    if (Test-Path "docs/ci.yml") { Copy-Item "docs/ci.yml" ".github/workflows/ci.yml" }
    Write-Ok "Workflow GitHub Actions установлен (.github/workflows/ci.yml)"
}

# --- 3. init + commit -----------------------------------------------------
if (-not (Test-Path ".git")) {
    Write-Step "Создаю git-репозиторий..."
    git init -b main | Out-Null
}
git add -A
$pending = git status --porcelain
if ($pending) {
    git commit -m "NEON DOOM: colorful retro raycasting shooter" | Out-Null
    Write-Ok "Коммит создан"
} else {
    Write-Ok "Изменений нет - использую существующий коммит"
}

# --- 4. publish -----------------------------------------------------------
$remoteUrl = "https://github.com/$GitHubUser/$RepoName.git"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    # GitHub CLI - fully automatic path
    gh auth status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Нужно войти в GitHub (откроется браузер)..."
        gh auth login --hostname github.com --web
    }
    $exists = gh repo view "$GitHubUser/$RepoName" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Создаю репозиторий $GitHubUser/$RepoName и загружаю код..."
        gh repo create "$GitHubUser/$RepoName" --public --source . --push `
            --description "Colorful retro raycasting shooter in pure Python + pygame"
    } else {
        Write-Step "Репозиторий уже существует - загружаю обновления..."
        if (-not (git remote | Select-String -Quiet "^origin$")) { git remote add origin $remoteUrl }
        git push -u origin main
    }
} else {
    # plain git path
    Write-Step "GitHub CLI (gh) не найден - публикую через обычный git."
    Write-Host ""
    Write-Host "  1) Если репозиторий ещё НЕ создан - сейчас откроется страница создания." -ForegroundColor Yellow
    Write-Host "     Назовите его: $RepoName , тип Public, БЕЗ README - и нажмите Create." -ForegroundColor Yellow
    Write-Host "  2) Затем вернитесь сюда и нажмите Enter." -ForegroundColor Yellow
    Write-Host ""
    Start-Process "https://github.com/new?name=$RepoName&visibility=public"
    Read-Host "Нажмите Enter, когда репозиторий создан"
    if (-not (git remote | Select-String -Quiet "^origin$")) { git remote add origin $remoteUrl }
    Write-Step "Загружаю код (Windows может спросить логин GitHub)..."
    git push -u origin main
}

Write-Host ""
Write-Ok "ГОТОВО! Ваша игра: https://github.com/$GitHubUser/$RepoName"
Start-Process "https://github.com/$GitHubUser/$RepoName"
Read-Host "Нажмите Enter, чтобы закрыть"
