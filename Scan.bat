@echo off
rem ===========================================================================
rem  Scan.bat - Scannen mit dem Canon imageFORMULA DR-C240 (oder jedem anderen
rem  WIA-faehigen Scanner) unter Windows 10/11.
rem
rem  Entwickelt von der IDO GmbH
rem  Anderslebener Str. 40, 39387 Oschersleben
rem
rem  Das Ergebnis wird standardmaessig als mehrseitige PDF-Datei unter
rem  "Eigene Dokumente\Scans" abgelegt.
rem
rem  Aufruf ohne Parameter (z.B. per Doppelklick) = Standardscan.
rem  "Scan.bat /hilfe" zeigt alle Optionen.
rem
rem  Die Datei ist ein Batch-/PowerShell-Hybrid: der Batch-Teil startet
rem  PowerShell mit dem Skriptteil ab der Marke weiter unten.
rem ===========================================================================

setlocal enableextensions
set "SCAN_SELF=%~f0"
set "SCAN_ARGS=%*"

rem --- Wurde die Datei per Doppelklick gestartet? Dann am Ende Fenster offen halten
set "SCAN_PAUSE="
echo "%cmdcmdline%" | find /i "%~nx0" >nul 2>&1 && set "SCAN_PAUSE=1"
rem --- SCAN_NOPAUSE=1 unterdrueckt das Warten (z.B. beim Aufruf aus Scanner.bat)
if defined SCAN_NOPAUSE set "SCAN_PAUSE="

rem --- Codepage auf UTF-8 umstellen (fuer Umlaute), alte Codepage merken
set "SCAN_OLDCP="
for /f "tokens=2 delims=:" %%a in ('chcp 2^>nul') do for /f "tokens=1 delims=. " %%b in ("%%a") do set "SCAN_OLDCP=%%b"
chcp 65001 >nul 2>&1

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo FEHLER: Windows PowerShell wurde nicht gefunden.
    set "SCAN_RC=9"
    goto :ende
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SCAN_SELF,[Text.Encoding]::UTF8); $m='#~'+'PSSTART~'; $p=$t.IndexOf($m); if($p -lt 0){Write-Host 'FEHLER: Skriptteil nicht gefunden.'; exit 9}; & ([scriptblock]::Create($t.Substring($p)))"
set "SCAN_RC=%ERRORLEVEL%"

:ende
if defined SCAN_OLDCP chcp %SCAN_OLDCP% >nul 2>&1
if defined SCAN_PAUSE (
    echo.
    pause
)
endlocal & exit /b %SCAN_RC%

#~PSSTART~
# ===========================================================================
#  PowerShell-Teil: Scannen ueber WIA (Windows Image Acquisition)
# ===========================================================================
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# ---------------------------------------------------------------------------
# Konstanten (WIA-Eigenschafts-IDs)
# ---------------------------------------------------------------------------
$WIA_DPS_DOCUMENT_HANDLING_CAPS   = 3086
$WIA_DPS_DOCUMENT_HANDLING_STATUS = 3087
$WIA_DPS_DOCUMENT_HANDLING_SELECT = 3088
$WIA_DPS_PAGES                    = 3096
$WIA_IPA_DATATYPE                 = 4103
$WIA_IPA_DEPTH                    = 4104
$WIA_IPS_CUR_INTENT               = 6146
$WIA_IPS_XRES                     = 6147
$WIA_IPS_YRES                     = 6148
$WIA_IPS_XPOS                     = 6149
$WIA_IPS_YPOS                     = 6150
$WIA_IPS_XEXTENT                  = 6151
$WIA_IPS_YEXTENT                  = 6152

$HANDLE_FEEDER  = 1
$HANDLE_FLATBED = 2
$HANDLE_DUPLEX  = 4

$FMT_JPEG = '{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}'
$FMT_PNG  = '{B96B3CAF-0728-11D3-9D7B-0000F81EF32E}'
$FMT_BMP  = '{B96B3CAB-0728-11D3-9D7B-0000F81EF32E}'

$ERR_PAPER_EMPTY = -2145320957   # 0x80210003
$ERR_PAPER_JAM   = -2145320958   # 0x80210002
$ERR_OFFLINE     = -2145320939   # 0x80210015

# ---------------------------------------------------------------------------
# Ausgabe-Hilfsfunktionen
# ---------------------------------------------------------------------------
function Info($t)  { Write-Host $t }
function Ok($t)    { Write-Host $t -ForegroundColor Green }
function Warn($t)  { Write-Host "Hinweis: $t" -ForegroundColor Yellow }
function Fehler($t){ Write-Host "FEHLER: $t" -ForegroundColor Red }

