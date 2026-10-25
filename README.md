# CleanWinTUI

Ferramenta TUI para debloat controlado do Windows 11, com seleção por item, agrupamento por importância, transação com rollback automático e plano de restauração completo.

## Requisitos
- Windows 11 (build >= 22000)
- PowerShell 5.1 ou PowerShell 7+
- Executar como Administrador

## Segurança
- Ponto de restauração é tentado SEMPRE antes de qualquer alteração
- Para itens `[CUIDADO]` ou `[AVANÇADO]`, o ponto de restauração é **obrigatório**
- Sistema de transação com rollback LIFO para ações reversíveis quando houver itens `[CUIDADO]` ou `[AVANÇADO]` selecionados
- Whitelist para proteger componentes essenciais
- Gera `Restore-Plan.ps1` ao final

## Uso
1. Abra PowerShell ou Terminal como Administrador
2. Navegue até `C:\CleanWinTUI`
3. Execute: `.\Start-DebloatTUI.ps1`
4. Siga as instruções na TUI

## Grupos
- `[SEGURO]` - Reversível, baixo impacto
- `[OPCIONAL]` - Melhora UX, reversível
- `[CUIDADO]` - Pode impactar cenários específicos
- `[AVANÇADO]` - Alto impacto, requer atenção extra

## Restauração
Caso precise restaurar, use o `Restore-Plan.ps1` gerado em `logs\<sessão>\` ou o ponto de restauração criado via `rstrui.exe`.
