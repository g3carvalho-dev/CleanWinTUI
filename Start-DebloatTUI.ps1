#Requires -RunAsAdministrator

using namespace System
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Text

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:CleanWinTUI = @{
    Root = $ScriptRoot
    ConfigPath = Join-Path $ScriptRoot "config"
    ModulesPath = Join-Path $ScriptRoot "modules"
    LibPath = Join-Path $ScriptRoot "lib"
    LogsRoot = Join-Path $env:LOCALAPPDATA "CleanWinTUI\logs"
    SessionId = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    SessionPath = $null
    WinBuild = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    SelectedItems = @()
    TransactionActive = $false
    RestorePointCreated = $false
    DryRun = $false
}

$Global:CleanWinTUI.SessionPath = Join-Path $Global:CleanWinTUI.LogsRoot $Global:CleanWinTUI.SessionId
New-Item -ItemType Directory -Path $Global:CleanWinTUI.SessionPath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Global:CleanWinTUI.SessionPath "backup") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Global:CleanWinTUI.SessionPath "quarantine") -Force | Out-Null

Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "Core.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "UI.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "Transaction.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "Apps.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "Features.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "Telemetry.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "Explorer.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "EdgeAI.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "System.psm1") -Force
Import-Module (Join-Path $Global:CleanWinTUI.ModulesPath "RestoreGen.psm1") -Force
. (Join-Path $Global:CleanWinTUI.LibPath "ConsoleMenu.ps1")

function Show-Welcome {
    Clear-Host
    Write-Host ""
    Write-Host "  ┌─ CLEANWINTUI ──────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │ Debloat Controlado para Windows 11                                     │" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Sessão: $($Global:CleanWinTUI.SessionId)" -ForegroundColor Gray
    Write-Host "  Build:  $($Global:CleanWinTUI.WinBuild)" -ForegroundColor Gray
    Write-Host "  Admin:  $($Global:CleanWinTUI.IsAdmin)" -ForegroundColor $(if($Global:CleanWinTUI.IsAdmin){"Green"}else{"Red"})
    Write-Host ""
    if ($Global:CleanWinTUI.WinBuild -lt 22000) {
        Write-Host "  [ERRO] Este programa é destinado apenas ao Windows 11 (build >= 22000)" -ForegroundColor Red
        Read-Host "  Pressione Enter para sair"
        exit 1
    }
    Write-Host "  [AVISO] Sempre crie/verifique ponto de restauração. Para itens CUIDADO/AVANÇADO será obrigatório." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Pressione Enter para continuar"
}

function Start-MainFlow {
    Show-Welcome
    $catalog = Get-Content (Join-Path $Global:CleanWinTUI.ConfigPath "catalog.json") | ConvertFrom-Json
    $whitelist = Get-Content (Join-Path $Global:CleanWinTUI.ConfigPath "whitelist.json") | ConvertFrom-Json
    $defaults = Get-Content (Join-Path $Global:CleanWinTUI.ConfigPath "defaults.json") | ConvertFrom-Json
    
    Write-Log "Iniciando CleanWinTUI - Build $($Global:CleanWinTUI.WinBuild)"
    
    # Seleção simplificada - usa defaults
    $Global:CleanWinTUI.SelectedItems = $catalog.items | Where-Object { $defaults.defaults -contains $_.id }
    
    $hasCritical = ($Global:CleanWinTUI.SelectedItems | Where-Object { $_.group -eq "CUIDADO" -or $_.group -eq "AVANÇADO" }).Count -gt 0
    
    if ($hasCritical) {
        $Global:CleanWinTUI.TransactionActive = $true
        Write-Host "`n  [TRANSACAO ATIVA] Itens CUIDADO/AVANÇADO detectados" -ForegroundColor Magenta
        $rp = New-RestorePoint -Description "CleanWinTUI - Pré-Debloat $($Global:CleanWinTUI.SessionId)"
        if (-not $rp.Success) {
            Write-Host "  [ERRO] Falha ao criar ponto de restauração. Execução bloqueada." -ForegroundColor Red
            Read-Host "  Pressione Enter para sair"
            exit 1
        }
        $Global:CleanWinTUI.RestorePointCreated = $true
        Start-Transaction
    } else {
        $rp = New-RestorePoint -Description "CleanWinTUI - Pré-Debloat $($Global:CleanWinTUI.SessionId)" -Quiet
        if ($rp.Success) { $Global:CleanWinTUI.RestorePointCreated = $true }
    }
    
    Backup-PreState -Items $Global:CleanWinTUI.SelectedItems
    Write-Manifest -Items $Global:CleanWinTUI.SelectedItems
    
    # Execução
    Show-ExecutionScreen -Items $Global:CleanWinTUI.SelectedItems
    
    if ($Global:CleanWinTUI.TransactionActive) {
        Complete-Transaction -Success $true
    }
    
    New-RestorePlan -Items $Global:CleanWinTUI.SelectedItems
    Show-FinalReport
}

