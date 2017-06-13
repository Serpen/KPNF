#
# Modulmanifest für das Modul "notfalldaten-module-1.0"
#
# Generiert von: Serpen
#
# Generiert am: 10.04.2015
#

@{

# Die diesem Manifest zugeordnete Skript- oder Binärmoduldatei.
RootModule = 'kpnd.psm1'

# Die Versionsnummer dieses Moduls
ModuleVersion = '1.0'

# ID zur eindeutigen Kennzeichnung dieses Moduls
GUID = '790592a3-e16b-4c1f-bac5-abeda8a78e63'

# Autor dieses Moduls
Author = 'Serpen'

# Unternehmen oder Hersteller dieses Moduls
CompanyName = 'FEK'

# Urheberrechtserklärung für dieses Modul
Copyright = '(c) 2017 Serpen under MIT License'

# Beschreibung der von diesem Modul bereitgestellten Funktionen
Description = 'KIS Patienten Notfalldaten'

# Die für dieses Modul mindestens erforderliche Version des Windows PowerShell-Moduls
PowerShellVersion = '3.0'

# Der Name des für dieses Modul erforderlichen Windows PowerShell-Hosts
# PowerShellHostName = ''

# Die für dieses Modul mindestens erforderliche Version des Windows PowerShell-Hosts
# PowerShellHostVersion = ''

# Die für dieses Modul mindestens erforderliche Microsoft .NET Framework-Version
DotNetFrameworkVersion = '4.0'

# Die für dieses Modul mindestens erforderliche Version der CLR (Common Language Runtime)
CLRVersion = '4.0'

# Die für dieses Modul erforderliche Prozessorarchitektur ("Keine", "X86", "Amd64").
# ProcessorArchitecture = ''

# Die Module, die vor dem Importieren dieses Moduls in die globale Umgebung geladen werden müssen
RequiredModules = @('Microsoft.powershell.host', 'microsoft.powershell.security')

# Die Assemblys, die vor dem Importieren dieses Moduls geladen werden müssen
RequiredAssemblies = @("System.Data")

# Die Skriptdateien (PS1-Dateien), die vor dem Importieren dieses Moduls in der Umgebung des Aufrufers ausgeführt werden.
ScriptsToProcess = @('config.ps1')

# Die Typdateien (.ps1xml), die beim Importieren dieses Moduls geladen werden sollen
# TypesToProcess = @()

# Die Formatdateien (.ps1xml), die beim Importieren dieses Moduls geladen werden sollen
# FormatsToProcess = @()

# Die Module, die als geschachtelte Module des in "RootModule/ModuleToProcess" angegebenen Moduls importiert werden sollen.
# NestedModules = @()

# Aus diesem Modul zu exportierende Funktionen
FunctionsToExport = '*'

# Aus diesem Modul zu exportierende Cmdlets
CmdletsToExport = '*'

# Die aus diesem Modul zu exportierenden Variablen
#VariablesToExport = '*'

# Aus diesem Modul zu exportierende Aliase
#AliasesToExport = '*'

# Liste aller Module in diesem Modulpaket
# ModuleList = @()

# Liste aller Dateien in diesem Modulpaket
# FileList = @()

# Die privaten Daten, die an das in "RootModule/ModuleToProcess" angegebene Modul übergeben werden sollen.
# PrivateData = ''

# HelpInfo-URI dieses Moduls
HelpInfoURI = ''

# Standardpräfix für Befehle, die aus diesem Modul exportiert werden. Das Standardpräfix kann mit "Import-Module -Prefix" überschrieben werden.
# DefaultCommandPrefix = ''

}

