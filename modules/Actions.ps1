# CleanWinTUI - action capture/apply layer

function Get-RegValueSnapshot {
    param([string]$Hive, [string]$Path, [string]$Name)
    $psPath = "$($Hive):\$($Path)"
    $snap = @{
        KeyExisted = $false
        PropExisted = $false
        Value = $null
        ValueType = 'String'
        Name = $Name
    }
    if (-not (Test-Path $psPath)) { return $snap }
    $snap.KeyExisted = $true
    try {
        if ($Name -eq '(Default)') {
            $item = Get-Item -Path $psPath -ErrorAction Stop
            $val = $item.GetValue('', $null)
            if ($null -ne $val) {
                $snap.PropExisted = $true
                $snap.Value = $val
                try { $snap.ValueType = $item.GetValueKind('').ToString() } catch { }
            }
            return $snap
        }
        $prop = Get-ItemProperty -Path $psPath -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $prop) {
            $snap.PropExisted = $true
            $snap.Value = $prop.$Name
            try {
                $key = Get-Item -Path $psPath -ErrorAction Stop
                $snap.ValueType = $key.GetValueKind($Name).ToString()
            } catch { }
        }
    } catch { }
    return $snap
}

function Invoke-RegistrySet {
    param([object]$Action)
    $psPath = "$($Action.hive):\$($Action.path)"
    if (-not (Test-Path $psPath)) {
        New-Item -Path $psPath -Force -ErrorAction Stop | Out-Null
    }
    if ($Action.name -eq '(Default)') {
        Set-Item -Path $psPath -Value ([string]$Action.value) -ErrorAction Stop
    } else {
        $kind = 'String'
        if ($Action.valueType) { $kind = [string]$Action.valueType }
        New-ItemProperty -Path $psPath -Name $Action.name -Value $Action.value -PropertyType $kind -Force -ErrorAction Stop | Out-Null
    }
    $check = Get-ItemProperty -Path $psPath -Name $Action.name -ErrorAction SilentlyContinue
    if ($Action.name -ne '(Default)' -and $null -eq $check) {
        throw "valor não pôde ser confirmado: $($Action.name)"
    }
}

function Invoke-RegistryDelete {
    param([object]$Action)
    $psPath = "$($Action.hive):\$($Action.path)"
    if (-not (Test-Path $psPath)) { return 'chave inexistente (ignorado)' }
    if (-not $Action.name) {
        Remove-Item -Path $psPath -Recurse -Force -ErrorAction Stop
        return 'chave removida'
    }
    if ($Action.name -eq '(Default)') {
        Set-Item -Path $psPath -Value '' -ErrorAction Stop
        return 'valor padrão limpo'
    }
    Remove-ItemProperty -Path $psPath -Name $Action.name -ErrorAction Stop
    return 'valor removido'
}

function Invoke-RegistryCreateKey {
    param([object]$Action)
    $psPath = "$($Action.hive):\$($Action.path)"
    if (-not (Test-Path $psPath)) {
        New-Item -Path $psPath -Force -ErrorAction Stop | Out-Null
    }
    return 'chave garantida'
}

