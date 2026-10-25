# CleanWinTUI - application state and catalog loading

function New-AppState {
    param([string]$Root)

    $configDir = Join-Path $Root 'config'
    $catalog = Get-Content -Raw -Encoding UTF8 (Join-Path $configDir 'catalog.json') | ConvertFrom-Json
    $defaults = Get-Content -Raw -Encoding UTF8 (Join-Path $configDir 'defaults.json') | ConvertFrom-Json
    $whitelist = Get-Content -Raw -Encoding UTF8 (Join-Path $configDir 'whitelist.json') | ConvertFrom-Json

    $build = Get-WindowsBuild
    $items = @($catalog.items | Where-Object { [int]$_.winverMin -le $build })

    $sessionId = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $logsRoot = Join-Path $env:LOCALAPPDATA 'CleanWinTUI\logs'
    $sessionPath = Join-Path $logsRoot $sessionId
    New-Item -ItemType Directory -Path $sessionPath -Force | Out-Null
    foreach ($sub in @('backup', 'backup\registry', 'backup\tasks', 'quarantine')) {
        New-Item -ItemType Directory -Path (Join-Path $sessionPath $sub) -Force | Out-Null
    }

    $selected = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($id in $defaults.defaults) {
        $match = $items | Where-Object { $_.id -eq $id } | Select-Object -First 1
        if ($match) { [void]$selected.Add($id) }
    }

    return @{
        Root = $Root
        ConfigDir = $configDir
        Build = $build
        SessionId = $sessionId
        SessionPath = $sessionPath
        Items = $items
        Catalog = $catalog
        Defaults = @($defaults.defaults)
        Whitelist = $whitelist
        GroupOrder = @('SEGURO', 'OPCIONAL', 'CUIDADO', 'AVANÇADO')
        GroupIndex = 0
        Cursor = @{ 'SEGURO' = 0; 'OPCIONAL' = 0; 'CUIDADO' = 0; 'AVANÇADO' = 0 }
        Scroll = @{ 'SEGURO' = 0; 'OPCIONAL' = 0; 'CUIDADO' = 0; 'AVANÇADO' = 0 }
        Selected = $selected
        StatusMessage = ''
        TxMode = $false
        RestorePoint = $null
        Outcomes = New-Object System.Collections.Generic.List[object]
        StartedAt = Get-Date
        DryRunOnly = $false
    }
}

function Get-GroupItems {
    param([string]$Group)
    return @($script:App.Items | Where-Object { $_.group -eq $Group })
}

function Get-SelectedItems {
    $chosen = New-Object System.Collections.Generic.List[object]
    foreach ($group in $script:App.GroupOrder) {
        foreach ($item in (Get-GroupItems $group)) {
            if ($script:App.Selected.Contains($item.id)) { $chosen.Add($item) }
        }
    }
    return $chosen.ToArray()
}

function Get-SelectedCount {
    param([string]$Group = $null)
    $n = 0
    foreach ($item in $script:App.Items) {
        if (-not $script:App.Selected.Contains($item.id)) { continue }
        if ($Group -and $item.group -ne $Group) { continue }
        $n++
    }
    return $n
}

function Get-TotalActionCount {
    $n = 0
    foreach ($item in (Get-SelectedItems)) {
        $n += @($item.actions).Count
    }
    return $n
}

function Test-HasCriticalSelection {
    foreach ($item in (Get-SelectedItems)) {
        if ($item.group -eq 'CUIDADO' -or $item.group -eq 'AVANÇADO') { return $true }
    }
    return $false
}
