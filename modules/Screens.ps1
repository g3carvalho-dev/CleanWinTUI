# CleanWinTUI - screens

function Initialize-Frame {
    param([string]$Right = '', [string]$Badge = '', [string]$BadgeColor = 'orange')
    $size = Get-TuiWindowSize
    if (($size.Width -ne $script:TW) -or ($size.Height -ne $script:TH)) {
        Tui-Reset
    }
    Tui-Fill 0 0 $script:TW $script:TH ' ' 'fg' 'base'
    Draw-TopBar -Right $Right -Badge $Badge -BadgeColor $BadgeColor
}

function Show-WelcomeScreen {
    $logo = @(
        ' ██████╗██╗     ███████╗ █████╗ ███╗   ██╗',
        '██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║',
        '██║     ██║     █████╗  ███████║██╔██╗ ██║',
        '██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║',
        '╚██████╗███████╗███████╗██║  ██║██║ ╚████║',
        ' ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝'
    )
    $gradient = @('cyan', 'cyan', 'accent', 'accent', 'purple', 'purple')

    while ($true) {
        Initialize-Frame -Right ("Windows 11 · build {0}" -f $script:App.Build)

        if ($script:TW -lt 60 -or $script:TH -lt 20) {
            Tui-PutCentered 3 'CleanWinTUI' 'accent'
            Tui-PutCentered 4 'Aumente a janela do terminal para a melhor experiência.' 'muted'
            Tui-PutCentered 6 'Enter para continuar' 'fg'
            Tui-Render
            $k = Tui-ReadKey
            if ($k.Key -eq 'enter') { return 'next' }
            if ($k.Key -in @('q', 'esc', 'ctrl-c')) { return 'quit' }
            continue
        }

        $logoWidth = 0
        foreach ($l in $logo) { if ($l.Length -gt $logoWidth) { $logoWidth = $l.Length } }
        $startY = [Math]::Max(2, [int](($script:TH - 20) / 2))
        $x = [int](($script:TW - $logoWidth) / 2)

        for ($i = 0; $i -lt $logo.Count; $i++) {
            Tui-Put $x ($startY + $i) $logo[$i] $gradient[$i] 'base'
        }

        Tui-PutCentered ($startY + 7) 'WINDOWS 11 · DEBLOAT CONTROLADO' 'muted'
        Tui-PutCentered ($startY + 8) ("build {0}  ·  {1}  ·  sessão {2}" -f $script:App.Build, 'PowerShell', $script:App.SessionId) 'dim'

        $boxW = [Math]::Min(72, $script:TW - 8)
        if ($boxW -lt 40) { $boxW = $script:TW - 4 }
        $boxX = [int](($script:TW - $boxW) / 2)
        $boxY = $startY + 10

        Tui-Box $boxX $boxY $boxW 3 'início' 'accent' 'base' 'accent'
        Tui-Put ($boxX + 2) ($boxY + 1) 'Pressione' 'muted' 'base'
        Tui-Put ($boxX + 12) ($boxY + 1) 'Enter' 'base' 'accent'
        Tui-Put ($boxX + 19) ($boxY + 1) 'para selecionar o que será removido' 'fg' 'base'

        $tipY = $boxY + 4
        if ($tipY + 2 -lt $script:TH - 2) {
            Tui-PutCentered $tipY '• nada é alterado sem a sua confirmação' 'muted'
            Tui-PutCentered ($tipY + 1) '• ponto de restauração e Restore-Plan sempre incluídos' 'muted'
        }

        if (-not $env:WT_SESSION) {
            Tui-PutCentered ($script:TH - 3) 'Dica: abra no Windows Terminal para o melhor visual' 'yellow'
        }

        Draw-Footer @(@('enter', 'iniciar'), @('q', 'sair'))
        Tui-Render

        $k = Tui-ReadKey
        if ($k.Key -eq 'enter') { return 'next' }
        if ($k.Key -in @('q', 'esc', 'ctrl-c')) { return 'quit' }
    }
}

function Show-GroupsIntro {
    while ($true) {
        Initialize-Frame -Right 'como funciona'
        Tui-PutCentered 2 'COMO AS AÇÕES SÃO ORGANIZADAS' 'fg'
        Tui-PutCentered 3 'Você escolhe item por item. Nada é obrigatório.' 'muted'

        $cardW = [Math]::Min(88, $script:TW - 10)
        $cardX = [int](($script:TW - $cardW) / 2)
        $cardH = 4
        $gap = 1
        $y = 5
        $room = $script:TH - 5 - 2
        if (($cardH + $gap) * 4 -gt $room) { $cardH = 3; $gap = 0 }

        foreach ($g in $script:App.GroupOrder) {
            $color = Get-GroupColor $g
            Tui-Box $cardX $y $cardW $cardH $g $color 'base' $color
            $line1 = Tui-Truncate (Get-GroupTagText $g) ($cardW - 4)
            Tui-Put ($cardX + 2) ($y + 1) $line1 'fg' 'base'
            if ($cardH -ge 4) {
                Tui-Put ($cardX + 2) ($y + 2) (Tui-Truncate $script:GroupBlurb[$g] ($cardW - 4)) 'muted' 'base'
            }
            $y += $cardH + $gap
            if ($y + $cardH -gt $script:TH - 3) { break }
        }

        Draw-Footer @(@('enter', 'continuar'), @('esc', 'voltar'))
        Tui-Render

        $k = Tui-ReadKey
        if ($k.Key -eq 'enter') { return 'next' }
        if ($k.Key -in @('esc', 'q', 'ctrl-c')) { return 'back' }
    }
}

