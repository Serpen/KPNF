

if ([environment]::osversion.version -lt '6.1') {
	write-error 'Es wird Windows 7 / Server 2008 R2 oder höher benötigt'
}

if ($PSVersionTable.PSVersion -lt '3.0') {
	write-error 'Es wird Powershell Version >= 3 benötigt'
}

if (-not (Test-Path "$env:ProgramFiles\7-Zip\7z.exe")) {
	write-Warning "Es wird ein installiertes SevenZip in '$($env:ProgramFiles)\7-Zip\7z.exe' benötigt"
}

"Verfügbare Datenbankanbieter: "
& {
	$availableDBProvider = @()

	$assembly = [Reflection.Assembly]::LoadWithPartialName("System.Data")
	if ($assembly -ne $null) {
		try {
			$con = [System.Data.Odbc.OdbcConnection]
			$adap =[System.Data.Odbc.OdbcDataAdapter]

			$availableDBProvider += New-Object PSObject -Property ([ordered]@{Assembly=$assembly ; Connection=$con.fullname; Adapter=$adap.fullname})
		} catch {}

		try {
			$con = [System.Data.OleDb.OleDbConnection]
			$adap =[System.Data.OleDb.OleDbDataAdapter]

			$availableDBProvider += New-Object PSObject -Property ([ordered]@{Assembly=$assembly ; Connection=$con.fullname; Adapter=$adap.fullname})
		} catch {}

		try {
			$con = [System.Data.SqlClient.SqlConnection]
			$adap =[System.Data.SqlClient.SqlDataAdapter]

			$availableDBProvider += New-Object PSObject -Property ([ordered]@{Assembly=$assembly ; Connection=$con.fullname; Adapter=$adap.fullname})
		} catch {}    
	}

	$assembly = [Reflection.Assembly]::LoadWithPartialName("System.Data.OracleClient")
	if ($assembly -ne $null) {
		try {
			$con = [System.Data.OracleClient.OracleConnection]
			$adap =[System.Data.OracleClient.OracleDataAdapter]

			$availableDBProvider += New-Object PSObject -Property ([ordered]@{Assembly=$assembly ; Connection=$con.fullname; Adapter=$adap.fullname})
		} catch {}
	}

	$assembly = [Reflection.Assembly]::LoadWithPartialName("Oracle.DataAccess")
	if ($assembly -ne $null) {
		$con = [Oracle.DataAccess.Client.OracleConnection]
		$adap =[Oracle.DataAccess.Client.OracleDataAdapter]

		$availableDBProvider += New-Object PSObject -Property ([ordered]@{Assembly=$assembly ; Connection=$con.fullname; Adapter=$adap.fullname})
	}

	$assembly = [Reflection.Assembly]::LoadWithPartialName("Oracle.ManagedDataAccess")
	if ($assembly -ne $null) {
		$con = [Oracle.ManagedDataAccess.Client.OracleConnection]
		$adap =[Oracle.ManagedDataAccess.Client.OracleDataAdapter]

		$availableDBProvider += New-Object PSObject -Property ([ordered]@{Assembly=$assembly ; Connection=$con.fullname; Adapter=$adap.fullname})
	}

	$assembly = [Reflection.Assembly]::LoadWithPartialName("MySql.Data")
	if ($assembly -ne $null) {
		$con = [MySql.Data.MySqlClient.MySqlConnection]
		$adap =[MySql.Data.MySqlClient.MySqlDataAdapter]

		$availableDBProvider += New-Object PSObject -Property ([ordered]@{Assembly=$assembly ; Connection=$con.fullname; Adapter=$adap.fullname})
	}

	$availableDBProvider
}

$chCol = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$chcol.add((New-Object Management.Automation.Host.ChoiceDescription -Arg "&Nein, keine Änderungen"))
$chcol.add((New-Object Management.Automation.Host.ChoiceDescription -Arg "&Ja, neue Anmeldedaten"))

if ((Get-Host).ui.PromptForChoice('DB Passwort', "Wollen Sie (neue) Datenbank Zugangsdaten hinterlegen?", $chCol, 0) -eq 1) {
	Get-Credential -Message 'Datenbank Zugangsdaten' | Export-Clixml ("$PSScriptRoot\cred-db.xml")
}

if ((Get-Host).ui.PromptForChoice('Mail Passwort', "Wollen Sie (neue) Mailserver Zugangsdaten hinterlegen?", $chCol, 0) -eq 1) {
	Get-Credential -Message 'Mailserver Zugangsdaten' | Export-Clixml ("$PSScriptRoot\cred-mail.xml")
}

. "$PSScriptRoot\config.ps1"
import-module "$PSScriptRoot\mpnd.psd1" -force

if (test-path variable:NotfallDatenRootDir) {
	try {
		$db_kis.open()
	} catch {
		Write-Error "Es konnte keine Verbindung zur Datenbank '$($db_KIS.ConnectionString)' aufgebaut werden"
	}

	$erg = $null
	$erg = (Read-KisDBScalar $BASIC_SQL_TEST -ea SilentlyContinue)
	if ($erg -eq $null) {
		Write-Error 'Es wurden keine Patienten in der Datenbank gefunden oder die Struktur der Datenbank wird nicht erkannt'
	}

	if ($MailHost -ne '') {
		Send-MailMessage -SmtpServer $MailHost -From $MailFrom -To $MailTo -Subject 'KIS Notfalldaten - Email Versand' -Body 'Testnachricht der KIS Notfalldaten'
		write-warning "Bitte prüfen ob eine Email an die hinterlegte Adresse '$MailTo' gesendet werden konnte"
	} else {
		write-warning 'Es wurde keine SMTP Emailserver konfiguriert'
	}

	New-Item -Path "$PSScriptRoot\archive" -ItemType Directory -ea SilentlyContinue
	New-Item -Path "$PSScriptRoot\work" -ItemType Directory -ea SilentlyContinue

	if (-not (Test-Path "$PSScriptRoot\Notfallpcs.csv")) {
		New-Object psobject -Property ([ordered]@{WS=$env:COMPUTERNAME;Station='*'}) | Export-Csv "$PSScriptRoot\Notfallpcs.csv" -NoTypeInformation -Delimiter ';'
		write-warning 'Notfallpcs Datei erstellt'
	}

	if (-not (Test-Path "$NotfallDatenRootDir\Verzeichnisrechte.bin.xml")) {
		write-warning 'Verzeichnisrechte existieren nicht'
	}
} else {
	Write-Error "Die Config Datei ist noch nicht fertig konfiguriert"
}



Read-Host -prompt "[Enter] zum Beenden"