function Show-ExecutionScreen {
    param([array]$Items)
    Clear-Host
    Write-Host "`n  ┌─ CLEANWINTUI - EXECUTANDO DEBLOAT ──────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │ Sessão: $($Global:CleanWinTUI.SessionId) | Win11 Build: $($Global:CleanWinTUI.WinBuild)$(if($Global:CleanWinTUI.TransactionActive){' | [TRANSACAO: ATIVA]'}) │" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    
    $total = $Items.Count
    $i = 0
    foreach ($item in $Items) {
        $i++
        $pct = [math]::Round(($i / $total) * 100)
        Write-Host "  MÓDULO ATUAL: [Processando]" -ForegroundColor White
        Write-Host "  ETAPA ATUAL:   Aplicando $($item.title)" -ForegroundColor White
        Write-Host ""
        $bar = ('█' * [math]::Floor($pct/10)) + ('░' * (10 - [math]::Floor($pct/10)))
        Write-Host "  PROGRESSO DA ETAPA:  [$bar]  $pct%   ($i / $total)" -ForegroundColor Cyan
        Write-Host "  PROGRESSO GERAL:     [$bar]  $pct%   ($i / $total módulos)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  EM EXECUÇÃO:" -ForegroundColor Yellow
        Write-Host "  > Aplicando: $($item.title)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  ÚLTIMAS AÇÕES:" -ForegroundColor Gray
        Write-Host "  [OK]   Processando item $i/$total" -ForegroundColor Green
        Write-Host "`n  " -NoNewline
        Start-Sleep -Milliseconds 500
        Invoke-ItemAction -Item $item
        Clear-Host
        Write-Host "`n  ┌─ CLEANWINTUI - EXECUTANDO DEBLOAT ──────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │ Sessão: $($Global:CleanWinTUI.SessionId) | Win11 Build: $($Global:CleanWinTUI.WinBuild)$(if($Global:CleanWinTUI.TransactionActive){' | [TRANSACAO: ATIVA]'}) │" -ForegroundColor Cyan
        Write-Host "  └─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
    }
}

function Invoke-ItemAction {
    param([object]$Item)
    foreach ($action in $Item.actions) {
        if ($Global:CleanWinTUI.TransactionActive -and $Item.transactionCritical) {
            $before = @{}
            Push-RollbackEntry -Item $Item -Action $action -BeforeState $before
        }
        try {
            switch ($action.type) {
                "appx_remove" {
                    $pkg = Get-AppxPackage -Name $action.name -ErrorAction SilentlyContinue
                    if ($pkg) {
                        Write-Log "Removendo Appx: $($action.name)"
                        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                        Add-AppxToQuarantine -Name $action.name -PackageFullName $pkg.PackageFullName
                    }
                }
                "reg_set" {
                    $key = Join-Path "$($action.hive):\" $action.path
                    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
                    New-ItemProperty -Path $key -Name $action.name -Value $action.value -PropertyType $action.type -Force | Out-Null
                    Write-Log "Registro alterado: $key\$($action.name)"
                }
                "reg_create_key" {
                    $key = Join-Path "$($action.hive):\" $action.path
                    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
                }
            }
        } catch {
            Write-Log "ERRO: $($_.Exception.Message)"
            if ($Global:CleanWinTUI.TransactionActive -and $Item.transactionCritical) {
                Invoke-Rollback
                exit 1
            }
        }
    }
}

function Show-FinalReport {
    Clear-Host
    Write-Host "`n  ┌─ CLEANWINTUI - CONCLUÍDO ──────────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "  │ Sessão finalizada                                                        │" -ForegroundColor Green
    Write-Host "  └───────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Logs:        $($Global:CleanWinTUI.SessionPath)" -ForegroundColor Gray
    Write-Host "  Restore-Plan: $(Join-Path $Global:CleanWinTUI.SessionPath 'Restore-Plan.ps1')" -ForegroundColor Gray
    Write-Host "  Backup:      $(Join-Path $Global:CleanWinTUI.SessionPath 'backup')" -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Pressione Enter para sair"
}

Start-MainFlow