function Get-GroupTagText {
    param([string]$Group)
    switch ($Group) {
        'SEGURO'   { return '● risco muito baixo · totalmente reversível' }
        'OPCIONAL' { return '● risco baixo · reversível' }
        'CUIDADO'  { return '● risco médio · transação automática' }
        'AVANÇADO' { return '● risco alto · confirmação obrigatória' }
    }
    return $Group
}

function Get-GroupBadge {
    param([string]$Group)
    return " $Group "
}

function Draw-ItemDetails {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [object]$Item)
    if ($W -lt 14 -or $H -lt 6) { return }
    if (-not $Item) {
        Tui-Put ($X + 2) ($Y + 1) 'Nenhum item disponível nesta categoria.' 'muted' 'base'
        return
    }

    $innerW = $W - 4
    $line = $Y + 1

    $titleLines = Tui-Wrap $Item.title $innerW
    foreach ($tl in $titleLines) {
        if ($line -ge $Y + $H - 2) { return }
        Tui-Put ($X + 2) $line $tl 'white' 'base'
        $line++
    }

    $color = Get-GroupColor $Item.group
    Tui-Put ($X + 2) $line (Get-GroupBadge $Item.group) 'base' $color
    $riskX = $X + 2 + $Item.group.Length + 2
    $maxRisk = ($X + $W - 2) - $riskX
    if ($maxRisk -gt 0) {
        Tui-Put $riskX $line (Tui-Truncate ('· ' + $script:GroupRisks[$Item.group]) $maxRisk) 'muted' 'base'
    }
    $line++

    $rev = if ($Item.reversible -eq 'yes') { 'reversível: sim' } else { 'reversível: parcial' }
    Tui-Put ($X + 2) $line $rev 'muted' 'base'
    $line += 2

    if ($line -lt $Y + $H - 2) {
        Draw-Separator ($X + 2) $line ($W - 4)
        $line++
    }

    foreach ($dl in (Tui-Wrap $Item.description $innerW)) {
        if ($line -ge $Y + $H - 2) { return }
        Tui-Put ($X + 2) $line $dl 'fg' 'base'
        $line++
    }

    if ($Item.notes -and $Item.notes.Count -gt 0 -and $line -lt $Y + $H - 4) {
        $line++
        if ($line -lt $Y + $H - 2) {
            Tui-Put ($X + 2) $line 'notas' 'dim' 'base'
            $line++
        }
        foreach ($note in $Item.notes) {
            foreach ($nl in (Tui-Wrap ('· ' + $note) $innerW)) {
                if ($line -ge $Y + $H - 2) { return }
                Tui-Put ($X + 2) $line $nl 'muted' 'base'
                $line++
            }
        }
    }

    if ($line -lt $Y + $H - 3) {
        $line++
        if ($line -lt $Y + $H - 2) {
            Tui-Put ($X + 2) $line ("ações planejadas ({0})" -f @($Item.actions).Count) 'dim' 'base'
            $line++
        }
        foreach ($action in $Item.actions) {
            if ($line -ge $Y + $H - 2) { return }
            $text = Tui-Truncate ('· ' + (Get-ActionDescription $action)) $innerW
            Tui-Put ($X + 2) $line $text 'muted' 'base'
            $line++
        }
    }
}

