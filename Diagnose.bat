@echo off
rem ===========================================================================
rem  Diagnose.bat - prueft, warum das Scannen nicht klappt
rem
rem  Entwickelt von der IDO GmbH
rem  Anderslebener Str. 40, 39387 Oschersleben
rem  (c) 2026 IDO GmbH - alle Rechte vorbehalten
rem
rem  Sammelt Angaben zu Windows, zum Dienst der Bilderfassung, zu den
rem  angeschlossenen Geraeten und zum Treiber und schreibt einen Bericht
rem  auf den Desktop.
rem
rem  Aufruf:  Diagnose.bat            nur pruefen
rem           Diagnose.bat /scan      zusaetzlich eine Testseite einziehen
rem           Diagnose.bat /freigeben Programme beenden, die den Scanner belegen
rem           Diagnose.bat /duplextest probiert aus, welche Duplex-Einstellung
rem                                    dieser Treiber annimmt (Blatt einlegen!)
rem           Diagnose.bat /naps2     NAPS2 suchen und dessen Geraete auflisten
rem ===========================================================================

setlocal enableextensions
set "DIAG_SELF=%~f0"
set "DIAG_ARGS=%*"

set "DIAG_OLDCP="
for /f "tokens=2 delims=:" %%a in ('chcp 2^>nul') do for /f "tokens=1 delims=. " %%b in ("%%a") do set "DIAG_OLDCP=%%b"
chcp 65001 >nul 2>&1

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo FEHLER: Windows PowerShell wurde nicht gefunden.
    pause
    exit /b 9
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:DIAG_SELF,[Text.Encoding]::UTF8); $m='#~'+'PSSTART~'; $p=$t.IndexOf($m); if($p -lt 0){Write-Host 'FEHLER: Skriptteil nicht gefunden.'; exit 9}; & ([scriptblock]::Create($t.Substring($p)))"
set "DIAG_RC=%ERRORLEVEL%"

if defined DIAG_OLDCP chcp %DIAG_OLDCP% >nul 2>&1
echo.
pause
endlocal & exit /b %DIAG_RC%

#~PSSTART~
# ===========================================================================
#  Scanner-Diagnose
# ===========================================================================
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$script:Firma  = 'IDO GmbH'
$script:Zeilen = New-Object System.Collections.ArrayList

function Zeile($text, $farbe) {
    if ($null -eq $text) { $text = '' }
    [void]$script:Zeilen.Add([string]$text)
    if ($farbe) { Write-Host $text -ForegroundColor $farbe } else { Write-Host $text }
}
function Titel($text) {
    Zeile ''
    Zeile ('--- ' + $text + ' ' + ('-' * [Math]::Max(3, 66 - $text.Length)))
}
function Gut($text)     { Zeile ("  [ok]   $text") 'Green' }
function Schlecht($text){ Zeile ("  [!]    $text") 'Red' }
function Warnung($text) { Zeile ("  [?]    $text") 'Yellow' }
function Punkt($text)   { Zeile ("         $text") }

# Programme, die einen Scanner belegen koennen. Der Name muss genau passen
# (ohne .exe), damit nichts Unbeteiligtes getroffen wird.
$script:Belegkandidaten = @(
    @{ Name = 'CaptureOnTouch';     Text = 'Canon CaptureOnTouch' }
    @{ Name = 'CaptureOnTouchLite'; Text = 'Canon CaptureOnTouch Lite' }
    @{ Name = 'COTLite';            Text = 'Canon CaptureOnTouch Lite' }
    @{ Name = 'CNMCOT';             Text = 'Canon CaptureOnTouch (Hintergrund)' }
    @{ Name = 'CNQL240';            Text = 'Canon DR-C240 Hilfsprogramm' }
    @{ Name = 'ScanButtonMonitor';  Text = 'Canon Tastenueberwachung' }
    @{ Name = 'CNMScanButton';      Text = 'Canon Tastenueberwachung' }
    @{ Name = 'wiaacmgr';           Text = 'Windows-Scan-Assistent' }
    @{ Name = 'WFS';                Text = 'Windows-Fax und -Scan' }
    @{ Name = 'WindowsScan';        Text = 'Windows-App "Scannen"' }
    @{ Name = 'NAPS2';              Text = 'NAPS2' }
    @{ Name = 'ScanGear';           Text = 'Canon ScanGear' }
    @{ Name = 'PaperStream';        Text = 'PaperStream' }
    @{ Name = 'ScanSnap';           Text = 'ScanSnap' }
    @{ Name = 'Acrobat';            Text = 'Adobe Acrobat (Scan-Dialog)' }
)

