
#Sobald diese Datei fertig konfiguriert ist bitte folgende Zeile auskommentieren
#return

#Welches KIS System wird benutzt, noch ohne Funktion
[String]$KisSystem = 'cerner medico'

#Datenbankanbieter laden
[Reflection.Assembly]::LoadWithPartialName("Oracle.ManagedDataAccess") | Out-Null

#Datenbank Connector
[type]$DBAdapterType = [Oracle.ManagedDataAccess.Client.OracleDataAdapter]

#Verschl�sselung der Anmeldedaten ist PC-bezogen, muss also beim Rechnertausch ge�ndert werden!
$cred_db = Import-Clixml ("$PSScriptRoot\cred-db.xml")

#Verbindungszeichenfolge zur KIS Datenbank, inklusive Passwort, am besten ein nur lesender Benutzer
[System.Data.Common.DbConnection]$db_kis = New-Object Oracle.ManagedDataAccess.Client.OracleConnection "Data Source=datasourcename;User ID=$($cred_db.username);Password=$($cred_db.GetNetworkCredential().Password)"
## Es werden zur Zeit noch keine verschl�sselten Anmeldedaten f�r den Datenbankserver unterst�tzt

#Pr�fung ob die Standarddatenbanktabellen ausgelesen werden k�nnen
$BASIC_SQL_TEST = 'SELECT count(*) as anz FROM x1100pat,x1000per,x1102sta,x1280dia WHERE rownum < 2'

#Arbeitsverzeichnis f�r die Ein-/Ausgabedateien
[string]$NotfallDatenRootDir = $PsScriptRoot

#Pfad zur ZipCompressor (7-ZIP)
[string]$zipper = "$env:ProgramFiles\7-Zip\7z.exe"
[string]$zipperArgCreate = "a"

#relativer Pfad auf den Clients f�r das Notfallkonzept
[string]$clientPathRoot = "c$\Notfalldaten_KIS"

#Zeitspanne zur Werteabfrage in die Vergangenheit
[int]$DaysLookBack = 5

#Zeitspanne zur Werteabfrage in die Vergangenheit
[int]$Mandant = 1

#SMTP Mail Server
[string]$MailHost = 'mail.example.com'
[string]$MailFrom = 'KIS_notfalldaten@example.com'
[string[]]$MailTo = 'info@example.com'
[string[]]$ErrorMailTo = 'info@example.com'
#Verschl�sselung der Anmeldedaten ist PC-bezogen, muss also beim Rechnertausch ge�ndert werden!
#[PSCredential]$MailServerLogin = Import-Clixml ("$PSScriptRoot\cred-mail.xml")

#XML Writer Einstellungen, Einr�cken zum Debugging aktivieren
[xml.xmlwriterSettings]$xmlset = New-Object Xml.XmlWriterSettings -Property @{Indent=$true}

#Wieviele Meldungen sollen angezeigt und protokolliert werden
#$VerbosePreference = 'Continue'
#$DebugPreference = 'Continue'

$DateFormat = 'dd.MM.yyyy HH:mm:ss'
$DBDateFormat = 'dd.MM.yyyy HH:mm'

$Module = @(
	'diagnosen.xml',
	#'labor-last.xml',
	#'medication.xml',
	#'par.xml',
	#'merkmale.xml',
	#'wfd.xml',
	#'vitalwerte.xml',
	#'koerpermasse.xml',
	#'anordnungen.xml',
	#'fkvfreitexte.xml',
	#'iao.xml',
	#'ao_bilanz.xml',
	#'pflegemassnahmen.xml',
	#'counter.xml',
	#'notizen.xml'
)