function Show-SelectionScreen {
    $app = $script:App
    $app.StatusMessage = ''

    while ($true) {
        Initialize-Frame -Right ("build {0} · sessão {1}" -f $app.Build, $app.SessionId)
        Tui-Put 2 1 ' SELEÇÃO DE ITENS ' 'fg' 'base'
        Tui-PutRight ($script:TW - 2) 1 ("{0} itens selecionados · {1} ações" -f (Get-SelectedCount), (Get-TotalActionCount)) 'dim' 'base'

        $tabX = 2
        for ($gi = 0; $gi -lt $app.GroupOrder.Count; $gi++) {
            $g = $app.GroupOrder[$gi]
            $gItems = @(Get-GroupItems $g)
            $gSel = Get-SelectedCount $g
            $label = " $g $gSel/$($gItems.Count) "
            $active = ($gi -eq $app.GroupIndex)
            if ($active) {
                Tui-Put $tabX 2 $label 'base' (Get-GroupColor $g)
            } else {
                Tui-Put $tabX 2 $label (Get-GroupColor $g) 'panel'
            }
            $tabX += $label.Length + 1
        }

        $panelY = 3
        $panelH = $script:TH - 5
        $leftW = [int]($script:TW * 0.4)
        if ($leftW -lt 34) { $leftW = 34 }
        if ($leftW -gt 56) { $leftW = 56 }
        $rightX = $leftW + 2
        $rightW = $script:TW - $rightX - 1
        if ($rightW -lt 30) {
            $leftW = 30
            $rightX = $leftW + 2
            $rightW = $script:TW - $rightX - 1
        }

        $group = $app.GroupOrder[$app.GroupIndex]
        $items = @(Get-GroupItems $group)
        $cursor = $app.Cursor[$group]
        if ($items.Count -eq 0) { $cursor = 0 }
        elseif ($cursor -ge $items.Count) { $cursor = $items.Count - 1 }
        $app.Cursor[$group] = $cursor

        Tui-Box 1 $panelY $leftW $panelH ("ITENS · $group") 'line' 'base' 'accent'
        Tui-Box $rightX $panelY $rightW $panelH 'DETALHES' 'line' 'base' 'accent'

        $innerX = 2
        $listTop = $panelY + 2
        $listCap = $panelH - 3
        $scroll = $app.Scroll[$group]
        if ($cursor -lt $scroll) { $scroll = $cursor }
        if ($cursor -ge $scroll + $listCap) { $scroll = $cursor - $listCap + 1 }
        if ($scroll -lt 0) { $scroll = 0 }
        $app.Scroll[$group] = $scroll

        Tui-Put ($innerX + 1) ($panelY + 1) ("{0} de {1} selecionados" -f (Get-SelectedCount $group), $items.Count) 'dim' 'base'

        if ($items.Count -eq 0) {
            Tui-Put ($innerX + 1) ($listTop + 1) 'Nada aqui para esta build do Windows.' 'muted' 'base'
        } else {
            for ($row = 0; $row -lt $listCap; $row++) {
                $idx = $scroll + $row
                if ($idx -ge $items.Count) { break }
                $item = $items[$idx]
                $y = $listTop + $row
                $selected = $app.Selected.Contains($item.id)
                $isCursor = ($idx -eq $cursor)

                $bg = 'base'
                if ($isCursor) { $bg = 'panel2'; Tui-Fill ($innerX) $y ($leftW - 2) 1 ' ' 'fg' $bg }

                $mark = ' '
                if ($isCursor) { $mark = '›' }
                Tui-Put $innerX $y $mark 'accent' $bg

                $box = '[ ]'
                $boxColor = 'dim'
                if ($selected) { $box = '[x]'; $boxColor = 'green' }
                Tui-Put ($innerX + 2) $y $box $boxColor $bg

                $titleW = $leftW - 9
                $title = Tui-Truncate $item.title $titleW
                $titleColor = 'fg'
                if ($isCursor) { $titleColor = 'white' }
                Tui-Put ($innerX + 6) $y $title $titleColor $bg
            }
        }

        $detailItem = $null
        if ($items.Count -gt 0) { $detailItem = $items[$cursor] }
        Draw-ItemDetails -X $rightX -Y $panelY -W $rightW -H $panelH -Item $detailItem

        if ($app.StatusMessage) {
            Tui-PutCentered ($script:TH - 2) $app.StatusMessage 'yellow'
        }

        Draw-Footer @(
            @('space', 'marcar'),
            @('tab', 'grupo'),
            @('a', 'todos'),
            @('n', 'limpar'),
            @('d', 'padrão'),
            @('enter', 'revisar'),
            @('q', 'sair')
        )
        Tui-Render

        $key = Tui-ReadKey
        $group = $app.GroupOrder[$app.GroupIndex]
        $items = @(Get-GroupItems $group)
        $cursor = $app.Cursor[$group]

        switch ($key.Key) {
            'up'      { if ($cursor -gt 0) { $app.Cursor[$group] = $cursor - 1 }; $app.StatusMessage = '' }
            'down'    { if ($cursor -lt $items.Count - 1) { $app.Cursor[$group] = $cursor + 1 }; $app.StatusMessage = '' }
            'pgup'    { $app.Cursor[$group] = [Math]::Max(0, $cursor - 8); $app.StatusMessage = '' }
            'pgdown'  { $app.Cursor[$group] = [Math]::Min([Math]::Max(0, $items.Count - 1), $cursor + 8); $app.StatusMessage = '' }
            'home'    { $app.Cursor[$group] = 0; $app.StatusMessage = '' }
            'end'     { $app.Cursor[$group] = [Math]::Max(0, $items.Count - 1); $app.StatusMessage = '' }
            'left'    { $app.GroupIndex = ($app.GroupIndex - 1 + 4) % 4; $app.StatusMessage = '' }
            'right'   { $app.GroupIndex = ($app.GroupIndex + 1) % 4; $app.StatusMessage = '' }
            'tab'     { $app.GroupIndex = ($app.GroupIndex + 1) % 4; $app.StatusMessage = '' }
            'space'   {
                if ($items.Count -gt 0) {
                    $item = $items[$cursor]
                    if ($app.Selected.Contains($item.id)) {
                        [void]$app.Selected.Remove($item.id)
                        $app.StatusMessage = "Removido da seleção: $($item.title)"
                    } else {
                        [void]$app.Selected.Add($item.id)
                        $app.StatusMessage = "Selecionado: $($item.title)"
                    }
                }
            }
            'a'       {
                foreach ($item in $items) { [void]$app.Selected.Add($item.id) }
                $app.StatusMessage = "Todos os itens de $group foram marcados"
            }
            'n'       {
                foreach ($item in $items) { [void]$app.Selected.Remove($item.id) }
                $app.StatusMessage = "Itens de $group foram desmarcados"
            }
            'd'       {
                foreach ($id in $app.Defaults) {
                    $match = $items | Where-Object { $_.id -eq $id } | Select-Object -First 1
                    if ($match) { [void]$app.Selected.Add($id) }
                }
                $app.StatusMessage = 'Sugestões seguras aplicadas'
            }
            'enter'   {
                if ((Get-SelectedCount) -eq 0) {
                    $app.StatusMessage = 'Selecione ao menos um item para continuar'
                } else {
                    return 'next'
                }
            }
            { $_ -in @('q', 'esc', 'ctrl-c') } { return 'quit' }
        }
    }
}

