@echo off
rem ===========================================================================
rem  Scan.bat - Scannen mit dem Canon imageFORMULA DR-C240 (oder jedem anderen
rem  WIA-faehigen Scanner) unter Windows 10/11.
rem
rem  Entwickelt von der IDO GmbH
rem  Anderslebener Str. 40, 39387 Oschersleben
rem  (c) 2026 IDO GmbH - alle Rechte vorbehalten
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

# --- Herausgeber ------------------------------------------------------------
$script:Firma     = 'IDO GmbH'
$script:Jahr      = '2026'
$script:Copyright = [string]([char]0x00A9) + " $script:Jahr $script:Firma"
$script:Programm  = 'Scan.bat'

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
  /einfach          ohne eigene Geraeteeinstellungen scannen (bei Treiberfehlern)
  /duplexwert <n>   Duplex-Schreibweise fest vorgeben (1, 4 oder 5)
  /gerade           schraeg eingezogene Seiten automatisch gerade richten
  /drehen <Grad>    alle Seiten fest drehen: 0, 90, 180 oder 270
  /leerseiten       leere Seiten (z.B. unbedruckte Rueckseiten) weglassen
  /leerwert <Zahl>  Empfindlichkeit dafuer in Promille (Standard: 1.5)
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
  (c) 2026 IDO GmbH - alle Rechte vorbehalten
'@ | Write-Host
}

# ---------------------------------------------------------------------------
# Programme, die den Scanner belegen und dadurch Fehler ausloesen koennen
# ---------------------------------------------------------------------------
function Get-BelegendeProgramme {
    $muster = @('CaptureOnTouch', 'CaptureOnTouchLite', 'COTLite', 'CNMCOT', 'CNQL240',
                'ScanButtonMonitor', 'CNMScanButton', 'wiaacmgr', 'WFS', 'WindowsScan',
                'NAPS2', 'ScanGear', 'PaperStream', 'ScanSnap')
    $gefunden = @()
    try {
        foreach ($prozess in (Get-Process -ErrorAction SilentlyContinue)) {
            if ($muster -contains $prozess.ProcessName) { $gefunden += $prozess.ProcessName }
        }
    } catch { }
    return ($gefunden | Select-Object -Unique)
}

