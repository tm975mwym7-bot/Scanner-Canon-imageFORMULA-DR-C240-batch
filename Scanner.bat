@echo off
rem ===========================================================================
rem  Scanner.bat - kleines Fenster-Programm zum Scannen (Canon DR-C240)
rem
rem  Entwickelt von der IDO GmbH
rem  Anderslebener Str. 40, 39387 Oschersleben
rem
rem  Zeigt eine Oberflaeche mit den wichtigsten Einstellungen (PDF oder Bild,
rem  Farbe, Aufloesung, Duplex, Zielordner). Der Zielordner und alle anderen
rem  Einstellungen werden gemerkt und beim naechsten Start wieder verwendet.
rem
rem  Gescannt wird ueber Scan.bat, das im selben Ordner liegen muss.
rem  Liegt eine Datei logo.png im selben Ordner, erscheint sie im Fensterkopf.
rem ===========================================================================

setlocal enableextensions
set "GUI_SELF=%~f0"

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo FEHLER: Windows PowerShell wurde nicht gefunden.
    pause
    exit /b 9
)

rem Fenster von der Konsole loesen, damit kein Eingabeaufforderungsfenster stehen bleibt
start "Scanner" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "$t=[IO.File]::ReadAllText($env:GUI_SELF,[Text.Encoding]::UTF8); $m='#~'+'PSSTART~'; $p=$t.IndexOf($m); if($p -lt 0){exit 9}; . ([scriptblock]::Create($t.Substring($p)))"
endlocal & exit /b 0

#~PSSTART~
# ===========================================================================
#  Oberflaeche (Windows Forms) fuer Scan.bat
#
#  Kundenansicht: nur "was wird gescannt" und die Schaltflaeche Scannen.
#  Alles zur Einrichtung (Scanner, Aufloesung, Zielordner, Protokoll) liegt
#  im Servicebereich - erreichbar ueber Strg+Alt+S oder Doppelklick auf das
#  Logo, geschuetzt durch das Servicekennwort.
# ===========================================================================
$ErrorActionPreference = 'Stop'

# --- Herausgeber ------------------------------------------------------------
$script:Firma      = 'IDO GmbH'
$script:Strasse    = 'Anderslebener Str. 40'
$script:Ort        = '39387 Oschersleben'
$script:Jahr       = '2026'

# --- Servicekennwort (SHA-256) ---------------------------------------------
# Leer = noch nicht eingerichtet; dann fragt das Programm beim ersten Start
# nach einem Kennwort und traegt die Pruefsumme hier ein.
$script:KennwortHash = ''

$script:EigenerPfad = $env:GUI_SELF
$script:Ordner      = Split-Path -Parent $script:EigenerPfad
$script:ScanBat     = [IO.Path]::Combine($script:Ordner, 'Scan.bat')
$script:EinstOrdner = [IO.Path]::Combine($env:APPDATA, 'Scan-DR-C240')

# Einstellungen liegen bevorzugt beim Programm (gilt dann fuer alle Benutzer
# des Rechners); ist der Ordner schreibgeschuetzt, weichen wir ins Profil aus.
$script:KennwortBeimProgramm = [IO.Path]::Combine($script:Ordner, 'service.dat')
$script:KennwortImProfil     = [IO.Path]::Combine($script:EinstOrdner, 'service.dat')
$script:EinstBeimProgramm = [IO.Path]::Combine($script:Ordner, 'einstellungen.json')
$script:EinstImProfil     = [IO.Path]::Combine($script:EinstOrdner, 'einstellungen.json')
$script:EinstDatei        = $script:EinstBeimProgramm
if (-not (Test-Path -LiteralPath $script:EinstBeimProgramm) -and (Test-Path -LiteralPath $script:EinstImProfil)) {
    $script:EinstDatei = $script:EinstImProfil
}

# ---------------------------------------------------------------------------
# Kennwort
# ---------------------------------------------------------------------------
function Get-TextHash([string]$text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))
    } finally { $sha.Dispose() }
    return (-join ($bytes | ForEach-Object { $_.ToString('x2') }))
}

# Pruefsumme aus dem Skript oder - falls es schreibgeschuetzt war - aus service.dat
function Get-KennwortHash {
    if ($script:KennwortHash -match '^[0-9a-fA-F]{64}$') { return $script:KennwortHash }
    foreach ($datei in @($script:KennwortBeimProgramm, $script:KennwortImProfil)) {
        if (Test-Path -LiteralPath $datei) {
            try {
                $inhalt = (Get-Content -LiteralPath $datei -Raw).Trim()
                if ($inhalt -match '^[0-9a-fA-F]{64}$') { return $inhalt }
            } catch { }
        }
    }
    return ''
}

function Test-Kennwort([string]$eingabe) {
    if (-not $eingabe) { return $false }
    $hash = Get-KennwortHash
    if (-not $hash) { return $false }
    return ((Get-TextHash $eingabe) -eq $hash)
}

# neuen Hash ablegen: bevorzugt in dieser Datei, sonst in service.dat
function Speichere-KennwortHash([string]$neuerHash) {
    $script:KennwortHash = $neuerHash
    try {
        Set-KennwortHash $neuerHash
        return 'Datei'
    } catch {
        foreach ($ziel in @($script:KennwortBeimProgramm, $script:KennwortImProfil)) {
            try {
                $ordner = Split-Path -Parent $ziel
                if (-not (Test-Path -LiteralPath $ordner)) { New-Item -ItemType Directory -Path $ordner -Force | Out-Null }
                Set-Content -LiteralPath $ziel -Value $neuerHash -Encoding ASCII
                return 'Nebendatei'
            } catch { continue }
        }
    }
    return 'Nur Sitzung'
}

# neuen Hash in diese Datei zurueckschreiben (Zeilenenden bleiben erhalten)
function Set-KennwortHash([string]$neuerHash) {
    $text = [IO.File]::ReadAllText($script:EigenerPfad, [Text.Encoding]::UTF8)
    $muster = "(?m)^\`$script:KennwortHash = '[0-9a-fA-F]*'"
    if ($text -notmatch $muster) { throw 'Die Kennwortzeile wurde in der Datei nicht gefunden.' }
    $neu = [regex]::Replace($text, $muster, "`$script:KennwortHash = '$neuerHash'", 1)
    [IO.File]::WriteAllText($script:EigenerPfad, $neu, (New-Object Text.UTF8Encoding($false)))
    $script:KennwortHash = $neuerHash
}

# ---------------------------------------------------------------------------
# Einstellungen laden und sichern
# ---------------------------------------------------------------------------
function Get-Standardordner {
    $dokumente = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($dokumente) -and $env:USERPROFILE) {
        $dokumente = [IO.Path]::Combine($env:USERPROFILE, 'Documents')
    }
    if ([string]::IsNullOrWhiteSpace($dokumente)) { return '' }
    return [IO.Path]::Combine($dokumente, 'Scans')
}

function Get-Einstellungen {
    $e = @{
        Ziel      = Get-Standardordner
        Format    = 'pdf'
        Bildart   = 'jpg'
        Farbe     = 'farbe'
        Dpi       = 300
        Duplex    = $false
        Name      = 'Scan'
        Oeffnen   = $true
        Scanner   = ''
        Kachel    = $true
        KachelX   = -1
        KachelY   = -1
    }
    if (Test-Path -LiteralPath $script:EinstDatei) {
        try {
            $gespeichert = Get-Content -LiteralPath $script:EinstDatei -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($schluessel in @($e.Keys)) {
                $wert = $gespeichert.$schluessel
                if ($null -ne $wert -and "$wert" -ne '') { $e[$schluessel] = $wert }
            }
            $e.Dpi     = [int]$e.Dpi
            $e.Duplex  = [bool]$e.Duplex
            $e.Oeffnen = [bool]$e.Oeffnen
            $e.Kachel  = [bool]$e.Kachel
            $e.KachelX = [int]$e.KachelX
            $e.KachelY = [int]$e.KachelY
        } catch {
            # beschaedigte Datei: mit den Vorgaben weiterarbeiten
        }
    }
    return $e
}

