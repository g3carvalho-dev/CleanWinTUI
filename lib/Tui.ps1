# CleanWinTUI - ANSI TUI toolkit (UTF-8, full-screen)

$script:TuiEsc = [char]27

$script:TuiRgb = @{
    base   = @(15,16,23)
    panel  = @(22,24,36)
    panel2 = @(33,36,54)
    line   = @(44,48,71)
    line2  = @(66,74,110)
    fg     = @(203,211,245)
    muted  = @(122,131,171)
    dim    = @(72,80,114)
    accent = @(122,162,247)
    purple = @(187,154,247)
    green  = @(158,206,106)
    yellow = @(224,175,104)
    red    = @(247,118,142)
    cyan   = @(125,207,255)
    orange = @(255,158,100)
    white  = @(238,242,255)
}

$script:TuiSgrCache = @{}

function Get-TuiSgr {
    param([string]$Fg, [string]$Bg)
    $key = "$Fg|$Bg"
    if ($script:TuiSgrCache.ContainsKey($key)) { return $script:TuiSgrCache[$key] }
    $parts = New-Object System.Collections.Generic.List[string]
    if ($Fg -and $script:TuiRgb.ContainsKey($Fg)) {
        $c = $script:TuiRgb[$Fg]
        $parts.Add("38;2;$($c[0]);$($c[1]);$($c[2])")
    }
    if ($Bg -and $script:TuiRgb.ContainsKey($Bg)) {
        $c = $script:TuiRgb[$Bg]
        $parts.Add("48;2;$($c[0]);$($c[1]);$($c[2])")
    }
    if ($parts.Count -eq 0) {
        $sgr = "$($script:TuiEsc)[0m"
    } else {
        $sgr = "$($script:TuiEsc)[0;$($parts -join ';')m"
    }
    $script:TuiSgrCache[$key] = $sgr
    return $sgr
}

function Enable-TuiVirtualTerminal {
    if (-not ('CleanWinTui.Native' -as [type])) {
        try {
            Add-Type -Namespace CleanWinTui -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop
        } catch {
            return
        }
    }
    try {
        $handle = [CleanWinTui.Native]::GetStdHandle(-11)
        $mode = [uint32]0
        if ([CleanWinTui.Native]::GetConsoleMode($handle, [ref]$mode)) {
            [void][CleanWinTui.Native]::SetConsoleMode($handle, $mode -bor 0x0004)
        }
    } catch { }
}

function Tui-Init {
    try {
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    } catch { }
    $global:OutputEncoding = [Console]::OutputEncoding
    Enable-TuiVirtualTerminal
    try { [Console]::TreatControlCAsInput = $true } catch { }
    try { $Host.UI.RawUI.WindowTitle = 'CleanWinTUI' } catch { }
    [Console]::Out.Write(
        "$($script:TuiEsc)]0;CleanWinTUI$([char]7)" +
        "$($script:TuiEsc)[?1049h" +
        "$($script:TuiEsc)[?25l" +
        "$($script:TuiEsc)[?7l" +
        "$($script:TuiEsc)[2J" +
        "$($script:TuiEsc)[H" +
        "$($script:TuiEsc)[0m"
    )
    [Console]::Out.Flush()
    Tui-Reset
}

function Tui-Close {
    try {
        [Console]::Out.Write(
            "$($script:TuiEsc)[0m" +
            "$($script:TuiEsc)[?7h" +
            "$($script:TuiEsc)[?25h" +
            "$($script:TuiEsc)[?1049l"
        )
        [Console]::Out.Flush()
    } catch { }
    try { [Console]::TreatControlCAsInput = $false } catch { }
    try { $Host.UI.RawUI.WindowTitle = 'CleanWinTUI' } catch { }
}

function Get-TuiWindowSize {
    $w = 0
    $h = 0
    try { $w = [Console]::WindowWidth } catch { }
    try { $h = [Console]::WindowHeight } catch { }
    if ($w -le 0) { $w = 120 }
    if ($h -le 0) { $h = 30 }
    return @{ Width = $w; Height = $h }
}