function Show-Hilfe {
@'
Scan.bat - Scannen mit dem Canon imageFORMULA DR-C240 unter Windows

  Ohne Parameter wird ein einseitiger Farbscan mit 300 dpi erstellt und als
  PDF unter "Eigene Dokumente\Scans" gespeichert.

VERWENDUNG
  Scan.bat [Optionen]

AUSGABEFORMAT
  /pdf              mehrseitiges PDF (Standard)
  /jpg  /png  /tif  einzelne Bilddateien statt PDF

FARBE
  /farbe            Farbe (Standard)
  /grau             Graustufen
  /sw               Schwarzweiss (Strichzeichnung)

WEITERE OPTIONEN
  /dpi <Zahl>       Aufloesung, z.B. 150, 200, 300, 400, 600 (Standard: 300)
  /duplex           Vorder- und Rueckseite scannen
  /name <Text>      Namensbestandteil der Zieldatei (Standard: Scan)
  /ordner <Pfad>    abweichender Zielordner
  /seiten <Zahl>    hoechstens so viele Seiten einziehen (0 = alle)
  /qualitaet <1-100> JPEG-Qualitaet (Standard: 80)
  /scanner <Text>   Geraet waehlen, wenn mehrere vorhanden sind (Namensteil)
  /liste            gefundene Scanner anzeigen und beenden
  /oeffnen          Ergebnis nach dem Scan oeffnen
  /warten <Sek>     so lange auf eingelegtes Papier warten (Standard: 30)
  /hilfe            diese Hilfe

BEISPIELE
  Scan.bat
  Scan.bat /duplex /grau /dpi 200 /name Rechnung
  Scan.bat /jpg /dpi 600 /ordner "D:\Archiv"
  Scan.bat /liste

HERAUSGEBER
  IDO GmbH - Anderslebener Str. 40 - 39387 Oschersleben
'@ | Write-Host
}

# ---------------------------------------------------------------------------
# WIA-Eigenschaften lesen/schreiben (fehlertolerant)
# ---------------------------------------------------------------------------
function Get-WiaProp($sammlung, $id) {
    foreach ($p in $sammlung) {
        if ($p.PropertyID -eq $id) { return $p }
    }
    return $null
}

function Get-WiaWert($sammlung, $id) {
    $p = Get-WiaProp $sammlung $id
    if ($null -eq $p) { return $null }
    try { return $p.Value } catch { return $null }
}

function Set-WiaWert($sammlung, $id, $wert) {
    $p = Get-WiaProp $sammlung $id
    if ($null -eq $p) { return $false }
    try { $p.Value = $wert; return $true } catch { return $false }
}

function Get-WiaMax($sammlung, $id) {
    $p = Get-WiaProp $sammlung $id
    if ($null -eq $p) { return $null }
    try { return $p.SubTypeMax } catch { return $null }
}

# HResult aus einer (ggf. verschachtelten) Ausnahme herausziehen
function Get-HResult($ausnahme) {
    $e = $ausnahme
    while ($null -ne $e) {
        if ($e -is [System.Runtime.InteropServices.COMException]) { return $e.HResult }
        $e = $e.InnerException
    }
    $e = $ausnahme
    while ($null -ne $e) {
        if ($e.HResult -ne 0) { return $e.HResult }
        $e = $e.InnerException
    }
    return 0
}

# ---------------------------------------------------------------------------
# JPEG-Kopfdaten lesen (Breite, Hoehe, Farbkanaele, Progressiv-Kennung)
# ---------------------------------------------------------------------------
function Get-JpegInfo([byte[]]$b) {
    if ($b.Length -lt 12 -or $b[0] -ne 0xFF -or $b[1] -ne 0xD8) { return $null }
    $i = 2
    while ($i -lt ($b.Length - 9)) {
        if ($b[$i] -ne 0xFF) { $i++; continue }
        $marker = $b[$i + 1]
        if ($marker -eq 0xFF) { $i++; continue }
        if ($marker -eq 0xD8 -or $marker -eq 0x01 -or ($marker -ge 0xD0 -and $marker -le 0xD7)) { $i += 2; continue }
        if ($marker -eq 0xD9 -or $marker -eq 0xDA) { break }
        $laenge = ([int]$b[$i + 2] -shl 8) -bor [int]$b[$i + 3]
        $istSOF = (($marker -ge 0xC0 -and $marker -le 0xC3) -or ($marker -ge 0xC5 -and $marker -le 0xC7) -or
                   ($marker -ge 0xC9 -and $marker -le 0xCB) -or ($marker -ge 0xCD -and $marker -le 0xCF))
        if ($istSOF) {
            return [pscustomobject]@{
                Hoehe       = ([int]$b[$i + 5] -shl 8) -bor [int]$b[$i + 6]
                Breite      = ([int]$b[$i + 7] -shl 8) -bor [int]$b[$i + 8]
                Kanaele     = [int]$b[$i + 9]
                Progressiv  = ($marker -eq 0xC2 -or $marker -eq 0xC6 -or $marker -eq 0xCA)
            }
        }
        if ($laenge -lt 2) { break }
        $i += 2 + $laenge
    }
    return $null
}