function Get-BelegendeProgramme {
    $gefunden = @()
    try {
        $laufend = Get-Process -ErrorAction SilentlyContinue
    } catch { return $gefunden }
    foreach ($kandidat in $script:Belegkandidaten) {
        foreach ($prozess in $laufend) {
            if ($prozess.ProcessName -ieq $kandidat.Name) {
                $gefunden += [pscustomobject]@{
                    Prozess = $prozess
                    Name    = $prozess.ProcessName
                    Text    = $kandidat.Text
                    Id      = $prozess.Id
                }
            }
        }
    }
    return $gefunden
}

$befunde = @{
    WiaDienst   = $false
    WiaGeraet   = $false
    PnpGeraet   = $false
    PnpProblem  = ''
    Verbindung  = $false
    Twain       = $false
    Fehlertext  = ''
    Belegt      = @()
}

Zeile '==========================================================================='
Zeile ' Scanner-Diagnose                                                 IDO GmbH '
Zeile ('                                                   ' + (Get-Date -Format 'dd.MM.yyyy HH:mm'))
Zeile '==========================================================================='

# ---------------------------------------------------------------------------
Titel '1. System'
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Punkt ("Windows      : {0} (Build {1}, {2})" -f $os.Caption.Trim(), $os.BuildNumber, $os.OSArchitecture)
} catch {
    Punkt "Windows      : konnte nicht ermittelt werden"
}
$bit = '32 Bit'
if ([Environment]::Is64BitProcess) { $bit = '64 Bit' }
Punkt ("PowerShell   : {0} ({1})" -f $PSVersionTable.PSVersion, $bit)
Punkt ("Benutzer     : {0}" -f $env:USERNAME)

# ---------------------------------------------------------------------------
Titel '2. Dienst "Windows-Bilderfassung (WIA)"'
try {
    $dienst = Get-Service -Name stisvc -ErrorAction Stop
    if ($dienst.Status -eq 'Running') {
        Gut ("stisvc laeuft (Starttyp: {0})" -f $dienst.StartType)
        $befunde.WiaDienst = $true
    } else {
        Schlecht ("stisvc ist NICHT gestartet (Status: {0})" -f $dienst.Status)
        Punkt 'Starten mit:  net start stisvc     (Eingabeaufforderung als Administrator)'
    }
} catch {
    Schlecht 'Der Dienst stisvc wurde nicht gefunden - die Windows-Bilderfassung fehlt.'
}

# ---------------------------------------------------------------------------
Titel '3. Von Windows gemeldete Bildgeraete (WIA)'
$wiaGeraete = @()
try {
    $manager = New-Object -ComObject WIA.DeviceManager -ErrorAction Stop
    $anzahl = 0
    try { $anzahl = [int]$manager.DeviceInfos.Count } catch { $anzahl = 0 }
    Punkt ("gemeldete Geraete insgesamt: {0}" -f $anzahl)
    for ($n = 1; $n -le $anzahl; $n++) {
        $info = $manager.DeviceInfos.Item($n)
        $name = ''
        $port = ''
        try { $name = [string]$info.Properties.Item('Name').Value } catch { }
        try { $port = [string]$info.Properties.Item('Port').Value } catch { }
        $art = switch ([int]$info.Type) { 1 { 'Scanner' } 2 { 'Kamera' } 3 { 'Video' } default { "Typ $($info.Type)" } }
        Punkt ("[{0}] {1}  ({2}, Anschluss: {3})" -f $n, $name, $art, $port)
        if ([int]$info.Type -eq 1) {
            $wiaGeraete += $info
            $befunde.WiaGeraet = $true
        }
    }
    if ($anzahl -eq 0) { Schlecht 'Windows meldet kein einziges Bildgeraet.' }
    elseif (-not $befunde.WiaGeraet) { Schlecht 'Es sind Bildgeraete da, aber kein Scanner.' }
    else { Gut ("{0} Scanner gefunden." -f $wiaGeraete.Count) }
} catch {
    Schlecht "Die Windows-Bilderfassung antwortet nicht: $($_.Exception.Message.Trim())"
}