function Get-TaskXmlBackupFile {
    param([string]$TaskPath)
    $indexFile = Join-Path $script:App.SessionPath 'backup\tasks\index.json'
    if (-not (Test-Path $indexFile)) { return $null }
    try {
        $index = Get-Content -Raw -Encoding UTF8 $indexFile | ConvertFrom-Json
        $entry = $index | Where-Object { $_.TaskPath -eq $TaskPath } | Select-Object -First 1
        if ($entry -and $entry.Existed) {
            return (Join-Path $script:App.SessionPath ('backup\tasks\' + $entry.File))
        }
    } catch { }
    return $null
}

function Invoke-TaskDisable {
    param([object]$Action)
    $wasEnabled = $false
    $leaf = ($Action.path -split '\\')[-1]
    $parent = $Action.path.Substring(0, $Action.path.Length - $leaf.Length)
    if (-not $parent.EndsWith('\')) { $parent += '\' }
    try {
        $task = Get-ScheduledTask -TaskPath $parent -TaskName $leaf -ErrorAction Stop
        $wasEnabled = ($task.State -ne 'Disabled')
    } catch {
        return @{ Result = 'tarefa não encontrada (ignorado)'; WasEnabled = $false; Found = $false }
    }

    if (-not $wasEnabled) {
        return @{ Result = 'tarefa já desativada'; WasEnabled = $false; Found = $true }
    }

    & schtasks.exe /change /tn $Action.path /disable 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "falha ao desativar tarefa $($Action.path) (código $LASTEXITCODE)"
    }
    return @{ Result = 'tarefa desativada'; WasEnabled = $true; Found = $true }
}

function Invoke-AppxRemove {
    param([object]$Action)
    $packages = @(Get-AppxPackage -Name $Action.name -ErrorAction SilentlyContinue)
    if (-not $packages -or $packages.Count -eq 0) {
        return @{ Result = 'pacote não instalado (ignorado)'; Found = $false; Removed = @() }
    }
    $removed = New-Object System.Collections.Generic.List[string]
    foreach ($pkg in $packages) {
        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
        $removed.Add($pkg.PackageFullName)
    }
    return @{ Result = "pacote(s) removido(s): $($removed.Count)"; Found = $true; Removed = @($removed) }
}

function Add-AppxQuarantine {
    param([string]$Name, [string[]]$PackageFullNames)
    $file = Join-Path $script:App.SessionPath 'quarantine\appx.json'
    $list = New-Object System.Collections.Generic.List[object]
    if (Test-Path $file) {
        try {
            $existing = Get-Content -Raw -Encoding UTF8 $file | ConvertFrom-Json
            foreach ($e in @($existing)) { $list.Add($e) }
        } catch { }
    }
    foreach ($pfn in $PackageFullNames) {
        $list.Add([pscustomobject]@{
            Name = $Name
            PackageFullName = $pfn
            RemovedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            StoreUri = "ms-windows-store://search/?query=$Name"
        })
    }
    $list | ConvertTo-Json -Depth 4 | Set-Content -Path $file -Encoding UTF8
}

function Invoke-Action {
    param(
        [object]$Item,
        [object]$Action,
        [bool]$TxMode = $false
    )

    $result = @{ Ok = $false; Message = ''; Pushed = $false }

    try {
        switch ($Action.type) {
            'appx_remove' {
                $snap = @(Get-AppxPackage -Name $Action.name -ErrorAction SilentlyContinue)
                if ($TxMode) {
                    Add-RollbackEntry @{
                        Type = 'appx'
                        Label = "Appx $($Action.name)"
                        AppxName = $Action.name
                        WasPresent = ($snap.Count -gt 0)
                    }
                }
                $r = Invoke-AppxRemove $Action
                if ($r.Removed.Count -gt 0) {
                    Add-AppxQuarantine -Name $Action.name -PackageFullNames $r.Removed
                }
                $result.Ok = $true
                $result.Message = $r.Result
            }
            'reg_set' {
                $snap = Get-RegValueSnapshot $Action.hive $Action.path $Action.name
                if ($TxMode) {
                    Add-RollbackEntry @{
                        Type = 'reg'
                        Label = "Registro $($Action.hive)\$($Action.path)\$($Action.name)"
                        Hive = $Action.hive
                        Path = $Action.path
                        Name = $Action.name
                        KeyExisted = [bool]$snap.KeyExisted
                        PropExisted = [bool]$snap.PropExisted
                        Value = $snap.Value
                        ValueType = $snap.ValueType
                    }
                }
                Invoke-RegistrySet $Action
                $result.Ok = $true
                $result.Message = 'valor aplicado'
            }
            'reg_delete' {
                $snap = Get-RegValueSnapshot $Action.hive $Action.path $Action.name
                if ($TxMode) {
                    Add-RollbackEntry @{
                        Type = 'reg'
                        Label = "Registro $($Action.hive)\$($Action.path)\$($Action.name)"
                        Hive = $Action.hive
                        Path = $Action.path
                        Name = $Action.name
                        KeyExisted = [bool]$snap.KeyExisted
                        PropExisted = [bool]$snap.PropExisted
                        Value = $snap.Value
                        ValueType = $snap.ValueType
                    }
                }
                $result.Message = Invoke-RegistryDelete $Action
                $result.Ok = $true
            }
            'reg_create_key' {
                $psPath = "$($Action.hive):\$($Action.path)"
                $existed = Test-Path $psPath
                if ($TxMode -and -not $existed) {
                    Add-RollbackEntry @{
                        Type = 'reg'
                        Label = "Chave $($Action.hive)\$($Action.path)"
                        Hive = $Action.hive
                        Path = $Action.path
                        Name = $null
                        KeyExisted = $false
                        PropExisted = $false
                        Value = $null
                        ValueType = 'String'
                    }
                }
                $result.Message = Invoke-RegistryCreateKey $Action
                $result.Ok = $true
            }
            'task_disable' {
                $leaf = ($Action.path -split '\\')[-1]
                $parent = $Action.path.Substring(0, $Action.path.Length - $leaf.Length)
                if (-not $parent.EndsWith('\')) { $parent += '\' }
                $wasEnabled = $false
                try {
                    $task = Get-ScheduledTask -TaskPath $parent -TaskName $leaf -ErrorAction Stop
                    $wasEnabled = ($task.State -ne 'Disabled')
                } catch {
                    $result.Ok = $true
                    $result.Message = 'tarefa não encontrada (ignorado)'
                    break
                }
                if ($TxMode) {
                    Add-RollbackEntry @{
                        Type = 'task'
                        Label = "Tarefa $($Action.path)"
                        TaskPath = $Action.path
                        WasEnabled = $wasEnabled
                        XmlFile = (Get-TaskXmlBackupFile $Action.path)
                    }
                }
                if (-not $wasEnabled) {
                    $result.Ok = $true
                    $result.Message = 'tarefa já desativada'
                    break
                }
                & schtasks.exe /change /tn $Action.path /disable 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "schtasks retornou código $LASTEXITCODE"
                }
                $result.Ok = $true
                $result.Message = 'tarefa desativada'
            }
            default {
                throw "tipo de ação desconhecido: $($Action.type)"
            }
        }
    } catch {
        $result.Ok = $false
        $result.Message = $_.Exception.Message
    }

    return $result
}