# ---------------------------------------------------------------------------
# Bild ueber GDI+ neu kodieren (immer 24-Bit-Baseline-JPEG bzw. Zielformat)
# ---------------------------------------------------------------------------
function Convert-Bild([string]$quelle, [string]$ziel, [string]$format, [int]$qualitaet, [int]$dpi) {
    Add-Type -AssemblyName System.Drawing | Out-Null
    $quellBild = [System.Drawing.Image]::FromFile($quelle)
    try {
        if ($format -eq 'jpg') {
            # JPEG braucht echte Farbkanaele: auf 24 Bit umzeichnen
            $bmp = New-Object System.Drawing.Bitmap($quellBild.Width, $quellBild.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            try {
                $bmp.SetResolution($dpi, $dpi)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                try {
                    $g.Clear([System.Drawing.Color]::White)
                    $g.DrawImage($quellBild, 0, 0, $quellBild.Width, $quellBild.Height)
                } finally { $g.Dispose() }
                $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
                $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
                $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int64]$qualitaet)
                $bmp.Save($ziel, $codec, $ep)
                $ep.Dispose()
            } finally { $bmp.Dispose() }
        }
        else {
            # PNG und TIFF verlustfrei und in der Original-Farbtiefe speichern
            try { $quellBild.SetResolution($dpi, $dpi) } catch { }
            switch ($format) {
                'png' { $quellBild.Save($ziel, [System.Drawing.Imaging.ImageFormat]::Png) }
                'tif' {
                    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/tiff' }
                    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
                    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
                        [System.Drawing.Imaging.Encoder]::Compression, [int64][System.Drawing.Imaging.EncoderValue]::CompressionLZW)
                    $quellBild.Save($ziel, $codec, $ep)
                    $ep.Dispose()
                }
                default { throw "Unbekanntes Zielformat: $format" }
            }
        }
    } finally { $quellBild.Dispose() }
}

# ---------------------------------------------------------------------------
# Mehrseitiges PDF aus JPEG-Dateien bauen (JPEG wird direkt eingebettet)
# ---------------------------------------------------------------------------
function New-PdfAusJpeg([string[]]$bilder, [string]$zielDatei, [int]$dpi) {
    $ascii  = [Text.Encoding]::ASCII
    $stream = New-Object System.IO.MemoryStream
    $offsets = @{}
    $ci = [Globalization.CultureInfo]::InvariantCulture

    $schreibeText = {
        param([string]$s)
        $bytes = $ascii.GetBytes($s)
        $stream.Write($bytes, 0, $bytes.Length)
    }

    & $schreibeText "%PDF-1.4`n"
    $binKommentar = [byte[]](0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A)
    $stream.Write($binKommentar, 0, $binKommentar.Length)

    # Seiteninformationen sammeln
    $seiten = @()
    foreach ($bild in $bilder) {
        $bytes = [IO.File]::ReadAllBytes($bild)
        $info  = Get-JpegInfo $bytes
        if ($null -eq $info -or $info.Breite -le 0 -or $info.Hoehe -le 0) {
            throw "Die Datei '$bild' konnte nicht als JPEG gelesen werden."
        }
        $farbraum = switch ($info.Kanaele) { 1 { '/DeviceGray' } 3 { '/DeviceRGB' } default { $null } }
        if ($null -eq $farbraum) { throw "Nicht unterstuetzter JPEG-Farbraum in '$bild'." }
        $seiten += [pscustomobject]@{
            Bytes    = $bytes
            Breite   = $info.Breite
            Hoehe    = $info.Hoehe
            Farbraum = $farbraum
            BreitePt = [math]::Round($info.Breite * 72.0 / $dpi, 2)
            HoehePt  = [math]::Round($info.Hoehe  * 72.0 / $dpi, 2)
        }
    }

    $anzahl      = $seiten.Count
    $objektAnzahl = 2 + $anzahl * 3

    # Objekt 1: Katalog
    $offsets[1] = $stream.Position
    & $schreibeText "1 0 obj`n<< /Type /Catalog /Pages 2 0 R >>`nendobj`n"

    # Objekt 2: Seitenbaum
    $kinder = (0..($anzahl - 1) | ForEach-Object { "$(3 + $_ * 3) 0 R" }) -join ' '
    $offsets[2] = $stream.Position
    & $schreibeText "2 0 obj`n<< /Type /Pages /Count $anzahl /Kids [ $kinder ] >>`nendobj`n"

    for ($n = 0; $n -lt $anzahl; $n++) {
        $seite     = $seiten[$n]
        $objSeite  = 3 + $n * 3
        $objInhalt = $objSeite + 1
        $objBild   = $objSeite + 2
        $breitePt  = $seite.BreitePt.ToString('0.##', $ci)
        $hoehePt   = $seite.HoehePt.ToString('0.##', $ci)

        # Seitenobjekt
        $offsets[$objSeite] = $stream.Position
        & $schreibeText ("$objSeite 0 obj`n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $breitePt $hoehePt ]" +
                         " /Resources << /XObject << /Im0 $objBild 0 R >> /ProcSet [/PDF /ImageC /ImageB] >>" +
                         " /Contents $objInhalt 0 R >>`nendobj`n")

        # Inhaltsstrom
        $inhalt = "q $breitePt 0 0 $hoehePt 0 0 cm /Im0 Do Q`n"
        $offsets[$objInhalt] = $stream.Position
        & $schreibeText "$objInhalt 0 obj`n<< /Length $($ascii.GetByteCount($inhalt)) >>`nstream`n"
        & $schreibeText $inhalt
        & $schreibeText "endstream`nendobj`n"

        # Bildobjekt (JPEG unveraendert als DCTDecode-Strom)
        $offsets[$objBild] = $stream.Position
        & $schreibeText ("$objBild 0 obj`n<< /Type /XObject /Subtype /Image /Width $($seite.Breite) /Height $($seite.Hoehe)" +
                         " /ColorSpace $($seite.Farbraum) /BitsPerComponent 8 /Filter /DCTDecode" +
                         " /Length $($seite.Bytes.Length) >>`nstream`n")
        $stream.Write($seite.Bytes, 0, $seite.Bytes.Length)
        & $schreibeText "`nendstream`nendobj`n"
    }

    # Querverweistabelle
    $xrefPos = $stream.Position
    & $schreibeText "xref`n0 $($objektAnzahl + 1)`n"
    & $schreibeText "0000000000 65535 f `n"
    for ($n = 1; $n -le $objektAnzahl; $n++) {
        & $schreibeText ("{0:D10} 00000 n `n" -f [int64]$offsets[$n])
    }
    & $schreibeText "trailer`n<< /Size $($objektAnzahl + 1) /Root 1 0 R >>`nstartxref`n$xrefPos`n%%EOF`n"

    [IO.File]::WriteAllBytes($zielDatei, $stream.ToArray())
    $stream.Dispose()
}