function Save-Einstellungen($e) {
    $inhalt = ([pscustomobject]$e) | ConvertTo-Json
    foreach ($ziel in @($script:EinstDatei, $script:EinstImProfil)) {
        try {
            $ordner = Split-Path -Parent $ziel
            if (-not (Test-Path -LiteralPath $ordner)) { New-Item -ItemType Directory -Path $ordner -Force | Out-Null }
            Set-Content -LiteralPath $ziel -Value $inhalt -Encoding UTF8
            $script:EinstDatei = $ziel
            return $true
        } catch {
            continue   # z.B. Programmordner schreibgeschuetzt -> naechster Versuch im Profil
        }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Aufrufzeile fuer Scan.bat zusammenbauen
# ---------------------------------------------------------------------------
function New-ScanArgumente($e) {
    $teile = @()
    if ($e.Format -eq 'pdf') { $teile += '/pdf' } else { $teile += ('/' + $e.Bildart) }
    $teile += ('/' + $e.Farbe)
    $teile += '/dpi'; $teile += [string][int]$e.Dpi
    if ($e.Duplex)  { $teile += '/duplex' }
    if ($e.Oeffnen) { $teile += '/oeffnen' }
    if ("$($e.Name)".Trim())    { $teile += '/name';    $teile += ('"' + "$($e.Name)".Trim() + '"') }
    if ("$($e.Ziel)".Trim())    { $teile += '/ordner';  $teile += ('"' + "$($e.Ziel)".Trim() + '"') }
    if ("$($e.Scanner)".Trim()) { $teile += '/scanner'; $teile += ('"' + "$($e.Scanner)".Trim() + '"') }
    return ($teile -join ' ')
}

# ---------------------------------------------------------------------------
# Protokolltext aufbereiten: Zeilen, die mit Wagenruecklauf ueberschrieben
# wurden, zeigen wir wie in der Konsole nur in ihrer letzten Fassung.
# ---------------------------------------------------------------------------
function Format-Protokoll([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    $zeilen = $text -split "`n"
    $ausgabe = foreach ($zeile in $zeilen) {
        $stueck = ($zeile -split "`r")[-1]
        $stueck.TrimEnd()
    }
    return (($ausgabe -join "`r`n").TrimEnd())
}

# Ergebnispfad aus der Ausgabe von Scan.bat herausziehen
function Get-ErgebnisPfad([string]$protokoll) {
    $treffer = [regex]::Matches($protokoll, '(?m)^(?:Datei|Ordner):\s+(.+?)(?:\s+\([^)]*\))?\s*$')
    if ($treffer.Count -eq 0) { return $null }
    return $treffer[$treffer.Count - 1].Groups[1].Value.Trim()
}

# ---------------------------------------------------------------------------
# Scanner ueber WIA auflisten
# ---------------------------------------------------------------------------
function Get-ScannerNamen {
    $namen = @()
    try {
        $manager = New-Object -ComObject WIA.DeviceManager
        $anzahl = 0
        try { $anzahl = [int]$manager.DeviceInfos.Count } catch { $anzahl = 0 }
        for ($n = 1; $n -le $anzahl; $n++) {
            $info = $manager.DeviceInfos.Item($n)
            if ($info.Type -ne 1) { continue }
            try { $namen += [string]$info.Properties.Item('Name').Value } catch { }
        }
    } catch { }
    return $namen
}

# ---------------------------------------------------------------------------
# Firmenlogo suchen und laden (logo.png/.jpg/.bmp/.gif im Programmordner)
# ---------------------------------------------------------------------------
function Get-LogoDatei {
    foreach ($name in @('logo.png', 'logo.jpg', 'logo.jpeg', 'logo.bmp', 'logo.gif')) {
        $pfad = [IO.Path]::Combine($script:Ordner, $name)
        if (Test-Path -LiteralPath $pfad -PathType Leaf) { return $pfad }
    }
    return $null
}

function Get-LogoBild([string]$pfad) {
    # ueber einen Speicherstrom laden, damit die Datei nicht gesperrt bleibt
    $bytes = [IO.File]::ReadAllBytes($pfad)
    $strom = New-Object IO.MemoryStream(,$bytes)
    return [System.Drawing.Image]::FromStream($strom)
}

# Breites Logo mittig in ein quadratisches Fenstersymbol einpassen
function New-SymbolAusBild($bild, [int]$kante) {
    $quadrat = New-Object System.Drawing.Bitmap($kante, $kante)
    $g = [System.Drawing.Graphics]::FromImage($quadrat)
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $faktor = [Math]::Min($kante / $bild.Width, $kante / $bild.Height)
        $breite = [int]($bild.Width * $faktor)
        $hoehe  = [int]($bild.Height * $faktor)
        $g.DrawImage($bild, [int](($kante - $breite) / 2), [int](($kante - $hoehe) / 2), $breite, $hoehe)
    } finally { $g.Dispose() }
    return $quadrat
}

# ---------------------------------------------------------------------------
# Symboldatei (.ico) aus fertigen PNG-Bloecken zusammensetzen
# ---------------------------------------------------------------------------
function New-IcoAusPngs([object[]]$pngListe, [int[]]$kanten, [string]$ziel) {
    $anzahl = $pngListe.Count
    $strom  = New-Object IO.FileStream($ziel, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    $s = New-Object IO.BinaryWriter($strom)
    try {
        $s.Write([uint16]0)       # reserviert
        $s.Write([uint16]1)       # Typ 1 = Symbol
        $s.Write([uint16]$anzahl)

        $offset = 6 + 16 * $anzahl
        for ($i = 0; $i -lt $anzahl; $i++) {
            $kante = $kanten[$i]
            $mass  = 0
            if ($kante -lt 256) { $mass = $kante }   # 256 wird als 0 eingetragen
            $s.Write([byte]$mass)                    # Breite
            $s.Write([byte]$mass)                    # Hoehe
            $s.Write([byte]0)                        # Farbtabelle
            $s.Write([byte]0)                        # reserviert
            $s.Write([uint16]1)                      # Ebenen
            $s.Write([uint16]32)                     # Bit je Bildpunkt
            $s.Write([uint32]$pngListe[$i].Length)
            $s.Write([uint32]$offset)
            $offset += $pngListe[$i].Length
        }
        foreach ($png in $pngListe) { $s.Write($png, 0, $png.Length) }
    } finally {
        $s.Dispose(); $strom.Dispose()
    }
}

# logo.ico erzeugen (fuer Fenster, Taskleiste und Verknuepfungen)
function New-LogoSymbol($bild, [string]$ziel) {
    $kanten = @(16, 24, 32, 48, 64, 128, 256)
    $pngs = @()
    foreach ($kante in $kanten) {
        $quadrat = New-SymbolAusBild $bild $kante
        try {
            $speicher = New-Object IO.MemoryStream
            $quadrat.Save($speicher, [System.Drawing.Imaging.ImageFormat]::Png)
            $pngs += ,$speicher.ToArray()
            $speicher.Dispose()
        } finally { $quadrat.Dispose() }
    }
    New-IcoAusPngs $pngs $kanten $ziel
}

# ---------------------------------------------------------------------------
# Oberflaeche
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$e = Get-Einstellungen

$script:HoeheKunde   = 330
$script:HoeheService = 726
try {
    # auf kleinen Bildschirmen kuerzen; der Servicebereich bekommt dann eine Bildlaufleiste
    $platz = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height - 70
    if ($script:HoeheService -gt $platz) { $script:HoeheService = [Math]::Max(430, $platz) }
} catch { }

$firmenBlau = [System.Drawing.Color]::FromArgb(43, 74, 155)

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = 'Scannen'
$form.ClientSize      = New-Object System.Drawing.Size(620, $script:HoeheKunde)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox     = $false
$form.StartPosition   = 'CenterScreen'
$form.Font            = New-Object System.Drawing.Font('Segoe UI', 9)
$form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.BackColor       = [System.Drawing.Color]::FromArgb(243, 243, 243)
$form.KeyPreview      = $true

# --- Kopfbereich mit Firmenlogo ---------------------------------------------
$pnlKopf           = New-Object System.Windows.Forms.Panel
$pnlKopf.Location  = New-Object System.Drawing.Point(0, 0)
$pnlKopf.Size      = New-Object System.Drawing.Size(620, 72)
$pnlKopf.BackColor = [System.Drawing.Color]::White

$logoDatei = Get-LogoDatei
$logoBild  = $null
if ($logoDatei) {
    try { $logoBild = Get-LogoBild $logoDatei } catch { $logoBild = $null }
}

# Fenstersymbol: vorhandene logo.ico nutzen, sonst eine aus dem Logo erzeugen
$script:IcoPfad = $null
$icoImOrdner = [IO.Path]::Combine($script:Ordner, 'logo.ico')
$icoErsatz   = [IO.Path]::Combine($script:EinstOrdner, 'logo.ico')
try {
    if ($logoBild) {
        $zielIco  = $icoImOrdner
        $neuBauen = $true
        if (Test-Path -LiteralPath $zielIco) {
            $neuBauen = (Get-Item -LiteralPath $zielIco).LastWriteTime -lt (Get-Item -LiteralPath $logoDatei).LastWriteTime
        }
        if ($neuBauen) {
            try {
                New-LogoSymbol $logoBild $zielIco
            } catch {
                # Programmordner schreibgeschuetzt: Symbol neben den Einstellungen ablegen
                if (-not (Test-Path -LiteralPath $script:EinstOrdner)) {
                    New-Item -ItemType Directory -Path $script:EinstOrdner -Force | Out-Null
                }
                New-LogoSymbol $logoBild $icoErsatz
                $zielIco = $icoErsatz
            }
        }
        $script:IcoPfad = $zielIco
    } elseif (Test-Path -LiteralPath $icoImOrdner) {
        $script:IcoPfad = $icoImOrdner
    }
    if ($script:IcoPfad) { $form.Icon = New-Object System.Drawing.Icon($script:IcoPfad) }
} catch {
    if ($logoBild) {
        try { $form.Icon = [System.Drawing.Icon]::FromHandle((New-SymbolAusBild $logoBild 32).GetHicon()) } catch { }
    }
}

if ($logoBild) {
    $picLogo          = New-Object System.Windows.Forms.PictureBox
    $picLogo.Location = New-Object System.Drawing.Point(16, 11)
    $picLogo.Size     = New-Object System.Drawing.Size(210, 50)
    $picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $picLogo.Image    = $logoBild
    $pnlKopf.Controls.Add($picLogo)
} else {
    $lblLogo           = New-Object System.Windows.Forms.Label
    $lblLogo.Text      = $script:Firma
    $lblLogo.Location  = New-Object System.Drawing.Point(16, 18)
    $lblLogo.AutoSize  = $true
    $lblLogo.Font      = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $lblLogo.ForeColor = $firmenBlau
    $pnlKopf.Controls.Add($lblLogo)
}

$lblTitel           = New-Object System.Windows.Forms.Label
$lblTitel.Text      = 'Scannen'
$lblTitel.Location  = New-Object System.Drawing.Point(244, 13)
$lblTitel.AutoSize  = $true
$lblTitel.Font      = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$lblTitel.ForeColor = $firmenBlau

$lblUnter           = New-Object System.Windows.Forms.Label
$lblUnter.Text      = 'Canon imageFORMULA DR-C240'
$lblUnter.Location  = New-Object System.Drawing.Point(246, 42)
$lblUnter.AutoSize  = $true
$lblUnter.ForeColor = [System.Drawing.Color]::DimGray

$pnlKopf.Controls.AddRange(@($lblTitel, $lblUnter))

$lblLinie           = New-Object System.Windows.Forms.Label
$lblLinie.Location  = New-Object System.Drawing.Point(0, 72)
$lblLinie.Size      = New-Object System.Drawing.Size(620, 1)
$lblLinie.BackColor = [System.Drawing.Color]::FromArgb(214, 214, 214)

$form.Controls.AddRange(@($pnlKopf, $lblLinie))

# ===========================================================================
#  Kundenansicht: was wird gescannt, und die Schaltflaeche Scannen
# ===========================================================================
$grpWas          = New-Object System.Windows.Forms.GroupBox
$grpWas.Text     = ' Was soll gescannt werden? '
$grpWas.Location = New-Object System.Drawing.Point(18, 88)
$grpWas.Size     = New-Object System.Drawing.Size(584, 88)

$radPdf          = New-Object System.Windows.Forms.RadioButton
$radPdf.Text     = 'PDF (alle Blätter in einer Datei)'
$radPdf.Location = New-Object System.Drawing.Point(18, 26)
$radPdf.AutoSize = $true

$radBild          = New-Object System.Windows.Forms.RadioButton
$radBild.Text     = 'Bilddateien'
$radBild.Location = New-Object System.Drawing.Point(300, 26)
$radBild.AutoSize = $true

$cmbBildart          = New-Object System.Windows.Forms.ComboBox
$cmbBildart.Location = New-Object System.Drawing.Point(404, 24)
$cmbBildart.Size     = New-Object System.Drawing.Size(80, 24)
$cmbBildart.DropDownStyle = 'DropDownList'
[void]$cmbBildart.Items.AddRange(@('JPG', 'PNG', 'TIF'))

$chkDuplex          = New-Object System.Windows.Forms.CheckBox
$chkDuplex.Text     = 'Vorder- und Rückseite scannen'
$chkDuplex.Location = New-Object System.Drawing.Point(18, 56)
$chkDuplex.AutoSize = $true

$grpWas.Controls.AddRange(@($radPdf, $radBild, $cmbBildart, $chkDuplex))
$form.Controls.Add($grpWas)

$btnScan          = New-Object System.Windows.Forms.Button
$btnScan.Text     = 'Scannen'
$btnScan.Location = New-Object System.Drawing.Point(18, 188)
$btnScan.Size     = New-Object System.Drawing.Size(220, 48)
$btnScan.Font     = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

$btnAbbruch          = New-Object System.Windows.Forms.Button
$btnAbbruch.Text     = 'Abbrechen'
$btnAbbruch.Location = New-Object System.Drawing.Point(246, 188)
$btnAbbruch.Size     = New-Object System.Drawing.Size(120, 48)
$btnAbbruch.Enabled  = $false

$btnZeigen          = New-Object System.Windows.Forms.Button
$btnZeigen.Text     = 'Ergebnis zeigen'
$btnZeigen.Location = New-Object System.Drawing.Point(374, 188)
$btnZeigen.Size     = New-Object System.Drawing.Size(150, 48)
$btnZeigen.Enabled  = $false

$btnOrdner          = New-Object System.Windows.Forms.Button
$btnOrdner.Text     = 'Ordner'
$btnOrdner.Location = New-Object System.Drawing.Point(532, 188)
$btnOrdner.Size     = New-Object System.Drawing.Size(70, 48)

$form.Controls.AddRange(@($btnScan, $btnAbbruch, $btnZeigen, $btnOrdner))

$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Text      = 'Bereit.'
$lblStatus.Location  = New-Object System.Drawing.Point(18, 248)
$lblStatus.Size      = New-Object System.Drawing.Size(584, 36)
$lblStatus.Font      = New-Object System.Drawing.Font('Segoe UI', 9.5)
$form.Controls.Add($lblStatus)

$lblLinie2           = New-Object System.Windows.Forms.Label
$lblLinie2.Location  = New-Object System.Drawing.Point(0, 292)
$lblLinie2.Size      = New-Object System.Drawing.Size(620, 1)
$lblLinie2.BackColor = [System.Drawing.Color]::FromArgb(214, 214, 214)
$form.Controls.Add($lblLinie2)

# ===========================================================================
#  Servicebereich (nur nach Kennworteingabe sichtbar)
# ===========================================================================
$pnlService          = New-Object System.Windows.Forms.Panel
$pnlService.Location = New-Object System.Drawing.Point(0, 296)
$pnlService.Size     = New-Object System.Drawing.Size(620, 392)
$pnlService.Visible  = $false

$lblService          = New-Object System.Windows.Forms.Label
$lblService.Text     = 'Service - Einrichtung durch die ' + $script:Firma
$lblService.Location = New-Object System.Drawing.Point(18, 6)
$lblService.AutoSize = $true
$lblService.Font     = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$lblService.ForeColor = $firmenBlau

# --- Gerät und Qualität -----------------------------------------------------
$grpGeraet          = New-Object System.Windows.Forms.GroupBox
$grpGeraet.Text     = ' Gerät und Qualität '
$grpGeraet.Location = New-Object System.Drawing.Point(18, 28)
$grpGeraet.Size     = New-Object System.Drawing.Size(584, 92)

$lblGeraet          = New-Object System.Windows.Forms.Label
$lblGeraet.Text     = 'Scanner:'
$lblGeraet.Location = New-Object System.Drawing.Point(15, 26)
$lblGeraet.AutoSize = $true

$cmbGeraet          = New-Object System.Windows.Forms.ComboBox
$cmbGeraet.Location = New-Object System.Drawing.Point(90, 22)
$cmbGeraet.Size     = New-Object System.Drawing.Size(352, 24)
$cmbGeraet.DropDownStyle = 'DropDownList'

$btnAktual          = New-Object System.Windows.Forms.Button
$btnAktual.Text     = 'Suchen'
$btnAktual.Location = New-Object System.Drawing.Point(450, 21)
$btnAktual.Size     = New-Object System.Drawing.Size(118, 26)

$lblFarbe          = New-Object System.Windows.Forms.Label
$lblFarbe.Text     = 'Farbe:'
$lblFarbe.Location = New-Object System.Drawing.Point(15, 60)
$lblFarbe.AutoSize = $true

$cmbFarbe          = New-Object System.Windows.Forms.ComboBox
$cmbFarbe.Location = New-Object System.Drawing.Point(68, 56)
$cmbFarbe.Size     = New-Object System.Drawing.Size(120, 24)
$cmbFarbe.DropDownStyle = 'DropDownList'
[void]$cmbFarbe.Items.AddRange(@('Farbe', 'Graustufen', 'Schwarzweiß'))

$lblDpi          = New-Object System.Windows.Forms.Label
$lblDpi.Text     = 'Auflösung:'
$lblDpi.Location = New-Object System.Drawing.Point(210, 60)
$lblDpi.AutoSize = $true

$cmbDpi          = New-Object System.Windows.Forms.ComboBox
$cmbDpi.Location = New-Object System.Drawing.Point(292, 56)
$cmbDpi.Size     = New-Object System.Drawing.Size(70, 24)
$cmbDpi.DropDownStyle = 'DropDownList'
[void]$cmbDpi.Items.AddRange(@('150', '200', '300', '400', '600'))

$lblDpiEinheit          = New-Object System.Windows.Forms.Label
$lblDpiEinheit.Text     = 'dpi'
$lblDpiEinheit.Location = New-Object System.Drawing.Point(367, 60)
$lblDpiEinheit.AutoSize = $true

$grpGeraet.Controls.AddRange(@($lblGeraet, $cmbGeraet, $btnAktual, $lblFarbe, $cmbFarbe,
                               $lblDpi, $cmbDpi, $lblDpiEinheit))

# --- Ablage -----------------------------------------------------------------
$grpAblage          = New-Object System.Windows.Forms.GroupBox
$grpAblage.Text     = ' Ablage '
$grpAblage.Location = New-Object System.Drawing.Point(18, 128)
$grpAblage.Size     = New-Object System.Drawing.Size(584, 116)

$lblZiel          = New-Object System.Windows.Forms.Label
$lblZiel.Text     = 'Ordner:'
$lblZiel.Location = New-Object System.Drawing.Point(15, 28)
$lblZiel.AutoSize = $true

$txtZiel          = New-Object System.Windows.Forms.TextBox
$txtZiel.Location = New-Object System.Drawing.Point(88, 25)
$txtZiel.Size     = New-Object System.Drawing.Size(380, 24)

$btnZiel          = New-Object System.Windows.Forms.Button
$btnZiel.Text     = 'Wählen'
$btnZiel.Location = New-Object System.Drawing.Point(476, 24)
$btnZiel.Size     = New-Object System.Drawing.Size(92, 26)

$lblName          = New-Object System.Windows.Forms.Label
$lblName.Text     = 'Name:'
$lblName.Location = New-Object System.Drawing.Point(15, 62)
$lblName.AutoSize = $true

$txtName          = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(88, 59)
$txtName.Size     = New-Object System.Drawing.Size(150, 24)

$lblMuster           = New-Object System.Windows.Forms.Label
$lblMuster.Location  = New-Object System.Drawing.Point(248, 62)
$lblMuster.Size      = New-Object System.Drawing.Size(320, 20)
$lblMuster.ForeColor = [System.Drawing.Color]::DimGray

$chkOeffnen          = New-Object System.Windows.Forms.CheckBox
$chkOeffnen.Text     = 'Ergebnis nach dem Scan öffnen'
$chkOeffnen.Location = New-Object System.Drawing.Point(88, 90)
$chkOeffnen.AutoSize = $true

$grpAblage.Controls.AddRange(@($lblZiel, $txtZiel, $btnZiel, $lblName, $txtName, $lblMuster, $chkOeffnen))

# --- Protokoll --------------------------------------------------------------
$chkKachel          = New-Object System.Windows.Forms.CheckBox
$chkKachel.Text     = 'Kleines Fenster unten rechts anzeigen (immer im Vordergrund)'
$chkKachel.Location = New-Object System.Drawing.Point(18, 250)
$chkKachel.AutoSize = $true

$lblProt          = New-Object System.Windows.Forms.Label
$lblProt.Text     = 'Protokoll:'
$lblProt.Location = New-Object System.Drawing.Point(18, 276)
$lblProt.AutoSize = $true

$txtLog            = New-Object System.Windows.Forms.TextBox
$txtLog.Location   = New-Object System.Drawing.Point(18, 296)
$txtLog.Size       = New-Object System.Drawing.Size(584, 58)
$txtLog.Multiline  = $true
$txtLog.ReadOnly   = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.BackColor  = [System.Drawing.Color]::White
$txtLog.Font       = New-Object System.Drawing.Font('Consolas', 9)

$btnLink          = New-Object System.Windows.Forms.Button
$btnLink.Text     = 'Verknüpfung auf dem Desktop'
$btnLink.Location = New-Object System.Drawing.Point(18, 360)
$btnLink.Size     = New-Object System.Drawing.Size(210, 26)

$btnKennwort          = New-Object System.Windows.Forms.Button
$btnKennwort.Text     = 'Kennwort ändern'
$btnKennwort.Location = New-Object System.Drawing.Point(236, 360)
$btnKennwort.Size     = New-Object System.Drawing.Size(150, 26)

$btnServiceZu          = New-Object System.Windows.Forms.Button
$btnServiceZu.Text     = 'Service schließen'
$btnServiceZu.Location = New-Object System.Drawing.Point(452, 360)
$btnServiceZu.Size     = New-Object System.Drawing.Size(150, 26)

$pnlService.Controls.AddRange(@($lblService, $grpGeraet, $grpAblage, $chkKachel, $lblProt, $txtLog,
                                $btnLink, $btnKennwort, $btnServiceZu))
$form.Controls.Add($pnlService)

# --- Fusszeile --------------------------------------------------------------
$lblFuss           = New-Object System.Windows.Forms.Label
$lblFuss.Text      = "$($script:Firma)  -  $($script:Strasse)  -  $($script:Ort)"
$lblFuss.Location  = New-Object System.Drawing.Point(18, 304)
$lblFuss.Size      = New-Object System.Drawing.Size(584, 18)
$lblFuss.Anchor    = 'Bottom,Left'
$lblFuss.ForeColor = [System.Drawing.Color]::Gray
$lblFuss.Font      = New-Object System.Drawing.Font('Segoe UI', 8)
$form.Controls.Add($lblFuss)

# ===========================================================================
#  Kleine Kachel unten rechts - liegt immer im Vordergrund und oeffnet
#  auf Klick dieses Fenster mit den Optionen.
# ===========================================================================
$kachel                 = New-Object System.Windows.Forms.Form
$kachel.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$kachel.ShowInTaskbar   = $false
$kachel.TopMost         = $true
$kachel.StartPosition   = 'Manual'
$kachel.Size            = New-Object System.Drawing.Size(222, 98)
$kachel.BackColor       = $firmenBlau          # dient als 2 Pixel breiter Rahmen
$kachel.Padding         = New-Object System.Windows.Forms.Padding(2)
$kachel.Font            = $form.Font
if ($form.Icon) { $kachel.Icon = $form.Icon }

$kachelInnen           = New-Object System.Windows.Forms.Panel
$kachelInnen.Dock      = [System.Windows.Forms.DockStyle]::Fill
$kachelInnen.BackColor = [System.Drawing.Color]::White
$kachel.Controls.Add($kachelInnen)

# Name der Firma - ein Doppelklick darauf oeffnet den Servicebereich
$kachelBild = $null
if ($logoDatei) {
    try { $kachelBild = Get-LogoBild $logoDatei } catch { $kachelBild = $null }
}
if ($kachelBild) {
    $kachelName          = New-Object System.Windows.Forms.PictureBox
    $kachelName.Location = New-Object System.Drawing.Point(10, 7)
    $kachelName.Size     = New-Object System.Drawing.Size(150, 24)
    $kachelName.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $kachelName.Image    = $kachelBild
} else {
    $kachelName           = New-Object System.Windows.Forms.Label
    $kachelName.Text      = $script:Firma
    $kachelName.Location  = New-Object System.Drawing.Point(10, 6)
    $kachelName.AutoSize  = $true
    $kachelName.Font      = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $kachelName.ForeColor = $firmenBlau
}

$lblKachelStatus           = New-Object System.Windows.Forms.Label
$lblKachelStatus.Text      = 'Bereit'
$lblKachelStatus.Location  = New-Object System.Drawing.Point(10, 33)
$lblKachelStatus.Size      = New-Object System.Drawing.Size(198, 28)
$lblKachelStatus.ForeColor = [System.Drawing.Color]::DimGray
$lblKachelStatus.Font      = New-Object System.Drawing.Font('Segoe UI', 8)

$btnKachelScan           = New-Object System.Windows.Forms.Button
$btnKachelScan.Text      = 'Scan'
$btnKachelScan.Location  = New-Object System.Drawing.Point(10, 63)
$btnKachelScan.Size      = New-Object System.Drawing.Size(198, 27)
$btnKachelScan.Font      = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$btnKachelScan.ForeColor = $firmenBlau

$kachelInnen.Controls.AddRange(@($kachelName, $lblKachelStatus, $btnKachelScan))

$hinweis = New-Object System.Windows.Forms.ToolTip
$hinweisText = 'Scan: scannen  -  Doppelklick auf den Namen: Einstellungen  -  rechte Maustaste: Menü'
$hinweis.SetToolTip($kachelInnen, $hinweisText)
$hinweis.SetToolTip($kachelName, $hinweisText)

# --- Menue der rechten Maustaste -------------------------------------------
$menuKachel = New-Object System.Windows.Forms.ContextMenuStrip

$miScannen = New-Object System.Windows.Forms.ToolStripMenuItem('Scan starten')
$miScannen.Font = New-Object System.Drawing.Font($menuKachel.Font, [System.Drawing.FontStyle]::Bold)
[void]$menuKachel.Items.Add($miScannen)
[void]$menuKachel.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$miPdf    = New-Object System.Windows.Forms.ToolStripMenuItem('als PDF')
$miBild   = New-Object System.Windows.Forms.ToolStripMenuItem('als Bilddateien')
$miDuplex = New-Object System.Windows.Forms.ToolStripMenuItem('Vorder- und Rückseite')
[void]$menuKachel.Items.Add($miPdf)
[void]$menuKachel.Items.Add($miBild)
[void]$menuKachel.Items.Add($miDuplex)
[void]$menuKachel.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$miOptionen = New-Object System.Windows.Forms.ToolStripMenuItem('Weitere Einstellungen ...')
$miBeenden  = New-Object System.Windows.Forms.ToolStripMenuItem('Beenden')
[void]$menuKachel.Items.Add($miOptionen)
[void]$menuKachel.Items.Add($miBeenden)

$kachel.ContextMenuStrip = $menuKachel

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------
$script:Prozess     = $null
$script:LogDatei    = $null
$script:FehlerDatei = $null
$script:LetzterLog  = ''
$script:Ergebnis    = $null
$script:ServiceFrei = $false
$script:KachelAktiv = $true
$script:Beenden     = $false
$script:ZiehtGerade = $false
$script:Gezogen     = $false
$script:ZiehStart   = New-Object System.Drawing.Point(0, 0)
$script:KachelStart = New-Object System.Drawing.Point(0, 0)

# Statusmeldung im Fenster und in der Kachel zeigen
function Setze-Status([string]$text) {
    $lblStatus.Text = $text
    $kurz = $text -replace '\s+', ' '
    if ($kurz.Length -gt 95) { $kurz = $kurz.Substring(0, 92) + '...' }
    $lblKachelStatus.Text = $kurz
    try { $hinweis.SetToolTip($lblKachelStatus, $text) } catch { }
}

function Lies-Oberflaeche {
    $bildart = 'jpg'
    if ($cmbBildart.SelectedItem) { $bildart = ([string]$cmbBildart.SelectedItem).ToLowerInvariant() }
    $farbe = 'farbe'
    switch ([string]$cmbFarbe.SelectedItem) {
        'Graustufen'  { $farbe = 'grau' }
        'Schwarzweiß' { $farbe = 'sw' }
        default       { $farbe = 'farbe' }
    }
    $dpi = 300
    if ($cmbDpi.SelectedItem) { $dpi = [int]([string]$cmbDpi.SelectedItem) }
    $format = 'pdf'
    if ($radBild.Checked) { $format = 'bild' }
    # Kachelposition nur sichern, wenn die Kachel auch benutzt wird
    $kx = -1
    $ky = -1
    if ($script:KachelAktiv -and $kachel.Visible) {
        $kx = $kachel.Location.X
        $ky = $kachel.Location.Y
    } elseif ($e.KachelX -ge 0) {
        $kx = [int]$e.KachelX
        $ky = [int]$e.KachelY
    }
    return @{
        Ziel    = $txtZiel.Text
        Format  = $format
        Bildart = $bildart
        Farbe   = $farbe
        Dpi     = $dpi
        Duplex  = $chkDuplex.Checked
        Name    = $txtName.Text
        Oeffnen = $chkOeffnen.Checked
        Scanner = [string]$cmbGeraet.SelectedItem
        Kachel  = $chkKachel.Checked
        KachelX = $kx
        KachelY = $ky
    }
}

function Aktualisiere-Muster {
    $endung = '.pdf'
    if ($radBild.Checked -and $cmbBildart.SelectedItem) {
        $endung = '.' + ([string]$cmbBildart.SelectedItem).ToLowerInvariant()
    }
    $name = $txtName.Text.Trim()
    if (-not $name) { $name = 'Scan' }
    $lblMuster.Text = '-> ' + $name + '_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + $endung
    $cmbBildart.Enabled = $radBild.Checked
}

function Setze-Betrieb([bool]$laeuft) {
    $btnScan.Enabled       = -not $laeuft
    $btnKachelScan.Enabled = -not $laeuft
    $btnAbbruch.Enabled  = $laeuft
    $grpWas.Enabled      = -not $laeuft
    $pnlService.Enabled  = -not $laeuft
    if ($laeuft) { $form.Cursor = [System.Windows.Forms.Cursors]::AppStarting }
    else         { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
}

function Fuelle-Scannerliste {
    $cmbGeraet.Items.Clear()
    $namen = Get-ScannerNamen
    if ($namen.Count -eq 0) {
        [void]$cmbGeraet.Items.Add('(kein Scanner gefunden)')
        $cmbGeraet.SelectedIndex = 0
        Setze-Status 'Kein Scanner gefunden - bitte Gerät einschalten und Kabel prüfen.'
        return
    }
    foreach ($n in $namen) { [void]$cmbGeraet.Items.Add($n) }
    $index = 0
    if ($e.Scanner) {
        $gefunden = $cmbGeraet.Items.IndexOf($e.Scanner)
        if ($gefunden -ge 0) { $index = $gefunden }
    }
    $cmbGeraet.SelectedIndex = $index
    Setze-Status 'Bereit.'
}

# ---------------------------------------------------------------------------
# Kennwortabfrage
# ---------------------------------------------------------------------------
function Show-Kennwortfrage([string]$titel, [string]$beschriftung) {
    $d                 = New-Object System.Windows.Forms.Form
    $d.Text            = $titel
    $d.ClientSize      = New-Object System.Drawing.Size(390, 132)
    $d.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $d.StartPosition   = 'CenterScreen'   # der Besitzer kann versteckt sein
    $d.MinimizeBox     = $false
    $d.MaximizeBox     = $false
    $d.ShowInTaskbar   = $false
    $d.TopMost         = $true            # sonst liegt die Kachel davor
    $d.Font            = $form.Font
    if ($form.Icon) { $d.Icon = $form.Icon }

    $l          = New-Object System.Windows.Forms.Label
    $l.Text     = $beschriftung
    $l.Location = New-Object System.Drawing.Point(18, 18)
    $l.Size     = New-Object System.Drawing.Size(354, 22)

    $t              = New-Object System.Windows.Forms.TextBox
    $t.Location     = New-Object System.Drawing.Point(18, 46)
    $t.Size         = New-Object System.Drawing.Size(354, 24)
    $t.UseSystemPasswordChar = $true

    $ok          = New-Object System.Windows.Forms.Button
    $ok.Text     = 'OK'
    $ok.Location = New-Object System.Drawing.Point(196, 88)
    $ok.Size     = New-Object System.Drawing.Size(84, 28)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $ab          = New-Object System.Windows.Forms.Button
    $ab.Text     = 'Abbrechen'
    $ab.Location = New-Object System.Drawing.Point(288, 88)
    $ab.Size     = New-Object System.Drawing.Size(84, 28)
    $ab.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $d.Controls.AddRange(@($l, $t, $ok, $ab))
    $d.AcceptButton = $ok
    $d.CancelButton = $ab

    [void]$d.Activate()
    $antwort = $d.ShowDialog()
    $eingabe = $t.Text
    $d.Dispose()
    if ($antwort -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return $eingabe
}

function Zeige-Service([bool]$sichtbar) {
    $pnlService.Visible = $sichtbar
    if ($sichtbar) {
        $form.ClientSize = New-Object System.Drawing.Size(620, $script:HoeheService)
        # auf niedrigen Bildschirmen bekommt der Servicebereich eine Bildlaufleiste
        $platz = $script:HoeheService - $pnlService.Top - 28
        if ($platz -lt 392) {
            $pnlService.Height     = $platz
            $pnlService.AutoScroll = $true
        } else {
            $pnlService.Height     = 392
            $pnlService.AutoScroll = $false
        }
    } else {
        $form.ClientSize = New-Object System.Drawing.Size(620, $script:HoeheKunde)
    }
}

# Kennwort festlegen (Ersteinrichtung oder Wechsel). Gibt $true bei Erfolg.
function Setze-NeuesKennwort([string]$titel, [string]$text) {
    $neu = Show-Kennwortfrage $titel $text
    if ($null -eq $neu) { return $false }
    if ($neu.Length -lt 4) {
        [void][System.Windows.Forms.MessageBox]::Show($null, 'Bitte mindestens vier Zeichen verwenden.', $titel, 'OK', 'Warning')
        return $false
    }
    $wdh = Show-Kennwortfrage $titel 'Kennwort zur Sicherheit wiederholen:'
    if ($null -eq $wdh) { return $false }
    if ($neu -cne $wdh) {
        [void][System.Windows.Forms.MessageBox]::Show($null, 'Die beiden Eingaben sind nicht gleich.', $titel, 'OK', 'Warning')
        return $false
    }
    $wohin = Speichere-KennwortHash (Get-TextHash $neu)
    if ($wohin -eq 'Nur Sitzung') {
        [void][System.Windows.Forms.MessageBox]::Show($null,
            ('Das Kennwort konnte nirgends gespeichert werden (alles schreibgeschützt).' + "`r`n" +
             'Es gilt nur bis zum Beenden des Programms.'), $titel, 'OK', 'Warning')
    }
    return $true
}

function Oeffne-Service {
    if (-not $script:ServiceFrei) {
        if (-not (Get-KennwortHash)) {
            # Erstes Mal: Kennwort festlegen, danach ist die Einrichtung frei
            $frage = [System.Windows.Forms.MessageBox]::Show($null,
                ('Für diesen Rechner ist noch kein Servicekennwort vergeben.' + "`r`n`r`n" +
                 'Jetzt eines festlegen?'), 'Einrichtung', 'YesNo', 'Question')
            if ($frage -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            if (-not (Setze-NeuesKennwort 'Einrichtung' 'Neues Servicekennwort festlegen:')) { return }
        } else {
            $eingabe = Show-Kennwortfrage 'Service' 'Servicekennwort eingeben:'
            if ($null -eq $eingabe) { return }
            if (-not (Test-Kennwort $eingabe)) {
                [void][System.Windows.Forms.MessageBox]::Show($null, 'Das Kennwort ist falsch.', 'Service', 'OK', 'Warning')
                return
            }
        }
        $script:ServiceFrei = $true
    }
    Zeige-Hauptfenster        # das Fenster kann versteckt sein
    Zeige-Service $true
}

# ---------------------------------------------------------------------------
# Ereignisse
# ---------------------------------------------------------------------------
$form.Add_KeyDown({
    param($absender, $ereignis)
    if ($ereignis.Control -and $ereignis.Alt -and $ereignis.KeyCode -eq [System.Windows.Forms.Keys]::S) {
        $ereignis.SuppressKeyPress = $true
        Oeffne-Service
    }
})

# Doppelklick auf den Kopfbereich oeffnet den Servicebereich ebenfalls
$pnlKopf.Add_DoubleClick({ Oeffne-Service })
$lblTitel.Add_DoubleClick({ Oeffne-Service })
$lblUnter.Add_DoubleClick({ Oeffne-Service })
if ($logoBild) { $picLogo.Add_DoubleClick({ Oeffne-Service }) } else { $lblLogo.Add_DoubleClick({ Oeffne-Service }) }

$btnServiceZu.Add_Click({ Zeige-Service $false })

$btnAktual.Add_Click({ Fuelle-Scannerliste })

$radPdf.Add_CheckedChanged({ Aktualisiere-Muster })
$radBild.Add_CheckedChanged({ Aktualisiere-Muster })
$cmbBildart.Add_SelectedIndexChanged({ Aktualisiere-Muster })
$txtName.Add_TextChanged({ Aktualisiere-Muster })

$btnZiel.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Ordner für die Scans wählen'
    if (Test-Path -LiteralPath $txtZiel.Text) { $dialog.SelectedPath = $txtZiel.Text }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtZiel.Text = $dialog.SelectedPath
    }
    $dialog.Dispose()
})

$btnOrdner.Add_Click({
    $ziel = $txtZiel.Text.Trim()
    if (-not $ziel) { return }
    try {
        if (-not (Test-Path -LiteralPath $ziel)) { New-Item -ItemType Directory -Path $ziel -Force | Out-Null }
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $ziel + '"')
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show($form, "Der Ordner konnte nicht geöffnet werden:`r`n$ziel",
            'Scannen', 'OK', 'Warning')
    }
})

$btnZeigen.Add_Click({
    if (-not $script:Ergebnis) { return }
    try {
        if (Test-Path -LiteralPath $script:Ergebnis -PathType Leaf) {
            Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $script:Ergebnis + '"')
        } else {
            Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $script:Ergebnis + '"')
        }
    } catch { }
})

