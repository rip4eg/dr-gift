<#
    Публикация калькулятора на GitHub Pages.

    Использование:
        .\publish.ps1                      # репозиторий с именем папки
        .\publish.ps1 -Repo dr-gift
        .\publish.ps1 -Repo dr-gift -Private

    Требуется GitHub CLI (gh), авторизованный через `gh auth login`.
#>

[CmdletBinding()]
param(
    [string]$Repo = (Split-Path -Leaf $PSScriptRoot),
    [switch]$Private,
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Fail($message) { Write-Host "✖ $message" -ForegroundColor Red; exit 1 }

# --- 1. проверки окружения ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "Не найден GitHub CLI. Установи: winget install GitHub.cli"
}

gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Сначала авторизуйся: gh auth login" }

foreach ($file in 'index.html', 'styles.css', 'app.js') {
    if (-not (Test-Path $file)) { Fail "Нет файла $file — запускай скрипт из папки сайта." }
}

$owner = (gh api user --jq .login)

# --- 2. git-репозиторий ---
if (-not (Test-Path '.git')) {
    git init | Out-Null
    git branch -M $Branch
    git add .
    git commit -m "Калькулятор подарка коллеге на ДР" | Out-Null
    Write-Host "✔ Создан git-репозиторий" -ForegroundColor Green
} else {
    git add .
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "Обновление сайта" | Out-Null
        Write-Host "✔ Изменения закоммичены" -ForegroundColor Green
    } else {
        Write-Host "• Изменений для коммита нет" -ForegroundColor DarkGray
    }
} 

# --- 3. репозиторий на GitHub ---
$visibility = if ($Private) { '--private' } else { '--public' }
gh repo view "$owner/$Repo" 2>$null | Out-Null

if ($LASTEXITCODE -ne 0) {
    gh repo create $Repo $visibility --source . --remote origin --push | Out-Null
    Write-Host "✔ Создан репозиторий $owner/$Repo и запушен код" -ForegroundColor Green
} else {
    if (-not (git remote | Select-String -Quiet '^origin$')) {
        git remote add origin "https://github.com/$owner/$Repo.git"
    }
    git push -u origin $Branch
    Write-Host "✔ Код запушен в $owner/$Repo" -ForegroundColor Green
}

# --- 4. GitHub Pages ---
$pagesEnabled = $true
try {
    gh api "repos/$owner/$Repo/pages" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $pagesEnabled = $false }
} catch { $pagesEnabled = $false }

if (-not $pagesEnabled) {
    gh api --method POST "repos/$owner/$Repo/pages" `
        -f "source[branch]=$Branch" -f 'source[path]=/' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠ Не удалось включить Pages автоматически. Включи вручную: Settings → Pages → Deploy from a branch → $Branch / (root)" -ForegroundColor Yellow
    } else {
        Write-Host "✔ GitHub Pages включён" -ForegroundColor Green
    }
} else {
    Write-Host "• GitHub Pages уже включён" -ForegroundColor DarkGray
}

$url = if ($Repo -eq "$owner.github.io") { "https://$owner.github.io/" } else { "https://$owner.github.io/$Repo/" }
Write-Host ""
Write-Host "Сайт будет доступен через 30–60 секунд:" -ForegroundColor Cyan
Write-Host "  $url" -ForegroundColor Cyan
Start-Process $url