# ---------------------------------------------------------------------------
# Argumente auswerten
# ---------------------------------------------------------------------------
$roh = $env:SCAN_ARGS
$argumente = @()
if ($roh -and $roh.Trim().Length -gt 0) {
    $argumente = @([regex]::Matches($roh, '"([^"]*)"|(\S+)') | ForEach-Object {
        if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
    })
}

$format     = 'pdf'
$farbmodus  = 'farbe'
$dpi        = 300
$duplex     = $false
$zielOrdner = $null
$basisName  = 'Scan'
$maxSeiten  = 0
$qualitaet  = 80
$geraetFilter = $null
$nurListe   = $false
$oeffnen    = $false
$wartenSek  = 30

function AlsZahl([string]$wert, [string]$option) {
    $zahl = 0
    if (-not [int]::TryParse($wert, [ref]$zahl)) {
        throw "Der Wert '$wert' zur Option '$option' ist keine ganze Zahl."
    }
    return $zahl
}

function Naechstes([ref]$index, [string]$option) {
    $i = $index.Value + 1
    if ($i -ge $argumente.Count) { throw "Zur Option '$option' fehlt ein Wert." }
    $index.Value = $i
    return $argumente[$i]
}

try {
    for ($i = 0; $i -lt $argumente.Count; $i++) {
        $schalter = $argumente[$i].TrimStart('/', '-').ToLowerInvariant()
        switch ($schalter) {
            'pdf'       { $format = 'pdf' }
            'jpg'       { $format = 'jpg' }
            'jpeg'      { $format = 'jpg' }
            'png'       { $format = 'png' }
            'tif'       { $format = 'tif' }
            'tiff'      { $format = 'tif' }
            'farbe'     { $farbmodus = 'farbe' }
            'color'     { $farbmodus = 'farbe' }
            'grau'      { $farbmodus = 'grau' }
            'graustufen'{ $farbmodus = 'grau' }
            'sw'        { $farbmodus = 'sw' }
            'duplex'    { $duplex = $true }
            'simplex'   { $duplex = $false }
            'liste'     { $nurListe = $true }
            'oeffnen'   { $oeffnen = $true }
            'dpi'       { $dpi        = AlsZahl (Naechstes ([ref]$i) 'dpi') 'dpi' }
            'name'      { $basisName  = (Naechstes ([ref]$i) 'name') }
            'ordner'    { $zielOrdner = (Naechstes ([ref]$i) 'ordner') }
            'seiten'    { $maxSeiten  = AlsZahl (Naechstes ([ref]$i) 'seiten') 'seiten' }
            'qualitaet' { $qualitaet  = AlsZahl (Naechstes ([ref]$i) 'qualitaet') 'qualitaet' }
            'qualität'  { $qualitaet  = AlsZahl (Naechstes ([ref]$i) 'qualitaet') 'qualitaet' }
            'scanner'   { $geraetFilter = (Naechstes ([ref]$i) 'scanner') }
            'warten'    { $wartenSek  = AlsZahl (Naechstes ([ref]$i) 'warten') 'warten' }
            { $_ -in @('hilfe', 'h', '?', 'help') } { Show-Hilfe; exit 0 }
            default { throw "Unbekannte Option '$($argumente[$i])'. 'Scan.bat /hilfe' zeigt alle Optionen." }
        }
    }
} catch {
    Fehler $_.Exception.Message
    exit 2
}