$btnLink.Add_Click({
    try {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $pfad = [IO.Path]::Combine($desktop, 'Scannen.lnk')
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($pfad)
        $lnk.TargetPath       = $script:EigenerPfad
        $lnk.WorkingDirectory = $script:Ordner
        $lnk.WindowStyle      = 7        # minimiert starten: kein Konsolenfenster
        $lnk.Description      = "Scannen - $($script:Firma)"
        if ($script:IcoPfad -and (Test-Path -LiteralPath $script:IcoPfad)) {
            $lnk.IconLocation = "$($script:IcoPfad),0"
        }
        $lnk.Save()
        [void][System.Windows.Forms.MessageBox]::Show($form,
            "Die Verknüpfung 'Scannen' liegt jetzt auf dem Desktop.", 'Scannen', 'OK', 'Information')
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show($form,
            "Die Verknüpfung konnte nicht angelegt werden:`r`n$($_.Exception.Message)", 'Scannen', 'OK', 'Warning')
    }
})

$btnKennwort.Add_Click({
    if (Setze-NeuesKennwort 'Kennwort ändern' 'Neues Servicekennwort:') {
        [void][System.Windows.Forms.MessageBox]::Show($form, 'Das Servicekennwort wurde geändert.', 'Kennwort ändern', 'OK', 'Information')
    }
})

