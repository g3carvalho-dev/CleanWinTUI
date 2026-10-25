function Test-IsAdmin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Win11Build {
    return [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
}

function Test-SystemRestoreEnabled {
    try {
        $sysDrive = $env:SystemDrive
        $comp = Get-WmiObject -Class SystemRestore -Namespace root\default -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function New-RestorePoint {
    param(
        [string]$Description = "CleanWinTUI Restore Point",
        [switch]$Quiet
    )
    try {
        if (-not $Quiet) {
            Write-Host "  [INFO] Criando ponto de restauração..." -ForegroundColor Cyan
        }
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Ponto de restauração criado: $Description"
        if (-not $Quiet) {
            Write-Host "  [OK] Ponto de restauração criado com sucesso" -ForegroundColor Green
        }
        return @{Success=$true; Description=$Description}
    } catch {
        Write-Log "ERRO ao criar ponto de restauração: $($_.Exception.Message)"
        if (-not $Quiet) {
            Write-Host "  [ERRO] Falha ao criar ponto de restauração: $($_.Exception.Message)" -ForegroundColor Red
        }
        return @{Success=$false; Error=$_.Exception.Message}
    }
}

function Write-Log {
    param([string]$Message)
    $logFile = Join-Path $Global:CleanWinTUI.SessionPath "cleanwintui.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

function Backup-PreState {
    param([array]$Items)
    Write-Host "  [INFO] Criando backups pré-alteração..." -ForegroundColor Cyan
    try {
        $appxBackup = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name, PackageFullName, Version, Publisher
        $appxBackup | ConvertTo-Json -Depth 3 | Out-File (Join-Path $Global:CleanWinTUI.SessionPath "backup\backup-appx.json") -Encoding UTF8
        
        $servicesBackup = Get-Service | Where-Object { $_.Name -in @("wuauserv", "WinDefend", "MpsSvc") } | Select-Object Name, Status, StartType
        $servicesBackup | ConvertTo-Json -Depth 2 | Out-File (Join-Path $Global:CleanWinTUI.SessionPath "backup\backup-services.json") -Encoding UTF8
        
        Write-Log "Backups pré-alteração criados"
        Write-Host "  [OK] Backups criados" -ForegroundColor Green
    } catch {
        Write-Log "ERRO ao criar backups: $($_.Exception.Message)"
    }
}

function Write-Manifest {
    param([array]$Items)
    $manifest = @{
        SessionId = $Global:CleanWinTUI.SessionId
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        WinBuild = $Global:CleanWinTUI.WinBuild
        User = $env:USERNAME
        TransactionActive = $Global:CleanWinTUI.TransactionActive
        RestorePointCreated = $Global:CleanWinTUI.RestorePointCreated
        Items = $Items | ForEach-Object {
            @{
                Id = $_.id
                Group = $_.group
                Title = $_.title
                Actions = $_.actions.Count
            }
        }
    }
    $manifest | ConvertTo-Json -Depth 4 | Out-File (Join-Path $Global:CleanWinTUI.SessionPath "backup\execution-manifest.json") -Encoding UTF8
}

function Test-Whitelisted {
    param([string]$Name)
    $whitelist = Get-Content (Join-Path $Global:CleanWinTUI.ConfigPath "whitelist.json") | ConvertFrom-Json
    foreach ($w in $whitelist.appx) {
        if ($Name -like $w) { return $true }
    }
    return $false
}

function Add-AppxToQuarantine {
    param([string]$Name, [string]$PackageFullName)
    $qFile = Join-Path $Global:CleanWinTUI.SessionPath "quarantine\appx.json"
    $q = @()
    if (Test-Path $qFile) {
        $q = Get-Content $qFile | ConvertFrom-Json
    }
    $q += @{Name=$Name; PackageFullName=$PackageFullName; RemovedAt=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")}
    $q | ConvertTo-Json -Depth 2 | Out-File $qFile -Encoding UTF8
}

Export-ModuleMember -Function Test-IsAdmin, Get-Win11Build, Test-SystemRestoreEnabled, New-RestorePoint, Write-Log, Backup-PreState, Write-Manifest, Test-Whitelisted, Add-AppxToQuarantine