# ---------------------------------------------------------------------------
Titel '4. Geraete-Manager (angeschlossene Hardware)'
try {
    $pnp = Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object {
        $_.PNPClass -in @('Image', 'USB', 'Scanner') -or $_.Name -match 'Canon|scanner|imageFORMULA|DR-C'
    }
    if (-not $pnp) {
        Warnung 'Kein passendes Geraet gefunden - bitte Kabel und Einschaltzustand pruefen.'
    }
    foreach ($g in $pnp) {
        $code = [int]$g.ConfigManagerErrorCode
        $text = "{0}  [{1}]" -f $g.Name, $g.PNPClass
        if ($g.Name -match 'Canon|imageFORMULA|DR-C|scanner') {
            $befunde.PnpGeraet = $true
            if ($code -eq 0) { Gut $text }
            else {
                $befunde.PnpProblem = "Code $code"
                Schlecht ("{0} - Problem Code {1}" -f $text, $code)
                switch ($code) {
                    1  { Punkt 'Code 1: Geraet ist falsch eingerichtet - Treiber neu installieren.' }
                    10 { Punkt 'Code 10: Geraet kann nicht gestartet werden - anderen USB-Anschluss versuchen.' }
                    28 { Punkt 'Code 28: Es ist KEIN Treiber installiert - Canon-Treiberpaket installieren.' }
                    43 { Punkt 'Code 43: Windows hat das Geraet angehalten - aus- und wieder einschalten.' }
                    45 { Punkt 'Code 45: Geraet ist gerade nicht angeschlossen.' }
                }
            }
        } elseif ($code -ne 0 -and $g.PNPClass -eq 'Image') {
            Warnung ("{0} - Problem Code {1}" -f $text, $code)
        }
    }
} catch {
    Warnung "Der Geraete-Manager konnte nicht abgefragt werden: $($_.Exception.Message.Trim())"
}

# ---------------------------------------------------------------------------
Titel '5. Treiberarten'
$twainOrdner = @("$env:WINDIR\twain_32", "$env:WINDIR\twain_64")
foreach ($ordner in $twainOrdner) {
    if (Test-Path -LiteralPath $ordner) {
        $quellen = @(Get-ChildItem -LiteralPath $ordner -Recurse -Include *.ds, *.ds64 -ErrorAction SilentlyContinue)
        if ($quellen.Count -gt 0) {
            $befunde.Twain = $true
            Punkt ("TWAIN in {0}: {1}" -f (Split-Path -Leaf $ordner), (($quellen | ForEach-Object { $_.Name }) -join ', '))
        }
    }
}
if (-not $befunde.Twain) { Punkt 'Keine TWAIN-Quellen gefunden.' }

try {
    $canon = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' `
               -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Canon|DR-C|CaptureOnTouch|ISIS' })
    if ($canon) {
        foreach ($c in $canon) { Punkt ("installiert   : {0} {1}" -f $c.DisplayName, $c.DisplayVersion) }
    } else {
        Warnung 'Es ist keine Canon-Software installiert.'
    }
} catch { }