function Tui-Reset {
    $size = Get-TuiWindowSize
    $script:TW = [Math]::Max(40, [int]$size.Width)
    $script:TH = [Math]::Max(16, [int]$size.Height)
    $script:TBufC = [char[,]]::new($script:TH, $script:TW)
    $script:TBufF = [string[,]]::new($script:TH, $script:TW)
    $script:TBufB = [string[,]]::new($script:TH, $script:TW)
    Tui-Fill 0 0 $script:TW $script:TH ' ' 'fg' 'base'
}

function Tui-Fill {
    param(
        [int]$X, [int]$Y, [int]$W, [int]$H,
        [char]$Char = ' ',
        [string]$Fg = 'fg',
        [string]$Bg = 'base'
    )
    $x2 = [Math]::Min($X + $W, $script:TW)
    $y2 = [Math]::Min($Y + $H, $script:TH)
    for ($cy = [Math]::Max(0, $Y); $cy -lt $y2; $cy++) {
        for ($cx = [Math]::Max(0, $X); $cx -lt $x2; $cx++) {
            $script:TBufC[$cy, $cx] = $Char
            $script:TBufF[$cy, $cx] = $Fg
            $script:TBufB[$cy, $cx] = $Bg
        }
    }
}

function Tui-Put {
    param([int]$X, [int]$Y, [string]$Text, [string]$Fg = 'fg', [string]$Bg = 'base')
    if ($null -eq $Text) { return }
    if ($Y -lt 0 -or $Y -ge $script:TH) { return }
    $len = $Text.Length
    for ($i = 0; $i -lt $len; $i++) {
        $cx = $X + $i
        if ($cx -lt 0) { continue }
        if ($cx -ge $script:TW) { break }
        $script:TBufC[$Y, $cx] = $Text[$i]
        $script:TBufF[$Y, $cx] = $Fg
        $script:TBufB[$Y, $cx] = $Bg
    }
}

function Tui-PutCentered {
    param([int]$Y, [string]$Text, [string]$Fg = 'fg', [string]$Bg = 'base')
    if ($null -eq $Text) { return }
    $x = [int](($script:TW - $Text.Length) / 2)
    if ($x -lt 0) { $x = 0 }
    Tui-Put $x $Y $Text $Fg $Bg
}

function Tui-PutRight {
    param([int]$Right, [int]$Y, [string]$Text, [string]$Fg = 'fg', [string]$Bg = 'base')
    $x = $Right - $Text.Length
    if ($x -lt 0) { $x = 0 }
    Tui-Put $x $Y $Text $Fg $Bg
}

function Tui-PutWrapped {
    param([int]$X, [int]$Y, [int]$Width, [string]$Text, [string]$Fg = 'fg', [string]$Bg = 'base')
    $cy = $Y
    foreach ($ln in (Tui-Wrap $Text $Width)) {
        if ($cy -ge $script:TH) { break }
        Tui-Put $X $cy $ln $Fg $Bg
        $cy++
    }
    return $cy
}

function Tui-PutWrappedCentered {
    param([int]$Y, [int]$Width, [string]$Text, [string]$Fg = 'fg', [string]$Bg = 'base')
    $cy = $Y
    foreach ($ln in (Tui-Wrap $Text $Width)) {
        if ($cy -ge $script:TH) { break }
        Tui-PutCentered $cy $ln $Fg $Bg
        $cy++
    }
    return $cy
}

function Tui-Truncate {
    param([string]$Text, [int]$Width)
    if ($null -eq $Text) { return '' }
    if ($Width -le 0) { return '' }
    if ($Text.Length -le $Width) { return $Text }
    if ($Width -le 1) { return $Text.Substring(0, $Width) }
    return $Text.Substring(0, $Width - 1) + [char]0x2026
}