function Show-ReviewScreen {
    $app = $script:App
    $selected = @(Get-SelectedItems)
    $scroll = 0

    while ($true) {
        Initialize-Frame -Right 'revisão'
        Tui-Put 2 1 ' REVISÃO DA SELEÇÃO ' 'fg' 'base'
        Tui-PutRight ($script:TW - 2) 1 ("{0} itens · {1} ações" -f $selected.Count, (Get-TotalActionCount)) 'dim' 'base'

        $panelY = 3
        $panelH = 6
        $panelW = [Math]::Min(100, $script:TW - 6)
        $panelX = [int](($script:TW - $panelW) / 2)
        Tui-Box $panelX $panelY $panelW $panelH 'RESUMO' 'line' 'base' 'accent'

        $x = $panelX + 2
        foreach ($g in $app.GroupOrder) {
            $count = Get-SelectedCount $g
            $label = ("{0} {1}" -f $g, $count)
            Tui-Put $x ($panelY + 1) $label 'base' (Get-GroupColor $g)
            $x += $label.Length + 3
        }
        Tui-Put ($panelX + 2) ($panelY + 3) (Tui-Truncate ("Ponto de restauração: {0}" -f $(if (Test-HasCriticalSelection) { 'obrigatório' } else { 'recomendado, será tentado' })) ($panelW - 4)) 'muted' 'base'
        Tui-Put ($panelX + 2) ($panelY + 4) (Tui-Truncate ("Modo transação: {0}" -f $(if (Test-HasCriticalSelection) { 'ATIVO · rollback automático em caso de erro' } else { 'não necessário' })) ($panelW - 4)) 'muted' 'base'

        $listY = $panelY + $panelH + 1
        $listH = $script:TH - $listY - 2
        if ($listH -lt 3) { $listH = 3 }
        Tui-Box 1 $listY ($script:TW - 2) $listH 'ITENS SELECIONADOS' 'line' 'base' 'accent'

        $cap = $listH - 2
        if ($scroll -gt [Math]::Max(0, $selected.Count - $cap)) { $scroll = [Math]::Max(0, $selected.Count - $cap) }
        if ($selected.Count -eq 0) {
            Tui-Put 3 ($listY + 1) 'Nenhum item selecionado.' 'muted' 'base'
        } else {
            for ($i = 0; $i -lt $cap; $i++) {
                $idx = $scroll + $i
                if ($idx -ge $selected.Count) { break }
                $item = $selected[$idx]
                $y = $listY + 1 + $i
                Tui-Put 3 $y ([char]0x2022).ToString() (Get-GroupColor $item.group) 'base'
                $tagX = [Math]::Max(26, $script:TW - 34)
                Tui-Put 5 $y (Tui-Truncate $item.title ([Math]::Max(20, $tagX - 7))) 'fg' 'base'
                Tui-Put $tagX $y (Get-GroupBadge $item.group) 'base' (Get-GroupColor $item.group)
                Tui-Put ($tagX + 14) $y ("{0} ação(ões)" -f @($item.actions).Count) 'dim' 'base'
            }
        }

        if (Test-HasCriticalSelection) {
            [void](Tui-PutWrappedCentered ($script:TH - 3) ($script:TW - 8) 'Itens de risco médio/alto exigem confirmação digitada na próxima etapa' 'yellow')
        } else {
            [void](Tui-PutWrappedCentered ($script:TH - 3) ($script:TW - 8) 'Você poderá revisar a simulação antes de executar' 'dim')
        }

        Draw-Footer @(
            @('enter', 'continuar'),
            @('setas', 'rolar'),
            @('esc', 'voltar')
        )
        Tui-Render

        $k = Tui-ReadKey
        switch ($k.Key) {
            'up'    { if ($scroll -gt 0) { $scroll-- } }
            'down'  { if ($scroll -lt [Math]::Max(0, $selected.Count - $cap)) { $scroll++ } }
            'pgup'  { $scroll = [Math]::Max(0, $scroll - 8) }
            'pgdown'{ $scroll = [Math]::Min([Math]::Max(0, $selected.Count - $cap), $scroll + 8) }
            'enter' { return 'next' }
            { $_ -in @('esc', 'backspace') } { return 'back' }
            { $_ -in @('q', 'ctrl-c') } { return 'quit' }
        }
    }
}

