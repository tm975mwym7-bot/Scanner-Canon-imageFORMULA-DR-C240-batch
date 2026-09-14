# Scannen unter Windows — Canon imageFORMULA DR-C240

Zwei Dateien, die zusammengehören und im **selben Ordner** liegen müssen:

| Datei | Zweck |
|---|---|
| **`Scanner.bat`** | kleines Fenster mit den wichtigsten Einstellungen — Zielordner einmal einstellen, danach nur noch auf *Scannen* klicken |
| **`Scan.bat`** | die eigentliche Scan-Funktion; läuft auch allein auf der Kommandozeile und wird vom Fenster aufgerufen |

Beides sind reine Bordmittel-Lösungen: Windows-Bilderfassung (WIA) und Windows
PowerShell, keine Zusatzsoftware, keine Installation. Das Ergebnis landet
standardmäßig als mehrseitige PDF-Datei unter **Eigene Dokumente\Scans**.

---

# 1. Das Fenster: `Scanner.bat`

Doppelklick auf `Scanner.bat` öffnet:

```
┌─ Scannen ──────────────────────────────────────────────┐
│  Scanner: [ CANON DR-C240              ▾ ]  [ Suchen ] │
│                                                        │
│ ┌ Ausgabe ─────────────────────────────────────────┐   │
│ │ (•) PDF (mehrseitig)   ( ) Bilddateien  [JPG ▾]  │   │
│ │ Farbe: [Farbe ▾]  Auflösung: [300 ▾] dpi         │   │
│ │ [ ] Vorder- und Rückseite                        │   │
│ └──────────────────────────────────────────────────┘   │
│ ┌ Ablage ──────────────────────────────────────────┐   │
│ │ Ordner: [C:\Users\...\Documents\Scans] [ Wählen ] │   │
│ │ Name:   [Scan        ]  -> Scan_2026-09-14_1530… │   │
│ │ [x] Ergebnis nach dem Scan öffnen                │   │
│ └──────────────────────────────────────────────────┘   │
│  [ Scannen ] [Abbrechen] [Ergebnis zeigen] [ Ordner ]  │
│  Bereit.                                               │
│ ┌──────────────────────────────────────────────────┐   │
│ │ Seite 1 wird gescannt ... fertig                 │   │
│ │ Seite 2 wird gescannt ... fertig                 │   │
│ └──────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

* **Einmal einstellen, immer gültig:** Zielordner, Format, Farbe, Auflösung,
  Duplex, Dateiname und die Scannerauswahl werden gespeichert und beim nächsten
  Start wieder verwendet. Die Einstellungen liegen in
  `%APPDATA%\Scan-DR-C240\einstellungen.json`.
* Während des Scans bleibt das Fenster bedienbar, der Fortschritt läuft unten
  mit, und *Abbrechen* stoppt den Vorgang.
* *Ergebnis zeigen* öffnet den Explorer mit der fertigen Datei, *Ordner* den
  Zielordner.

Für den Start ohne kurz aufblitzendes Konsolenfenster: Rechtsklick auf
`Scanner.bat` → *Verknüpfung erstellen*, dann in den Eigenschaften der
Verknüpfung *Ausführen: Minimiert* wählen. Die Verknüpfung lässt sich auch an
Startmenü oder Taskleiste anheften.

---

# 2. Die Kommandozeile: `Scan.bat`

Für feste Abläufe, Verknüpfungen mit vorgegebenen Schaltern und die
Aufgabenplanung — und als Motor hinter dem Fenster.

## Schnellstart

1. `Scan.bat` auf den eigenen Rechner kopieren (z. B. auf den Desktop).
2. Falls die Datei aus dem Internet stammt: Rechtsklick → *Eigenschaften* →
   unten bei *Sicherheit* das Häkchen **Zulassen** setzen → *OK*.
3. Dokument in den Einzug legen.
4. Doppelklick auf `Scan.bat`.

Ergebnis:

```
C:\Users\<Benutzer>\Documents\Scans\Scan_2026-09-14_153012.pdf
```

Der Ablageort folgt der Windows-Einstellung für „Eigene Dokumente“ — ist der
Ordner nach OneDrive verschoben, wird dort abgelegt. Mit `/ordner` lässt sich
jedes andere Ziel angeben.

## Standardeinstellungen

| Einstellung | Wert |
|---|---|
| Ausgabe | PDF (mehrseitig, alle eingezogenen Blätter in einer Datei) |
| Auflösung | 300 dpi |
| Farbe | Farbe |
| Seiten | einseitig (Vorderseite) |
| Ziel | `Eigene Dokumente\Scans` |
| Dateiname | `Scan_JJJJ-MM-TT_HHMMSS.pdf` |

Alle Blätter im Einzug werden nacheinander eingezogen, bis das Fach leer ist.

## Optionen

Aufruf aus der Eingabeaufforderung oder aus einer Verknüpfung:

```
Scan.bat [Optionen]
```

| Option | Bedeutung |
|---|---|
| `/pdf` | mehrseitiges PDF (Standard) |
| `/jpg` `/png` `/tif` | einzelne Bilddateien statt PDF |
| `/farbe` `/grau` `/sw` | Farbe (Standard), Graustufen, Schwarzweiß |
| `/dpi <Zahl>` | Auflösung, z. B. `150`, `200`, `300`, `400`, `600` |
| `/duplex` | Vorder- und Rückseite scannen |
| `/name <Text>` | Namensbestandteil der Zieldatei |
| `/ordner <Pfad>` | abweichender Zielordner |
| `/seiten <Zahl>` | höchstens so viele Blätter einziehen (`0` = alle) |
| `/qualitaet <1-100>` | JPEG-Qualität (Standard: 80) |
| `/scanner <Text>` | Gerät wählen, wenn mehrere angeschlossen sind |
| `/liste` | gefundene Scanner anzeigen und beenden |
| `/oeffnen` | Ergebnis nach dem Scan öffnen |
| `/warten <Sek>` | so lange auf eingelegtes Papier warten (Standard: 30) |
| `/hilfe` | Hilfe anzeigen |

### Beispiele

```bat
Scan.bat                                          zweiseitiges Standard-PDF starten
Scan.bat /duplex /grau /dpi 200 /name Rechnung    Rechnung beidseitig in Graustufen
Scan.bat /jpg /dpi 600 /ordner "D:\Archiv"        Einzelbilder in hoher Auflösung
Scan.bat /sw /dpi 200 /name Vertrag               Textvorlage klein und kontrastreich
Scan.bat /liste                                   angeschlossene Scanner anzeigen
```

Bei mehreren Seiten und Bildformaten (`/jpg`, `/png`, `/tif`) landen die Seiten
in einem Unterordner `Name_Zeitstempel\Name_001.jpg`, `…_002.jpg` usw.; eine
einzelne Seite wird direkt als Datei abgelegt.

### Verknüpfung mit festen Einstellungen

Für wiederkehrende Scans eine Verknüpfung anlegen (Rechtsklick auf `Scan.bat` →
*Senden an* → *Desktop*), dann Rechtsklick auf die Verknüpfung → *Eigenschaften*
und das Ziel ergänzen:

```
C:\Tools\Scan.bat /duplex /grau /dpi 200 /name Posteingang
```

## Voraussetzungen

* Windows 10 oder 11
* Canon-Treiber für den DR-C240 installiert (im Canon-Setup enthalten); das
  Gerät muss im Geräte-Manager unter *Bildverarbeitungsgeräte* erscheinen
* Dienst *Windows-Bilderfassung (WIA)* läuft (Standard bei Windows)
* `Scanner.bat` und `Scan.bat` im selben Ordner

## Problembehandlung

**„Es wurde kein Scanner gefunden.“**
Gerät einschalten und USB-Kabel prüfen. Erscheint das Gerät im Geräte-Manager?
Prüfen, ob der WIA-Dienst läuft — in einer Eingabeaufforderung als Administrator:

```
net start stisvc
```

**„Der Scanvorgang ist fehlgeschlagen“ / Scanner reagiert nicht**
Eine andere Anwendung belegt das Gerät. Canon CaptureOnTouch, Windows-Fax und
-Scan oder eine Scan-Software schließen und erneut versuchen.

**Das Fenster schließt sich sofort**
Beim Doppelklick bleibt das Fenster bis zum Tastendruck offen. Schließt es sich
trotzdem, `Scan.bat` in einer Eingabeaufforderung starten — dann bleiben alle
Meldungen sichtbar.

**„Scan.bat wurde nicht gefunden“**
`Scanner.bat` erwartet `Scan.bat` im selben Ordner. Beide Dateien zusammen
kopieren — nicht nur die Verknüpfung.

**Der Scan ist abgeschnitten**
Das Gerät meldet einen zu kleinen Scanbereich. Mit einer anderen Auflösung
versuchen (`/dpi 200`) oder im Canon-Treiber die Vorlagengröße auf A4 stellen.

**Umlaute werden falsch dargestellt**
Die Batchdatei stellt die Konsole auf UTF-8 um und danach zurück. Bei sehr alten
Konsoleneinstellungen kann die Anzeige abweichen — die Dateien sind davon nicht
betroffen.

### Rückgabewerte

| Wert | Bedeutung |
|---|---|
| 0 | erfolgreich |
| 2 | fehlerhafter Aufruf (Option oder Wert) |
| 3 | kein Scanner gefunden bzw. WIA nicht verfügbar |
| 4 | kein Papier eingezogen |
| 5 | Fehler während der Übertragung |
| 6 | Zielordner oder Zieldatei nicht beschreibbar |
| 9 | PowerShell nicht gefunden |

Damit lässt sich der Aufruf auch in eigene Skripte oder in die Aufgabenplanung
einbinden. Beim Doppelklick wartet `Scan.bat` am Ende auf einen Tastendruck;
wird die Umgebungsvariable `SCAN_NOPAUSE=1` gesetzt, entfällt das Warten — so
ruft auch `Scanner.bat` die Datei auf.

## Technische Hinweise

Beide Dateien sind Batch-/PowerShell-Hybride: Der Batch-Teil startet jeweils
den PowerShell-Teil, der in derselben Datei steht. `Scanner.bat` baut die
Oberfläche mit Windows Forms auf und startet `Scan.bat` als eigenen Prozess —
deshalb friert das Fenster während des Scannens nicht ein und der Vorgang lässt
sich abbrechen. Die Scan-Logik gibt es also nur einmal.

* Der Scan läuft über **WIA** (`WIA.DeviceManager`); Einzug, Duplex, Farbmodus,
  Auflösung und Scanbereich werden über die WIA-Eigenschaften gesetzt. Nach
  einer Änderung der Auflösung wird der Scanbereich mitskaliert, damit die
  Seite nicht beschnitten wird.
* Jede Seite wird einzeln übertragen, bis der Treiber „kein Papier“ meldet.
* Das PDF wird direkt geschrieben: Die JPEG-Daten der Seiten werden ohne
  erneutes Komprimieren als `DCTDecode`-Bilder eingebettet, die Seitengröße
  ergibt sich aus Pixelmaß und Auflösung (300 dpi, A4 → 595 × 842 pt).
  Es wird also keine zusätzliche PDF-Software benötigt.