function Tui-Box {
    param(
        [int]$X, [int]$Y, [int]$W, [int]$H,
        [string]$Title = '',
        [string]$Border = 'line',
        [string]$Fg = 'muted',
        [string]$Bg = 'base',
        [string]$TitleFg = 'fg'
    )
    if ($W -lt 2 -or $H -lt 2) { return }
    Tui-Put $X $Y ([char]0x256D) $Fg $Bg
    Tui-Put ($X + $W - 1) $Y ([char]0x256E) $Fg $Bg
    Tui-Put $X ($Y + $H - 1) ([char]0x2570) $Fg $Bg
    Tui-Put ($X + $W - 1) ($Y + $H - 1) ([char]0x256F) $Fg $Bg
    for ($i = 1; $i -lt $W - 1; $i++) {
        Tui-Put ($X + $i) $Y ([char]0x2500) $Fg $Bg
        Tui-Put ($X + $i) ($Y + $H - 1) ([char]0x2500) $Fg $Bg
    }
    for ($j = 1; $j -lt $H - 1; $j++) {
        Tui-Put $X ($Y + $j) ([char]0x2502) $Fg $Bg
        Tui-Put ($X + $W - 1) ($Y + $j) ([char]0x2502) $Fg $Bg
    }
    if ($Title) {
        $t = " $Title "
        $t = Tui-Truncate $t ($W - 4)
        Tui-Put ($X + 2) $Y $t $TitleFg $Bg
    }
}

function Tui-Wrap {
    param([string]$Text, [int]$Width)
    if ($Width -lt 8) { $Width = 8 }
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Text) { return @('') }
    foreach ($para in ($Text -split "`r?`n")) {
        if ($para.Length -eq 0) { $out.Add(''); continue }
        $line = ''
        foreach ($word in ($para -split '\s+')) {
            if ($word.Length -eq 0) { continue }
            while ($word.Length -gt $Width) {
                if ($line.Length -gt 0) { $out.Add($line); $line = '' }
                $out.Add($word.Substring(0, $Width))
                $word = $word.Substring($Width)
            }
            if ($line.Length -eq 0) {
                $line = $word
            } elseif (($line.Length + 1 + $word.Length) -le $Width) {
                $line = $line + ' ' + $word
            } else {
                $out.Add($line)
                $line = $word
            }
        }
        if ($line.Length -gt 0) { $out.Add($line) }
    }
    if ($out.Count -eq 0) { $out.Add('') }
    return @($out)
}

function Tui-Render {
    if (-not $script:TW) { Tui-Reset }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("$($script:TuiEsc)[?2026h")
    [void]$sb.Append("$($script:TuiEsc)[H")
    $lastRow = $script:TH - 1
    for ($y = 0; $y -le $lastRow; $y++) {
        $curF = ''
        $curB = ''
        $run = New-Object System.Text.StringBuilder
        for ($x = 0; $x -lt $script:TW; $x++) {
            $f = $script:TBufF[$y, $x]
            $b = $script:TBufB[$y, $x]
            if ($f -ne $curF -or $b -ne $curB) {
                if ($run.Length -gt 0) {
                    [void]$sb.Append($run.ToString())
                    [void]$run.Clear()
                }
                [void]$sb.Append((Get-TuiSgr $f $b))
                $curF = $f
                $curB = $b
            }
            [void]$run.Append(($script:TBufC[$y, $x]))
        }
        if ($run.Length -gt 0) { [void]$sb.Append($run.ToString()) }
        if ($y -lt $lastRow) { [void]$sb.Append("`r`n") }
    }
    [void]$sb.Append("$($script:TuiEsc)[0m")
    [void]$sb.Append("$($script:TuiEsc)[?2026l")
    [Console]::Out.Write($sb.ToString())
    [Console]::Out.Flush()
}

