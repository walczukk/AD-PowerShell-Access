# 🔒AD PowerShell Access (SecOps)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue?logo=powershell) ![Active Directory](https://img.shields.io/badge/ActiveDirectory-Module-green) ![v1.0](https://img.shields.io/badge/wersja-1.0-e45959)

To repozytorium zawiera rozwiązanie do zautomatyzowanego zarządzania uprawnieniami dostępu do usługi PowerShell na stacjach roboczych w środowisku Active Directory, połączone z monitoringiem w systemie Zabbix.

## Architektura rozwiązania

Rozwiązanie opiera się na wymuszaniu modelu bezpieczeństwa który składa się z trzech warstw:

### 1. Polityka GPO (AppLocker)
Zamiast blokować samego użytkownika, blokowany jest proces na stacji roboczej. Utworzono dedykowany obiekt GPO konfigurujący reguły AppLocker:
* **Usługa Tożsamość aplikacji (AppIDSvc):** Uruchamianie Automatyczne.
* **Reguły wykonywalne (Odmowa):** Blokada po wydawcy (Microsoft) dla plików `POWERSHELL.EXE` oraz `POWERSHELL_ISE.EXE`.
* **Reguły domyślne (Zezwolenie):** Standardowe zezwolenia dla katalogów Windows i Program Files, aby nie ubić systemu.
* **Filtrowanie zabezpieczeń:** Polityka jest aplikowana **wyłącznie** do komputerów znajdujących się w grupie `ug-DisablePowerShell`.

### 2. Skrypt Automatyzujący (PowerShell)
Skrypt `PowerShell_Status_Check.ps1` dba o odpowiednie sortowanie maszyn w AD. Cyklicznie skanuje komputery po zdefiniowanym prefiksie:
* Jeśli komputer nie należy do grupy zezwalającej (`ug-EnablePowerShell`) ani blokującej (`ug-DisablePowerShell`), jest domyślnie wrzucany do grupy blokującej.
* W przypadku konfliktu (komputer omyłkowo dodany do obu grup), przywilej zezwolenia ma priorytet i komputer jest usuwany z grupy blokującej.

### 3. Monitoring (Zabbix)
Skrypt posiada wbudowaną obsługę narzędzia `zabbix_sender.exe`. Raportuje swój status bezpośrednio do serwera Zabbix (1 - sukces, 0 - porażka), włączając w to przesyłanie dokładnych komunikatów błędów za pomocą kluczy Zabbix Trapper.

## Wymagania
* Moduł `ActiveDirectory`.
* Zainstalowany `Zabbix Agent 2` z narzędziem zabbix_sender (domyślnie w `C:\Program Files\Zabbix Agent 2\`).
* Skonfigurowane Item'y w Zabbixie (typ: Zabbix trapper) z kluczami:
  * `pwsh.status.check.script.status`
  * `pwsh.status.check.script.error`

## Użycie
Wywołaj skrypt z odpowiednimi parametrami, żeby dostosować go do swojego nazewnictwa w AD

**Przykład wywołania:**
```powershell
.\PowerShell_Status_Check.ps1 -ComputerPrefix "PC" -NotebookPrefix "NB" -ZabbixServer "192.168.1.100" -Verbose
```

**Zastrzeżenie!**
*Skrypt wprowadza zmiany w Active Directory. Mimo że został napisany z dbałością o błędy,
używasz ich na własną odpowiedzialność! Przetestuj dokładnie jego działanie na środowisku 
testowym przed uruchomieniem go na produkcji :)*

Autor: *Kacper Walczuk **(@walczukk)***
