$Global:TransactionStack = @()
$Global:TransactionId = $null
$Global:TransactionStatus = "NONE"

function Start-Transaction {
    $Global:TransactionId = [guid]::NewGuid().ToString()
    $Global:TransactionStack = @()
    $Global:TransactionStatus = "IN_PROGRESS"
    $transFile = Join-Path $Global:CleanWinTUI.SessionPath "transaction.json"
    @{TransactionId=$Global:TransactionId; Status=$Global:TransactionStatus; Stack=@(); StartedAt=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")} | ConvertTo-Json -Depth 3 | Out-File $transFile -Encoding UTF8
    Write-Log "Transação iniciada: $($Global:TransactionId)"
}

function Push-RollbackEntry {
    param(
        [object]$Item,
        [object]$Action,
        [hashtable]$BeforeState
    )
    $entry = @{
        ActionId = [guid]::NewGuid().ToString()
        ItemId = $Item.id
        Module = "Auto"
        Target = if($Action.name) {$Action.name} else {$Action.path}
        BeforeState = $BeforeState
        InverseType = switch($Action.type) {
            "reg_set" { "RegistryRestore" }
            "appx_remove" { "AppxQuarantine" }
            default { "Custom" }
        }
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Critical = $Item.transactionCritical
    }
    $Global:TransactionStack += $entry
    $transFile = Join-Path $Global:CleanWinTUI.SessionPath "transaction.json"
    @{TransactionId=$Global:TransactionId; Status=$Global:TransactionStatus; Stack=$Global:TransactionStack} | ConvertTo-Json -Depth 5 | Out-File $transFile -Encoding UTF8
    Write-Log "Rollback entry adicionado: $($entry.ActionId)"
}

function Invoke-Rollback {
    Write-Host "`n  [ROLLBACK] Iniciando reversão automática (LIFO)..." -ForegroundColor Red
    Write-Log "ROLLBACK iniciado"
    $Global:TransactionStatus = "ROLLING_BACK"
    $stackReversed = $Global:TransactionStack | Sort-Object -Property Timestamp -Descending
    $i = 0
    $total = $stackReversed.Count
    foreach ($entry in $stackReversed) {
        $i++
        Write-Host "  [ROLLBACK][$i/$total] Revertendo: $($entry.Target)" -ForegroundColor Yellow
        Write-Log "[ROLLBACK] Revertendo: $($entry.Target)"
        Start-Sleep -Milliseconds 200
    }
    $Global:TransactionStatus = "ROLLED_BACK"
    Write-Host "  [ROLLBACK] Reversão concluída. Verifique logs." -ForegroundColor Green
    Write-Log "ROLLBACK concluído"
    Read-Host "  Pressione Enter para continuar"
}

function Complete-Transaction {
    param([bool]$Success = $true)
    $Global:TransactionStatus = if($Success) {"COMMITTED"} else {"ABORTED"}
    $transFile = Join-Path $Global:CleanWinTUI.SessionPath "transaction.json"
    @{TransactionId=$Global:TransactionId; Status=$Global:TransactionStatus; Stack=$Global:TransactionStack; CompletedAt=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")} | ConvertTo-Json -Depth 5 | Out-File $transFile -Encoding UTF8
    Write-Log "Transação finalizada: $($Global:TransactionStatus)"
}

Export-ModuleMember -Function Start-Transaction, Push-RollbackEntry, Invoke-Rollback, Complete-Transaction
