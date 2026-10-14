<#
    Публикация калькулятора "Сколько скинуться коллеге на ДР" на GitHub Pages.

    Использование (из папки сайта):
        .\publish.ps1                      # репозиторий с именем папки
        .\publish.ps1 -Repo dr-gift
        .\publish.ps1 -Repo podarki -Private

    Требуется GitHub CLI (gh), авторизованный через `gh auth login`.
#>

[CmdletBinding()]
param(
    [string]$Repo,
    [switch]$Private,
    [string]$Branch = 'main'
)

# Внешние команды (git, gh) пишут предупреждения в stderr. В Windows PowerShell 5.1
# при ErrorActionPreference='Stop' это превращается в фатальную ошибку, поэтому
# работаем в режиме Continue и сами проверяем коды возврата.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# В Windows PowerShell 5.1 $PSScriptRoot в значении по умолчанию для параметра пуст.
$Here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $Here

if (-not $Repo) { $Repo = Split-Path -Leaf $Here }

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "x $Message" -ForegroundColor Red
    exit 1
}

function Ok([string]$Message) { Write-Host "v $Message" -ForegroundColor Green }
function Info([string]$Message) { Write-Host "- $Message" -ForegroundColor DarkGray }
function Warn([string]$Message) { Write-Host "! $Message" -ForegroundColor Yellow }

# Выполняет команду, ничего не печатая, и возвращает $true при коде 0.
function Test-External([scriptblock]$Command) {
    $null = & $Command *> $null
    return ($LASTEXITCODE -eq 0)
}

# Выполняет команду и падает с понятным текстом, если код возврата не 0.
function Invoke-Checked([string]$Label, [scriptblock]$Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { Fail "$Label (код возврата $LASTEXITCODE)" }
}

# ---------- 1. проверки окружения ----------

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "Не найден GitHub CLI. Установи: winget install GitHub.cli"
}

if (-not (Test-External { gh auth status })) {
    Fail "GitHub CLI не авторизован. Выполни: gh auth login"
}

foreach ($file in 'index.html', 'styles.css', 'app.js') {
    if (-not (Test-Path $file)) { Fail "Нет файла $file. Запускай скрипт из папки сайта." }
}

$owner = (& gh api user --jq .login | Select-Object -First 1)
if (-not $owner) { Fail "Не удалось определить логин GitHub." }
$owner = $owner.Trim()
Info "Аккаунт: $owner | репозиторий: $Repo | ветка: $Branch"

# ---------- 2. git ----------

if (-not (Test-Path '.git')) {
    Invoke-Checked 'Не удалось создать git-репозиторий' { git init --quiet }
    Invoke-Checked 'Не удалось переименовать ветку' { git branch -M $Branch }
    Ok "Создан git-репозиторий"
} else {
    Invoke-Checked 'Не удалось переключиться на ветку' { git checkout -q -B $Branch }
}

# Git не даст сделать коммит без имени и почты. Если глобально они не заданы,
# подставляем данные GitHub-аккаунта — только для этого репозитория.
if (-not (git config user.name)) { git config user.name "$owner" }
if (-not (git config user.email)) { git config user.email "$owner@users.noreply.github.com" }

if (Test-External { git rev-parse --verify HEAD }) {
    Invoke-Checked 'Не удалось проиндексировать файлы' { git add --all }
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        Invoke-Checked 'Не удалось закоммитить изменения' { git commit --quiet -m "Обновление сайта" }
        Ok "Изменения закоммичены"
    } else {
        Info "Изменений для коммита нет"
    }
} else {
    Invoke-Checked 'Не удалось проиндексировать файлы' { git add --all }
    Invoke-Checked 'Не удалось создать первый коммит' { git commit --quiet -m "Калькулятор подарка коллеге на ДР" }
    Ok "Первый коммит создан"
}

# ---------- 3. репозиторий на GitHub ----------

$visibility = if ($Private) { '--private' } else { '--public' }

if (Test-External { gh repo view "$owner/$Repo" }) {
    if (-not ((git remote) -contains 'origin')) {
        Invoke-Checked 'Не удалось добавить remote origin' {
            git remote add origin "https://github.com/$owner/$Repo.git"
        }
    }
    Invoke-Checked 'Не удалось запушить код' { git push -u origin $Branch }
    Ok "Код запушен в $owner/$Repo"
} else {
    Info "Репозитория $owner/$Repo ещё нет — создаю"
    Invoke-Checked 'Не удалось создать репозиторий на GitHub' {
        gh repo create $Repo $visibility --source . --remote origin --push
    }
    Ok "Репозиторий $owner/$Repo создан, код запушен"
}

# ---------- 4. GitHub Pages ----------

if (Test-External { gh api "repos/$owner/$Repo/pages" }) {
    Info "GitHub Pages уже включён"
} elseif (Test-External {
    gh api --method POST "repos/$owner/$Repo/pages" -f "source[branch]=$Branch" -f 'source[path]=/'
}) {
    Ok "GitHub Pages включён"
} else {
    Warn "Не удалось включить Pages автоматически."
    Warn "Сделай вручную: Settings -> Pages -> Source: Deploy from a branch -> $Branch / (root) -> Save"
}

$url = if ($Repo -eq "$owner.github.io") { "https://$owner.github.io/" } else { "https://$owner.github.io/$Repo/" }

Write-Host ""
Write-Host "Сайт будет доступен через 30-60 секунд:" -ForegroundColor Cyan
Write-Host "  $url" -ForegroundColor Cyan
Start-Process $url
