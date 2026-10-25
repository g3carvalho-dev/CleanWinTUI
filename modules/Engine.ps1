# CleanWinTUI - execution engine with live progress

$script:ModuleOrder = @(
    @{ Id = 'apps';      Label = 'Aplicativos (Appx)' },
    @{ Id = 'explorer';  Label = 'Explorer & interface' },
    @{ Id = 'telemetry'; Label = 'Telemetria & privacidade' },
    @{ Id = 'edgeai';    Label = 'Recursos de IA' },
    @{ Id = 'system';    Label = 'Sistema & energia' },
    @{ Id = 'features';  Label = 'Recursos opcionais' }
)

function Get-LogColor {
    param([string]$Status)
    switch ($Status) {
        'OK'       { return 'green' }
        'WARN'     { return 'yellow' }
        'ERR'      { return 'red' }
        'ROLLBACK' { return 'orange' }
        'INFO'     { return 'muted' }
        default    { return 'muted' }
    }
}

function Draw-ExecutionFrame {
    param([hashtable]$View)

    $badge = ''
    $badgeColor = 'orange'
    if ($View.Mode -eq 'rollback') {
        $badge = 'ROLLBACK EM CURSO'
        $badgeColor = 'red'
    } elseif ($script:App.TxMode) {
        $badge = 'TRANSACAO ATIVA'
        $badgeColor = 'orange'
    }

    Initialize-Frame -Right ("sessão {0}" -f $script:App.SessionId) -Badge $badge -BadgeColor $badgeColor

    $title = if ($View.Mode -eq 'rollback') { 'REVERTENDO ALTERAÇÕES' } else { 'EXECUTANDO DEBLOAT' }
    $titleColor = if ($View.Mode -eq 'rollback') { 'red' } else { 'fg' }
    Tui-Put 2 1 (" " + $title + " ") $titleColor 'base'

    $boxY = 3
    $boxH = $script:TH - 5
    if ($boxH -lt 12) { $boxH = 12 }
    Tui-Box 1 $boxY ($script:TW - 2) $boxH 'PROGRESSO' 'line' 'base' 'accent'

    $left = 3
    $labelW = 10
    $valueX = $left + $labelW + 1
    $innerW = $script:TW - 6

    Tui-Put $left ($boxY + 1) 'MÓDULO' 'dim' 'base'
    Tui-Put $valueX ($boxY + 1) (Tui-Truncate $View.Module ($innerW - $labelW - 1)) 'fg' 'base'

    Tui-Put $left ($boxY + 2) 'ETAPA' 'dim' 'base'
    Tui-Put $valueX ($boxY + 2) (Tui-Truncate $View.Step ($innerW - $labelW - 1)) 'fg' 'base'

    $barW = $script:TW - 48
    if ($barW -lt 12) { $barW = 12 }
    if ($barW -gt 56) { $barW = 56 }

    $stepPct = 0
    if ($View.ModuleTotal -gt 0) { $stepPct = [int][Math]::Round(($View.ModuleDone * 100) / $View.ModuleTotal) }
    $globalPct = 0
    if ($View.GlobalTotal -gt 0) { $globalPct = [int][Math]::Round(($View.GlobalDone * 100) / $View.GlobalTotal) }

    $barY = $boxY + 4
    Tui-Put $left $barY 'ETAPA' 'dim' 'base'
    Draw-ProgressBar $valueX $barY $barW $stepPct 'accent' 'base'
    Tui-Put ($valueX + $barW + 2) $barY ("{0,3}%" -f $stepPct) 'fg' 'base'
    Tui-Put ($valueX + $barW + 7) $barY ("({0}/{1})" -f $View.ModuleDone, $View.ModuleTotal) 'dim' 'base'

    $barY2 = $boxY + 5
    Tui-Put $left $barY2 'GERAL' 'dim' 'base'
    Draw-ProgressBar $valueX $barY2 $barW $globalPct 'purple' 'base'
    Tui-Put ($valueX + $barW + 2) $barY2 ("{0,3}%" -f $globalPct) 'fg' 'base'
    Tui-Put ($valueX + $barW + 7) $barY2 ("({0}/{1})" -f $View.GlobalDone, $View.GlobalTotal) 'dim' 'base'

    Draw-Separator 3 ($boxY + 7) ($script:TW - 6)

    Tui-Put $left ($boxY + 8) 'EM EXECUÇÃO' 'dim' 'base'
    $currentColor = if ($View.Mode -eq 'rollback') { 'red' } else { 'yellow' }
    Tui-Put $left ($boxY + 9) '›' 'accent' 'base'
    Tui-Put ($left + 2) ($boxY + 9) (Tui-Truncate $View.Current ($script:TW - 8)) $currentColor 'base'

    $logY = $boxY + 11
    $logCap = ($boxY + $boxH - 1) - $logY
    if ($logCap -gt 0) {
        Tui-Put $left $logY 'LOG' 'dim' 'base'
        $logs = $View.Logs.ToArray()
        $show = @()
        if ($logs.Count -gt $logCap) {
            $show = $logs[($logs.Count - $logCap)..($logs.Count - 1)]
        } else {
            $show = $logs
        }
        $y = $logY + 1
        foreach ($entry in $show) {
            if ($y -ge $boxY + $boxH - 1) { break }
            $tag = "[$($entry.Status)]"
            Tui-Put $left $y $tag (Get-LogColor $entry.Status) 'base'
            Tui-Put ($left + 11) $y (Tui-Truncate $entry.Text ($script:TW - 14)) 'muted' 'base'
            $y++
        }
    }

    Tui-PutCentered ($script:TH - 2) 'Pressione Ctrl+C para abortar (rollback automático quando aplicável)' 'dim'
    Tui-Render
}