if ($dpi -lt 50 -or $dpi -gt 1200) { Fehler "Die Aufloesung muss zwischen 50 und 1200 dpi liegen."; exit 2 }
if ($qualitaet -lt 1 -or $qualitaet -gt 100) { Fehler "Die Qualitaet muss zwischen 1 und 100 liegen."; exit 2 }
if ($maxSeiten -lt 0) { Fehler "Die Seitenzahl darf nicht negativ sein."; exit 2 }
if ($wartenSek -lt 0) { $wartenSek = 0 }

$ungueltig = [IO.Path]::GetInvalidFileNameChars()
$basisName = -join ($basisName.ToCharArray() | Where-Object { $ungueltig -notcontains $_ })
if ([string]::IsNullOrWhiteSpace($basisName)) { $basisName = 'Scan' }

# ---------------------------------------------------------------------------
# Zielordner bestimmen: standardmaessig "Eigene Dokumente\Scans"
# ---------------------------------------------------------------------------
if (-not $zielOrdner) {
    # GetFolderPath beruecksichtigt auch verschobene Ordner (z.B. nach OneDrive)
    $dokumente = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($dokumente) -and $env:USERPROFILE) {
        $dokumente = [IO.Path]::Combine($env:USERPROFILE, 'Documents')
    }
    if ([string]::IsNullOrWhiteSpace($dokumente)) {
        Fehler "Der Ordner 'Eigene Dokumente' konnte nicht ermittelt werden."
        Info   "Geben Sie das Ziel bitte mit '/ordner <Pfad>' an."
        exit 6
    }
    $zielOrdner = [IO.Path]::Combine($dokumente, 'Scans')
}

# ---------------------------------------------------------------------------
# Scanner suchen
# ---------------------------------------------------------------------------
try {
    $geraeteManager = New-Object -ComObject WIA.DeviceManager
} catch {
    Fehler "Die Windows-Bilderfassung (WIA) ist nicht verfuegbar."
    Info   "Pruefen Sie, ob der Dienst 'Windows-Bilderfassung (WIA)' laeuft:"
    Info   "    net start stisvc"
    exit 3
}

$geraete = @()
$anzahlGeraete = 0
try { $anzahlGeraete = [int]$geraeteManager.DeviceInfos.Count } catch { $anzahlGeraete = 0 }
for ($n = 1; $n -le $anzahlGeraete; $n++) {
    $info = $geraeteManager.DeviceInfos.Item($n)
    if ($info.Type -ne 1) { continue }   # 1 = Scanner
    $name = ''
    try { $name = [string]$info.Properties.Item('Name').Value } catch { }
    if (-not $name) { try { $name = [string]$info.DeviceID } catch { $name = "Scanner $n" } }
    $geraete += [pscustomobject]@{ Name = $name; Info = $info }
}

if ($nurListe) {
    if ($geraete.Count -eq 0) {
        Warn "Es wurde kein Scanner gefunden."
    } else {
        Info "Gefundene Scanner:"
        for ($n = 0; $n -lt $geraete.Count; $n++) { Info ("  [{0}] {1}" -f ($n + 1), $geraete[$n].Name) }
    }
    exit 0
}

if ($geraete.Count -eq 0) {
    Fehler "Es wurde kein Scanner gefunden."
    Info   "Pruefen Sie: Geraet eingeschaltet und per USB verbunden, Canon-WIA-/TWAIN-Treiber"
    Info   "installiert, Geraet erscheint im Geraete-Manager unter 'Bildverarbeitungsgeraete'."
    exit 3
}

$auswahl = $geraete[0]
if ($geraetFilter) {
    $treffer = $geraete | Where-Object { $_.Name -like "*$geraetFilter*" }
    if (-not $treffer) {
        Fehler "Kein Scanner gefunden, dessen Name '$geraetFilter' enthaelt."
        Info   ("Verfuegbar: " + (($geraete | ForEach-Object { $_.Name }) -join ', '))
        exit 3
    }
    $auswahl = @($treffer)[0]
} elseif ($geraete.Count -gt 1) {
    $canon = $geraete | Where-Object { $_.Name -match 'DR-C240|imageFORMULA|Canon' }
    if ($canon) { $auswahl = @($canon)[0] }
}

Info "Scanner: $($auswahl.Name)"

try {
    $geraet = $auswahl.Info.Connect()
} catch {
    Fehler "Die Verbindung zum Scanner ist fehlgeschlagen: $($_.Exception.Message)"
    exit 3
}

$element = $geraet.Items.Item(1)

# ---------------------------------------------------------------------------
# Einzug/Duplex einstellen
# ---------------------------------------------------------------------------
$faehigkeiten = Get-WiaWert $geraet.Properties $WIA_DPS_DOCUMENT_HANDLING_CAPS
if ($null -eq $faehigkeiten) { $faehigkeiten = $HANDLE_FEEDER }
$hatEinzug = ($faehigkeiten -band $HANDLE_FEEDER) -ne 0

