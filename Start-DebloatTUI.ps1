# CleanWinTUI - ponto de entrada
# Debloat controlado para Windows 11 com TUI, transação e plano de restauração.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

. (Join-Path $Root 'lib\Tui.ps1')
. (Join-Path $Root 'lib\Widgets.ps1')
. (Join-Path $Root 'modules\Core.ps1')
. (Join-Path $Root 'modules\State.ps1')
. (Join-Path $Root 'modules\Transaction.ps1')
. (Join-Path $Root 'modules\Actions.ps1')
. (Join-Path $Root 'modules\Engine.ps1')
. (Join-Path $Root 'modules\Screens.ps1')
. (Join-Path $Root 'modules\RestoreGen.ps1')

function Confirm-Administrator {
    if (Test-IsAdmin) { return $true }
    Write-Host ''
    Write-Host '  CleanWinTUI precisa de privilegios de administrador.' -ForegroundColor Yellow
    Write-Host '  Tentando elevar...' -ForegroundColor DarkGray
    try {
        $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $args -ErrorAction Stop
    } catch {
        Write-Host ''
        Write-Host '  Nao foi possivel elevar automaticamente.' -ForegroundColor Red
        Write-Host '  Abra o Windows Terminal como Administrador e execute novamente.' -ForegroundColor DarkGray
        Write-Host ''
        Read-Host '  Pressione Enter para sair'
    }
    return $false
}

function Filter-WhitelistedItems {
    $safe = New-Object System.Collections.Generic.List[object]
    foreach ($item in $script:App.Items) {
        if (Test-WhitelistedItem $item) {
            Write-Log "Item bloqueado pela whitelist: $($item.id)" 'WARN'
        } else {
            $safe.Add($item)
        }
    }
    $script:App.Items = $safe.ToArray()
}

function Invoke-AppFlow {
    $stage = 'welcome'

    while ($true) {
        switch ($stage) {
            'welcome' {
                $r = Show-WelcomeScreen
                if ($r -eq 'quit') { return $null }
                $stage = 'intro'
            }
            'intro' {
                $r = Show-GroupsIntro
                if ($r -eq 'back') { $stage = 'welcome' } else { $stage = 'select' }
            }
            'select' {
                $r = Show-SelectionScreen
                if ($r -eq 'quit') { return $null }
                $stage = 'review'
            }
            'review' {
                $r = Show-ReviewScreen
                if ($r -eq 'quit') { return $null }
                if ($r -eq 'back') { $stage = 'select' } else { $stage = 'dry' }
            }
            'dry' {
                $r = Show-DryRunScreen
                if ($r -eq 'quit') { return $null }
                if ($r -eq 'back') { $stage = 'review' } else { $stage = 'confirm' }
            }
            'confirm' {
                $r = Show-ConfirmScreen
                if ($r -eq 'quit') { return $null }
                if ($r -eq 'back') { $stage = 'dry' } else { $stage = 'preflight' }
            }
            'preflight' {
                $r = Show-PreflightScreen
                if ($r -eq 'back') { $stage = 'review' } else { $stage = 'execute' }
            }
            'execute' {
                $selected = @(Get-SelectedItems)
                $summary = Invoke-DebloatExecution
                $script:App.Outcomes = $summary
                $planPath = New-RestorePlan -Items $selected -Summary $summary
                $summary | Add-Member -NotePropertyName RestorePlan -NotePropertyValue $planPath -Force
                Show-ReportScreen -Summary $summary
                return $summary
            }
        }
    }
}

function Write-PlainSummary {
    param([hashtable]$Summary)
    Write-Host ''
    if (-not $Summary) {
        Write-Host '  CleanWinTUI encerrado sem alteracoes.' -ForegroundColor DarkGray
        return
    }
    Write-Host '  CleanWinTUI finalizado' -ForegroundColor Magenta
    Write-Host ("  Acoes aplicadas : {0}" -f $Summary.Ok) -ForegroundColor Green
    Write-Host ("  Falhas          : {0}" -f $Summary.Fail) -ForegroundColor $(if ($Summary.Fail -gt 0) { 'Red' } else { 'DarkGray' })
    Write-Host ("  Ignoradas       : {0}" -f $Summary.Skipped) -ForegroundColor DarkYellow
    Write-Host ("  Duracao         : {0}" -f $Summary.Duration) -ForegroundColor DarkGray
    if ($Summary.RolledBack) {
        Write-Host '  Alteracoes revertidas automaticamente (transacao).' -ForegroundColor Yellow
    }
    Write-Host ("  Logs            : {0}" -f $script:App.SessionPath) -ForegroundColor DarkGray
    Write-Host ("  Restore-Plan    : {0}" -f (Join-Path $script:App.SessionPath 'Restore-Plan.ps1')) -ForegroundColor DarkGray
    Write-Host ''
}

if (-not (Confirm-Administrator)) { exit 1 }

if ((Get-WindowsBuild) -lt 22000) {
    Write-Host ''
    Write-Host '  Este programa e destinado apenas ao Windows 11 (build 22000 ou superior).' -ForegroundColor Red
    Write-Host ''
    Read-Host '  Pressione Enter para sair'
    exit 1
}

$summary = $null
$script:App = $null
$tuiStarted = $false
try {
    $script:App = New-AppState -Root $Root
    Filter-WhitelistedItems
    Tui-Init
    $tuiStarted = $true
    $summary = Invoke-AppFlow
} catch {
    if ($tuiStarted) { try { Tui-Close } catch { }; $tuiStarted = $false }
    Write-Host ''
    Write-Host '  Erro inesperado:' -ForegroundColor Red
    Write-Host ("  " + $_.Exception.Message) -ForegroundColor DarkGray
    if ($_.ScriptStackTrace) {
        Write-Host ''
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    Write-Host ''
    if ($script:App -and $script:App.SessionPath) {
        Write-Host ("  Logs: " + $script:App.SessionPath) -ForegroundColor DarkGray
    }
    Read-Host '  Pressione Enter para sair'
    exit 1
} finally {
    if ($tuiStarted) { try { Tui-Close } catch { } }
}

Write-PlainSummary -Summary $summary