function Tui-ReadKey {
    while ($true) {
        $available = $false
        try {
            $available = [Console]::KeyAvailable
        } catch {
            Start-Sleep -Milliseconds 40
            return @{ Key = 'none'; Char = '' }
        }

        if ($available) {
            try {
                $k = [Console]::ReadKey($true)
            } catch {
                Start-Sleep -Milliseconds 40
                return @{ Key = 'none'; Char = '' }
            }
            if (($k.Modifiers -band [ConsoleModifiers]::Control) -ne 0) {
                if ($k.Key -eq [ConsoleKey]::C) { return @{ Key = 'ctrl-c'; Char = '' } }
                return @{ Key = 'ctrl'; Char = '' }
            }
            switch ($k.Key) {
                ([ConsoleKey]::UpArrow)    { return @{ Key = 'up'; Char = '' } }
                ([ConsoleKey]::DownArrow)  { return @{ Key = 'down'; Char = '' } }
                ([ConsoleKey]::LeftArrow)  { return @{ Key = 'left'; Char = '' } }
                ([ConsoleKey]::RightArrow) { return @{ Key = 'right'; Char = '' } }
                ([ConsoleKey]::Enter)      { return @{ Key = 'enter'; Char = '' } }
                ([ConsoleKey]::Escape)     { return @{ Key = 'esc'; Char = '' } }
                ([ConsoleKey]::Spacebar)   { return @{ Key = 'space'; Char = ' ' } }
                ([ConsoleKey]::Tab)        { return @{ Key = 'tab'; Char = '' } }
                ([ConsoleKey]::Backspace)  { return @{ Key = 'backspace'; Char = '' } }
                ([ConsoleKey]::PageUp)     { return @{ Key = 'pgup'; Char = '' } }
                ([ConsoleKey]::PageDown)   { return @{ Key = 'pgdown'; Char = '' } }
                ([ConsoleKey]::Home)       { return @{ Key = 'home'; Char = '' } }
                ([ConsoleKey]::End)        { return @{ Key = 'end'; Char = '' } }
            }
            if ($k.KeyChar -ne [char]0) {
                $ch = [string]$k.KeyChar
                if ($ch -match '^[\x20-\x7E]$') {
                    return @{ Key = $ch.ToLower(); Char = $ch }
                }
                return @{ Key = 'char'; Char = $ch }
            }
            return @{ Key = 'none'; Char = '' }
        }

        $cw = 0
        $chh = 0
        try { $cw = [Console]::WindowWidth } catch { }
        try { $chh = [Console]::WindowHeight } catch { }
        if ($cw -gt 0 -and $chh -gt 0 -and ($cw -ne $script:TW -or $chh -ne $script:TH)) {
            Start-Sleep -Milliseconds 50
            return @{ Key = 'resize'; Char = '' }
        }

        Start-Sleep -Milliseconds 30
    }
}

function Tui-InputLine {
    param([int]$X, [int]$Y, [int]$Width, [string]$Prompt = '', [string]$Bg = 'panel2')
    $text = ''
    while ($true) {
        Tui-Fill $X $Y $Width 1 ' ' 'fg' $Bg
        $visible = $Prompt + $text
        if ($visible.Length -gt $Width - 2) {
            $visible = $visible.Substring($visible.Length - ($Width - 2))
        }
        Tui-Put $X $Y (" " + $visible) 'fg' $Bg
        $cx = $X + 1 + $visible.Length
        if ($cx -ge $X + $Width) { $cx = $X + $Width - 1 }
        Tui-Put $cx $Y ' ' 'base' 'accent'
        Tui-Render
        $k = Tui-ReadKey
        if ($k.Key -eq 'resize') { Tui-Reset; continue }
        switch ($k.Key) {
            'enter'     { return $text }
            'esc'       { return $null }
            'backspace' { if ($text.Length -gt 0) { $text = $text.Substring(0, $text.Length - 1) } }
            'space'     { $text += ' ' }
            default {
                if ($k.Char -and $k.Char -match '^[\x20-\x7E]$') { $text += $k.Char }
            }
        }
    }
}