$einzugsWert = 0
if ($hatEinzug) {
    $einzugsWert = $HANDLE_FEEDER
    if ($duplex) {
        if (($faehigkeiten -band $HANDLE_DUPLEX) -ne 0) {
            $einzugsWert = $einzugsWert -bor $HANDLE_DUPLEX
        } else {
            Warn "Der Scanner meldet keine Duplex-Faehigkeit - es wird einseitig gescannt."
            $duplex = $false
        }
    }
} elseif (($faehigkeiten -band $HANDLE_FLATBED) -ne 0) {
    $einzugsWert = $HANDLE_FLATBED
}

if ($einzugsWert -ne 0) {
    if (-not (Set-WiaWert $geraet.Properties $WIA_DPS_DOCUMENT_HANDLING_SELECT $einzugsWert)) {
        Warn "Die Einzugsart konnte nicht gesetzt werden - es gilt die Geraeteeinstellung."
    }
}
# Pro Transfer genau eine Seite liefern, die Schleife unten holt die weiteren Seiten.
Set-WiaWert $geraet.Properties $WIA_DPS_PAGES 1 | Out-Null

# ---------------------------------------------------------------------------
# Bildeinstellungen (Farbe, Aufloesung, Scanbereich)
# ---------------------------------------------------------------------------
switch ($farbmodus) {
    'farbe' { $datentyp = 3; $tiefe = 24; $absicht = 1 }
    'grau'  { $datentyp = 2; $tiefe = 8;  $absicht = 2 }
    'sw'    { $datentyp = 0; $tiefe = 1;  $absicht = 4 }
}

Set-WiaWert $element.Properties $WIA_IPS_CUR_INTENT $absicht | Out-Null
if (-not (Set-WiaWert $element.Properties $WIA_IPA_DATATYPE $datentyp)) {
    Warn "Der Farbmodus konnte nicht gesetzt werden - es gilt die Geraeteeinstellung."
}
Set-WiaWert $element.Properties $WIA_IPA_DEPTH $tiefe | Out-Null

# Aufloesung aendern und den Scanbereich mitskalieren, damit nichts abgeschnitten wird
$altDpi     = Get-WiaWert $element.Properties $WIA_IPS_XRES
$altBreite  = Get-WiaWert $element.Properties $WIA_IPS_XEXTENT
$altHoehe   = Get-WiaWert $element.Properties $WIA_IPS_YEXTENT

$dpiGesetzt = (Set-WiaWert $element.Properties $WIA_IPS_XRES $dpi) -and (Set-WiaWert $element.Properties $WIA_IPS_YRES $dpi)
if (-not $dpiGesetzt) {
    Warn "Die Aufloesung $dpi dpi wird nicht unterstuetzt - es gilt die Geraeteeinstellung."
    $dpi = Get-WiaWert $element.Properties $WIA_IPS_XRES
    if (-not $dpi) { $dpi = 300 }
} elseif ($altDpi -and $altDpi -gt 0 -and $altBreite -and $altHoehe) {
    $faktor = $dpi / [double]$altDpi
    if ([math]::Abs($faktor - 1.0) -gt 0.001) {
        $neuBreite = [int][math]::Round($altBreite * $faktor)
        $neuHoehe  = [int][math]::Round($altHoehe  * $faktor)
        $maxBreite = Get-WiaMax $element.Properties $WIA_IPS_XEXTENT
        $maxHoehe  = Get-WiaMax $element.Properties $WIA_IPS_YEXTENT
        if ($maxBreite -and $neuBreite -gt $maxBreite) { $neuBreite = [int]$maxBreite }
        if ($maxHoehe  -and $neuHoehe  -gt $maxHoehe)  { $neuHoehe  = [int]$maxHoehe }
        # Nur anpassen, wenn der Treiber den Bereich nicht selbst nachgezogen hat
        if ((Get-WiaWert $element.Properties $WIA_IPS_XEXTENT) -eq $altBreite) {
            Set-WiaWert $element.Properties $WIA_IPS_XPOS 0 | Out-Null
            Set-WiaWert $element.Properties $WIA_IPS_YPOS 0 | Out-Null
            Set-WiaWert $element.Properties $WIA_IPS_XEXTENT $neuBreite | Out-Null
            Set-WiaWert $element.Properties $WIA_IPS_YEXTENT $neuHoehe  | Out-Null
        }
    }
}

$modusText = switch ($farbmodus) { 'farbe' { 'Farbe' } 'grau' { 'Graustufen' } 'sw' { 'Schwarzweiss' } }
$seitenText = if ($duplex) { 'Duplex' } else { 'Einseitig' }
Info "Einstellungen: $modusText, $dpi dpi, $seitenText, Ausgabe: $($format.ToUpperInvariant())"

# ---------------------------------------------------------------------------
# Transferformat waehlen
# ---------------------------------------------------------------------------
$verfuegbareFormate = @()
try { foreach ($f in $element.Formats) { $verfuegbareFormate += [string]$f } } catch { }

function KannFormat($liste, $guid) {
    if ($liste.Count -eq 0) { return $true }   # Treiber meldet nichts: einfach versuchen
    return ($liste -contains $guid)
}