function Add-ExecLog {
    param([hashtable]$View, [string]$Status, [string]$Text)
    [void]$View.Logs.Add(@{ Status = $Status; Text = $Text })
    if ($View.Logs.Count -gt 400) { $View.Logs.RemoveAt(0) }
}

function Invoke-DebloatExecution {
    $app = $script:App
    $selected = @(Get-SelectedItems)

    $globalTotal = 0
    foreach ($item in $selected) { $globalTotal += @($item.actions).Count }

    $view = @{
        Mode = 'run'
        Module = 'Iniciando'
        Step = 'Preparando execução'
        Current = 'Inicializando'
        ModuleDone = 0
        ModuleTotal = 0
        GlobalDone = 0
        GlobalTotal = $globalTotal
        Logs = New-Object System.Collections.ArrayList
    }

    $ok = 0
    $fail = 0
    $skipped = 0
    $globalDone = 0
    $aborted = $false
    $rolledBack = $false
    $rollbackData = $null
    $started = Get-Date

    Add-ExecLog $view 'INFO' ("{0} itens · {1} ações planejadas" -f $selected.Count, $globalTotal)

    $abortNow = $false
    foreach ($mod in $script:ModuleOrder) {
        if ($abortNow) { break }
        $modItems = @($selected | Where-Object { $_.module -eq $mod.Id })
        if ($modItems.Count -eq 0) { continue }

        $moduleTotal = 0
        foreach ($it in $modItems) { $moduleTotal += @($it.actions).Count }
        $moduleDone = 0

        $view.Module = $mod.Label
        foreach ($item in $modItems) {
            if ($abortNow) { break }
            $view.Step = "Item: $($item.title)"
            foreach ($action in $item.actions) {
                if ([Console]::KeyAvailable) {
                    $pk = [Console]::ReadKey($true)
                    if ($pk.Key -eq [ConsoleKey]::C -and (($pk.Modifiers -band [ConsoleModifiers]::Control) -ne 0)) {
                        Add-ExecLog $view 'WARN' 'Cancelado pelo usuário'
                        $aborted = $true
                        $abortNow = $true
                        break
                    }
                }
                if ($abortNow) { break }

                $view.Current = Get-ActionDescription $action
                $view.ModuleDone = $moduleDone
                $view.ModuleTotal = $moduleTotal
                $view.GlobalDone = $globalDone
                Draw-ExecutionFrame $view

                $r = Invoke-Action -Item $item -Action $action -TxMode ([bool]$app.TxMode)

                if ($r.Ok) {
                    $globalDone++
                    $moduleDone++
                    $msg = $r.Message
                    if ($msg -match 'ignorad|não encontrad|não instalad|já estava|já desativada') {
                        $skipped++
                        Add-ExecLog $view 'WARN' ("{0} — {1}" -f $item.title, $msg)
                    } else {
                        $ok++
                        Add-ExecLog $view 'OK' ("{0} — {1}" -f $item.title, $msg)
                    }
                } else {
                    $fail++
                    Add-ExecLog $view 'ERR' ("{0} — {1}" -f $item.title, $r.Message)
                    Write-Log ("FALHA em {0} / {1}: {2}" -f $item.id, $action.type, $r.Message) 'ERR'
                    if ($app.TxMode) {
                        $abortNow = $true
                        break
                    }
                }

                $view.ModuleDone = $moduleDone
                $view.GlobalDone = $globalDone
                Draw-ExecutionFrame $view
            }
        }
    }

    if ($abortNow -and $app.TxMode -and -not $rolledBack) {
        $view.Mode = 'rollback'
        $view.Module = 'ROLLBACK'
        $view.Step = 'Revertendo alterações aplicadas'
        $view.Current = 'Preparando reversão'
        $view.ModuleDone = 0
        $view.ModuleTotal = 1
        Draw-ExecutionFrame $view

        $rollbackData = Invoke-TransactionRollback -OnProgress {
            param($i, $total, $label)
            $view.ModuleDone = $i - 1
            $view.ModuleTotal = $total
            $view.Current = "Revertendo: $label"
            Draw-ExecutionFrame $view
        }

        Add-ExecLog $view 'ROLLBACK' ("revertidas: {0} · falhas: {1}" -f $rollbackData.Reverted, $rollbackData.Failed)
        $rolledBack = ($rollbackData.Failed -eq 0)
        if (-not $rolledBack) {
            Add-ExecLog $view 'ERR' 'rollback incompleto — use o ponto de restauração'
        }
        $view.Mode = 'run'
        $view.Module = 'Finalizado'
        $view.Step = 'Encerrando sessão'
        $view.Current = 'Concluído'
        Draw-ExecutionFrame $view
        Start-Sleep -Milliseconds 600
    } elseif ($app.TxMode -and -not $abortNow) {
        Set-TransactionStatus 'COMMITTED'
    } elseif ($app.TxMode -and $aborted) {
        $view.Mode = 'rollback'
        $view.Module = 'ROLLBACK'
        $view.Step = 'Cancelamento solicitado'
        $view.Current = 'Revertendo alterações aplicadas'
        $view.ModuleDone = 0
        $view.ModuleTotal = 1
        Draw-ExecutionFrame $view
        $rollbackData = Invoke-TransactionRollback -OnProgress {
            param($i, $total, $label)
            $view.ModuleDone = $i - 1
            $view.ModuleTotal = $total
            $view.Current = "Revertendo: $label"
            Draw-ExecutionFrame $view
        }
        Add-ExecLog $view 'ROLLBACK' ("revertidas: {0} · falhas: {1}" -f $rollbackData.Reverted, $rollbackData.Failed)
        $rolledBack = ($rollbackData.Failed -eq 0)
        $view.Mode = 'run'
    }

    $duration = (Get-Date) - $started
    return @{
        Ok = $ok
        Fail = $fail
        Skipped = $skipped
        RolledBack = $rolledBack
        RollbackData = $rollbackData
        Aborted = $aborted
        Duration = ('{0:hh\:mm\:ss}' -f $duration)
        Total = $globalTotal
    }
}
