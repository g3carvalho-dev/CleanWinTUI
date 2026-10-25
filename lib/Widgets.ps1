# CleanWinTUI - reusable widgets

$script:GroupColors = @{
    'SEGURO'   = 'green'
    'OPCIONAL' = 'cyan'
    'CUIDADO'  = 'yellow'
    'AVANÇADO' = 'red'
}

$script:GroupRisks = @{
    'SEGURO'   = 'risco muito baixo'
    'OPCIONAL' = 'risco baixo'
    'CUIDADO'  = 'risco médio'
    'AVANÇADO' = 'risco alto'
}

$script:GroupBlurb = @{
    'SEGURO'   = 'Itens redundantes, sugestões e anúncios. Podem ser reativados depois.'
    'OPCIONAL' = 'Ajustes de interface e conveniência. Reversíveis pelas configurações.'
    'CUIDADO'  = 'Afeta cenários específicos. Ponto de restauração passa a ser obrigatório.'
    'AVANÇADO' = 'Mudanças profundas. Exige confirmação digitada e entra em modo transação.'
}

function Get-GroupColor {
    param([string]$Group)
    if ($script:GroupColors.ContainsKey($Group)) { return $script:GroupColors[$Group] }
    return 'muted'
}

function Draw-TopBar {
    param(
        [string]$Right = '',
        [string]$Badge = '',
        [string]$BadgeColor = 'orange'
    )
    $w = $script:TW
    Tui-Fill 0 0 $w 1 ' ' 'white' 'purple'
    Tui-Put 1 0 ' ◆ CleanWinTUI ' 'white' 'purple'
    $cursor = $w - 1
    if ($Right) {
        Tui-PutRight ($w - 1) 0 "$Right " 'base' 'purple'
        $cursor = $w - $Right.Length - 2
    }
    if ($Badge) {
        $label = " $Badge "
        $bx = $cursor - $label.Length - 1
        if ($bx -gt 14) {
            Tui-Put $bx 0 $label 'base' $BadgeColor
            $cursor = $bx - 1
        }
    }
}

function Draw-Footer {
    param([array]$Pills)
    $y = $script:TH - 1
    Tui-Fill 0 $y $script:TW 1 ' ' 'muted' 'panel'
    if (-not $Pills) { return }
    $x = 1
    foreach ($p in $Pills) {
        if (-not $p -or $p.Count -lt 2) { continue }
        $keyText = " $($p[0]) "
        $lblText = " $($p[1]) "
        $need = $keyText.Length + $lblText.Length + 1
        if (($x + $need) -gt $script:TW) { break }
        Tui-Put $x $y $keyText 'base' 'accent'
        $x += $keyText.Length
        Tui-Put $x $y $lblText 'muted' 'panel'
        $x += $lblText.Length + 1
    }
}

function Draw-ProgressBar {
    param(
        [int]$X, [int]$Y, [int]$Width,
        [int]$Percent,
        [string]$Color = 'accent',
        [string]$Bg = 'base'
    )
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $filled = [int][Math]::Round(($Width * $Percent) / 100)
    if ($filled -gt $Width) { $filled = $Width }
    for ($i = 0; $i -lt $Width; $i++) {
        $ch = [char]0x2591
        $c = 'dim'
        if ($i -lt $filled) { $ch = [char]0x2588; $c = $Color }
        Tui-Put ($X + $i) $Y ([string]$ch) $c $Bg
    }
}

function Draw-Badge {
    param([int]$X, [int]$Y, [string]$Text, [string]$Fg = 'base', [string]$Bg = 'accent')
    Tui-Put $X $Y " $Text " $Fg $Bg
}

function Draw-GroupTag {
    param([int]$X, [int]$Y, [string]$Group)
    $color = Get-GroupColor $Group
    Tui-Put $X $Y " $Group " 'base' $color
}

function Draw-Separator {
    param([int]$X, [int]$Y, [int]$Width, [string]$Bg = 'base')
    Tui-Put $X $Y ([string]([char]0x2500) * $Width) 'line' $Bg
}

function Draw-Title {
    param([string]$Text, [string]$Sub = '')
    Tui-Put 2 1 (" " + $Text) 'fg' 'base' | Out-Null
    if ($Sub) {
        Tui-PutRight ($script:TW - 2) 1 $Sub 'dim' 'base'
    }
}
