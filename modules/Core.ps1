# CleanWinTUI - core helpers (admin, logging, backups, restore point, whitelist)

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsBuild {
    return [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    if (-not $script:App) { return }
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    try {
        Add-Content -Path (Join-Path $script:App.SessionPath 'session.log') -Value $line -Encoding UTF8
    } catch { }
}

function New-RestorePointSafe {
    param([string]$Description)

    $result = @{ Success = $false; Message = ''; Sequence = $null }
    $srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $hadFrequency = $false
    $frequencyBefore = $null

    try {
        $props = Get-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -ErrorAction Stop
        $frequencyBefore = $props.SystemRestorePointCreationFrequency
        $hadFrequency = $true
    } catch { }

    try {
        if (-not (Test-Path $srKey)) {
            New-Item -Path $srKey -Force | Out-Null
        }
        New-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null

        $before = @()
        try {
            $before = @(Get-ComputerRestorePoint -ErrorAction Stop | Select-Object -ExpandProperty SequenceNumber)
        } catch {
            $before = @()
        }

        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Start-Sleep -Milliseconds 800

        $points = @()
        try {
            $points = @(Get-ComputerRestorePoint -ErrorAction Stop | Sort-Object SequenceNumber)
        } catch { }

        $newPoint = $points | Where-Object { $before -notcontains $_.SequenceNumber } | Select-Object -Last 1
        if ($newPoint) {
            $result.Success = $true
            $result.Sequence = $newPoint.SequenceNumber
            $result.Message = "Ponto #$($newPoint.SequenceNumber) criado: $($newPoint.Description)"
        } elseif ($points.Count -gt 0) {
            $result.Success = $true
            $result.Sequence = ($points | Select-Object -Last 1).SequenceNumber
            $result.Message = 'Checkpoint-Computer concluiu; ponto mais recente confirmado.'
        } else {
            $result.Message = 'Checkpoint-Computer concluiu, mas nenhum ponto pôde ser confirmado.'
        }
    } catch {
        $result.Message = $_.Exception.Message
    } finally {
        try {
            if ($hadFrequency) {
                New-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value $frequencyBefore -PropertyType DWord -Force | Out-Null
            } else {
                Remove-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue
            }
        } catch { }
    }

    Write-Log ("Ponto de restauração: " + $result.Message) ($(if ($result.Success) { 'OK' } else { 'WARN' }))
    return $result
}

function Backup-RegistryKeys {
    param([array]$Items)
    $dir = Join-Path $script:App.SessionPath 'backup\registry'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $keys = @()
    foreach ($item in $Items) {
        if ($item.backupKeys) {
            foreach ($k in $item.backupKeys) { $keys += $k }
        }
    }
    $keys = @($keys | Select-Object -Unique)

    $index = New-Object System.Collections.Generic.List[object]
    $i = 0
    foreach ($k in $keys) {
        $i++
        $regPath = $k -replace '^(HKCU|HKLM):', '$1'
        $safe = ('{0:D2}_{1}.reg' -f $i, (($regPath -replace '[^A-Za-z0-9]+', '_').Trim('_')))
        if ($safe.Length -gt 90) { $safe = $safe.Substring(0, 90) + '.reg' }
        $file = Join-Path $dir $safe
        $existed = $true
        try {
            & reg.exe export $regPath $file /y 2>$null | Out-Null
            if (-not (Test-Path $file)) { $existed = $false }
        } catch {
            $existed = $false
        }
        $index.Add([pscustomobject]@{ Key = $regPath; File = $safe; Existed = $existed })
    }
    $index | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $dir 'index.json') -Encoding UTF8
    Write-Log "Backup de registro exportado: $($index.Count) chave(s)"
    return $index.Count
}

function Backup-AppxSnapshot {
    $file = Join-Path $script:App.SessionPath 'backup\appx.json'
    $list = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name, PackageFullName, Version, Publisher)
    $list | ConvertTo-Json -Depth 3 | Set-Content -Path $file -Encoding UTF8
    Write-Log "Snapshot Appx salvo: $($list.Count) pacotes"
    return $list.Count
}

