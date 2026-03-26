<#
.SYNOPSIS
Skrypt sprawdza poprawność przynależności do grup kontrolujących dostęp do usługi Powershell.

.DESCRIPTION
Skrypt weryfikuje komputery w AD na podstawie prefiksu. Jeśli komputer nie ma jawnie
przyznanego dostępu (ug-EnablePowerShell) ani nie jest zablokowany (ug-DisablePowerShell),
domyślnie ląduje w grupie blokującej. Dodatkowo skrypt raportuje swój status i błędy do Zabbixa.

.EXAMPLE
.\PowerShell_Status_Check.ps1 -ComputerPrefix "PC" -NotebookPrefix "NB" -Verbose

.NOTES
    Wersja: 1.0
    Autor: Kacper Walczuk
    Data publikacji: 2026-03-25

    ZASTRZEŻENIE
    Skrypt wprowadza zmiany w Active Directory. Mimo że został napisany z dbałością o błędy,
    używasz ich na własną odpowiedzialność! Przetestuj dokładnie jego działanie na środowisku
    testowym przed uruchomieniem go na produkcji :) 
#>

[CmdletBinding()]
param (
    [string]$ComputerPrefix = "PC",
    [string]$NotebookPrefix = "NB",
    [string]$ZabbixServer = "8.8.8.8",
    [string]$HostNameOnZabbix = "server01",
    [string]$DisableGroup = "ug-DisablePowerShell",
    [string]$EnableGroup = "ug-EnablePowerShell",
    [string]$ZabbixSenderPath = "C:\Program Files\Zabbix Agent 2\zabbix_sender.exe",
    [string]$ZabbixKeyStatus = "pwsh.status.check.script.status",
    [string]$ZabbixKeyError = "pwsh.status.check.script.error"
)

$ADComputers = Get-ADComputer -Filter "Name -like '$ComputerPrefix*' -or Name -like '$NotebookPrefix*'" | Select -ExpandProperty Name
$DisablePowerShellGroup = Get-ADGroupMember -Identity $DisableGroup | Select Name
$EnablePowerShellGroup = Get-ADGroupMember -Identity $EnableGroup | Select Name

Try {
    #Testowa linijka do sprawdzenia poprawności odczytu awarii
    #throw $a = 1/0

    foreach ($computer in $ADComputers) {
        if (!($computer -in $DisablePowerShellGroup.Name) -and !($computer -in $EnablePowerShellGroup.Name)) {
            #dodaj do ug-DisablePowerShell jeśli nie istnieje w obu grupach
            Write-Verbose "[$computer] brak w obu grupach. Dodaję do grupy blokującej ($DisableGroup)."
            Add-ADGroupMember -Identity $DisableGroup -Members ($computer) -ErrorAction Stop
        } elseif (($computer -in $DisablePowerShellGroup.Name) -and ($computer -in $EnablePowerShellGroup.Name)) {
            #usuń z ug-DisablePowerShell jeśli istnieje w grupie ug-EnablePowerShell
            Write-Verbose "[$computer] istnieje w obu grupach. Usuwam z grupy blokującej ($DisableGroup)."
            Remove-ADGroupMember -Identity $DisableGroup -Members ($computer) -Confirm:$false -ErrorAction Stop
        } elseif (($computer -in $DisablePowerShellGroup.Name) -and !($computer -in $EnablePowerShellGroup.Name)) {
            #jeśli istnieje w ug-DisablePowerShell i nie istnieje w ug-EnablePowerShell idź dalej
        } else {
            #
            Write-Verbose "[$computer] ma prawidłową przynależność."
        }
    }

    Write-Verbose "Wysyłanie statusu do Zabbixa..."
    $Arguments = "-z $ZabbixServer -s ""$HostNameOnZabbix"" -k $ZabbixKeyStatus -o 1"

    Start-Process -FilePath $ZabbixSenderPath -ArgumentList $Arguments -NoNewWindow -Wait
}
Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Error "BŁĄD: $ErrorMessage"

    $ArgumentsError = "-z $ZabbixServer -s ""$HostNameOnZabbix"" -k $ZabbixKeyError -o ""$ErrorMessage"""
    Start-Process -FilePath $ZabbixSenderPath -ArgumentList $ArgumentsError -NoNewWindow -Wait

    $Arguments = "-z $ZabbixServer -s ""$HostNameOnZabbix"" -k $ZabbixKeyStatus -o 0"
    Start-Process -FilePath $ZabbixSenderPath -ArgumentList $Arguments -NoNewWindow -Wait    
}