# Fuer PDF/JPG ist JPEG am sparsamsten, fuer PNG/TIFF und Schwarzweiss
# wird verlustfrei uebertragen, damit nicht zweimal komprimiert wird.
$transferFormat = $FMT_BMP
$transferEndung = '.bmp'
if (($format -eq 'pdf' -or $format -eq 'jpg') -and $farbmodus -ne 'sw' -and (KannFormat $verfuegbareFormate $FMT_JPEG)) {
    $transferFormat = $FMT_JPEG
    $transferEndung = '.jpg'
} elseif (KannFormat $verfuegbareFormate $FMT_PNG) {
    $transferFormat = $FMT_PNG
    $transferEndung = '.png'
}

# ---------------------------------------------------------------------------
# Auf eingelegtes Papier warten
# ---------------------------------------------------------------------------
if ($hatEinzug -and ($einzugsWert -band $HANDLE_FEEDER)) {
    $status = Get-WiaWert $geraet.Properties $WIA_DPS_DOCUMENT_HANDLING_STATUS
    if ($null -ne $status -and ($status -band 1) -eq 0) {
        Info "Bitte Dokument in den Einzug legen ..."
        $frist = (Get-Date).AddSeconds($wartenSek)
        while ((Get-Date) -lt $frist) {
            Start-Sleep -Milliseconds 700
            $status = Get-WiaWert $geraet.Properties $WIA_DPS_DOCUMENT_HANDLING_STATUS
            if ($null -eq $status -or ($status -band 1) -ne 0) { break }
        }
        if ($null -ne $status -and ($status -band 1) -eq 0) {
            Fehler "Es liegt kein Papier im Einzug - der Scan wurde abgebrochen."
            exit 4
        }
    }
}