# Hinweis ausgeben, wenn ein solches Programm laeuft
function Zeige-Belegung {
    $belegt = @(Get-BelegendeProgramme)
    if ($belegt.Count -gt 0) {
        Warn ("Diese Programme greifen selbst auf den Scanner zu: " + ($belegt -join ', '))
        Info "Bitte beenden - sie belegen das Geraet. 'Diagnose.bat /freigeben' erledigt das."
        return $true
    }
    return $false
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
# Leere Seiten erkennen
#
# Die Seite wird auf eine kleine Vorschau verkleinert und darin der Anteil
# dunkler Bildpunkte gezaehlt. Ein schmaler Rand bleibt aussen vor, weil der
# Einzug dort haeufig Schatten oder Streifen hinterlaesst.
# ---------------------------------------------------------------------------
$script:LeerZaehlerBereit = $false
$script:LeerBlockGrenze   = 0.004   # 0,4 % dunkle Punkte in einem Feld = Inhalt
$script:LeerFelder        = 12      # Raster fuer die Feldpruefung
$script:LeerRand          = 0.07    # Rand ausserhalb der Pruefung (Lochung, Schatten)
$script:LeerSchwelle      = 200     # dunkler als das gilt als Inhalt

function Initialisiere-LeerZaehler {
    if ($script:LeerZaehlerBereit) { return $true }
    try {
        Add-Type -TypeDefinition @'
public static class SeitenPruefer
{
    // Liefert { Anteil dunkler Punkte insgesamt, groesster Anteil in einem Feld }
    public static double[] Werte(byte[] puffer, int stride, int breite, int hoehe,
                                 int randX, int randY, int schwelle, int felder)
    {
        long dunkel = 0, gesamt = 0;
        int fx = (breite - 2 * randX) / felder; if (fx < 1) { fx = 1; }
        int fy = (hoehe  - 2 * randY) / felder; if (fy < 1) { fy = 1; }
        long[] feldDunkel = new long[felder * felder];
        long[] feldGesamt = new long[felder * felder];

        for (int y = randY; y < hoehe - randY; y++)
        {
            int zeile = y * stride;
            int iy = (y - randY) / fy; if (iy >= felder) { iy = felder - 1; }
            for (int x = randX; x < breite - randX; x++)
            {
                int i = zeile + x * 3;
                int hell = (puffer[i] + puffer[i + 1] + puffer[i + 2]) / 3;
                int ix = (x - randX) / fx; if (ix >= felder) { ix = felder - 1; }
                int k = iy * felder + ix;
                gesamt++; feldGesamt[k]++;
                if (hell < schwelle) { dunkel++; feldDunkel[k]++; }
            }
        }
        double maxFeld = 0.0;
        for (int k = 0; k < feldDunkel.Length; k++)
        {
            if (feldGesamt[k] > 50)
            {
                double a = (double)feldDunkel[k] / feldGesamt[k];
                if (a > maxFeld) { maxFeld = a; }
            }
        }
        double ges = gesamt == 0 ? 0.0 : (double)dunkel / gesamt;
        return new double[] { ges, maxFeld };
    }

    // --- Schraeglauf messen -------------------------------------------------
    // Alle Textpunkte werden gescherrt und das Zeilenprofil gebildet; beim
    // richtigen Winkel liegen die Zeilen genau uebereinander, das Profil hat
    // dann die groesste Streuung.
    private static int[] Punkte(byte[] p, int stride, int b, int h, int schwelle, out int anzahl)
    {
        int[] xy = new int[b * h * 2];
        int n = 0;
        for (int y = 0; y < h; y++)
        {
            int z = y * stride;
            for (int x = 0; x < b; x++)
            {
                if (p[z + x * 3] < schwelle) { xy[n * 2] = x; xy[n * 2 + 1] = y; n++; }
            }
        }
        anzahl = n;
        return xy;
    }

    private static double Streuung(int[] xy, int n, int b, int h, double tang)
    {
        int off = (int)Math.Abs(tang * b) + 1;
        int zeilen = h + 2 * off + 2;
        long[] profil = new long[zeilen];
        for (int i = 0; i < n; i++)
        {
            int x = xy[i * 2], y = xy[i * 2 + 1];
            int yy = y + off + (int)Math.Round(tang * (x - b / 2.0));
            if (yy >= 0 && yy < zeilen) { profil[yy]++; }
        }
        double summe = 0, quadrat = 0;
        for (int i = 0; i < zeilen; i++) { summe += profil[i]; quadrat += (double)profil[i] * profil[i]; }
        double mittel = summe / zeilen;
        return quadrat / zeilen - mittel * mittel;
    }

    public static double BesterWinkel(byte[] p, int stride, int b, int h, int schwelle,
                                      double grenze, double schritt)
    {
        int n;
        int[] xy = Punkte(p, stride, b, h, schwelle, out n);
        if (n < 200) { return 0.0; }          // zu wenig Inhalt fuer eine Messung
        double bester = 0.0, bestWert = -1.0;
        for (double w = -grenze; w <= grenze + 1e-9; w += schritt)
        {
            double v = Streuung(xy, n, b, h, Math.Tan(w * Math.PI / 180.0));
            if (v > bestWert) { bestWert = v; bester = w; }
        }
        for (double w = bester - schritt; w <= bester + schritt + 1e-9; w += schritt / 5.0)
        {
            double v = Streuung(xy, n, b, h, Math.Tan(w * Math.PI / 180.0));
            if (v > bestWert) { bestWert = v; bester = w; }
        }
        return bester;
    }
}
'@ -ErrorAction Stop
        $script:LeerZaehlerBereit = $true
    } catch {
        $script:LeerZaehlerBereit = $false
    }
    return $script:LeerZaehlerBereit
}

# Bild einlesen, ohne die Datei zu sperren
function Get-BildAusDatei([string]$pfad) {
    $bytes = [IO.File]::ReadAllBytes($pfad)
    $strom = New-Object IO.MemoryStream(,$bytes)
    return [System.Drawing.Image]::FromStream($strom)
}

# Verkleinerte Vorschau als Bildpunkt-Puffer (24 Bit) fuer die Auswertungen
function Get-Vorschau([string]$pfad, [int]$breite) {
    Add-Type -AssemblyName System.Drawing | Out-Null
    $quelle = Get-BildAusDatei $pfad
    try {
        $hoehe = [int][Math]::Round($quelle.Height * $breite / [double]$quelle.Width)
        if ($hoehe -lt 32) { $hoehe = 32 }
        $klein = New-Object System.Drawing.Bitmap($breite, $hoehe, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        try {
            $g = [System.Drawing.Graphics]::FromImage($klein)
            try {
                $g.Clear([System.Drawing.Color]::White)
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.DrawImage($quelle, 0, 0, $breite, $hoehe)
            } finally { $g.Dispose() }

            $bereich = New-Object System.Drawing.Rectangle(0, 0, $breite, $hoehe)
            $daten = $klein.LockBits($bereich, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                                     [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            try {
                $stride = $daten.Stride
                $puffer = New-Object byte[] ($stride * $hoehe)
                [System.Runtime.InteropServices.Marshal]::Copy($daten.Scan0, $puffer, 0, $puffer.Length)
            } finally { $klein.UnlockBits($daten) }
            return @{ Puffer = $puffer; Stride = $stride; Breite = $breite; Hoehe = $hoehe }
        } finally { $klein.Dispose() }
    } finally { $quelle.Dispose() }
}

# Liefert @(Gesamtanteil, groesster Feldanteil) einer Seite - beide 0 bis 1
function Get-SeitenWerte([string]$pfad) {
    $schnell = Initialisiere-LeerZaehler
    $breite  = 300
    if (-not $schnell) { $breite = 150 }   # ohne Hilfsklasse kleiner rechnen
    $v = Get-Vorschau $pfad $breite
    $puffer = $v.Puffer; $stride = $v.Stride; $breite = $v.Breite; $hoehe = $v.Hoehe
    $randX = [int]($breite * $script:LeerRand)
    $randY = [int]($hoehe  * $script:LeerRand)

    if ($schnell) {
        return [SeitenPruefer]::Werte($puffer, $stride, $breite, $hoehe, $randX, $randY,
                                      $script:LeerSchwelle, $script:LeerFelder)
    }

    # Ersatzweg ohne Hilfsklasse: gleiche Rechnung in PowerShell
    $felder = $script:LeerFelder
    $fx = [Math]::Max(1, [int](($breite - 2*$randX) / $felder))
    $fy = [Math]::Max(1, [int](($hoehe  - 2*$randY) / $felder))
    $feldDunkel = New-Object 'int[]' ($felder * $felder)
    $feldGesamt = New-Object 'int[]' ($felder * $felder)
    $dunkel = 0; $gesamt = 0
    for ($y = $randY; $y -lt ($hoehe - $randY); $y++) {
        $zeile = $y * $stride
        $iy = [Math]::Min($felder - 1, [int](($y - $randY) / $fy))
        for ($x = $randX; $x -lt ($breite - $randX); $x++) {
            $i = $zeile + $x * 3
            $hell = ([int]$puffer[$i] + [int]$puffer[$i+1] + [int]$puffer[$i+2]) / 3
            $k = $iy * $felder + [Math]::Min($felder - 1, [int](($x - $randX) / $fx))
            $gesamt++; $feldGesamt[$k]++
            if ($hell -lt $script:LeerSchwelle) { $dunkel++; $feldDunkel[$k]++ }
        }
    }
    $maxFeld = 0.0
    for ($k = 0; $k -lt $feldDunkel.Length; $k++) {
        if ($feldGesamt[$k] -gt 50) {
            $a = $feldDunkel[$k] / [double]$feldGesamt[$k]
            if ($a -gt $maxFeld) { $maxFeld = $a }
        }
    }
    $ges = 0.0
    if ($gesamt -gt 0) { $ges = $dunkel / [double]$gesamt }
    return @($ges, $maxFeld)
}

# ---------------------------------------------------------------------------
# Schraeglauf messen und Seiten drehen
# ---------------------------------------------------------------------------
function Get-Schraeglauf([string]$pfad) {
    if (-not (Initialisiere-LeerZaehler)) { return 0.0 }   # ohne Hilfsklasse zu langsam
    $v = Get-Vorschau $pfad 600
    return [SeitenPruefer]::BesterWinkel($v.Puffer, $v.Stride, $v.Breite, $v.Hoehe, 180, 8.0, 0.5)
}

# Dreht eine Seite und schreibt sie zurueck. Vielfache von 90 Grad werden
# verlustfrei gedreht, dazwischen wird mit weissem Hintergrund gerechnet.
function Drehe-Seite([string]$pfad, [double]$winkel, [int]$qualitaet) {
    Add-Type -AssemblyName System.Drawing | Out-Null
    $endung = [IO.Path]::GetExtension($pfad).ToLowerInvariant()
    $quelle = Get-BildAusDatei $pfad
    $ergebnis = $null
    try {
        $rest = [Math]::IEEERemainder($winkel, 90.0)
        if ([Math]::Abs($rest) -lt 0.01) {
            $viertel = [int][Math]::Round((($winkel % 360) + 360) % 360 / 90.0) % 4
            if ($viertel -eq 0) { return }
            $ergebnis = New-Object System.Drawing.Bitmap($quelle)
            switch ($viertel) {
                1 { $ergebnis.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
                2 { $ergebnis.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
                3 { $ergebnis.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
            }
        } else {
            $breite = $quelle.Width
            $hoehe  = $quelle.Height
            $ergebnis = New-Object System.Drawing.Bitmap($breite, $hoehe, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $ergebnis.SetResolution($quelle.HorizontalResolution, $quelle.VerticalResolution)
            $g = [System.Drawing.Graphics]::FromImage($ergebnis)
            try {
                $g.Clear([System.Drawing.Color]::White)
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.TranslateTransform($breite / 2.0, $hoehe / 2.0)
                $g.RotateTransform($winkel)          # im Uhrzeigersinn - hebt den Schraeglauf auf
                $g.TranslateTransform(-$breite / 2.0, -$hoehe / 2.0)
                $g.DrawImage($quelle, 0, 0, $breite, $hoehe)
            } finally { $g.Dispose() }
        }
    } finally { $quelle.Dispose() }

    if ($null -eq $ergebnis) { return }
    try {
        switch ($endung) {
            '.jpg' {
                $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
                $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
                $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int64]$qualitaet)
                $ergebnis.Save($pfad, $codec, $ep)
                $ep.Dispose()
            }
            '.png' { $ergebnis.Save($pfad, [System.Drawing.Imaging.ImageFormat]::Png) }
            default { $ergebnis.Save($pfad, [System.Drawing.Imaging.ImageFormat]::Bmp) }
        }
    } finally { $ergebnis.Dispose() }
}

# ---------------------------------------------------------------------------
# Mehrseitiges PDF aus JPEG-Dateien bauen (JPEG wird direkt eingebettet)
# ---------------------------------------------------------------------------
function New-PdfAusJpeg([string[]]$bilder, [string]$zielDatei, [int]$dpi) {
    # ISO-8859-1: fuer ASCII identisch, erlaubt aber Zeichen wie (c) und Umlaute
    $ascii  = [Text.Encoding]::GetEncoding(28591)
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
    $objektAnzahl = 2 + $anzahl * 3 + 1   # das letzte Objekt sind die Dokumentangaben
    $objInfo     = $objektAnzahl

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

    # Dokumentangaben (Programm und Herausgeber)
    $pdfText = {
        param([string]$roh)
        return ($roh -replace '\\', '\\' -replace '\(', '\(' -replace '\)', '\)')
    }
    $zeitpunkt = Get-Date
    $versatz = [TimeZoneInfo]::Local.GetUtcOffset($zeitpunkt)
    $vorzeichen = '+'
    if ($versatz.Ticks -lt 0) { $vorzeichen = '-' }
    $datumPdf = "D:{0}{1}{2:00}'{3:00}'" -f $zeitpunkt.ToString('yyyyMMddHHmmss'), $vorzeichen,
                [Math]::Abs($versatz.Hours), [Math]::Abs($versatz.Minutes)
    $offsets[$objInfo] = $stream.Position
    & $schreibeText ("$objInfo 0 obj`n<< /Producer (" + (& $pdfText "$script:Programm - $script:Firma") + ")" +
                     " /Creator (" + (& $pdfText "$script:Programm - $script:Firma") + ")" +
                     " /Author (" + (& $pdfText $script:Firma) + ")" +
                     " /Subject (" + (& $pdfText $script:Copyright) + ")" +
                     " /CreationDate ($datumPdf) /ModDate ($datumPdf) >>`nendobj`n")

    # Querverweistabelle
    $xrefPos = $stream.Position
    & $schreibeText "xref`n0 $($objektAnzahl + 1)`n"
    & $schreibeText "0000000000 65535 f `n"
    for ($n = 1; $n -le $objektAnzahl; $n++) {
        & $schreibeText ("{0:D10} 00000 n `n" -f [int64]$offsets[$n])
    }
    & $schreibeText "trailer`n<< /Size $($objektAnzahl + 1) /Root 1 0 R /Info $objInfo 0 R >>`nstartxref`n$xrefPos`n%%EOF`n"

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
$einfach    = $false
$duplexWert = 0            # 0 = automatisch probieren
$geradeRichten = $false
$festDrehen = 0
$leerseiten = $false
$leerWert   = 1.5          # Promille dunkler Bildpunkte
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
            'einfach'   { $einfach = $true }
            'duplexwert' { $duplexWert = AlsZahl (Naechstes ([ref]$i) 'duplexwert') 'duplexwert' }
            'gerade'    { $geradeRichten = $true }
            'drehen'    { $festDrehen = AlsZahl (Naechstes ([ref]$i) 'drehen') 'drehen' }
            'leerseiten' { $leerseiten = $true }
            'leerwert'  {
                $roh = Naechstes ([ref]$i) 'leerwert'
                $zahl = 0.0
                if (-not [double]::TryParse(($roh -replace ',', '.'), [Globalization.NumberStyles]::Float,
                        [Globalization.CultureInfo]::InvariantCulture, [ref]$zahl)) {
                    throw "Der Wert '$roh' zur Option 'leerwert' ist keine Zahl."
                }
                $leerWert = $zahl
                $leerseiten = $true
            }
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
if ($leerWert -lt 0 -or $leerWert -gt 100) { Fehler "Der Wert fuer /leerwert muss zwischen 0 und 100 liegen."; exit 2 }
$festDrehen = (($festDrehen % 360) + 360) % 360
if ($festDrehen -ne 0 -and $festDrehen -ne 90 -and $festDrehen -ne 180 -and $festDrehen -ne 270) {
    Fehler "Fuer /drehen sind nur 0, 90, 180 oder 270 moeglich."
    exit 2
}
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
    $meldung = $_.Exception.Message.Trim()
    $hr = Get-HResult $_.Exception
    Fehler "Die Verbindung zum Scanner ist fehlgeschlagen: $meldung"
    if ($hr -ne 0) { Info ("Fehlernummer: 0x{0:X8}" -f $hr) }
    if (-not (Zeige-Belegung)) {
        Info "Geraet aus- und wieder einschalten, USB-Kabel direkt am Rechner anschliessen."
        Info "Mehr Hinweise liefert Diagnose.bat"
    }
    exit 3
}

$element = $geraet.Items.Item(1)

# ---------------------------------------------------------------------------
# Einzug/Duplex einstellen
# ---------------------------------------------------------------------------
$faehigkeiten = Get-WiaWert $geraet.Properties $WIA_DPS_DOCUMENT_HANDLING_CAPS
if ($null -eq $faehigkeiten) { $faehigkeiten = $HANDLE_FEEDER }
$hatEinzug = ($faehigkeiten -band $HANDLE_FEEDER) -ne 0

# Nicht jeder Treiber versteht dieselbe Schreibweise fuer Duplex. Deshalb
# stehen mehrere bereit; scheitert der Scan, wird der Reihe nach umgestellt
# und zuletzt einseitig gescannt, statt ganz aufzugeben.
$einzugsWege = @()
if ($hatEinzug) {
    if ($duplex) {
        if (($faehigkeiten -band $HANDLE_DUPLEX) -ne 0) {
            $einzugsWege += @{ Wert = ($HANDLE_FEEDER -bor $HANDLE_DUPLEX); Text = 'Einzug + Duplex'; Duplex = $true }
            $einzugsWege += @{ Wert = $HANDLE_DUPLEX;                       Text = 'nur Duplex';      Duplex = $true }
        } else {
            Warn "Der Scanner meldet keine Duplex-Faehigkeit - es wird einseitig gescannt."
            $duplex = $false
        }
    }
    $einzugsWege += @{ Wert = $HANDLE_FEEDER; Text = 'Einzug einseitig'; Duplex = $false }
} elseif (($faehigkeiten -band $HANDLE_FLATBED) -ne 0) {
    $einzugsWege += @{ Wert = $HANDLE_FLATBED; Text = 'Flachbett'; Duplex = $false }
}

$wegNummer = 0
if ($duplexWert -gt 0) {
    # von Hand vorgegeben: nur diesen Wert verwenden
    $einzugsWege = @(@{ Wert = $duplexWert; Text = "fest vorgegeben ($duplexWert)"; Duplex = (($duplexWert -band $HANDLE_DUPLEX) -ne 0) })
}

function Setze-Einzugsart([int]$nummer) {
    if ($nummer -ge $script:EinzugsWege.Count) { return $false }
    $weg = $script:EinzugsWege[$nummer]
    if (-not (Set-WiaWert $script:Geraet.Properties $WIA_DPS_DOCUMENT_HANDLING_SELECT $weg.Wert)) {
        return $false
    }
    return $true
}

$script:EinzugsWege = $einzugsWege
$script:Geraet = $geraet
$einzugsWert = 0
if ($einzugsWege.Count -gt 0) {
    $einzugsWert = $einzugsWege[0].Wert
    if (-not (Setze-Einzugsart 0)) {
        Warn "Die Einzugsart '$($einzugsWege[0].Text)' laesst sich nicht setzen - es gilt die Geraeteeinstellung."
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

if ($einfach) {
    # Manche Treiber stolpern ueber gesetzte Eigenschaften. Im einfachen Modus
    # bleibt alles so, wie es der Treiber selbst vorgibt.
    Warn "Einfacher Modus: Farbe, Aufloesung und Scanbereich bleiben beim Geraet."
    $dpi = Get-WiaWert $element.Properties $WIA_IPS_XRES
    if (-not $dpi) { $dpi = 300 }
} else {

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

}   # Ende des Zweigs ohne /einfach

$modusText = switch ($farbmodus) { 'farbe' { 'Farbe' } 'grau' { 'Graustufen' } 'sw' { 'Schwarzweiss' } }
if ($einfach) { $modusText = 'Geraetevorgabe' }
$seitenText = if ($duplex) { 'Duplex' } else { 'Einseitig' }
$duplexGewuenscht = $duplex
$leerText = ''
if ($geradeRichten) { $leerText += ', gerade richten' }
if ($festDrehen -ne 0) { $leerText += ", um $festDrehen Grad drehen" }
if ($leerseiten) { $leerText += ', leere Seiten weglassen' }
Info "Einstellungen: $modusText, $dpi dpi, $seitenText, Ausgabe: $($format.ToUpperInvariant())$leerText"

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
if ($hatEinzug) {
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
            # Scheitert die erste Seite, liegt es meist an einer Einstellung, die
            # der Treiber nicht mag. Dann werden der Reihe nach andere Duplex-
            # Schreibweisen und zuletzt ein anderes Bildformat probiert.
            $rettung = 0
            while ($true) {
                try {
                    $bild = $element.Transfer($transferFormat)
                    break
                } catch {
                    $hrErst = Get-HResult $_.Exception
                    $istPapierfehler = ($hrErst -eq $ERR_PAPER_EMPTY -or $hrErst -eq $ERR_PAPER_JAM -or $hrErst -eq $ERR_OFFLINE)
                    if ($seitenNr -ne 1 -or $istPapierfehler -or $rettung -ge 4) { throw }
                    $rettung++

                    if (($wegNummer + 1) -lt $einzugsWege.Count) {
                        $wegNummer++
                        $weg = $einzugsWege[$wegNummer]
                        Write-Host ("`r" + (' ' * 44) + "`r") -NoNewline
                        if ($weg.Duplex) {
                            Warn "Diese Duplex-Einstellung lehnt der Treiber ab - es wird '$($weg.Text)' versucht."
                        } else {
                            Warn "Der Treiber beherrscht Duplex ueber WIA nicht - es wird einseitig gescannt."
                            Info "Beidseitig geht dann ueber die Einstellung im Canon-Treiber oder CaptureOnTouch."
                            $duplex = $false
                        }
                        [void](Setze-Einzugsart $wegNummer)
                        $einzugsWert = $weg.Wert
                        try { $element = $geraet.Items.Item(1) } catch { }
                        Write-Host ("  Seite {0} wird gescannt ..." -f $seitenNr) -NoNewline
                        continue
                    }

                    if ($transferFormat -ne $FMT_BMP) {
                        $transferFormat = $FMT_BMP
                        $transferEndung = '.bmp'
                        continue
                    }
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

        if (-not $hatEinzug) { break }   # Flachbett: nur eine Seite
    }
} catch {
    Write-Host ("`r" + (' ' * 44) + "`r") -NoNewline
    $meldung = $_.Exception.Message.Trim()
    $hr = Get-HResult $_.Exception
    Fehler "Der Scanvorgang ist fehlgeschlagen: $meldung"
    if ($hr -ne 0) { Info ("Fehlernummer: 0x{0:X8}" -f $hr) }
    $belegt = Zeige-Belegung
    if (-not $belegt) {
        Info "Moegliche Ursachen:"
        Info "  - das Geraet ist aus oder das USB-Kabel steckt nicht fest"
        Info "  - der Treiber verweigert eine Einstellung: 'Scan.bat /einfach' versuchen"
        Info "  - ein Neustart loest haengende Treiberteile"
        Info "Mehr Hinweise liefert Diagnose.bat"
    }
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
# Seiten ausrichten (feste Drehung und Schraeglauf)
# ---------------------------------------------------------------------------
if (($geradeRichten -or $festDrehen -ne 0) -and $rohSeiten.Count -gt 0) {
    Info ""
    Info "Seiten werden ausgerichtet ..."
    $nummer = 0
    foreach ($seite in $rohSeiten) {
        $nummer++
        try {
            if ($festDrehen -ne 0) {
                Drehe-Seite $seite $festDrehen $qualitaet
            }
            if ($geradeRichten) {
                $winkel = [double](Get-Schraeglauf $seite)
                if ([Math]::Abs($winkel) -ge 0.2) {
                    Drehe-Seite $seite $winkel $qualitaet
                    Info ("  Seite {0}: um {1:N1} Grad gerade gerichtet" -f $nummer, $winkel)
                }
            }
        } catch {
            Warn "Die Seiten konnten nicht ausgerichtet werden ($($_.Exception.Message.Trim()))."
            break
        }
    }
}

# ---------------------------------------------------------------------------
# Leere Seiten aussortieren
# ---------------------------------------------------------------------------
$leereSeiten = 0
if ($leerseiten -and $rohSeiten.Count -gt 0) {
    Info ""
    Info "Seiten werden auf Inhalt geprueft ..."
    $grenze   = $leerWert / 1000.0
    $behalten = @()
    $nummer   = 0
    $fehlgeschlagen = $false
    foreach ($seite in $rohSeiten) {
        $nummer++
        try {
            $werte = Get-SeitenWerte $seite
        } catch {
            Warn "Die Seiten konnten nicht geprueft werden - es wird nichts weggelassen."
            $fehlgeschlagen = $true
            break
        }
        # Leer ist eine Seite nur, wenn insgesamt kaum etwas da ist UND auch
        # kein einzelnes Feld auffaellt - so bleibt ein kleines Kuerzel erhalten.
        $istLeer = ([double]$werte[0] -lt $grenze) -and ([double]$werte[1] -lt $script:LeerBlockGrenze)
        if ($istLeer) {
            $leereSeiten++
            Info ("  Seite {0}: leer ({1:N2} Promille) - wird weggelassen" -f $nummer, ($werte[0] * 1000))
        } else {
            $behalten += $seite
        }
    }
    if ($fehlgeschlagen) {
        $leereSeiten = 0
    } elseif ($behalten.Count -eq 0) {
        Warn "Alle Seiten wurden als leer erkannt - es wird nichts weggelassen."
        $leereSeiten = 0
    } else {
        $rohSeiten = $behalten
    }
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
if ($duplexGewuenscht -and -not $duplex) {
    Warn "Es wurde einseitig gescannt - der Treiber nimmt ueber WIA keine Duplex-Einstellung an."
    Info "Welche Schreibweise Ihr Geraet akzeptiert, zeigt:  Diagnose.bat /duplextest"
}
$seitenWort = if ($rohSeiten.Count -eq 1) { 'Seite' } else { 'Seiten' }
if ($leereSeiten -gt 0) {
    $leerWort = if ($leereSeiten -eq 1) { 'leere Seite' } else { 'leere Seiten' }
    Ok ("Fertig: {0} {1} gespeichert, {2} {3} weggelassen." -f $rohSeiten.Count, $seitenWort, $leereSeiten, $leerWort)
} else {
    Ok ("Fertig: {0} {1} gescannt." -f $rohSeiten.Count, $seitenWort)
}
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
