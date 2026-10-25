function New-RestorePlan {
    param([array]$Items)
    $planPath = Join-Path $Global:CleanWinTUI.SessionPath "Restore-Plan.ps1"
    $content = @"
# CleanWinTUI - RESTORE PLAN
# Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Sessão: $($Global:CleanWinTUI.SessionId)
# Build: $($Global:CleanWinTUI.WinBuild)
# Ponto de restauração criado: $($Global:CleanWinTUI.RestorePointCreated)
# Transação ativa: $($Global:CleanWinTUI.TransactionActive)

# AVISO: Este plano foi gerado automaticamente pelo CleanWinTUI
# Recomenda-se PRIORITARIAMENTE usar o ponto de restauração via rstrui.exe

Write-Host "=== CleanWinTUI Restore Plan ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. MÉTODO MAIS CONFIÁVEL - Ponto de Restauração" -ForegroundColor Yellow
Write-Host "   Execute: rstrui.exe" -ForegroundColor White
Write-Host "   Selecione o ponto criado durante o debloat e siga as instruções" -ForegroundColor Gray
Write-Host ""

Write-Host "2. ITENS APLICADOS NESTA SESSÃO" -ForegroundColor Yellow
"@
    foreach ($item in $Items) {
        $content += "Write-Host '   - [$($item.group)] $($item.title)' -ForegroundColor Gray`r`n"
    }
    $content += @"

Write-Host ""
Write-Host "3. APPX REMOVIDOS" -ForegroundColor Yellow
Write-Host "   Verificar quarentena em: $(Join-Path $Global:CleanWinTUI.SessionPath 'quarantine\appx.json')" -ForegroundColor Gray
Write-Host "   Muitos podem ser reinstalados pela Microsoft Store" -ForegroundColor Gray
Write-Host ""

Write-Host "4. AJUSTES DE REGISTRO" -ForegroundColor Yellow
Write-Host "   Ajustes foram aplicados. Para reverter, use o ponto de restauração." -ForegroundColor Gray
Write-Host ""

Write-Host "5. LOGS COMPLETOS" -ForegroundColor Yellow
Write-Host "   $($Global:CleanWinTUI.SessionPath)" -ForegroundColor Gray
Write-Host ""
Write-Host "=== FIM DO PLANO ===" -ForegroundColor Cyan
"@
    $content | Out-File -FilePath $planPath -Encoding UTF8
    Write-Log "Restore-Plan.ps1 gerado: $planPath"
}

Export-ModuleMember -Function New-RestorePlan