function Backup-TaskDefinitions {
    param([array]$Items)
    $dir = Join-Path $script:App.SessionPath 'backup\tasks'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $index = New-Object System.Collections.Generic.List[object]
    $i = 0
    foreach ($item in $Items) {
        foreach ($action in $item.actions) {
            if ($action.type -ne 'task_disable') { continue }
            $i++
            $safe = ('{0:D2}_task.xml' -f $i)
            $file = Join-Path $dir $safe
            $xml = $null
            try { $xml = & schtasks.exe /query /tn $action.path /xml 2>$null } catch { }
            $existed = $false
            if ($xml) {
                $text = ($xml -join "`r`n")
                if ($text -match '<Task') {
                    [System.IO.File]::WriteAllText($file, $text, [System.Text.Encoding]::Unicode)
                    $existed = $true
                }
            }
            $index.Add([pscustomobject]@{ TaskPath = $action.path; File = $safe; Existed = $existed })
        }
    }
    $index | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $dir 'index.json') -Encoding UTF8
    Write-Log "Backup de tarefas: $($index.Count) definição(ões)"
    return $index.Count
}

function Backup-ServiceState {
    $file = Join-Path $script:App.SessionPath 'backup\services.json'
    $list = @(Get-Service -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType)
    $list | ConvertTo-Json -Depth 3 | Set-Content -Path $file -Encoding UTF8
    Write-Log "Snapshot de serviços salvo: $($list.Count)"
    return $list.Count
}

function Write-ExecutionManifest {
    param([array]$Items)
    $manifest = [ordered]@{
        sessionId = $script:App.SessionId
        createdAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        windowsBuild = $script:App.Build
        user = $env:USERNAME
        computer = $env:COMPUTERNAME
        transactionMode = [bool]$script:App.TxMode
        restorePoint = $script:App.RestorePoint
        items = @($Items | ForEach-Object {
            [ordered]@{
                id = $_.id
                group = $_.group
                module = $_.module
                title = $_.title
                actions = @($_.actions | ForEach-Object { Get-ActionDescription $_ })
            }
        })
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $script:App.SessionPath 'backup\manifest.json') -Encoding UTF8
    Write-Log 'Manifesto de execução gravado'
}

function Get-NormalizedRegPath {
    param([string]$Hive, [string]$Path)
    return ("{0}\{1}" -f $Hive, $Path) -replace '\\+', '\'
}

function Test-WhitelistedItem {
    param([object]$Item)
    $wl = $script:App.Whitelist
    foreach ($action in $Item.actions) {
        if ($action.type -eq 'appx_remove') {
            foreach ($pattern in $wl.appx) {
                if ($action.name -like $pattern) { return $true }
            }
        }
        if ($action.type -like 'reg_*') {
            $full = Get-NormalizedRegPath $action.hive $action.path
            foreach ($pattern in $wl.registryKeys) {
                $p = ($pattern -replace ':', '') -replace '\\+', '\'
                if ($full.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
            }
        }
        if ($action.type -eq 'task_disable') {
            foreach ($pattern in $wl.tasks) {
                if ($action.path.StartsWith($pattern, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
            }
        }
    }
    return $false
}

function Get-ActionDescription {
    param([object]$Action)
    switch ($Action.type) {
        'appx_remove'   { return "Remover pacote Appx: $($Action.name)" }
        'reg_set'       {
            if ($Action.name -eq '(Default)') { return "Definir valor padrão em $($Action.hive)\$($Action.path)" }
            return "Definir $($Action.name) = $($Action.value) em $($Action.hive)\$($Action.path)"
        }
        'reg_delete'    { return "Remover valor $($Action.name) de $($Action.hive)\$($Action.path)" }
        'reg_create_key'{ return "Criar chave $($Action.hive)\$($Action.path)" }
        'task_disable'  { return "Desativar tarefa agendada: $($Action.path)" }
        default         { return "$($Action.type) $($Action.name)$($Action.path)" }
    }
}

function Get-ActionMotivo {
    param([object]$Action)
    switch ($Action.type) {
        'appx_remove'    { return "remover aplicativo" }
        'reg_set'        { return "ajustar configuração" }
        'reg_delete'     { return "remover configuração" }
        'reg_create_key' { return "preparar chave" }
        'task_disable'   { return "desativar tarefa" }
        default          { return "aplicar ajuste" }
    }
}