function Get-PlannedLines {
    $lines = New-Object System.Collections.Generic.List[object]
    foreach ($mod in $script:ModuleOrder) {
        $items = @(Get-SelectedItems | Where-Object { $_.module -eq $mod.Id })
        if ($items.Count -eq 0) { continue }
        $lines.Add(@{ Text = ("▸ {0}" -f $mod.Label); Fg = 'accent' })
        foreach ($item in $items) {
            $lines.Add(@{ Text = ("  • {0}" -f $item.title); Fg = 'fg' })
            foreach ($action in $item.actions) {
                $lines.Add(@{ Text = ("      · {0}" -f (Get-ActionDescription $action)); Fg = 'muted' })
            }
        }
        $lines.Add(@{ Text = ''; Fg = 'dim' })
    }
    return $lines.ToArray()
}

function Show-DryRunScreen {
    $lines = @(Get-PlannedLines)
    $scroll = 0

    while ($true) {
        Initialize-Frame -Right 'simulação'
        Tui-Put 2 1 ' PLANO DE EXECUÇÃO · SIMULAÇÃO ' 'fg' 'base'
        Tui-PutRight ($script:TW - 2) 1 'nada foi alterado' 'yellow'

        $boxY = 3
        $boxH = $script:TH - 5
        Tui-Box 1 $boxY ($script:TW - 2) $boxH 'OPERAÇÕES QUE SERÃO EXECUTADAS' 'line' 'base' 'accent'

        $cap = $boxH - 2
        for ($i = 0; $i -lt $cap; $i++) {
            $idx = $scroll + $i
            if ($idx -ge $lines.Count) { break }
            $entry = $lines[$idx]
            Tui-Put 3 ($boxY + 1 + $i) (Tui-Truncate $entry.Text ($script:TW - 6)) $entry.Fg 'base'
        }

        if ($lines.Count -gt $cap) {
            Tui-PutRight ($script:TW - 3) ($boxY + $boxH - 1) (" {0}/{1} " -f [Math]::Min($scroll + $cap, $lines.Count), $lines.Count) 'base' 'panel2'
        }

        Draw-Footer @(
            @('enter', 'executar'),
            @('setas', 'rolar'),
            @('esc', 'voltar')
        )
        Tui-Render

        $k = Tui-ReadKey
        switch ($k.Key) {
            'up'     { if ($scroll -gt 0) { $scroll-- } }
            'down'   { if ($scroll -lt [Math]::Max(0, $lines.Count - $cap)) { $scroll++ } }
            'pgup'   { $scroll = [Math]::Max(0, $scroll - 10) }
            'pgdown' { $scroll = [Math]::Min([Math]::Max(0, $lines.Count - $cap), $scroll + 10) }
            'enter'  { return 'next' }
            'esc'    { return 'back' }
            { $_ -in @('q', 'ctrl-c') } { return 'quit' }
        }
    }
}