$btnAbbruch.Add_Click({
    if ($null -eq $script:Prozess) { return }
    try {
        if (-not $script:Prozess.HasExited) {
            $script:Prozess.Kill()
            Setze-Status 'Abgebrochen. Ein bereits begonnenes Blatt zieht der Scanner noch zu Ende.'
        }
    } catch { }
})

# Timer verfolgt den laufenden Scan
$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = 300

$timer.Add_Tick({
    if ($null -eq $script:Prozess) { $timer.Stop(); return }

    $text = ''
    foreach ($datei in @($script:LogDatei, $script:FehlerDatei)) {
        if ($datei -and (Test-Path -LiteralPath $datei)) {
            try {
                $strom = New-Object IO.FileStream($datei, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                $leser = New-Object IO.StreamReader($strom, [Text.Encoding]::UTF8)
                $text += $leser.ReadToEnd()
                $leser.Dispose(); $strom.Dispose()
            } catch { }
        }
    }
    $aufbereitet = Format-Protokoll $text
    if ($aufbereitet -ne $script:LetzterLog) {
        $script:LetzterLog = $aufbereitet
        $txtLog.Text = $aufbereitet
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
        # letzte Meldung auch in der Kundenansicht zeigen
        $zeilen = @($aufbereitet -split "`r`n" | Where-Object { $_.Trim() })
        if ($zeilen.Count -gt 0) {
            $letzte = $zeilen[$zeilen.Count - 1].Trim()
            if ($letzte -match '^\s*Seite ') { Setze-Status $letzte }
        }
    }

    if (-not $script:Prozess.HasExited) { return }

    $timer.Stop()
    $code = $script:Prozess.ExitCode
    $script:Prozess.Dispose()
    $script:Prozess = $null
    Setze-Betrieb $false

    $script:Ergebnis = Get-ErgebnisPfad $script:LetzterLog
    $btnZeigen.Enabled = [bool]$script:Ergebnis

    switch ($code) {
        0 {
            $anzahl = ''
            if ($script:LetzterLog -match '(?m)^Fertig:\s*(\d+)\s') { $anzahl = $matches[1] }
            if ($anzahl) { Setze-Status "Fertig - $anzahl Seite(n) gescannt und gespeichert." }
            else         { Setze-Status 'Fertig.' }
        }
        2 { Setze-Status 'Fehlerhafte Einstellung - bitte den Service verständigen.' }
        3 { Setze-Status 'Kein Scanner gefunden - Gerät einschalten und Kabel prüfen.' }
        4 { Setze-Status 'Es wurde kein Blatt eingezogen - Dokument einlegen und erneut auf Scannen klicken.' }
        5 { Setze-Status 'Fehler während des Scans - läuft eine andere Scan-Software?' }
        6 { Setze-Status 'Die Datei konnte nicht gespeichert werden - bitte den Service verständigen.' }
        9 { Setze-Status 'PowerShell wurde nicht gefunden.' }
        default { Setze-Status "Beendet (Rückgabewert $code)." }
    }
    Aktualisiere-Muster
})

function Starte-Scan {
    if ($null -ne $script:Prozess) { return }   # laeuft bereits
    if (-not (Test-Path -LiteralPath $script:ScanBat)) {
        [void][System.Windows.Forms.MessageBox]::Show($form,
            "Scan.bat wurde nicht gefunden.`r`n`r`nErwartet wird die Datei im selben Ordner:`r`n$($script:ScanBat)",
            'Scannen', 'OK', 'Error')
        return
    }

    $aktuell = Lies-Oberflaeche
    $ziel = "$($aktuell.Ziel)".Trim()
    if (-not $ziel) {
        [void][System.Windows.Forms.MessageBox]::Show($form,
            'Es ist noch kein Zielordner eingerichtet. Bitte den Service verständigen.', 'Scannen', 'OK', 'Warning')
        return
    }
    try {
        if (-not (Test-Path -LiteralPath $ziel)) { New-Item -ItemType Directory -Path $ziel -Force | Out-Null }
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show($form,
            "Der Zielordner ist nicht erreichbar:`r`n$ziel`r`n`r`nBitte den Service verständigen.", 'Scannen', 'OK', 'Error')
        return
    }

    [void](Save-Einstellungen $aktuell)

    $script:LetzterLog  = ''
    $script:Ergebnis    = $null
    $btnZeigen.Enabled  = $false
    $txtLog.Text        = ''
    Setze-Status 'Scan läuft - bitte warten ...'
    Setze-Betrieb $true

    $kennung = [Guid]::NewGuid().ToString('N')
    $script:LogDatei    = [IO.Path]::Combine([IO.Path]::GetTempPath(), "scan_$kennung.log")
    $script:FehlerDatei = [IO.Path]::Combine([IO.Path]::GetTempPath(), "scan_$kennung.err")

    $argumente = New-ScanArgumente $aktuell
    $env:SCAN_NOPAUSE = '1'   # Scan.bat soll nicht auf einen Tastendruck warten

    try {
        $script:Prozess = Start-Process -FilePath $script:ScanBat -ArgumentList $argumente `
            -NoNewWindow -PassThru -RedirectStandardOutput $script:LogDatei -RedirectStandardError $script:FehlerDatei
        $timer.Start()
    } catch {
        Setze-Betrieb $false
        Setze-Status 'Der Scanvorgang konnte nicht gestartet werden.'
        [void][System.Windows.Forms.MessageBox]::Show($form, $_.Exception.Message, 'Scannen', 'OK', 'Error')
    }
}

$btnScan.Add_Click({ Starte-Scan })

# ---------------------------------------------------------------------------
# Fenster und Kachel verwalten
# ---------------------------------------------------------------------------
function Zeige-Hauptfenster {
    if (-not $form.Visible) { $form.Show() }
    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    }
    $form.BringToFront()
    [void]$form.Activate()
}

function Positioniere-Kachel {
    $bereich = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x = [int]$e.KachelX
    $y = [int]$e.KachelY
    $passt = ($x -ge $bereich.Left) -and ($y -ge $bereich.Top) -and
             ($x -le ($bereich.Right - 40)) -and ($y -le ($bereich.Bottom - 20))
    if (-not $passt) {
        # Vorgabe: rechte untere Ecke des Arbeitsbereichs (ueber der Taskleiste)
        $x = $bereich.Right  - $kachel.Width  - 16
        $y = $bereich.Bottom - $kachel.Height - 16
    }
    $kachel.Location = New-Object System.Drawing.Point($x, $y)
}

function Beende-Programm {
    if ($null -ne $script:Prozess -and -not $script:Prozess.HasExited) {
        $antwort = [System.Windows.Forms.MessageBox]::Show($form,
            'Es läuft noch ein Scan. Wirklich beenden?', 'Scannen', 'YesNo', 'Question')
        if ($antwort -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        try { $script:Prozess.Kill() } catch { }
    }
    $script:Beenden = $true
    $timer.Stop()
    [void](Save-Einstellungen (Lies-Oberflaeche))
    foreach ($datei in @($script:LogDatei, $script:FehlerDatei)) {
        if ($datei) { Remove-Item -LiteralPath $datei -Force -ErrorAction SilentlyContinue }
    }
    $kachel.Hide()
    $form.Close()
    [System.Windows.Forms.Application]::Exit()
}

# --- Kachel: Ziehen verschiebt sie, Doppelklick auf den Namen oeffnet den
#     Servicebereich, der Knopf Scan startet den Scan.
$kachelRunter = {
    param($absender, $ereignis)
    if ($ereignis.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $script:ZiehtGerade = $true
    $script:Gezogen     = $false
    $script:ZiehStart   = [System.Windows.Forms.Cursor]::Position
    $script:KachelStart = $kachel.Location
}
$kachelBewegt = {
    param($absender, $ereignis)
    if (-not $script:ZiehtGerade) { return }
    $jetzt = [System.Windows.Forms.Cursor]::Position
    $dx = $jetzt.X - $script:ZiehStart.X
    $dy = $jetzt.Y - $script:ZiehStart.Y
    if (-not $script:Gezogen -and ([Math]::Abs($dx) + [Math]::Abs($dy)) -lt 4) { return }
    $script:Gezogen = $true
    $kachel.Location = New-Object System.Drawing.Point(($script:KachelStart.X + $dx), ($script:KachelStart.Y + $dy))
}
$kachelHoch = {
    param($absender, $ereignis)
    $script:ZiehtGerade = $false
}

foreach ($teil in @($kachel, $kachelInnen, $kachelName, $lblKachelStatus)) {
    $teil.Add_MouseDown($kachelRunter)
    $teil.Add_MouseMove($kachelBewegt)
    $teil.Add_MouseUp($kachelHoch)
    $teil.ContextMenuStrip = $menuKachel
}
$kachelName.Cursor = [System.Windows.Forms.Cursors]::Hand
$kachelName.Add_DoubleClick({ Oeffne-Service })

$btnKachelScan.Add_Click({ Starte-Scan })

# Haken im Menue vor dem Aufklappen an die aktuellen Einstellungen anpassen
$menuKachel.Add_Opening({
    $miPdf.Checked    = $radPdf.Checked
    $miBild.Checked   = $radBild.Checked
    $miDuplex.Checked = $chkDuplex.Checked
    $miScannen.Enabled = ($null -eq $script:Prozess)
})

$miScannen.Add_Click({ Starte-Scan })
$miPdf.Add_Click({ $radPdf.Checked = $true })
$miBild.Add_Click({ $radBild.Checked = $true })
$miDuplex.Add_Click({ $chkDuplex.Checked = -not $chkDuplex.Checked })
$miOptionen.Add_Click({ Zeige-Hauptfenster })
$miBeenden.Add_Click({ Beende-Programm })

$form.Add_FormClosing({
    param($absender, $ereignis)
    if ($script:Beenden) { return }          # wird gerade beendet

    # Mit Kachel bleibt das Programm laufen; das Fenster verschwindet nur.
    if ($script:KachelAktiv -and $ereignis.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $ereignis.Cancel = $true
        [void](Save-Einstellungen (Lies-Oberflaeche))
        if ($pnlService.Visible) { Zeige-Service $false }
        $script:ServiceFrei = $false     # naechstes Mal wieder mit Kennwort
        $form.Hide()
        return
    }

    if ($null -ne $script:Prozess -and -not $script:Prozess.HasExited) {
        $antwort = [System.Windows.Forms.MessageBox]::Show($form,
            'Es läuft noch ein Scan. Wirklich beenden?', 'Scannen', 'YesNo', 'Question')
        if ($antwort -ne [System.Windows.Forms.DialogResult]::Yes) {
            $ereignis.Cancel = $true
            return
        }
        try { $script:Prozess.Kill() } catch { }
    }
    $script:Beenden = $true
    $timer.Stop()
    [void](Save-Einstellungen (Lies-Oberflaeche))
    foreach ($datei in @($script:LogDatei, $script:FehlerDatei)) {
        if ($datei) { Remove-Item -LiteralPath $datei -Force -ErrorAction SilentlyContinue }
    }
    [System.Windows.Forms.Application]::Exit()
})

# Kachel ein- oder ausschalten, wenn die Einstellung im Service geaendert wird
$chkKachel.Add_CheckedChanged({
    $script:KachelAktiv = $chkKachel.Checked
    if ($script:KachelAktiv) {
        if (-not $kachel.Visible) { Positioniere-Kachel; $kachel.Show() }
    } else {
        $kachel.Hide()
        if (-not $form.Visible) { Zeige-Hauptfenster }
    }
})

# ---------------------------------------------------------------------------
# Gespeicherte Einstellungen in die Oberflaeche uebernehmen
# ---------------------------------------------------------------------------
$txtZiel.Text       = $e.Ziel
$txtName.Text       = $e.Name
$chkDuplex.Checked  = [bool]$e.Duplex
$chkOeffnen.Checked = [bool]$e.Oeffnen
$radPdf.Checked     = ($e.Format -eq 'pdf')
$radBild.Checked    = ($e.Format -ne 'pdf')
$chkKachel.Checked  = [bool]$e.Kachel
$script:KachelAktiv = [bool]$e.Kachel

$cmbBildart.SelectedItem = ("$($e.Bildart)".ToUpperInvariant())
if ($null -eq $cmbBildart.SelectedItem) { $cmbBildart.SelectedIndex = 0 }

switch ("$($e.Farbe)") {
    'grau' { $cmbFarbe.SelectedItem = 'Graustufen' }
    'sw'   { $cmbFarbe.SelectedItem = 'Schwarzweiß' }
    default { $cmbFarbe.SelectedItem = 'Farbe' }
}
$cmbDpi.SelectedItem = [string][int]$e.Dpi
if ($null -eq $cmbDpi.SelectedItem) { $cmbDpi.SelectedItem = '300' }

Aktualisiere-Muster
Fuelle-Scannerliste

if (-not (Test-Path -LiteralPath $script:ScanBat)) {
    Setze-Status 'Scan.bat fehlt - sie muss im selben Ordner liegen wie dieses Programm.'
}

Setze-Status $lblStatus.Text

if ($script:KachelAktiv) {
    Positioniere-Kachel
    $kachel.Show()
} else {
    $form.Show()
}

# Erster Start auf diesem Rechner: zuerst das Servicekennwort festlegen,
# danach steht die Einrichtung sofort offen.
if (-not (Get-KennwortHash)) {
    [void][System.Windows.Forms.MessageBox]::Show($null,
        ('Einrichtung durch die ' + $script:Firma + "`r`n`r`n" +
         'Legen Sie zuerst ein Servicekennwort fest. Es schützt Zielordner und ' +
         'Geräteeinstellungen vor versehentlichen Änderungen.'),
        'Einrichtung', 'OK', 'Information')
    if (Setze-NeuesKennwort 'Einrichtung' 'Neues Servicekennwort festlegen:') {
        $script:ServiceFrei = $true
        Zeige-Hauptfenster
        Zeige-Service $true
    }
}

[System.Windows.Forms.Application]::Run()

if ($logoBild)   { $logoBild.Dispose() }
if ($kachelBild) { $kachelBild.Dispose() }
$kachel.Dispose()
$form.Dispose()
