# ConsoleMenu base
function Read-Key { $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
Export-ModuleMember -Function Read-Key