# ---------------------------------------------------------------------------
# Scannen
# ---------------------------------------------------------------------------
$zeitstempel = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$arbeitsOrdner = [IO.Path]::Combine([IO.Path]::GetTempPath(), "Scan_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $arbeitsOrdner -Force | Out-Null

$rohSeiten = @()
$seitenNr  = 0
$abbruch   = $null

Info ""
try {
    while ($true) {
        if ($maxSeiten -gt 0 -and $seitenNr -ge $maxSeiten) { break }
        $seitenNr++
        Write-Host ("  Seite {0} wird gescannt ..." -f $seitenNr) -NoNewline

        $bild = $null
        try {
            try {
                $bild = $element.Transfer($transferFormat)
            } catch {
                # Meldet der Treiber ein Format, das er nicht liefern kann, auf BMP ausweichen
                $hrErst = Get-HResult $_.Exception
                if ($seitenNr -eq 1 -and $transferFormat -ne $FMT_BMP -and
                    $hrErst -ne $ERR_PAPER_EMPTY -and $hrErst -ne $ERR_PAPER_JAM -and $hrErst -ne $ERR_OFFLINE) {
                    $transferFormat = $FMT_BMP
                    $transferEndung = '.bmp'
                    $bild = $element.Transfer($transferFormat)
                } else {
                    throw
                }
            }
        } catch {
            # angefangene Statuszeile wieder entfernen
            Write-Host ("`r" + (' ' * 44) + "`r") -NoNewline
            $hr = Get-HResult $_.Exception
            if ($hr -eq $ERR_PAPER_EMPTY) {
                $seitenNr--
                break
            }
            if ($hr -eq $ERR_PAPER_JAM)   { $abbruch = "Papierstau im Einzug." ; $seitenNr--; break }
            if ($hr -eq $ERR_OFFLINE)     { $abbruch = "Der Scanner ist offline oder belegt."; $seitenNr--; break }
            if ($seitenNr -gt 1) {
                $abbruch = "Die Uebertragung wurde nach Seite $($seitenNr - 1) beendet ($($_.Exception.Message.Trim()))."
                $seitenNr--
                break
            }
            throw
        }

        $datei = [IO.Path]::Combine($arbeitsOrdner, ("Seite_{0:D4}{1}" -f $seitenNr, $transferEndung))
        if (Test-Path -LiteralPath $datei) { Remove-Item -LiteralPath $datei -Force }
        $bild.SaveFile($datei)
        try { [Runtime.InteropServices.Marshal]::ReleaseComObject($bild) | Out-Null } catch { }
        $rohSeiten += $datei
        Write-Host " fertig"

        if (-not ($einzugsWert -band $HANDLE_FEEDER)) { break }   # Flachbett: nur eine Seite
    }
} catch {
    Write-Host ("`r" + (' ' * 44) + "`r") -NoNewline
    Fehler "Der Scanvorgang ist fehlgeschlagen: $($_.Exception.Message.Trim())"
    Info   "Pruefen Sie, ob das Geraet eingeschaltet ist und keine andere Software (z.B."
    Info   "CaptureOnTouch) den Scanner gerade belegt."
    Remove-Item -LiteralPath $arbeitsOrdner -Recurse -Force -ErrorAction SilentlyContinue
    exit 5
}

if ($abbruch) { Warn $abbruch }

if ($rohSeiten.Count -eq 0) {
    Fehler "Es wurde keine Seite eingezogen."
    Remove-Item -LiteralPath $arbeitsOrdner -Recurse -Force -ErrorAction SilentlyContinue
    exit 4
}

# ---------------------------------------------------------------------------
# Ergebnis ablegen
# ---------------------------------------------------------------------------
try {
    if (-not (Test-Path -LiteralPath $zielOrdner)) {
        New-Item -ItemType Directory -Path $zielOrdner -Force | Out-Null
    }
} catch {
    Fehler "Der Zielordner '$zielOrdner' konnte nicht angelegt werden: $($_.Exception.Message)"
    Remove-Item -LiteralPath $arbeitsOrdner -Recurse -Force -ErrorAction SilentlyContinue
    exit 6
}

function Get-FreierPfad([string]$pfad) {
    if (-not (Test-Path -LiteralPath $pfad)) { return $pfad }
    $ordner  = Split-Path -Parent $pfad
    $name    = [IO.Path]::GetFileNameWithoutExtension($pfad)
    $endung  = [IO.Path]::GetExtension($pfad)
    for ($n = 2; $n -lt 1000; $n++) {
        $neu = [IO.Path]::Combine($ordner, ("{0}_{1}{2}" -f $name, $n, $endung))
        if (-not (Test-Path -LiteralPath $neu)) { return $neu }
    }
    throw "Es konnte kein freier Dateiname in '$ordner' gefunden werden."
}

Info ""
$ergebnis = $null
try {
    if ($format -eq 'pdf') {
        Info "PDF wird erstellt ..."
        $jpegSeiten = @()
        foreach ($seite in $rohSeiten) {
            $brauchtKonvertierung = $true
            if ([IO.Path]::GetExtension($seite) -eq '.jpg') {
                $info = Get-JpegInfo ([IO.File]::ReadAllBytes($seite))
                if ($info -and -not $info.Progressiv -and ($info.Kanaele -eq 1 -or $info.Kanaele -eq 3)) {
                    $brauchtKonvertierung = $false
                }
            }
            if ($brauchtKonvertierung) {
                $neu = [IO.Path]::ChangeExtension($seite, '.pdfsrc.jpg')
                Convert-Bild $seite $neu 'jpg' $qualitaet $dpi
                $jpegSeiten += $neu
            } else {
                $jpegSeiten += $seite
            }
        }
        $ergebnis = Get-FreierPfad ([IO.Path]::Combine($zielOrdner, ("{0}_{1}.pdf" -f $basisName, $zeitstempel)))
        New-PdfAusJpeg $jpegSeiten $ergebnis $dpi
    }
    else {
        $endung = switch ($format) { 'jpg' { '.jpg' } 'png' { '.png' } 'tif' { '.tif' } }
        if ($rohSeiten.Count -eq 1) {
            $ergebnis = Get-FreierPfad ([IO.Path]::Combine($zielOrdner, ("{0}_{1}{2}" -f $basisName, $zeitstempel, $endung)))
            $zielDateien = @($ergebnis)
        } else {
            $ergebnis = Get-FreierPfad ([IO.Path]::Combine($zielOrdner, ("{0}_{1}" -f $basisName, $zeitstempel)))
            New-Item -ItemType Directory -Path $ergebnis -Force | Out-Null
            $zielDateien = 1..$rohSeiten.Count | ForEach-Object {
                [IO.Path]::Combine($ergebnis, ("{0}_{1:D3}{2}" -f $basisName, $_, $endung))
            }
        }
        for ($n = 0; $n -lt $rohSeiten.Count; $n++) {
            $quelle = $rohSeiten[$n]
            $ziel   = $zielDateien[$n]
            if (($format -eq 'jpg' -and [IO.Path]::GetExtension($quelle) -eq '.jpg') -or
                ($format -eq 'png' -and [IO.Path]::GetExtension($quelle) -eq '.png')) {
                Move-Item -LiteralPath $quelle -Destination $ziel -Force
            } else {
                Convert-Bild $quelle $ziel $format $qualitaet $dpi
                Remove-Item -LiteralPath $quelle -Force -ErrorAction SilentlyContinue
            }
        }
    }
} catch {
    Fehler "Die Ergebnisdatei konnte nicht erstellt werden: $($_.Exception.Message)"
    Info   "Die Rohseiten liegen noch unter: $arbeitsOrdner"
    exit 6
}

Remove-Item -LiteralPath $arbeitsOrdner -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# Zusammenfassung
# ---------------------------------------------------------------------------
$seitenWort = if ($rohSeiten.Count -eq 1) { 'Seite' } else { 'Seiten' }
Ok ("Fertig: {0} {1} gescannt." -f $rohSeiten.Count, $seitenWort)
if (Test-Path -LiteralPath $ergebnis -PathType Leaf) {
    $groesse = (Get-Item -LiteralPath $ergebnis).Length
    Info ("Datei:  {0}  ({1:N1} MB)" -f $ergebnis, ($groesse / 1MB))
} else {
    Info ("Ordner: {0}" -f $ergebnis)
}

if ($oeffnen) {
    try { Start-Process -FilePath $ergebnis } catch { Warn "Die Datei konnte nicht geoeffnet werden." }
}

exit 0
