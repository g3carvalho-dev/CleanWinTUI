# CleanWinTUI - transaction with LIFO rollback

$script:Tx = $null

function Start-Transaction {
    $script:Tx = @{
        Id = [guid]::NewGuid().ToString()
        Status = 'IN_PROGRESS'
        StartedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Stack = New-Object System.Collections.ArrayList
    }
    Save-Transaction
    Write-Log "Transação iniciada: $($script:Tx.Id)"
}

function Save-Transaction {
    if (-not $script:Tx -or -not $script:App) { return }
    $path = Join-Path $script:App.SessionPath 'transaction.json'
    $payload = @{
        id = $script:Tx.Id
        status = $script:Tx.Status
        startedAt = $script:Tx.StartedAt
        finishedAt = $script:Tx.FinishedAt
        stack = @($script:Tx.Stack)
    }
    try {
        $payload | ConvertTo-Json -Depth 8 | Set-Content -Path $path -Encoding UTF8
    } catch { }
}

function Add-RollbackEntry {
    param([hashtable]$Entry)
    if (-not $script:Tx) { return }
    $Entry.Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    [void]$script:Tx.Stack.Add($Entry)
    Save-Transaction
}

function Set-TransactionStatus {
    param([string]$Status)
    if (-not $script:Tx) { return }
    $script:Tx.Status = $Status
    if ($Status -in @('COMMITTED', 'ROLLED_BACK', 'ABORTED')) {
        $script:Tx.FinishedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    Save-Transaction
    Write-Log "Transação: $Status"
}

function Restore-RegistryEntry {
    param([hashtable]$Entry)
    $path = "$($Entry.Hive):\$($Entry.Path)"
    try {
        if (-not $Entry.KeyExisted) {
            if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop }
            return @{ Ok = $true; Message = "chave removida: $path" }
        }
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        if (-not $Entry.Name) {
            return @{ Ok = $true; Message = "chave preservada: $path" }
        }
        if (-not $Entry.PropExisted) {
            if ($Entry.Name -eq '(Default)') {
                Set-Item -Path $path -Value '' -ErrorAction Stop
            } else {
                Remove-ItemProperty -Path $path -Name $Entry.Name -ErrorAction SilentlyContinue
            }
            return @{ Ok = $true; Message = "valor removido: $($Entry.Name)" }
        }
        if ($Entry.Name -eq '(Default)') {
            Set-Item -Path $path -Value $Entry.Value -ErrorAction Stop
        } else {
            New-ItemProperty -Path $path -Name $Entry.Name -Value $Entry.Value -PropertyType $Entry.ValueType -Force -ErrorAction Stop | Out-Null
        }
        return @{ Ok = $true; Message = "valor restaurado: $($Entry.Name)" }
    } catch {
        return @{ Ok = $false; Message = $_.Exception.Message }
    }
}

function Restore-TaskEntry {
    param([hashtable]$Entry)
    try {
        if ($Entry.WasEnabled) {
            & schtasks.exe /change /tn $Entry.TaskPath /enable 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0 -and $Entry.XmlFile -and (Test-Path $Entry.XmlFile)) {
                & schtasks.exe /create /tn $Entry.TaskPath /xml $Entry.XmlFile /f 2>$null | Out-Null
            }
            return @{ Ok = $true; Message = "tarefa reativada: $($Entry.TaskPath)" }
        }
        return @{ Ok = $true; Message = "tarefa já estava desativada: $($Entry.TaskPath)" }
    } catch {
        return @{ Ok = $false; Message = $_.Exception.Message }
    }
}

function Restore-AppxEntry {
    param([hashtable]$Entry)
    $present = Get-AppxPackage -Name $Entry.AppxName -ErrorAction SilentlyContinue
    if ($present) {
        return @{ Ok = $true; Message = "pacote presente: $($Entry.AppxName)" }
    }
    return @{ Ok = $false; Message = "reinstalação manual necessária: $($Entry.AppxName) (Microsoft Store)" }
}

function Invoke-RollbackEntry {
    param([hashtable]$Entry)
    if (-not $Entry.Type) { return @{ Ok = $false; Message = 'entrada de rollback inválida' } }
    switch ($Entry.Type) {
        'reg'     { return Restore-RegistryEntry $Entry }
        'task'    { return Restore-TaskEntry $Entry }
        'appx'    { return Restore-AppxEntry $Entry }
        default   { return @{ Ok = $false; Message = "tipo desconhecido: $($Entry.Type)" } }
    }
}

function Invoke-TransactionRollback {
    param([scriptblock]$OnProgress)

    if (-not $script:Tx -or $script:Tx.Stack.Count -eq 0) {
        Set-TransactionStatus 'ROLLED_BACK'
        return @{ Reverted = 0; Failed = 0; Fallback = $false; Errors = @() }
    }

    Set-TransactionStatus 'ROLLING_BACK'
    $entries = @($script:Tx.Stack)
    [array]::Reverse($entries)

    $reverted = 0
    $failed = 0
    $errors = New-Object System.Collections.Generic.List[string]
    $total = $entries.Count
    $i = 0

    foreach ($entry in $entries) {
        $i++
        $label = $entry.Label
        if (-not $label) { $label = $entry.Type }
        if ($OnProgress) { & $OnProgress $i $total $label }
        $r = Invoke-RollbackEntry $entry
        if ($r.Ok) {
            $reverted++
            Write-Log "ROLLBACK OK: $label - $($r.Message)" 'ROLLBACK'
        } else {
            $failed++
            $errors.Add($label)
            Write-Log "ROLLBACK FALHOU: $label - $($r.Message)" 'ERR'
        }
    }

    if ($failed -eq 0) {
        Set-TransactionStatus 'ROLLED_BACK'
    } else {
        Set-TransactionStatus 'ABORTED'
    }

    return @{
        Reverted = $reverted
        Failed = $failed
        Fallback = ($failed -gt 0)
        Errors = @($errors)
    }
}

function Get-TransactionStatus {
    if (-not $script:Tx) { return 'NONE' }
    return $script:Tx.Status
}