function Show-ConfirmScreen {
    $critical = Test-HasCriticalSelection

    while ($true) {
        Initialize-Frame -Right 'confirmação' -Badge 'TRANSACAO' -BadgeColor 'orange'
        Tui-PutCentered 3 'CONFIRMAÇÃO FINAL' 'fg'
        Tui-PutCentered 4 ("{0} itens · {1} ações planejadas" -f (Get-SelectedItems).Count, (Get-TotalActionCount)) 'muted'

        $boxW = [Math]::Min(84, $script:TW - 8)
        $boxX = [int](($script:TW - $boxW) / 2)
        $boxY = 6
        $inner = $boxW - 4

        if ($critical) {
            $texts = @(
                'A seleção inclui itens de risco médio ou alto.',
                'O modo transação será ativado antes da primeira alteração.',
                'Se qualquer ação falhar, o CleanWinTUI tentará reverter tudo na ordem inversa.',
                'O ponto de restauração permanece como último recurso garantido.'
            )
            $wrapped = @()
            foreach ($t in $texts) { $wrapped += (Tui-Wrap $t $inner) }
            $boxH = $wrapped.Count + 2
            Tui-Box $boxX $boxY $boxW $boxH 'ATENÇÃO' 'red' 'base' 'red'
            $y = $boxY + 1
            foreach ($t in $wrapped) {
                Tui-Put ($boxX + 2) $y $t 'fg' 'base'
                $y++
            }
        } else {
            $wrapped = @()
            $wrapped += (Tui-Wrap 'Somente itens de baixo risco selecionados.' $inner)
            $wrapped += (Tui-Wrap 'Ponto de restauração será tentado antes de qualquer alteração.' $inner)
            $boxH = $wrapped.Count + 2
            Tui-Box $boxX $boxY $boxW $boxH 'PRONTO PARA EXECUTAR' 'green' 'base' 'green'
            $y = $boxY + 1
            foreach ($t in $wrapped) {
                Tui-Put ($boxX + 2) $y $t 'fg' 'base'
                $y++
            }
        }

        $promptY = $boxY + $boxH + 2
        if ($critical) {
            Tui-PutCentered $promptY 'Digite CONFIRMO para iniciar a execução' 'yellow'
            Draw-Footer @(@('enter', 'enviar'), @('esc', 'voltar'))
            Tui-Render
            $answer = Tui-InputLine 2 ($promptY + 1) ($script:TW - 4) '> '
            if ($null -eq $answer) { return 'back' }
            if ($answer.Trim().ToUpper() -eq 'CONFIRMO') { return 'next' }
            continue
        }

        Tui-PutCentered $promptY 'Pressione Enter para iniciar' 'green'
        Tui-PutCentered ($promptY + 1) 'Esc para voltar à revisão' 'dim'
        Draw-Footer @(@('enter', 'iniciar'), @('esc', 'voltar'))
        Tui-Render

        $k = Tui-ReadKey
        if ($k.Key -eq 'enter') { return 'next' }
        if ($k.Key -eq 'esc') { return 'back' }
        if ($k.Key -in @('q', 'ctrl-c')) { return 'quit' }
    }
}

