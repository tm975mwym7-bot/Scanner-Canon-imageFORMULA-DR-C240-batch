@echo off
rem ===========================================================================
rem  Scanner.bat - kleines Fenster-Programm zum Scannen (Canon DR-C240)
rem
rem  Zeigt eine Oberflaeche mit den wichtigsten Einstellungen (PDF oder Bild,
rem  Farbe, Aufloesung, Duplex, Zielordner). Der Zielordner und alle anderen
rem  Einstellungen werden gemerkt und beim naechsten Start wieder verwendet.
rem
rem  Gescannt wird ueber Scan.bat, das im selben Ordner liegen muss.
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
# ===========================================================================
$ErrorActionPreference = 'Stop'

$script:EigenerPfad  = $env:GUI_SELF
$script:Ordner       = Split-Path -Parent $script:EigenerPfad
$script:ScanBat      = [IO.Path]::Combine($script:Ordner, 'Scan.bat')
$script:EinstOrdner  = [IO.Path]::Combine($env:APPDATA, 'Scan-DR-C240')
$script:EinstDatei   = [IO.Path]::Combine($script:EinstOrdner, 'einstellungen.json')

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
    }
    if (Test-Path -LiteralPath $script:EinstDatei) {
        try {
            $gespeichert = Get-Content -LiteralPath $script:EinstDatei -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($schluessel in @($e.Keys)) {
                $wert = $gespeichert.$schluessel
                if ($null -ne $wert -and "$wert" -ne '') { $e[$schluessel] = $wert }
            }
            $e.Dpi    = [int]$e.Dpi
            $e.Duplex = [bool]$e.Duplex
            $e.Oeffnen = [bool]$e.Oeffnen
        } catch {
            # beschaedigte Datei: mit den Vorgaben weiterarbeiten
        }
    }
    return $e
}

