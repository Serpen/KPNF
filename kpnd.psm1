Set-Variable -Name FileVersion -Value ([Version]'1.0') -Option Constant 

Set-StrictMode -Version Latest

$MailArg = @{
    'SmtpServer'=$MailHost;
    'From'=$MailFrom;
    'Attachments'="$NotfallDatenRootDir\work\Pat.log"
}

<#
.SYNOPSIS
Exportiert die aktuellen KIS Patientendaten

.DESCRIPTION
Durchläuft alle Patienten und fragt pro Patient per SQL Wertebereich zum Patienten ab,
abschließend werden die Patientendaten in einer XML-Datei gespeichert

.PARAMETER patFilter
Begrenz die Abfrage auf einen Patientenfallnummer bzw. ein Patientenfallnummerschema
Eine Angabe dieses Parameters schaltet das Skript in des Testmodus

.PARAMETER wdsFilter
Begrenz die Abfrage auf eine Station
Eine Angabe dieses Parameters schaltet das Skript in des Testmodus

#>
function Export-PatientenNotfallDaten {
[CmdletBinding()]
param (
	[string]$patFilter = '%', 
	[string]$wdsFilter = '%',
	[Switch]$TestModus = (($patFilter -ne '%') -or ($wdsFilter -ne '%') )
)

del "$NotfallDatenRootDir\work\Pat.log" -ErrorAction SilentlyContinue

Write-Protokoll "Starte Export-PatientenNotfallDaten"
Write-Protokoll " Version $FileVersion"
Write-Protokoll " $($db_kis.GetType().Name) Version $($db_kis.GetType().assembly.GetName().Version.tostring())"

#Variablen für die Iteration durch die Patienten
[string]$mypat = ''
[string]$myper = ''
[int]$myDaysLookBack = $DaysLookBack

[int]$PatZaehler = 0

[xml.xmlwriter]$xml = $null

Write-Protokoll "Datenbankverbindung herstellen"
if ($db_kis.state -ne 'Open') {
    [void] $db_kis.open()
}

if ($db_kis.state -ne 'Open') {
    #Prüfen ob Verbindung erfolgreich
    Write-Protokoll -GenerateError 'KIS Datenbank nicht erreichbar, Abbruch'
	if ($MailHost -ne '') {
		Send-MailMessage @MailArg -to $ErrorMailTo -Subject 'KIS Notfalldaten - Fehler' -Body 'KIS Datenbank nicht erreichbar, Abbruch'
	}
    return
}

Write-Protokoll " $($db_kis.GetType().Name) ServerVersion $($db_kis.ServerVersion)"

Write-Protokoll "Datenbankabfrage testen"

try {
if ((Read-KisDBScalar "SELECT 1 FROM dual") -ne 1) {
    Write-Protokoll -GenerateError 'Datenbankabfrage nicht möglich, Abbruch'
	if ($MailHost -ne '') {
		Send-MailMessage @MailArg -to $ErrorMailTo  -Subject 'KIS Notfalldaten - Fehler' -Body 'Datenbankabfrage nicht möglich, Abbruch'
	}
    return
}
} catch {
    Write-Protokoll -GenerateError 'Datenbankabfrage nicht möglich, Abbruch'
    return
	#Send-MailMessage @MailArg -to $ErrorMailTo  -Subject 'KIS Notfalldaten - Fehler' -Body 'Datenbankabfrage nicht möglich, Abbruch'
}



$Querys = New-Object "System.Collections.Generic.Dictionary[String,System.Data.Common.DbCommand]"
$Modules = New-Object "System.Collections.Generic.Dictionary[String,xml]"

Write-Protokoll "Laden der Module"

## XSL generieren
Write-DefinitionFiles

$Query_PATs = $db_kis.CreateCommand()
$Query_PATs.CommandText = (Get-Content -raw "$PSScriptRoot\module\pats.sql")

Write-Protokoll "Bereinigung des Arbeitsverzeichnisses"
if ($patFilter -eq '%' -and $wdsFilter -eq '%') { # Kein Testbetrieb
    del "$NotfallDatenRootDir\work\pat-*.xml"
}

Write-Protokoll "Datenbankabfrage auf alle Patienten starten"

$allePat = Read-KisDB $Query_PATs -Parameters @{wdsFilter=$wdsFilter;patFilter=$patFilter;Mandant=$Mandant}

#Pfortenliste
$allePat | select @{l='Name'; e={$_.namechr}}, @{l='Geschlecht';e={$_.sex}}, @{l='Sperre'; e={$_.inflock}}, @{l='Station'; e={$_.wds}} | sort name | export-csv "$NotfallDatenRootDir\work\pat-pforte-FEK.csv" -NoTypeInformation -Delimiter "`t" -Encoding Unicode

[int]$allePatCount=($allePat | measure-object).Count

############################ Schleife: Abfrage über alle Patienten ############################
$allePat | foreach {
    $PatZaehler++
    Write-Progress -Activity "Datenbankabfragen" -status "Abfrage ausführen für" -CurrentOperation $mypat -PercentComplete ($PatZaehler / $allePatCount * 100)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $mypat = $psitem.pat
    $myper = $psitem.per

    Write-Protokoll " Verarbeite PAT $mypat"

    if ($psitem.typ -ne 'S') {
        Write-Verbose $psitem.typ
    }

    [string]$filename = "$NotfallDatenRootDir\work\pat-$($psitem.wds)-$($psitem.dep)-$mypat-$($psitem.namechr)-$(get-date $psitem.birthd -format 'dd.MM.yyyy').xml"
    $xml = [xml.xmlwriter]::Create($filename, $xmlset)
    
    $xml.WriteStartDocument()

    #Stylesheet zur Formatierung der XML Ausgabe
    $xml.WriteProcessingInstruction('xml-stylesheet', 'type="text/xsl" href="pat.xsl"')
	
    $xml.WriteComment("KIS Notfalldaten generated from $env:USERNAME@$env:COMPUTERNAME at $(get-date -Format $DateFormat)")
    $xml.WriteStartElement('notfall')
	$xml.WriteAttributeString("version",$FileVersion.toString())
	 
    #Patientenkopfdaten
    $xml.WriteStartElement('patient')
        $xml.WriteElementString('pat', $psitem.pat)
        $xml.WriteElementString('per', $psitem.per)
        $xml.WriteElementString('namechr', $psitem.namechr)
        $xml.WriteElementString('sex', $psitem.sex)
        $xml.WriteElementString('admd', (get-date $psitem.admd -Format $DBDateFormat)) 
        $xml.WriteElementString('typ', $psitem.typ)
        $xml.WriteElementString('birthd', (get-date $psitem.birthd -Format $DBDateFormat))
        $xml.WriteElementString('wds', $psitem.wds)
        $xml.WriteElementString('dep', $psitem.dep)
        $xml.WriteElementString('timestamp', (get-date -Format $DateFormat))
        $xml.WriteElementString('kranktage', $psitem.kranktage)
        $xml.WriteElementString('postopkranktage', $psitem.postoperativ_tage)
    $xml.WriteEndElement()

    foreach ($mod in $Modules.GetEnumerator()) {
        [string]$converterFunction = $mod.value.notfalldatenmodul.converter.InnerText
        $parameterUebergabe = @{}
        #foreach ($modparam in $mod.Value.SelectNodes('/notfalldatenmodul/parameter/')) {
        foreach ($modparam in $mod.value.notfalldatenmodul.parameter.ChildNodes) {
            $parameterUebergabe[$modparam.InnerText] = Get-Variable -Name "my$($modparam.InnerText)" -ValueOnly
        }

        $_typeX = $mod.value.notfalldatenmodul.xsl.type
        if ($converterFunction -eq 'Convert-QueryToXML') {
            Convert-QueryToXML -query $($Querys[$_typeX]) -para $parameterUebergabe -xmlwriter $xml -type $($_typeX) -subtype $($Mod.value.notfalldatenmodul.xsl.subtype)
        } else {
            if (Test-Path "function:\$converterFunction") {
                & $converterFunction -query ($Querys[$_typeX]) -para $parameterUebergabe -xmlwriter $xml -type $($_typeX) -subtype $($Mod.value.notfalldatenmodul.xsl.subtype)
            } else {
                Write-Protokoll -GenerateError "$($mod.value.notfalldatenmodul.Name) verwendet einen nicht unterstützten Converter"
            }
        }
    }

    Write-Protokoll " PAT $mypat in $($sw.ElapsedMilliseconds) ms verarbeitet"
    $xml.WriteComment("KIS Notfalldaten generated $($sw.ElapsedMilliseconds) ms")

    #Dokument (ab-)schließen
    $xml.WriteEndDocument()
    $xml.Close()
} ############################ ENDE Schleife: Abfrage über alle Patienten ############################

Write-Progress -Completed -Activity "Verarbeite Patient"

Write-Protokoll "Datenbankabfrage komplett"

#Nur wenn es sich nicht um einen Testbetrieb handelt, werden die Daten auf die Clients kopiert
if (-not $Testmodus) {
	
    #Stammdaten ins Arbeitsverzeichnis duplizieren
	copy "$NotfallDatenRootDir\pat.*" "$NotfallDatenRootDir\work"
    
    #Die letzten Rohdaten löschen und durch neue ersetzen
    del "$NotfallDatenRootDir\archive\pat-*.xml"
    & "$zipper" "$zipperArgCreate" "$NotfallDatenRootDir\archive\Pat-$(get-date -Format 'yyyy-MM-dd-HH').zip" "$NotfallDatenRootDir\work\*.*" | out-null
	mv "$NotfallDatenRootDir\work\*.*" "$NotfallDatenRootDir\archive" -force
    
    Write-Protokoll "Daten auf Clients kopieren"

    $notfallPCs = Import-Csv $NotfallDatenRootDir\Notfallpcs.csv -Delimiter ';'
    [int]$notfallPCsCount = ($notfallPCs | measure-object).Count
    [int]$notfallPCsCounter=0
    # Pro NotfallPC einen CopyJob der Stationspatienten durchführen
    $notfallPCs | foreach {
        $notfallPCsCounter++
        Write-Progress -Activity "Lokale Kopiervorgänge" -status "Kopieren" -CurrentOperation $psitem.ws -PercentComplete ($notfallPCsCounter / $notfallPCsCount * 100)
        if ((Test-Path "\\$($psitem.ws)\c$")) { #Wenn Zugriff auf das c$ möglich ist
            if (-not (Test-Path "\\$($psitem.ws)\$clientPathRoot\")) {
                mkdir "\\$($psitem.ws)\$clientPathRoot\" #Verzeichnis anlegen
			    if (Test-Path "$NotfallDatenRootDir\Verzeichnisrechte.bin.xml") {
				    Set-Acl "\\$($psitem.ws)\$clientPathRoot" -AclObject (Import-Clixml "$NotfallDatenRootDir\Verzeichnisrechte.bin.xml") #Rechte setzen
                }
            }
            Write-Protokoll "   kopiere auf \\$($psitem.ws)"
            if (-not (Test-Path "\\$($psitem.ws)\$clientPathRoot\archiv")) {mkdir "\\$($psitem.ws)\$clientPathRoot\archiv"} #Verzeichnis anlegen
            del  "\\$($psitem.ws)\$clientPathRoot\archiv\pat-$($psitem.station)*-*.*"
            move "\\$($psitem.ws)\$clientPathRoot\pat-$($psitem.station)-*.*" "\\$($psitem.ws)\$clientPathRoot\archiv"
            copy "$NotfallDatenRootDir\archive\pat-$($psitem.station)-*.*" "\\$($psitem.ws)\$clientPathRoot\"
            copy "$NotfallDatenRootDir\archive\pat.*" "\\$($psitem.ws)\$clientPathRoot\" -Force
            del "\\$($psitem.ws)\$clientPathRoot\pat.log"
        }
    }

    Write-Progress -Completed -Activity "Lokale Kopiervorgänge"

    #Inhalt des Arbeitsverzeichnisses in ein Archiv komprimieren
    Write-Protokoll "Komprimiere Daten"
    Write-Protokoll "  erfolgreich komprimiert"
}

# An einem der letzten Monatstage das Archiv bereinigen
if ((Get-Date).day -eq 27) {
    Write-Protokoll "Archivdateien werden bereinigt"
	dir "$NotfallDatenRootDir\archive\*.zip" | where {$psitem.CreationTime.Month -ne ((get-date).month)} | del
}

Write-Protokoll "Workflow abgeschlossen"
if ($MailHost -ne '' -and !$TestModus) {
	Send-MailMessage @MailArg -to $MailTo  -Subject 'KIS Notfalldaten - Erfolg' -Body "$(get-date -Format $DateFormat) KIS Notfalldaten Workflow abgeschlossen"
}


} ### end function Export-PatientenNotfallDaten ####################################################
########################################################################################################
########################################################################################################

<#
.SYNOPSIS
Liest Daten aus der KIS Datenbank

.DESCRIPTION
Sendet eine SELECT-sQL Abfrage an die KISdatenbank und gibt das Ergebnis als Datetable zurück

.PARAMETER QueryString
Eine SQL Select Abfrage

.EXAMPLE
Read-KisDB 'Select COUNT(pat) FROM x1100pat'
#>
function Read-KisDB {
[CmdletBinding()]
param (
	[Parameter(Mandatory=$true)][System.Data.Common.DbCommand]$Command,
    [Parameter(Mandatory=$true)][hashtable]$Parameters
)

    $Command.Parameters.Clear()
    foreach ($p in $Parameters.GetEnumerator()) {
        $Command.Parameters.Add(":$($p.key)", $p.value) | Out-Null
    }    
	[System.Data.Common.DbDataAdapter]$adapter = New-Object $DBAdapterType $Command
	[Data.DataTable]$datatable = New-Object System.Data.DataTable
    
    try {
	    [void] $adapter.Fill($datatable)
        $datatable
    } catch {
        Write-Protokoll -GenerateError $psitem
    }
}

function Read-KisDBScalar {
[CmdletBinding()]
param (
	[Parameter(Mandatory=$true)][string]$Query
)
	$cmd = $db_kis.CreateCommand()
	$cmd.CommandText = $Query
	$cmd.ExecuteScalar()
}

########################################################################################################

<#
.SYNOPSIS
Schreib die Query Ergebnisse in eine XML Struktur

.PARAMETER Query
Eine SQL Select Abfrage als Command

.PARAMETER Parameters
Ein Hashtable mit Parameters für den Query

.PARAMETER XmlWriter
Eine referenz auf einen bereits erstellen XMLWriter in den geschrieben wird

.PARAMETER Type
Der XML Name der Oberkategorie für die Abfrage

.PARAMETER subtype
Der XML Name der Unterkategorie, spiegelt eine Zeilen im Ergebnis wieder

.EXAMPLE
Convert-QueryToXML 'Select pat,namechr FROM x1100pat' -XmlWriter $myxmlwriter -type 'diagnosen' -subtype 'diagnose'
#>
function Convert-QueryToXML {
param (
    [Parameter(Mandatory=$true)] [System.Data.Common.DbCommand]$Query,
    [Parameter(Mandatory=$true)] [hashtable]$Parameters,
    [Parameter(Mandatory=$true)] [xml.xmlwriter]$XmlWriter,
    [Parameter(Mandatory=$true)] [string]$type, 
    [Parameter(Mandatory=$false)][string]$subtype = "$($type)s"
    )

	Write-Protokoll "      Verarbeite $type"
 
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
	
    $Query.Parameters.Clear()
    foreach ($p in $Parameters.GetEnumerator()) {
        $Query.Parameters.Add(":$($p.key)", $p.value) | Out-Null
    }    
	[System.Data.Common.DbDataAdapter]$adapter = New-Object $DBAdapterType $Query
	[Data.DataTable]$erg = New-Object System.Data.DataTable
    
    try {
	    [void] $adapter.Fill($erg)
    } catch {
        Write-Protokoll -GenerateError $psitem
        return
    }

    [int]$ergcount = $erg.Rows.Count
    
    if ($erg -ne $null) {
        $xmlwriter.WriteStartElement($type)
        foreach ($currentrow in $erg) {

            #Schreibt Name-Value Pairs in den XMLWriter
            $xmlwriter.WriteStartElement($subtype)
                $erg | get-member -membertype Property | foreach {
                    $cname = $_.name.ToLower() #Name der Column in Kleinschreibung
                    if ($currentRow[$cname] -is [datetime]) {
                        $xmlwriter.WriteElementString($cname, (get-date ($currentRow[$cname]) -Format $DBDateFormat))
                    } else {
                        $xmlwriter.WriteElementString($cname, $currentRow[$cname])
                    }
                }
            $xmlwriter.WriteEndElement()
        }
	
	    
	

        $xmlwriter.WriteComment("generated $type in $($sw.ElapsedMilliseconds) ms")
        $xmlwriter.WriteEndElement()
    }

    $sw.Stop()

    Write-Protokoll "         $($ergcount) Ergebnissen in $($sw.ElapsedMilliseconds) ms"

    
}

########################################################################################################

function Convert-MedikationToXML {
param (
    [Parameter(Mandatory=$true)] [System.Data.Common.DbCommand]$Query,
    [Parameter(Mandatory=$true)] [hashtable]$Parameters,
    [Parameter(Mandatory=$true)] [xml.xmlwriter]$XmlWriter,
    [Parameter(Mandatory=$true)] [string]$type, 
    [Parameter(Mandatory=$false)][string]$subtype = "$($type)s"
    )

    Write-Protokoll "      Verarbeite Medikation"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $Query.Parameters.Clear()
    foreach ($p in $Parameters.GetEnumerator()) {
        $Query.Parameters.Add(":$($p.key)", $p.value) | Out-Null
    }    
	[System.Data.Common.DbDataAdapter]$adapter = New-Object $DBAdapterType $Query
	[Data.DataTable]$erg = New-Object System.Data.DataTable
    
    try {
	    [void] $adapter.Fill($erg)
    } catch {
        Write-Protokoll -GenerateError $psitem
        return
    }

    [int]$ergcount = $erg.Rows.Count

    if ($erg -ne $null) {
        $xml.WriteStartElement($type)

        foreach ($aktMedi in $erg) { 
            $xml.WriteStartElement($subtype)
            $xml.WriteElementString('mdc', $aktMedi.mdc)
            $xml.WriteElementString('des', $aktMedi.des)
            $xml.WriteElementString('wirkstoff', $aktMedi.wirkstoff)

            #Die Gabefrequenzen als Subitems modellieren, die am Absatzzeichen getrennt werden
            $xml.WriteStartElement('adm_info')
                $xml.WriteString($aktMedi.ADM_INFO)
            $xml.WriteEndElement()

            $xml.WriteElementString('adm_roa', $aktMedi.ADM_ROA)
            $xml.WriteElementString('datf', (get-date ($aktMedi.datf) -Format $DBDateFormat))
            $xml.WriteElementString('datt', (get-date ($aktMedi.datt) -Format $DBDateFormat) )
            $xml.WriteElementString('status', $aktMedi.status)
            $xml.WriteElementString('orderer', $aktMedi.orderer)
            $xml.WriteElementString('orderts', (get-date ($aktMedi.orderts) -Format $DBDateFormat))
            $xml.WriteElementString('comment', $aktMedi.DOS_COMMENT)

            #Merkmal für Bedarfsmedikation
            [String]$bedarf = ''
            if ($aktMedi.ADD_ONDEMAND -eq 1) {
                $bedarf = 'bei Bedarf '
            } else {
                $bedarf = ''
            }

            #Unterschiedliche Serienschemata unterscheiden
	        switch ($aktMedi.sertype) {
		        0 { #täglich
			        if ($aktMedi.periodicity -eq 1)  {
				        $xml.WriteElementString('periodicity', $bedarf + 'jeden Tag')
			        } else {
				        $xml.WriteElementString('periodicity', $bedarf + "jeden $($aktMedi.periodicity). Tag")
			        }
		        }
		        1 { #wöchentlich
                    #Bitmasken für die Wochentage
			        [string[]]$wtname = @('So','Mo','Di', 'Mi', 'Do', 'Fr', 'Arbeitstage', 'Sa', 'Wochenendtage', 'Jeden Tag')
                    [byte[]]$wtint = @(1,2,4,8,16,32,62,64,65,127)

                    #Die Gabetage in einem Stack verwalten
                    [System.Collections.Stack]$st = New-Object System.Collections.Stack

			        if ($aktMedi.weekdays -eq 127) {
				        $st.Push($wtname[9])
			        } elseif ($aktMedi.weekdays -eq 65) {
				        $st.Push($wtname[8])
			        } else {
				        $rest = $aktMedi.weekdays
				        [int]$i = 7 # (bis vor Wocheendetage) runterzaehlen
				        while ($rest -ne 0) {
					        $tmp = $rest - $wtint[$i]
					        if ($tmp -ge 0) {
						        $st.Push($wtname[$i])
						        $rest = $tmp
					        }
					        $i--
				        }
			        }
						
                    if ($aktMedi.periodicity -eq 1)  {
				        $xml.WriteElementString('periodicity', $bedarf + 'jede Woche ' + ($st.ToArray() -join ', '))
			        } else {
				        $xml.WriteElementString('periodicity', $bedarf + "jede $($aktMedi.periodicity). Woche" + ($st.ToArray() -join ', '))
			        }
		        }
                2 { #monatlich
                    # wird bis dato nicht genutzt
                    Write-Protokoll -GenerateError "$(Get-Date -format $DateFormat)        monatliches Gabeschema für $mypat entdeckt, wird noch nicht unterstützt"
                    $xml.WriteElementString('periodicity', 'unbekannt monatlich')
                }
	        }
            $xml.WriteEndElement()
        }

        
        $xml.WriteComment("generated medis in $($sw.ElapsedMilliseconds) ms")
        $xml.WriteEndElement()
    }
    Write-Protokoll "          in $($sw.ElapsedMilliseconds) ms"
}

########################################################################################################

function Write-Protokoll {
    param([String]$Text,
        [Switch]$GenerateError)

    if (!$GenerateError) {
        Write-Verbose "$(Get-Date -format $DateFormat) $Text"
    } else {
        Write-Error "$(Get-Date -format $DateFormat) $Text"
    }
    "$(Get-Date -format $DateFormat) $Text" | Out-File "$NotfallDatenRootDir\work\Pat.log" -Append
}

########################################################################################################

function ConvertFrom-XslToHTML {
param (
    [Parameter(Mandatory=$true)][string]$source,
    [Parameter(Mandatory=$true)][string]$xsl,
    [Parameter(Mandatory=$true)][string]$destination
)
begin {
    [System.Xml.Xsl.XslCompiledTransform]$xslTrans = new-object System.Xml.Xsl.XslCompiledTransform
    $xslTrans.Load($xsl)
} process {
    [System.Xml.XPath.XPathDocument]$xpdoc = new-object System.Xml.XPath.XPathDocument $source

    [System.Xml.XmlTextWriter]$writer = New-Object System.Xml.XmlTextWriter ($destination, [System.Text.UnicodeEncoding]::Unicode)
    $writer.Formatting = 'Indented'

    $xslTrans.Transform($xpdoc, $null, $writer)
    $writer.Close()
}    
}

########################################################################################################

function Write-DefinitionFiles {
    $xmlwriter = [xml.xmlwriter]::Create("$NotfallDatenRootDir\work\pat.xsl", $xmlset)
    $xmlwriter | Add-Member -MemberType ScriptMethod -Name WriteStartXslElement -Value {param ([string]$Name) $this.WriteStartElement("xsl",$Name,"http://www.w3.org/1999/XSL/Transform")}
    $xmlwriter.WriteStartDocument()
    $xmlwriter.WriteStartElement("xsl","stylesheet","http://www.w3.org/1999/XSL/Transform")
    $xmlwriter.WriteAttributeString("version","1.0")

    $xmlwriter.WriteStartElement("xsl","template","http://www.w3.org/1999/XSL/Transform")
        $xmlwriter.WriteAttributeString("match","/")

        $xmlwriter.WriteStartElement("html")
            $xmlwriter.WriteStartElement("head")
                $xmlwriter.WriteStartElement("title")
                    $xmlwriter.WriteString("FEK-Notfalldaten-")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","/notfall/patient/namechr")
                    $xmlwriter.WriteEndElement()
                    $xmlwriter.WriteString("-")

                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","/notfall/patient/pat")
                    $xmlwriter.WriteEndElement()
                    $xmlwriter.WriteString("-*")

                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","/notfall/patient/birthd")
                    $xmlwriter.WriteEndElement()
                $xmlwriter.WriteEndElement() #title

                $xmlwriter.WriteStartElement("link")
                    $xmlwriter.WriteAttributeString("rel","stylesheet")
                    $xmlwriter.WriteAttributeString("type","text/css")
                    $xmlwriter.WriteAttributeString("href","pat.css")
                    $xmlwriter.WriteAttributeString("media","all")
                $xmlwriter.WriteEndElement() #link
            $xmlwriter.WriteEndElement() #head

            $xmlwriter.WriteStartElement("body")
                $xmlwriter.WriteStartElement("xsl","apply-templates","http://www.w3.org/1999/XSL/Transform")
                $xmlwriter.WriteEndElement() #apply-templates

                $xmlwriter.WriteStartElement("h1")
                    $xmlwriter.WriteAttributeString("id","notizen")
                $xmlwriter.WriteEndElement() #h1

                1 .. 7 | foreach {
                $xmlwriter.WriteStartElement("br")
                $xmlwriter.WriteEndElement()
                }

            $xmlwriter.WriteEndElement() #body
        $xmlwriter.WriteEndElement() #html
    $xmlwriter.WriteEndElement() #xsltemplate

    $xmlwriter.WriteStartElement("xsl","template","http://www.w3.org/1999/XSL/Transform")
        $xmlwriter.WriteAttributeString("match","patient")

        $xmlwriter.WriteStartElement("table")
            $xmlwriter.WriteAttributeString("id","tblPatient")

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteElementString("th","Fall:")

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","pat")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteAttributeString("rowspan","9")
                    $xmlwriter.WriteAttributeString("id","toc")

                    $xmlwriter.WriteStartElement("ol")
                        #foreach ($modFile in (ls "$PSScriptRoot\module\*.xml" -rec | sort name)) {
                        foreach ($moduleXml in $Modules.GetEnumerator()) {
                            [string]$moduleName = $moduleXml.value.notfalldatenmodul.xsl.type

                            $xmlwriter.WriteStartElement("li")
                                $xmlwriter.WriteStartElement("a")
                                    $xmlwriter.WriteAttributeString("href","#$moduleName")
                                    $xmlwriter.WriteString($moduleXml.value.notfalldatenmodul.name)
                                $xmlwriter.WriteEndElement() #a
                            $xmlwriter.WriteEndElement() #li
                        } #end foreach

                    $xmlwriter.WriteEndElement() #ol
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("Name:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","namechr")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("Geburtsdatum:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","birthd")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("Station:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","typ")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                    $xmlwriter.WriteString("-")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","wds")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                    $xmlwriter.WriteString("-")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","dep")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("Geschlecht:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","sex")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("Aufnahme:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","admd")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("Krankheitstage:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","kranktage")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

        
            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("postoperative Krankheitstage:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","postopkranktage")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr

            $xmlwriter.WriteStartElement("tr")
                $xmlwriter.WriteStartElement("th")
                    $xmlwriter.WriteString("Datenstand:")
                $xmlwriter.WriteEndElement() #th

                $xmlwriter.WriteStartElement("td")
                    $xmlwriter.WriteStartElement("xsl","value-of","http://www.w3.org/1999/XSL/Transform")
                        $xmlwriter.WriteAttributeString("select","timestamp")
                    $xmlwriter.WriteEndElement() #xsl:value-of
                $xmlwriter.WriteEndElement() #td
            $xmlwriter.WriteEndElement() #tr
        $xmlwriter.WriteEndElement() #table
    $xmlwriter.WriteEndElement() #xsl:template

    #foreach ($modFile in (ls "$PSScriptRoot\module\*.xml" | sort name)) {
    foreach ($modFile in $KPNDModule) {
        #[xml]$moduleXml = Get-Content $modfile
        [xml]$moduleXml = Get-Content "$PSScriptRoot\module\$modFile"
		
        [string]$moduleName = $moduleXml.notfalldatenmodul.xsl.type

        $Querys.Add($moduleName, $db_kis.CreateCommand())
        $Modules.Add($moduleName, $moduleXml)

        $Querys[$moduleName].CommandText = $moduleXml.notfalldatenmodul.sql
        $Querys[$moduleName].Prepare()

            $xmlwriter.WriteStartElement("xsl","template", "http://www.w3.org/1999/XSL/Transform")
                $xmlwriter.WriteAttributeString("match", $moduleXml.notfalldatenmodul.xsl.type)
            
                $xmlwriter.WriteStartElement("h1")
                    $xmlwriter.WriteAttributeString("id", $moduleXml.notfalldatenmodul.xsl.type)
                    $xmlwriter.WriteString($moduleXml.notfalldatenmodul.name)
                $xmlwriter.WriteEndElement() #h1

                $xmlwriter.WriteStartElement("table")
                    $xmlwriter.WriteAttributeString("id", "tbl$($moduleXml.notfalldatenmodul.xsl.type)")
                
                    $xmlwriter.WriteStartElement("thead")
                        $xmlwriter.WriteStartElement("tr")
                            foreach ($header in $moduleXml.notfalldatenmodul.xsl.columns.ChildNodes) {
                                $xmlwriter.WriteElementString("th", $header.innerText)
                            }
                        $xmlwriter.WriteEndElement() #tr
                    $xmlwriter.WriteEndElement() #thead

                    $xmlwriter.WriteStartElement("tbody")
                        $xmlwriter.WriteStartElement("xsl","for-each", "http://www.w3.org/1999/XSL/Transform")
                            $xmlwriter.WriteAttributeString("select", $moduleXml.notfalldatenmodul.xsl.subtype)

                            $xmlwriter.WriteStartElement("xsl","variable", "http://www.w3.org/1999/XSL/Transform")
                                $xmlwriter.WriteAttributeString("name", "css-class")

                                $xmlwriter.WriteStartElement("xsl","choose", "http://www.w3.org/1999/XSL/Transform")
                                    $xmlwriter.WriteStartElement("xsl","when", "http://www.w3.org/1999/XSL/Transform")
                                        $xmlwriter.WriteAttributeString("test", "position() mod 2 = 0")
                                        $xmlwriter.WriteString("roweven")
                                    $xmlwriter.WriteEndElement() #xsl:when
								
								    $xmlwriter.WriteStartElement("xsl","otherwise", "http://www.w3.org/1999/XSL/Transform")
                                    $xmlwriter.WriteString("rowodd")
                                    $xmlwriter.WriteEndElement() #xsl:otherwise

                                $xmlwriter.WriteEndElement() #xsl:choose
                            $xmlwriter.WriteEndElement() #xsl:variable

                            $xmlwriter.WriteStartElement("tr")
                                $xmlwriter.WriteAttributeString("class", '{$css-class}')

                                foreach ($header in $moduleXml.notfalldatenmodul.xsl.columns.ChildNodes) {
                                    $xmlwriter.WriteStartElement("td")
                                        if ($header.type -eq 'date') {
                                            $xmlwriter.WriteAttributeString("class","date")
                                        } elseif ($header.type -eq 'number') {
                                            $xmlwriter.WriteAttributeString("class","number")
                                        }
                                        $xmlwriter.WriteStartElement("xsl","value-of", "http://www.w3.org/1999/XSL/Transform")
                                            $xmlwriter.WriteAttributeString("select",$header.id)
                                        $xmlwriter.WriteEndElement() #xsl:value-of
                                    $xmlwriter.WriteEndElement() #td
                                }
                            $xmlwriter.WriteEndElement() # tr
                        $xmlwriter.WriteEndElement() #foreach
                    $xmlwriter.WriteEndElement() #tbody

            $xmlwriter.WriteEndElement() #table
            $xmlwriter.WriteEndElement() #template
    }
    $xmlwriter.WriteEndDocument()
    $xmlwriter.Close()
}