# ---------------------------------------------------------------------------
Titel '6. Programme, die den Scanner belegen koennen'
$befunde.Belegt = @(Get-BelegendeProgramme)
if ($befunde.Belegt.Count -eq 0) {
    Gut 'Es laeuft kein bekanntes Scan-Programm.'
} else {
    Schlecht 'Diese Programme greifen selbst auf den Scanner zu:'
    foreach ($b in $befunde.Belegt) {
        Punkt ("{0}  (Prozess {1}, PID {2})" -f $b.Text, $b.Name, $b.Id)
    }
    Punkt ''
    Punkt 'Solange eines davon laeuft, meldet Windows beim Scannen haeufig nur'
    Punkt '"Schwerwiegender Fehler". Beenden mit:  Diagnose.bat /freigeben'

    if ($env:DIAG_ARGS -match '/freigeben') {
        Punkt ''
        Punkt 'Die Programme werden beendet ...'
        foreach ($b in $befunde.Belegt) {
            try {
                $b.Prozess.CloseMainWindow() | Out-Null
                Start-Sleep -Milliseconds 700
                if (-not $b.Prozess.HasExited) { $b.Prozess.Kill() }
                Start-Sleep -Milliseconds 300
                Gut ("{0} wurde beendet." -f $b.Text)
            } catch {
                Schlecht ("{0} liess sich nicht beenden: {1}" -f $b.Text, $_.Exception.Message.Trim())
            }
        }
        $befunde.Belegt = @(Get-BelegendeProgramme)
        if ($befunde.Belegt.Count -eq 0) { Gut 'Der Scanner ist jetzt frei.' }
    }
}

# Canon-Dienste, die im Hintergrund laufen
try {
    $dienste = @(Get-Service -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -match 'Canon|CNM|imageFORMULA') -and $_.Status -eq 'Running' })
    foreach ($d in $dienste) { Punkt ("Dienst laeuft: {0} ({1})" -f $d.DisplayName, $d.Name) }
} catch { }

# ---------------------------------------------------------------------------
Titel '7. Verbindungstest'
if ($wiaGeraete.Count -eq 0) {
    Punkt 'uebersprungen - es wurde kein Scanner gefunden.'
} else {
    $info = $wiaGeraete[0]
    $name = ''
    try { $name = [string]$info.Properties.Item('Name').Value } catch { $name = 'Scanner' }
    Punkt ("Test mit: {0}" -f $name)
    try {
        $geraet = $info.Connect()
        Gut 'Verbindung steht.'
        $befunde.Verbindung = $true

        $lese = {
            param($sammlung, $id)
            foreach ($p in $sammlung) { if ($p.PropertyID -eq $id) { try { return $p.Value } catch { return $null } } }
            return $null
        }
        $caps   = & $lese $geraet.Properties 3086
        $status = & $lese $geraet.Properties 3087
        if ($null -ne $caps) {
            $arten = @()
            if ($caps -band 1) { $arten += 'Einzug' }
            if ($caps -band 2) { $arten += 'Flachbett' }
            if ($caps -band 4) { $arten += 'Duplex' }
            Punkt ("Faehigkeiten : {0}" -f ($arten -join ', '))
        }
        if ($null -ne $status) {
            if ($status -band 1) { Punkt 'Papier       : liegt im Einzug' }
            else                 { Punkt 'Papier       : kein Papier im Einzug' }
        }
        $element = $geraet.Items.Item(1)
        $formate = @()
        try { foreach ($f in $element.Formats) { $formate += [string]$f } } catch { }
        $namen = @()
        foreach ($f in $formate) {
            switch ($f.ToUpperInvariant()) {
                '{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}' { $namen += 'JPEG' }
                '{B96B3CAF-0728-11D3-9D7B-0000F81EF32E}' { $namen += 'PNG' }
                '{B96B3CAB-0728-11D3-9D7B-0000F81EF32E}' { $namen += 'BMP' }
                '{B96B3CB1-0728-11D3-9D7B-0000F81EF32E}' { $namen += 'TIFF' }
                default { $namen += $f }
            }
        }
        if ($namen.Count -gt 0) { Punkt ("Bildformate  : {0}" -f ($namen -join ', ')) }
        $dpi = & $lese $element.Properties 6147
        if ($null -ne $dpi) { Punkt ("Aufloesung   : {0} dpi eingestellt" -f $dpi) }
    } catch {
        $hr = 0
        $ex = $_.Exception
        while ($null -ne $ex) {
            if ($ex -is [System.Runtime.InteropServices.COMException]) { $hr = $ex.HResult; break }
            $ex = $ex.InnerException
        }
        $befunde.Fehlertext = $_.Exception.Message.Trim()
        Schlecht ("Die Verbindung schlaegt fehl: {0}" -f $befunde.Fehlertext)
        if ($hr -ne 0) {
            Punkt ("Fehlernummer : 0x{0:X8}" -f $hr)
            switch ($hr) {
                -2145320939 { Punkt 'Das Geraet ist offline oder von einem anderen Programm belegt.' }
                -2145320954 { Punkt 'Das Geraet wird gerade von einem anderen Programm benutzt.' }
                -2145320959 { Punkt 'Allgemeiner Geraetefehler - Geraet aus- und wieder einschalten.' }
            }
        }
    }
}