function Save-Einstellungen($e) {
    try {
        if (-not (Test-Path -LiteralPath $script:EinstOrdner)) {
            New-Item -ItemType Directory -Path $script:EinstOrdner -Force | Out-Null
        }
        ([pscustomobject]$e) | ConvertTo-Json | Set-Content -LiteralPath $script:EinstDatei -Encoding UTF8
        return $true
    } catch {
        return $false
    }
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
# Oberflaeche
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$e = Get-Einstellungen

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = 'Scannen'
$form.Size            = New-Object System.Drawing.Size(580, 560)
$form.MinimumSize     = New-Object System.Drawing.Size(580, 480)
$form.StartPosition   = 'CenterScreen'
$form.Font            = New-Object System.Drawing.Font('Segoe UI', 9)
$form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::Dpi

# --- Scannerauswahl ---------------------------------------------------------
$lblGeraet          = New-Object System.Windows.Forms.Label
$lblGeraet.Text     = 'Scanner:'
$lblGeraet.Location = New-Object System.Drawing.Point(18, 22)
$lblGeraet.Size     = New-Object System.Drawing.Size(70, 20)

$cmbGeraet          = New-Object System.Windows.Forms.ComboBox
$cmbGeraet.Location = New-Object System.Drawing.Point(90, 18)
$cmbGeraet.Size     = New-Object System.Drawing.Size(330, 24)
$cmbGeraet.DropDownStyle = 'DropDownList'
$cmbGeraet.Anchor   = 'Top,Left,Right'

$btnAktual          = New-Object System.Windows.Forms.Button
$btnAktual.Text     = 'Suchen'
$btnAktual.Location = New-Object System.Drawing.Point(430, 17)
$btnAktual.Size     = New-Object System.Drawing.Size(110, 26)
$btnAktual.Anchor   = 'Top,Right'

$form.Controls.AddRange(@($lblGeraet, $cmbGeraet, $btnAktual))

# --- Gruppe: Ausgabe --------------------------------------------------------
$grpAusgabe          = New-Object System.Windows.Forms.GroupBox
$grpAusgabe.Text     = ' Ausgabe '
$grpAusgabe.Location = New-Object System.Drawing.Point(18, 55)
$grpAusgabe.Size     = New-Object System.Drawing.Size(522, 105)
$grpAusgabe.Anchor   = 'Top,Left,Right'

$radPdf          = New-Object System.Windows.Forms.RadioButton
$radPdf.Text     = 'PDF (mehrseitig)'
$radPdf.Location = New-Object System.Drawing.Point(15, 25)
$radPdf.Size     = New-Object System.Drawing.Size(140, 22)

$radBild          = New-Object System.Windows.Forms.RadioButton
$radBild.Text     = 'Bilddateien'
$radBild.Location = New-Object System.Drawing.Point(165, 25)
$radBild.Size     = New-Object System.Drawing.Size(100, 22)

$cmbBildart          = New-Object System.Windows.Forms.ComboBox
$cmbBildart.Location = New-Object System.Drawing.Point(268, 24)
$cmbBildart.Size     = New-Object System.Drawing.Size(80, 24)
$cmbBildart.DropDownStyle = 'DropDownList'
[void]$cmbBildart.Items.AddRange(@('JPG', 'PNG', 'TIF'))

$lblFarbe          = New-Object System.Windows.Forms.Label
$lblFarbe.Text     = 'Farbe:'
$lblFarbe.Location = New-Object System.Drawing.Point(15, 66)
$lblFarbe.Size     = New-Object System.Drawing.Size(50, 20)

$cmbFarbe          = New-Object System.Windows.Forms.ComboBox
$cmbFarbe.Location = New-Object System.Drawing.Point(68, 62)
$cmbFarbe.Size     = New-Object System.Drawing.Size(120, 24)
$cmbFarbe.DropDownStyle = 'DropDownList'
[void]$cmbFarbe.Items.AddRange(@('Farbe', 'Graustufen', 'Schwarzweiss'))

$lblDpi          = New-Object System.Windows.Forms.Label
$lblDpi.Text     = 'Aufloesung:'
$lblDpi.Location = New-Object System.Drawing.Point(205, 66)
$lblDpi.Size     = New-Object System.Drawing.Size(75, 20)

$cmbDpi          = New-Object System.Windows.Forms.ComboBox
$cmbDpi.Location = New-Object System.Drawing.Point(282, 62)
$cmbDpi.Size     = New-Object System.Drawing.Size(70, 24)
$cmbDpi.DropDownStyle = 'DropDownList'
[void]$cmbDpi.Items.AddRange(@('150', '200', '300', '400', '600'))

$lblDpiEinheit          = New-Object System.Windows.Forms.Label
$lblDpiEinheit.Text     = 'dpi'
$lblDpiEinheit.Location = New-Object System.Drawing.Point(357, 66)
$lblDpiEinheit.Size     = New-Object System.Drawing.Size(30, 20)

$chkDuplex          = New-Object System.Windows.Forms.CheckBox
$chkDuplex.Text     = 'Vorder- und Rueckseite'
$chkDuplex.Location = New-Object System.Drawing.Point(390, 64)
$chkDuplex.Size     = New-Object System.Drawing.Size(170, 22)

$grpAusgabe.Controls.AddRange(@($radPdf, $radBild, $cmbBildart, $lblFarbe, $cmbFarbe,
                                $lblDpi, $cmbDpi, $lblDpiEinheit, $chkDuplex))
$form.Controls.Add($grpAusgabe)

# --- Gruppe: Ablage ---------------------------------------------------------
$grpAblage          = New-Object System.Windows.Forms.GroupBox
$grpAblage.Text     = ' Ablage '
$grpAblage.Location = New-Object System.Drawing.Point(18, 170)
$grpAblage.Size     = New-Object System.Drawing.Size(522, 120)
$grpAblage.Anchor   = 'Top,Left,Right'

$lblZiel          = New-Object System.Windows.Forms.Label
$lblZiel.Text     = 'Ordner:'
$lblZiel.Location = New-Object System.Drawing.Point(15, 28)
$lblZiel.Size     = New-Object System.Drawing.Size(70, 20)

$txtZiel          = New-Object System.Windows.Forms.TextBox
$txtZiel.Location = New-Object System.Drawing.Point(88, 25)
$txtZiel.Size     = New-Object System.Drawing.Size(320, 24)
$txtZiel.Anchor   = 'Top,Left,Right'

$btnZiel          = New-Object System.Windows.Forms.Button
$btnZiel.Text     = 'Waehlen'
$btnZiel.Location = New-Object System.Drawing.Point(415, 24)
$btnZiel.Size     = New-Object System.Drawing.Size(90, 26)
$btnZiel.Anchor   = 'Top,Right'

$lblName          = New-Object System.Windows.Forms.Label
$lblName.Text     = 'Name:'
$lblName.Location = New-Object System.Drawing.Point(15, 62)
$lblName.Size     = New-Object System.Drawing.Size(70, 20)

$txtName          = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(88, 59)
$txtName.Size     = New-Object System.Drawing.Size(150, 24)

$lblMuster          = New-Object System.Windows.Forms.Label
$lblMuster.Location = New-Object System.Drawing.Point(244, 62)
$lblMuster.Size     = New-Object System.Drawing.Size(265, 20)
$lblMuster.ForeColor = [System.Drawing.Color]::DimGray

$chkOeffnen          = New-Object System.Windows.Forms.CheckBox
$chkOeffnen.Text     = 'Ergebnis nach dem Scan oeffnen'
$chkOeffnen.Location = New-Object System.Drawing.Point(88, 90)
$chkOeffnen.Size     = New-Object System.Drawing.Size(260, 22)

$grpAblage.Controls.AddRange(@($lblZiel, $txtZiel, $btnZiel, $lblName, $txtName, $lblMuster, $chkOeffnen))
$form.Controls.Add($grpAblage)

# --- Schaltflaechen ---------------------------------------------------------
$btnScan          = New-Object System.Windows.Forms.Button
$btnScan.Text     = 'Scannen'
$btnScan.Location = New-Object System.Drawing.Point(18, 302)
$btnScan.Size     = New-Object System.Drawing.Size(150, 38)
$btnScan.Font     = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

$btnAbbruch          = New-Object System.Windows.Forms.Button
$btnAbbruch.Text     = 'Abbrechen'
$btnAbbruch.Location = New-Object System.Drawing.Point(176, 302)
$btnAbbruch.Size     = New-Object System.Drawing.Size(110, 38)
$btnAbbruch.Enabled  = $false

$btnZeigen          = New-Object System.Windows.Forms.Button
$btnZeigen.Text     = 'Ergebnis zeigen'
$btnZeigen.Location = New-Object System.Drawing.Point(294, 302)
$btnZeigen.Size     = New-Object System.Drawing.Size(130, 38)
$btnZeigen.Enabled  = $false

$btnOrdner          = New-Object System.Windows.Forms.Button
$btnOrdner.Text     = 'Ordner'
$btnOrdner.Location = New-Object System.Drawing.Point(432, 302)
$btnOrdner.Size     = New-Object System.Drawing.Size(108, 38)
$btnOrdner.Anchor   = 'Top,Right'

$form.Controls.AddRange(@($btnScan, $btnAbbruch, $btnZeigen, $btnOrdner))

# --- Statusbereich ----------------------------------------------------------
$lblStatus          = New-Object System.Windows.Forms.Label
$lblStatus.Text     = 'Bereit.'
$lblStatus.Location = New-Object System.Drawing.Point(18, 350)
$lblStatus.Size     = New-Object System.Drawing.Size(522, 20)
$lblStatus.Anchor   = 'Top,Left,Right'

$txtLog             = New-Object System.Windows.Forms.TextBox
$txtLog.Location    = New-Object System.Drawing.Point(18, 373)
$txtLog.Size        = New-Object System.Drawing.Size(522, 130)
$txtLog.Multiline   = $true
$txtLog.ReadOnly    = $true
$txtLog.ScrollBars  = 'Vertical'
$txtLog.BackColor   = [System.Drawing.Color]::White
$txtLog.Font        = New-Object System.Drawing.Font('Consolas', 9)
$txtLog.Anchor      = 'Top,Bottom,Left,Right'

$form.Controls.AddRange(@($lblStatus, $txtLog))

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------
$script:Prozess     = $null
$script:LogDatei    = $null
$script:FehlerDatei = $null
$script:LetzterLog  = ''
$script:Ergebnis    = $null

function Lies-Oberflaeche {
    $bildart = 'jpg'
    if ($cmbBildart.SelectedItem) { $bildart = ([string]$cmbBildart.SelectedItem).ToLowerInvariant() }
    $farbe = 'farbe'
    switch ([string]$cmbFarbe.SelectedItem) {
        'Graustufen'   { $farbe = 'grau' }
        'Schwarzweiss' { $farbe = 'sw' }
        default        { $farbe = 'farbe' }
    }
    $dpi = 300
    if ($cmbDpi.SelectedItem) { $dpi = [int]([string]$cmbDpi.SelectedItem) }
    $format = 'pdf'
    if ($radBild.Checked) { $format = 'bild' }
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
    $btnScan.Enabled    = -not $laeuft
    $btnAbbruch.Enabled = $laeuft
    $btnAktual.Enabled  = -not $laeuft
    $grpAusgabe.Enabled = -not $laeuft
    $grpAblage.Enabled  = -not $laeuft
    $cmbGeraet.Enabled  = -not $laeuft
    if ($laeuft) { $form.Cursor = [System.Windows.Forms.Cursors]::AppStarting }
    else         { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
}

function Fuelle-Scannerliste {
    $cmbGeraet.Items.Clear()
    $namen = Get-ScannerNamen
    if ($namen.Count -eq 0) {
        [void]$cmbGeraet.Items.Add('(kein Scanner gefunden)')
        $cmbGeraet.SelectedIndex = 0
        $lblStatus.Text = 'Kein Scanner gefunden - Geraet einschalten, Kabel und Treiber pruefen.'
        return
    }
    foreach ($n in $namen) { [void]$cmbGeraet.Items.Add($n) }
    $index = 0
    if ($e.Scanner) {
        $gefunden = $cmbGeraet.Items.IndexOf($e.Scanner)
        if ($gefunden -ge 0) { $index = $gefunden }
    }
    $cmbGeraet.SelectedIndex = $index
    $lblStatus.Text = 'Bereit.'
}

# ---------------------------------------------------------------------------
# Ereignisse
# ---------------------------------------------------------------------------
$btnAktual.Add_Click({ Fuelle-Scannerliste })

$radPdf.Add_CheckedChanged({ Aktualisiere-Muster })
$radBild.Add_CheckedChanged({ Aktualisiere-Muster })
$cmbBildart.Add_SelectedIndexChanged({ Aktualisiere-Muster })
$txtName.Add_TextChanged({ Aktualisiere-Muster })

$btnZiel.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Ordner fuer die Scans waehlen'
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
        [void][System.Windows.Forms.MessageBox]::Show($form, "Der Ordner konnte nicht geoeffnet werden:`r`n$ziel",
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

$btnAbbruch.Add_Click({
    if ($null -eq $script:Prozess) { return }
    try {
        if (-not $script:Prozess.HasExited) {
            $script:Prozess.Kill()
            $lblStatus.Text = 'Abgebrochen. Der Scanner zieht ein bereits begonnenes Blatt noch zu Ende.'
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
        0 { $lblStatus.Text = 'Fertig.' }
        2 { $lblStatus.Text = 'Fehlerhafte Einstellung - bitte Werte pruefen.' }
        3 { $lblStatus.Text = 'Kein Scanner gefunden oder Windows-Bilderfassung nicht verfuegbar.' }
        4 { $lblStatus.Text = 'Es wurde kein Blatt eingezogen - Dokument einlegen und erneut scannen.' }
        5 { $lblStatus.Text = 'Fehler waehrend des Scans - laeuft eine andere Scan-Software?' }
        6 { $lblStatus.Text = 'Die Datei konnte nicht gespeichert werden - Zielordner pruefen.' }
        9 { $lblStatus.Text = 'PowerShell wurde nicht gefunden.' }
        default { $lblStatus.Text = "Beendet (Rueckgabewert $code)." }
    }
    Aktualisiere-Muster
})

$btnScan.Add_Click({
    if (-not (Test-Path -LiteralPath $script:ScanBat)) {
        [void][System.Windows.Forms.MessageBox]::Show($form,
            "Scan.bat wurde nicht gefunden.`r`n`r`nErwartet wird die Datei im selben Ordner:`r`n$($script:ScanBat)",
            'Scannen', 'OK', 'Error')
        return
    }

    $aktuell = Lies-Oberflaeche
    $ziel = "$($aktuell.Ziel)".Trim()
    if (-not $ziel) {
        [void][System.Windows.Forms.MessageBox]::Show($form, 'Bitte zuerst einen Zielordner waehlen.', 'Scannen', 'OK', 'Warning')
        return
    }
    try {
        if (-not (Test-Path -LiteralPath $ziel)) { New-Item -ItemType Directory -Path $ziel -Force | Out-Null }
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show($form, "Der Zielordner kann nicht angelegt werden:`r`n$ziel", 'Scannen', 'OK', 'Error')
        return
    }

    [void](Save-Einstellungen $aktuell)

    $script:LetzterLog  = ''
    $script:Ergebnis    = $null
    $btnZeigen.Enabled  = $false
    $txtLog.Text        = ''
    $lblStatus.Text     = 'Scan laeuft - bitte warten ...'
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
        $lblStatus.Text = 'Der Scanvorgang konnte nicht gestartet werden.'
        [void][System.Windows.Forms.MessageBox]::Show($form, $_.Exception.Message, 'Scannen', 'OK', 'Error')
    }
})

$form.Add_FormClosing({
    param($absender, $ereignis)
    if ($null -ne $script:Prozess -and -not $script:Prozess.HasExited) {
        $antwort = [System.Windows.Forms.MessageBox]::Show($form,
            'Es laeuft noch ein Scan. Wirklich beenden?', 'Scannen', 'YesNo', 'Question')
        if ($antwort -ne [System.Windows.Forms.DialogResult]::Yes) {
            $ereignis.Cancel = $true
            return
        }
        try { $script:Prozess.Kill() } catch { }
    }
    $timer.Stop()
    [void](Save-Einstellungen (Lies-Oberflaeche))
    foreach ($datei in @($script:LogDatei, $script:FehlerDatei)) {
        if ($datei) { Remove-Item -LiteralPath $datei -Force -ErrorAction SilentlyContinue }
    }
})

# ---------------------------------------------------------------------------
# Gespeicherte Einstellungen in die Oberflaeche uebernehmen
# ---------------------------------------------------------------------------
$txtZiel.Text      = $e.Ziel
$txtName.Text      = $e.Name
$chkDuplex.Checked = [bool]$e.Duplex
$chkOeffnen.Checked = [bool]$e.Oeffnen
$radPdf.Checked    = ($e.Format -eq 'pdf')
$radBild.Checked   = ($e.Format -ne 'pdf')

$cmbBildart.SelectedItem = ("$($e.Bildart)".ToUpperInvariant())
if ($null -eq $cmbBildart.SelectedItem) { $cmbBildart.SelectedIndex = 0 }

switch ("$($e.Farbe)") {
    'grau' { $cmbFarbe.SelectedItem = 'Graustufen' }
    'sw'   { $cmbFarbe.SelectedItem = 'Schwarzweiss' }
    default { $cmbFarbe.SelectedItem = 'Farbe' }
}
$cmbDpi.SelectedItem = [string][int]$e.Dpi
if ($null -eq $cmbDpi.SelectedItem) { $cmbDpi.SelectedItem = '300' }

Aktualisiere-Muster
Fuelle-Scannerliste

if (-not (Test-Path -LiteralPath $script:ScanBat)) {
    $lblStatus.Text = 'Scan.bat fehlt - sie muss im selben Ordner liegen wie dieses Programm.'
}

[void]$form.ShowDialog()
$form.Dispose()