function Show-PreflightScreen {
    $critical = Test-HasCriticalSelection

    $steps = New-Object System.Collections.Generic.List[object]
    $steps.Add(@{ Label = 'Ponto de restauração'; State = 'pending'; Detail = '' })
    $steps.Add(@{ Label = 'Backup de chaves de registro'; State = 'pending'; Detail = '' })
    $steps.Add(@{ Label = 'Snapshot de aplicativos'; State = 'pending'; Detail = '' })
    $steps.Add(@{ Label = 'Backup de tarefas agendadas'; State = 'pending'; Detail = '' })
    $steps.Add(@{ Label = 'Manifesto da sessão'; State = 'pending'; Detail = '' })
    $steps.Add(@{ Label = 'Modo transação'; State = 'pending'; Detail = '' })

    $draw = {
        Initialize-Frame -Right 'preparação' -Badge $(if ($critical) { 'TRANSACAO' } else { '' }) -BadgeColor 'orange'
        $boxW = [Math]::Min(96, $script:TW - 8)
        $boxX = [int](($script:TW - $boxW) / 2)
        $boxY = 3
        $boxH = 13
        Tui-PutCentered 2 'PREPARAÇÃO DE SEGURANÇA' 'fg'
        Tui-Box $boxX $boxY $boxW $boxH 'ETAPAS' 'line' 'base' 'accent'
        $y = $boxY + 1
        foreach ($s in $steps) {
            $sym = [char]0x25CB
            $color = 'dim'
            if ($s.State -eq 'running') { $sym = [char]0x25D4; $color = 'yellow' }
            if ($s.State -eq 'ok') { $sym = [char]0x2713; $color = 'green' }
            if ($s.State -eq 'warn') { $sym = '!'; $color = 'yellow' }
            if ($s.State -eq 'fail') { $sym = [char]0x2717; $color = 'red' }
            Tui-Put ($boxX + 2) $y ([string]$sym) $color 'base'
            Tui-Put ($boxX + 4) $y (Tui-Truncate $s.Label 20) 'fg' 'base'
            Tui-Put ($boxX + 26) $y (Tui-Truncate $s.Detail ($boxW - 28)) 'muted' 'base'
            $y++
        }
        [void](Tui-PutWrappedCentered ($script:TH - 3) ($script:TW - 8) 'Se algo falhar, a execução pode ser bloqueada conforme o risco da seleção' 'dim')
        Tui-Render
    }

    & $draw

    $steps[0].State = 'running'
    & $draw
    $restore = New-RestorePointSafe -Description ("CleanWinTUI - pré-debloat " + $script:App.SessionId)
    $script:App.RestorePoint = $restore
    if ($restore.Success) {
        $steps[0].State = 'ok'
        $steps[0].Detail = $restore.Message
    } else {
        $steps[0].State = 'fail'
        $steps[0].Detail = $restore.Message
    }
    & $draw

    if (-not $restore.Success) {
        if ($critical) {
            while ($true) {
                Initialize-Frame -Right 'preparação' -Badge 'BLOQUEADO' -BadgeColor 'red'
                Tui-PutCentered 2 'EXECUÇÃO BLOQUEADA' 'red'
                $w2 = [Math]::Min(88, $script:TW - 8)
                $inner = $w2 - 4
                $msgs = New-Object System.Collections.Generic.List[object]
                foreach ($ln in (Tui-Wrap 'Itens de risco médio/alto exigem um ponto de restauração.' $inner)) { $msgs.Add(@{ Text = $ln; Fg = 'fg' }) }
                $msgs.Add(@{ Text = ''; Fg = 'muted' })
                foreach ($ln in (Tui-Wrap ('Detalhe: ' + $restore.Message) $inner)) { $msgs.Add(@{ Text = $ln; Fg = 'muted' }) }
                $msgs.Add(@{ Text = ''; Fg = 'muted' })
                $msgs.Add(@{ Text = 'Como resolver:'; Fg = 'yellow' })
                foreach ($step in @('1. Abra sysdm.cpl > Proteção do Sistema', '2. Selecione o disco do sistema e clique em Configurar', '3. Ative a proteção e volte para tentar novamente')) {
                    foreach ($ln in (Tui-Wrap $step $inner)) { $msgs.Add(@{ Text = $ln; Fg = 'muted' }) }
                }
                $boxH = $msgs.Count + 2
                if ($boxH -gt $script:TH - 5) { $boxH = $script:TH - 5 }
                $x2 = [int](($script:TW - $w2) / 2)
                $boxY = 4
                Tui-Box $x2 $boxY $w2 $boxH 'PONTO DE RESTAURAÇÃO NÃO CRIADO' 'red' 'base' 'red'
                $y = $boxY + 1
                foreach ($m in $msgs) {
                    if ($y -ge $boxY + $boxH - 1) { break }
                    Tui-Put ($x2 + 2) $y $m.Text $m.Fg 'base'
                    $y++
                }
                Draw-Footer @(@('r', 'tentar de novo'), @('esc', 'abortar'))
                Tui-Render
                $k = Tui-ReadKey
                if ($k.Key -eq 'r') {
                    $restore = New-RestorePointSafe -Description ("CleanWinTUI - pré-debloat " + $script:App.SessionId)
                    $script:App.RestorePoint = $restore
                    if ($restore.Success) { break }
                } elseif ($k.Key -in @('esc', 'q', 'ctrl-c')) {
                    return 'back'
                }
            }
        } else {
            while ($true) {
                Initialize-Frame -Right 'preparação' -Badge 'SEM PONTO' -BadgeColor 'yellow'
                Tui-PutCentered 3 'PONTO DE RESTAURAÇÃO NÃO CRIADO' 'yellow'
                $textW = $script:TW - 8
                $y = 5
                $y = Tui-PutWrappedCentered $y $textW 'A seleção contém apenas itens de baixo risco.' 'fg'
                $y = Tui-PutWrappedCentered $y $textW ('Detalhe: ' + $restore.Message) 'muted'
                $y++
                $y = Tui-PutWrappedCentered $y $textW 'Você pode continuar, mas o Restore-Plan será sua principal rede de segurança.' 'muted'
                Draw-Footer @(@('c', 'continuar assim'), @('r', 'tentar de novo'), @('esc', 'abortar'))
                Tui-Render
                $k = Tui-ReadKey
                if ($k.Key -eq 'c') { break }
                if ($k.Key -eq 'r') {
                    $restore = New-RestorePointSafe -Description ("CleanWinTUI - pré-debloat " + $script:App.SessionId)
                    $script:App.RestorePoint = $restore
                    if ($restore.Success) { break }
                }
                if ($k.Key -in @('esc', 'q', 'ctrl-c')) { return 'back' }
            }
        }
    }

    if ($restore.Success) {
        $steps[0].State = 'ok'
        $steps[0].Detail = $restore.Message
    }

    $selected = @(Get-SelectedItems)
    $taskItems = @($selected | Where-Object { $_.actions | Where-Object { $_.type -eq 'task_disable' } })

    $steps[1].State = 'running'
    & $draw
    try {
        $n = Backup-RegistryKeys -Items $selected
        $steps[1].State = 'ok'
        $steps[1].Detail = "$n chave(s) exportada(s)"
    } catch {
        $steps[1].State = 'warn'
        $steps[1].Detail = $_.Exception.Message
    }
    & $draw

    $steps[2].State = 'running'
    & $draw
    try {
        $n = Backup-AppxSnapshot
        $steps[2].State = 'ok'
        $steps[2].Detail = "$n pacote(s) listado(s)"
    } catch {
        $steps[2].State = 'warn'
        $steps[2].Detail = $_.Exception.Message
    }
    & $draw

    $steps[3].State = 'running'
    & $draw
    try {
        if ($taskItems.Count -gt 0) {
            $n = Backup-TaskDefinitions -Items $taskItems
            $steps[3].State = 'ok'
            $steps[3].Detail = "$n definição(ões)"
        } else {
            $steps[3].State = 'ok'
            $steps[3].Detail = 'nenhuma tarefa na seleção'
        }
    } catch {
        $steps[3].State = 'warn'
        $steps[3].Detail = $_.Exception.Message
    }
    & $draw

    $steps[4].State = 'running'
    & $draw
    try {
        Write-ExecutionManifest -Items $selected
        $steps[4].State = 'ok'
        $steps[4].Detail = 'manifesto gravado'
    } catch {
        $steps[4].State = 'warn'
        $steps[4].Detail = $_.Exception.Message
    }
    & $draw

    $steps[5].State = 'running'
    & $draw
    if ($critical) {
        Start-Transaction
        $script:App.TxMode = $true
        $steps[5].State = 'ok'
        $steps[5].Detail = "ativa · $($script:Tx.Id.Substring(0,8))"
    } else {
        $script:App.TxMode = $false
        $steps[5].State = 'ok'
        $steps[5].Detail = 'não necessária'
    }
    & $draw
    Start-Sleep -Milliseconds 350

    while ($true) {
        & $draw
        Draw-Footer @(@('enter', 'executar'), @('esc', 'voltar'))
        Tui-Render
        $k = Tui-ReadKey
        if ($k.Key -eq 'enter') { return 'next' }
        if ($k.Key -in @('esc', 'q', 'ctrl-c')) { return 'back' }
    }
}

