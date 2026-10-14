<#
    Вход в GitHub CLI по токену (Personal Access Token).

    Нужен, когда код подтверждения не приходит на почту при обычном `gh auth login`.

    Порядок действий:
      1. Создай токен: https://github.com/settings/tokens/new?scopes=repo&description=dr-gift
         Тип: classic. Галочка обязательно у "repo". Срок годности — на твой вкус.
      2. Запусти этот файл (правый клик -> "Выполнить с помощью PowerShell").
      3. Вставь токен в чёрное окно и нажми Enter. Ввод не отображается — это нормально.

    Токен не сохраняется на диск: он живёт только в памяти до передачи в gh,
    а сам gh хранит его в защищённом хранилище Windows (Credential Manager).
#>

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($true)

Write-Host ""
Write-Host "=== Вход в GitHub по токену ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "x Не найден GitHub CLI (gh). Установи: winget install GitHub.cli" -ForegroundColor Red
    Read-Host "Нажми Enter, чтобы закрыть"
    exit 1
}

Write-Host "Создать токен: https://github.com/settings/tokens/new?scopes=repo&description=dr-gift"
Write-Host "Нужен тип 'classic' и галочка 'repo'." -ForegroundColor DarkGray
Write-Host ""
Write-Host "Вставь токен и нажми Enter (ввод скрыт):" -ForegroundColor Yellow

$secure = Read-Host -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

$token = "$token".Trim()
if (-not $token) {
    Write-Host ""
    Write-Host "x Токен пустой, вход отменён." -ForegroundColor Red
    Read-Host "Нажми Enter, чтобы закрыть"
    exit 1
}

$token | gh auth login --with-token
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "x gh не принял токен. Проверь, что он типа classic и с галочкой 'repo', и не истёк." -ForegroundColor Red
    Read-Host "Нажми Enter, чтобы закрыть"
    exit 1
}

$token = $null
$secure = $null
[GC]::Collect()

& gh auth setup-git | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "! Не удалось настроить git на использование gh (обычно не критично)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "v Вход выполнен" -ForegroundColor Green
& gh auth status
Write-Host ""
Write-Host "Теперь можно публиковать сайт: .\publish.ps1 -Repo dr-gift" -ForegroundColor Cyan
Read-Host "Нажми Enter, чтобы закрыть"
