# CleanWinTUI

Ferramenta TUI para debloat controlado do Windows 11, com seleção item a item, agrupamento por risco, transação com rollback automático e plano de restauração completo.

## Requisitos
- Windows 11 (build >= 22000)
- PowerShell 5.1 ou PowerShell 7+
- Windows Terminal recomendado (truecolor, UTF-8 e box-drawing corretos)
- Executar como Administrador (o script tenta se auto-elevar)

## Uso
1. Abra o Windows Terminal como Administrador
2. Navegue até a pasta do projeto
3. Execute: `.\Start-DebloatTUI.ps1`
4. Siga o fluxo da TUI: boas-vindas → grupos → seleção → revisão → simulação → confirmação → execução → relatório

## Controles
- `↑` `↓` / `PgUp` `PgDn` / `Home` `End` - navegar itens
- `←` `→` ou `Tab` - trocar de grupo
- `Space` - marcar/desmarcar item
- `a` - marcar todos do grupo · `n` - limpar grupo · `d` - aplicar padrões seguros
- `Enter` - avançar · `Esc` - voltar · `q` - sair
- `Ctrl+C` durante a execução - abortar e disparar rollback quando aplicável

## Grupos
- `[SEGURO]` - reversível, baixo impacto
- `[OPCIONAL]` - melhora UX, reversível
- `[CUIDADO]` - pode impactar cenários específicos
- `[AVANÇADO]` - alto impacto, exige confirmação digitada (`CONFIRMO`)

## Segurança
- Ponto de restauração é tentado SEMPRE antes de qualquer alteração
- Para itens `[CUIDADO]` ou `[AVANÇADO]`, o ponto de restauração é **obrigatório**
- Itens `[CUIDADO]`/`[AVANÇADO]` ativam o modo transação com rollback LIFO automático em qualquer falha
- Whitelist (`config/whitelist.json`) protege Store, Defender, Windows Update, shell, StartMenu e componentes base
- Backups de registro, Appx e tarefas são gravados por sessão
- `Restore-Plan.ps1` é sempre gerado ao final

## Estrutura
```
Start-DebloatTUI.ps1      ponto de entrada (dot-sourcing + fluxo)
lib/Tui.ps1               toolkit ANSI/truecolor (buffer, render, teclado, input)
lib/Widgets.ps1           barras, tags, progresso, separadores
modules/Core.ps1          admin, build, logs, ponto de restauração, backups, whitelist
modules/State.ps1         catálogo, seleção e contadores
modules/Transaction.ps1   transação e rollback LIFO
modules/Actions.ps1       execução de appx_remove / reg_set / reg_create_key / task_disable
modules/Engine.ps1        orquestração, progresso e log ao vivo
modules/Screens.ps1       telas da TUI
modules/RestoreGen.ps1    geração do Restore-Plan.ps1
config/catalog.json       catálogo de itens e ações
config/whitelist.json     componentes protegidos
config/defaults.json      itens seguros pré-selecionados
```

## Adicionando itens
Edite `config/catalog.json`. Cada item declara `id`, `group`, `module`, `winverMin`, `title`, `description`, `impact`, `reversible`, `backupKeys`, `notes` e `actions`. Tipos de ação suportados: `appx_remove`, `reg_set`, `reg_create_key`, `task_disable`.

## Restauração
Use o `Restore-Plan.ps1` gerado em `%LOCALAPPDATA%\CleanWinTUI\logs\<sessão>\`, ou o ponto de restauração criado via `rstrui.exe`.