function Show-ReportScreen {
    param([hashtable]$Summary)

    while ($true) {
        Initialize-Frame -Right 'relatório'
        Tui-PutCentered 2 'EXECUÇÃO CONCLUÍDA' 'green'

        $boxW = [Math]::Min(92, $script:TW - 8)
        $boxX = [int](($script:TW - $boxW) / 2)
        $boxY = 4
        Tui-Box $boxX $boxY $boxW 11 'RESUMO' 'line' 'base' 'accent'

        $ok = $Summary.Ok
        $fail = $Summary.Fail
        $skipped = $Summary.Skipped
        $status = if ($Summary.RolledBack) { 'REVERTIDO' } elseif ($fail -gt 0) { 'CONCLUÍDO COM FALHAS' } else { 'CONCLUÍDO' }
        $statusColor = if ($Summary.RolledBack) { 'yellow' } elseif ($fail -gt 0) { 'red' } else { 'green' }

        Tui-Put ($boxX + 2) ($boxY + 1) 'Status' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 1) $status $statusColor 'base'
        Tui-Put ($boxX + 2) ($boxY + 2) 'Ações aplicadas' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 2) ([string]$ok) 'green' 'base'
        Tui-Put ($boxX + 2) ($boxY + 3) 'Falhas' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 3) ([string]$fail) $(if ($fail -gt 0) { 'red' } else { 'fg' }) 'base'
        Tui-Put ($boxX + 2) ($boxY + 4) 'Ignoradas' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 4) ([string]$skipped) 'yellow' 'base'
        Tui-Put ($boxX + 2) ($boxY + 5) 'Duração' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 5) $Summary.Duration 'fg' 'base'

        Draw-Separator ($boxX + 2) ($boxY + 6) ($boxW - 4)

        Tui-Put ($boxX + 2) ($boxY + 7) 'Log da sessão' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 7) (Tui-Truncate $script:App.SessionPath ($boxW - 21)) 'fg' 'base'
        Tui-Put ($boxX + 2) ($boxY + 8) 'Restore-Plan' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 8) (Tui-Truncate (Join-Path $script:App.SessionPath 'Restore-Plan.ps1') ($boxW - 21)) 'fg' 'base'
        Tui-Put ($boxX + 2) ($boxY + 9) 'Backups' 'muted' 'base'
        Tui-Put ($boxX + 18) ($boxY + 9) (Tui-Truncate (Join-Path $script:App.SessionPath 'backup') ($boxW - 21)) 'fg' 'base'

        $textW = $script:TW - 8
        if ($Summary.RolledBack) {
            $ty = Tui-PutWrappedCentered ($boxY + 13) $textW 'As alterações foram revertidas automaticamente.' 'yellow'
            [void](Tui-PutWrappedCentered $ty $textW 'Se algo ainda parecer alterado, use o ponto de restauração (rstrui.exe).' 'muted')
        } elseif ($fail -gt 0) {
            [void](Tui-PutWrappedCentered ($boxY + 13) $textW 'Algumas ações falharam. Consulte o log e o Restore-Plan.' 'red')
        } else {
            [void](Tui-PutWrappedCentered ($boxY + 13) $textW 'Reinicie o Explorador ou o sistema para aplicar todos os ajustes de interface.' 'muted')
        }

        Draw-Footer @(@('enter', 'sair'))
        Tui-Render

        $k = Tui-ReadKey
        if ($k.Key -in @('enter', 'esc', 'q', 'ctrl-c')) { return }
    }
}