# ---------------------------------------------------------------------------
if ($env:DIAG_ARGS -match '/scan') {
    Titel '8. Testscan'
    if (-not $befunde.Verbindung) {
        Punkt 'uebersprungen - keine Verbindung.'
    } else {
        try {
            $geraet2 = $wiaGeraete[0].Connect()
            $element2 = $geraet2.Items.Item(1)
            $ziel = [IO.Path]::Combine([IO.Path]::GetTempPath(), 'Testscan.jpg')
            if (Test-Path -LiteralPath $ziel) { Remove-Item -LiteralPath $ziel -Force }
            Punkt 'Es wird eine Seite eingezogen ...'
            $bild = $element2.Transfer('{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}')
            $bild.SaveFile($ziel)
            Gut ("Testscan erfolgreich: {0} ({1:N0} Bytes)" -f $ziel, (Get-Item -LiteralPath $ziel).Length)
        } catch {
            $hr2 = 0
            $ex2 = $_.Exception
            while ($null -ne $ex2) {
                if ($ex2 -is [System.Runtime.InteropServices.COMException]) { $hr2 = $ex2.HResult; break }
                $ex2 = $ex2.InnerException
            }
            Schlecht ("Der Testscan schlaegt fehl: {0}" -f $_.Exception.Message.Trim())
            if ($hr2 -ne 0) {
                Punkt ("Fehlernummer : 0x{0:X8}" -f $hr2)
                switch ($hr2) {
                    -2145320957 { Punkt 'Kein Papier im Einzug - Blatt einlegen und erneut versuchen.' }
                    -2145320958 { Punkt 'Papierstau.' }
                    -2145320939 { Punkt 'Geraet offline oder belegt.' }
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
if ($env:DIAG_ARGS -match '/duplextest') {
    Titel '9. Duplex-Test'
    if ($wiaGeraete.Count -eq 0) {
        Punkt 'uebersprungen - kein Scanner gefunden.'
    } else {
        # Die Einzugsart gibt es am Geraet und am Scan-Element. Laut Microsoft
        # muss erst das Element und dann das Geraet gesetzt werden. Ob der
        # Treiber einen Wert wirklich annimmt, zeigt das Zurueck-Lesen - dafuer
        # wird kein Blatt eingezogen.
        $varianten = @(
            @{ Wert = 13; Text = 'Einzug + Duplex + Vorderseite zuerst (13)'; Duplex = $true }
            @{ Wert =  5; Text = 'Einzug + Duplex (5)';                       Duplex = $true }
            @{ Wert =  4; Text = 'nur Duplex (4)';                            Duplex = $true }
            @{ Wert = 33; Text = 'Einzug, nur Vorderseite (33)';              Duplex = $false }
            @{ Wert =  1; Text = 'Einzug einseitig (1)';                      Duplex = $false }
        )
        try {
            $g  = $wiaGeraete[0].Connect()
            $it = $g.Items.Item(1)

            $gueltig = @()
            foreach ($sammlung in @($it.Properties, $g.Properties)) {
                foreach ($prop in $sammlung) {
                    if ($prop.PropertyID -eq 3088) {
                        try { foreach ($w in $prop.SubTypeValues) { $gueltig += [int]$w } } catch { }
                    }
                }
            }
            $gueltig = @($gueltig | Select-Object -Unique | Sort-Object)
            if ($gueltig.Count -gt 0) { Punkt ("Der Treiber meldet als gueltig: " + ($gueltig -join ', ')) }
            else { Punkt 'Der Treiber meldet keine Liste gueltiger Werte.' }
            Punkt ''

            $genommen = @()
            foreach ($v in $varianten) {
                $amElement = $false
                $amGeraet  = $false
                foreach ($prop in $it.Properties) {
                    if ($prop.PropertyID -eq 3088) {
                        try { $prop.Value = $v.Wert } catch { }
                        try { if ([int]$prop.Value -eq $v.Wert) { $amElement = $true } } catch { }
                    }
                }
                foreach ($prop in $g.Properties) {
                    if ($prop.PropertyID -eq 3088) {
                        try { $prop.Value = $v.Wert } catch { }
                        try { if ([int]$prop.Value -eq $v.Wert) { $amGeraet = $true } } catch { }
                    }
                }
                $wo = @()
                if ($amElement) { $wo += 'Element' }
                if ($amGeraet)  { $wo += 'Geraet' }
                if ($wo.Count -gt 0) {
                    Gut ("{0}: angenommen ({1})" -f $v.Text, ($wo -join ' und '))
                    $genommen += $v
                } else {
                    Punkt ("{0}: wird nicht uebernommen" -f $v.Text)
                }
            }

            Punkt ''
            $besteDuplex = $genommen | Where-Object { $_.Duplex } | Select-Object -First 1
            if ($besteDuplex) {
                Gut ("Beidseitig sollte gehen mit: {0}" -f $besteDuplex.Text)
                Punkt ("Fest einstellen:  Scan.bat /duplex /duplexwert {0}" -f $besteDuplex.Wert)
                Punkt ''
                Punkt 'Zum Gegenpruefen mit Papier:  Diagnose.bat /duplextest /scan'
                if ($env:DIAG_ARGS -match '/scan') {
                    Punkt ''
                    Punkt ("Es wird ein Blatt mit '{0}' eingezogen ..." -f $besteDuplex.Text)
                    foreach ($prop in $it.Properties) { if ($prop.PropertyID -eq 3088) { try { $prop.Value = $besteDuplex.Wert } catch { } } }
                    foreach ($prop in $g.Properties)  { if ($prop.PropertyID -eq 3088) { try { $prop.Value = $besteDuplex.Wert } catch { } } }
                    try {
                        $bild = $it.Transfer('{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}')
                        $tmp = [IO.Path]::Combine([IO.Path]::GetTempPath(), 'duplextest.jpg')
                        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
                        $bild.SaveFile($tmp)
                        Gut 'Der Scan mit dieser Einstellung funktioniert.'
                        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                    } catch {
                        $hr3 = 0
                        $ex3 = $_.Exception
                        while ($null -ne $ex3) {
                            if ($ex3 -is [System.Runtime.InteropServices.COMException]) { $hr3 = $ex3.HResult; break }
                            $ex3 = $ex3.InnerException
                        }
                        if ($hr3 -eq -2145320957) { Warnung 'Kein Papier im Einzug - bitte Blatt einlegen und erneut testen.' }
                        else { Schlecht ("Der Scan schlaegt fehl: {0}{1}" -f $_.Exception.Message.Trim(),
                                         $(if ($hr3 -ne 0) { ' (0x{0:X8})' -f $hr3 } else { '' })) }
                    }
                }
            } else {
                Warnung 'Keine Duplex-Schreibweise wird uebernommen.'
                Punkt 'Dieser WIA-Treiber nimmt keine Duplex-Vorgabe von aussen an. Das Geraet'
                Punkt 'kann es trotzdem - die Einstellung muss nur im Treiber selbst stehen:'
                Punkt '    Scan.bat /dialog      Einstellungen des Treibers oeffnen,'
                Punkt '                          dort Duplex waehlen, mit OK bestaetigen'
                Punkt 'Im Fenster: Service -> Knopf "Treiber ..." neben der Scannerauswahl.'
            }
        } catch {
            Schlecht ("Der Duplex-Test ist fehlgeschlagen: {0}" -f $_.Exception.Message.Trim())
        }
    }
}

# ---------------------------------------------------------------------------
Titel '10. NAPS2 (Weg ueber TWAIN)'
$naps2Pfad = $null
$orte = @()
$basen = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA, $env:ProgramData)
foreach ($basis in $basen) {
    if (-not $basis) { continue }
    $orte += [IO.Path]::Combine($basis, 'NAPS2', 'NAPS2.Console.exe')
    $orte += [IO.Path]::Combine($basis, 'Programs', 'NAPS2', 'NAPS2.Console.exe')
}
if ($env:DIAG_SELF) {
    $eigener = Split-Path -Parent $env:DIAG_SELF
    $orte += [IO.Path]::Combine($eigener, 'NAPS2.Console.exe')
    $orte += [IO.Path]::Combine($eigener, 'NAPS2', 'NAPS2.Console.exe')
}
foreach ($ort in $orte) {
    if ($ort -and (Test-Path -LiteralPath $ort -PathType Leaf)) { $naps2Pfad = $ort; break }
}
if (-not $naps2Pfad) {
    try {
        foreach ($eintrag in (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                               'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                               'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue)) {
            if ($eintrag.DisplayName -like 'NAPS2*' -and $eintrag.InstallLocation) {
                $ort = [IO.Path]::Combine($eintrag.InstallLocation, 'NAPS2.Console.exe')
                if (Test-Path -LiteralPath $ort -PathType Leaf) { $naps2Pfad = $ort; break }
            }
        }
    } catch { }
}

if ($naps2Pfad) {
    Gut ("NAPS2 gefunden: {0}" -f $naps2Pfad)
    if ($env:DIAG_ARGS -match '/naps2') {
        foreach ($treiber in @('twain', 'wia')) {
            Punkt ''
            Punkt ("Geraete ueber {0}:" -f $treiber.ToUpperInvariant())
            try {
                $tmp = [IO.Path]::Combine([IO.Path]::GetTempPath(), ("naps2_{0}.txt" -f $treiber))
                $lauf = Start-Process -FilePath $naps2Pfad -ArgumentList ("--listdevices --driver " + $treiber) `
                            -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmp
                $zeilen = @(Get-Content -LiteralPath $tmp -ErrorAction SilentlyContinue | Where-Object { "$_".Trim() })
                if ($zeilen.Count -eq 0) { Punkt '  (keines gemeldet)' }
                foreach ($z in $zeilen) { Punkt ("  " + $z.Trim()) }
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            } catch {
                Punkt ("  Abfrage fehlgeschlagen: " + $_.Exception.Message.Trim())
            }
        }
        Punkt ''
        Punkt 'Die Namen unterscheiden sich je Treiber ("CANON DR-C240" gegenueber'
        Punkt '"CANON DR-C240 USB"). Scan.bat ordnet den eingestellten Scanner selbst'
        Punkt 'zu; nur wenn das misslingt, einen der oben genannten Namen eintragen.'
        Punkt ''
        Punkt 'Scannen darueber:  Scan.bat /naps2 /duplex'
    } else {
        Punkt 'Geraete auflisten:  Diagnose.bat /naps2'
    }
} else {
    Warnung 'NAPS2 ist nicht installiert.'
    Punkt 'Es spricht TWAIN und beherrscht damit auch beidseitiges Scannen an'
    Punkt 'Geraeten, deren WIA-Treiber daran scheitert (etwa der Canon DR-C240).'
    Punkt 'Kostenlos unter https://www.naps2.com'
}

# ---------------------------------------------------------------------------
Titel 'Bewertung'
if (-not $befunde.WiaDienst) {
    Schlecht 'Der Dienst der Windows-Bilderfassung laeuft nicht.'
    Punkt 'Eingabeaufforderung als Administrator:  net start stisvc'
    Punkt 'Dauerhaft: Dienste (services.msc) -> Windows-Bilderfassung (WIA) -> Automatisch'
}
elseif ($befunde.WiaGeraet -and $befunde.Verbindung) {
    Gut 'Windows und Scanner arbeiten zusammen - die Software kann das Geraet ansprechen.'
    Punkt 'Kommt beim Scannen trotzdem ein Fehler, bitte Scan.bat in der Eingabe-'
    Punkt 'aufforderung starten und die vollstaendige Meldung hierher schicken.'
}
elseif ($befunde.WiaGeraet -and -not $befunde.Verbindung) {
    Schlecht 'Der Scanner ist eingerichtet, laesst sich aber nicht ansprechen.'
    if ($befunde.Belegt.Count -gt 0) {
        Punkt ('Das liegt sehr wahrscheinlich an: ' + (($befunde.Belegt | ForEach-Object { $_.Text }) -join ', '))
        Punkt 'Beenden mit:  Diagnose.bat /freigeben     danach erneut scannen.'
    } else {
        Punkt 'Geraet aus- und wieder einschalten, USB-Kabel direkt am Rechner (kein Hub).'
        Punkt 'Hilft das nicht: Rechner neu starten - ein Treiberteil haengt dann noch.'
    }
}
elseif ($befunde.WiaGeraet -and $befunde.Verbindung -and $befunde.Belegt.Count -gt 0) {
    Warnung 'Die Verbindung steht, aber es laufen Programme, die den Scanner belegen.'
    Punkt ('Naemlich: ' + (($befunde.Belegt | ForEach-Object { $_.Text }) -join ', '))
    Punkt 'Kommt beim Scannen "Schwerwiegender Fehler", zuerst diese beenden:'
    Punkt '   Diagnose.bat /freigeben'
}
elseif ($befunde.PnpGeraet -and -not $befunde.WiaGeraet) {
    Schlecht 'Der Scanner haengt am Rechner, ist aber nicht als Bildgeraet eingerichtet.'
    if ($befunde.Twain) {
        Punkt 'Es ist nur der TWAIN-Teil des Treibers installiert. Das Canon-Treiber-'
        Punkt 'paket unterstuetzt ISIS, TWAIN UND WIA - bitte das vollstaendige Paket'
        Punkt 'von der Canon-Seite installieren und dabei nichts abwaehlen.'
    } else {
        Punkt 'Bitte das Treiberpaket von der Canon-Seite installieren.'
    }
    Punkt 'Danach neu starten und diese Diagnose erneut ausfuehren.'
}
else {
    Schlecht 'Windows sieht den Scanner gar nicht.'
    Punkt '1. Geraet einschalten und das USB-Kabel direkt am Rechner anschliessen'
    Punkt '2. anderen USB-Anschluss versuchen (moeglichst USB 2.0, kein Hub)'
    Punkt '3. Treiberpaket installieren, danach Rechner neu starten'
}

Zeile ''
Zeile 'Hinweis: "Diagnose.bat /scan" zieht zusaetzlich eine Testseite ein,'
Zeile '         "Diagnose.bat /freigeben" beendet belegende Programme,'
Zeile '         "Diagnose.bat /duplextest" prueft die Duplex-Einstellungen,'
Zeile '         "Diagnose.bat /naps2" listet die Geraete von NAPS2 auf.'

# ---------------------------------------------------------------------------
$berichtOrdner = [Environment]::GetFolderPath('Desktop')
if (-not $berichtOrdner) { $berichtOrdner = [IO.Path]::GetTempPath() }
$bericht = [IO.Path]::Combine($berichtOrdner, ('Scanner-Diagnose_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.txt'))
try {
    Set-Content -LiteralPath $bericht -Value ($script:Zeilen -join "`r`n") -Encoding UTF8
    Zeile ''
    Zeile ("Bericht gespeichert: {0}" -f $bericht) 'Cyan'
} catch {
    Zeile ''
    Zeile "Der Bericht konnte nicht gespeichert werden: $($_.Exception.Message)"
}

exit 0
