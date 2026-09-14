<img src="logo.png" alt="IDO GmbH" width="260">

# Scannen unter Windows — Canon imageFORMULA DR-C240

Entwickelt von der **IDO GmbH**, Anderslebener Str. 40, 39387 Oschersleben.

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

## Die Kachel unten rechts — das Bedienelement für den Alltag

Beim Start legt sich eine kleine Kachel in die **rechte untere Bildschirmecke**,
über der Taskleiste. Sie liegt **immer im Vordergrund** und bleibt liegen,
während nebenher gearbeitet wird:

```
                       ┌─────────────────────────┐
                       │ IDO GmbH                │   <- Doppelklick: Service
                       │ Fertig - 3 Seite(n)     │
                       │ gescannt und gespeichert│
                       │ ┌─────────────────────┐ │
                       │ │        Scan         │ │   <- ein Klick genügt
                       │ └─────────────────────┘ │
                       └─────────────────────────┘
```

Oben steht der Firmenname — liegt eine `logo.png` daneben, erscheint dort
stattdessen das Logo. Darunter läuft der Stand des Scans mit, und die
Schaltfläche **Scan** startet ihn. Mehr braucht die Kundin nicht: Blätter
einlegen, auf *Scan* klicken, fertig.

| Aktion | Wirkung |
|---|---|
| **Scan** | startet den Scan sofort |
| **Doppelklick auf den Namen/das Logo** | öffnet nach Kennworteingabe den Servicebereich |
| **Rechtsklick** | Menü: *Scan starten*, *als PDF* / *als Bilddateien*, *Vorder- und Rückseite*, *Weitere Einstellungen …*, *Beenden* |
| **Ziehen** | Kachel verschieben — die Position wird gemerkt |

Format und Duplex lassen sich also direkt im Rechtsklickmenü umstellen, ohne
je ein Fenster zu öffnen. Das große Fenster wird nur noch für die Einrichtung
und für Sonderfälle gebraucht; wer es gar nicht möchte, schaltet im
Servicebereich die Kachel ab und arbeitet nur mit dem Fenster.

Beendet wird über *Beenden* im Kachelmenü.

## Das Fenster (Kundenansicht)

Ein Klick auf die Kachel öffnet die **Kundenansicht** — bewusst knapp
gehalten: was gescannt wird, und die Schaltfläche *Scannen*.

```
┌─ Scannen ──────────────────────────────────────────────────┐
│  [ IDO-Logo ]        Scannen                               │
│                      Canon imageFORMULA DR-C240            │
├────────────────────────────────────────────────────────────┤
│ ┌ Was soll gescannt werden? ─────────────────────────────┐ │
│ │ (•) PDF (alle Blätter in einer Datei)                  │ │
│ │ ( ) Bilddateien  [JPG ▾]                               │ │
│ │ [ ] Vorder- und Rückseite scannen                      │ │
│ └────────────────────────────────────────────────────────┘ │
│  [   Scannen   ] [Abbrechen] [Ergebnis zeigen] [ Ordner ]  │
│  Fertig - 3 Seite(n) gescannt und gespeichert.             │
├────────────────────────────────────────────────────────────┤
│  IDO GmbH - Anderslebener Str. 40 - 39387 Oschersleben     │
└────────────────────────────────────────────────────────────┘
```

Zielordner, Scanner, Auflösung und Protokoll sind hier **nicht** sichtbar —
die Kundin kann nichts verstellen.

## Servicebereich (nur für die Einrichtung)

Geöffnet wird er auf zwei Wegen, beide unauffällig:

* **Strg + Alt + S**
* **Doppelklick auf das Logo** im Fensterkopf

Danach fragt das Programm das **Servicekennwort** ab. Stimmt es, klappt das
Fenster nach unten auf und zeigt:

| Bereich | Inhalt |
|---|---|
| Gerät und Qualität | Scannerauswahl, *Suchen*, Farbmodus, Auflösung |
| Ablage | **Zielordner**, Dateiname, Namensvorschau, „Ergebnis öffnen" |
| Nachbearbeitung | schräge Seiten gerade richten, leere Seiten weglassen |
| Anzeige | Kachel unten rechts ein- oder ausschalten |
| Protokoll | vollständige Ausgabe des letzten Scans |
| Schaltflächen | Verknüpfung auf dem Desktop, Kennwort ändern, Service schließen |

Wird das Fenster geschlossen, ist der Servicebereich wieder gesperrt — beim
nächsten Öffnen fragt das Programm erneut nach dem Kennwort.

**Beim ersten Start auf einem Rechner** meldet sich das Programm sofort:
*„Legen Sie zuerst ein Servicekennwort fest."* — Kennwort zweimal eingeben,
danach öffnet sich der Servicebereich direkt zum Einrichten. Ausgeliefert wird
also **ohne** vorgegebenes Kennwort; ohne festgelegtes Kennwort kommt auch
niemand in den Servicebereich.

Gespeichert wird nur die SHA-256-Prüfsumme, und zwar in `Scanner.bat` selbst
(Zeile `$script:KennwortHash`). Ist die Datei schreibgeschützt, landet sie
stattdessen in einer kleinen Datei `service.dat` neben dem Programm oder im
Benutzerprofil. Später ändern lässt sie sich jederzeit über *Kennwort ändern*
im Servicebereich.

> **Einordnung:** Das ist ein Bedienschutz, kein Zugriffsschutz. Eine
> Batchdatei ist lesbarer Text — wer sich auskennt, kann die Prüfsumme
> austauschen. Gegen versehentliches Verstellen und gegen neugieriges
> Herumklicken hilft es zuverlässig; soll der Pfad wirklich unantastbar sein,
> gehören zusätzlich NTFS-Schreibrechte auf den Programmordner gesetzt.

## Wo die Einstellungen liegen

Zielordner, Format, Farbe, Auflösung, Duplex, Dateiname, Scannerauswahl sowie
Sichtbarkeit und Position der Kachel werden gespeichert — bevorzugt als `einstellungen.json` **neben `Scanner.bat`**.
Damit gilt Ihre Einrichtung für **jeden Benutzer des Rechners**. Ist der
Programmordner schreibgeschützt, weicht das Programm auf
`%APPDATA%\Scan-DR-C240\einstellungen.json` aus (dann gilt sie nur für den
angemeldeten Benutzer).

## Logo, Symbol und Desktop-Verknüpfung

Liegt im Programmordner eine Datei **`logo.png`** (alternativ `logo.jpg`,
`logo.bmp` oder `logo.gif`), passiert beim Start automatisch:

* das Logo erscheint im Fensterkopf,
* daraus wird eine **`logo.ico`** erzeugt (16 bis 256 Pixel, mit
  Transparenz) — sie dient als Fenster- und Taskleistensymbol,
* *Verknüpfung auf dem Desktop* im Servicebereich legt eine Verknüpfung
  **mit diesem Symbol** an, die **minimiert** startet: damit blitzt beim
  Start kein Konsolenfenster mehr auf.

Ohne Logodatei steht im Kopf der Schriftzug *IDO GmbH*; eine vorhandene
`logo.ico` wird auch allein verwendet.

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
| `/gerade` | schräg eingezogene Seiten automatisch gerade richten |
| `/drehen <Grad>` | alle Seiten fest drehen: `0`, `90`, `180` oder `270` |
| `/leerseiten` | leere Seiten (z. B. unbedruckte Rückseiten) weglassen |
| `/leerwert <Zahl>` | Empfindlichkeit dafür in Promille (Standard: `1.5`) |
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

## Leere Seiten und schiefe Vorlagen

Beides schaltet man im Servicebereich ein (Kommandozeile: `/leerseiten` und
`/gerade`); im Auslieferungszustand ist beides **aus**, damit ohne
ausdrückliche Entscheidung nichts verschwindet.

**Leere Seiten weglassen** — vor allem für Duplex-Stapel gedacht, bei denen die
Rückseiten unbedruckt sind. Geprüft wird auf einer verkleinerten Vorschau, wie
viel Farbe auf der Seite liegt; ein Rand von 7 % bleibt außen vor, weil dort
Lochung, Einzugsschatten und Knicke sitzen. Eine Seite gilt nur dann als leer,
wenn **insgesamt** fast nichts da ist **und** kein einzelnes Raster­feld
auffällt — sonst würde ein Handzeichen in der Ecke mit verschwinden. Sollten
ausnahmsweise alle Seiten als leer gelten, wird nichts weggelassen.

Gemessen an Testvorlagen (300 dpi):

| Vorlage | gemessen | Ergebnis |
|---|---|---|
| unbedrucktes Blatt, mit Scannerrauschen | 0,00 ‰ | wird weggelassen |
| leeres Blatt mit Aktenlochung und Einzugsschatten | 0,00 ‰ | wird weggelassen |
| leere Rückseite, Vorderseite scheint durch | 0,00 ‰ | wird weggelassen |
| Blatt mit nur „ok" handschriftlich | 0,06 ‰, Feld 0,5 % | bleibt |
| Blatt mit kleinem Kürzel „i. A. Müller" | 0,39 ‰, Feld 2,9 % | bleibt |
| Brief, Formular | 47–109 ‰ | bleibt |

Wer es strenger oder lockerer möchte, verstellt `/leerwert` (höher = mehr wird
als leer eingestuft).

**Gerade richten** — der Schräglauf wird über die Textzeilen gemessen: Die
Seite wird probeweise in Schritten von einem halben Grad geschert, und der
Winkel, bei dem die Zeilen am saubersten übereinanderliegen, ist der gesuchte.
Anschließend wird das Bild um genau diesen Winkel zurückgedreht (weißer
Hintergrund, Bildgröße bleibt). Im Test wurden -4,2°, -1,5°, +0,8°, +2,7° und
+6,0° jeweils exakt erkannt; nach der Korrektur blieb ein Restwinkel von 0,0°.
Erst ab 0,2° wird überhaupt gedreht — darunter lohnt sich das Neuberechnen der
Bildpunkte nicht.

> **Textausrichtung (Kopfstand, Querlage) erkennt das Programm nicht.**
> Das ist kein Versehen, sondern gemessen: Für aufrecht und um 180° gedreht
> liefern die Kennzahlen 0,518 gegenüber 0,523 — das trennt nichts.
> Zuverlässig geht das nur mit Texterkennung (OCR). Wenn Vorlagen systematisch
> falsch herum eingezogen werden, hilft `/drehen 90|180|270`; die
> OCR-gestützte Ausrichtung bringt Canon CaptureOnTouch mit.

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

**Servicekennwort vergessen**
In `Scanner.bat` die Zeile `$script:KennwortHash = '...'` auf zwei
Anführungszeichen leeren (`$script:KennwortHash = ''`) und eine eventuell
vorhandene `service.dat` löschen — neben dem Programm und unter
`%APPDATA%\Scan-DR-C240\`. Beim nächsten Start fragt das Programm wieder
nach einem neuen Kennwort.

**Die Kundin soll den Zielordner gar nicht ändern können**
Zusätzlich zum Kennwort die NTFS-Rechte auf den Programmordner so setzen, dass
nur Administratoren schreiben dürfen. Dann liegt `einstellungen.json` dort
unveränderlich; die Kundin kann das Programm weiter starten und scannen.

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

* Das Servicekennwort wird als SHA-256-Prüfsumme geprüft und nur als solche
  gespeichert — in der Programmdatei, ersatzweise in `service.dat`.
* Kachel und Fenster laufen in einer gemeinsamen Nachrichtenschleife
  (`Application.Run`); Statusmeldungen gehen über eine Funktion an beide.
* Die `logo.ico` wird zur Laufzeit aus dem Logo gebaut: je Größe ein
  PNG-Block, zusammengesetzt zu einer ICO-Datei mit 16/24/32/48/64/128/256
  Pixel Kantenlänge.
* Die Desktop-Verknüpfung entsteht über `WScript.Shell` mit Fensterstil
  „minimiert".
* Leerseitenprüfung und Schräglaufmessung rechnen in einer kleinen, zur
  Laufzeit übersetzten C#-Klasse (Rückfallweg in PowerShell, falls das
  Übersetzen scheitert).
* Jedes erzeugte PDF trägt die Dokumentangaben `/Producer`, `/Author` und
  `/Subject` mit dem Copyright der IDO GmbH sowie Erstellungsdatum und
  Zeitzone.

* Der Scan läuft über **WIA** (`WIA.DeviceManager`); Einzug, Duplex, Farbmodus,
  Auflösung und Scanbereich werden über die WIA-Eigenschaften gesetzt. Nach
  einer Änderung der Auflösung wird der Scanbereich mitskaliert, damit die
  Seite nicht beschnitten wird.
* Jede Seite wird einzeln übertragen, bis der Treiber „kein Papier“ meldet.
* Das PDF wird direkt geschrieben: Die JPEG-Daten der Seiten werden ohne
  erneutes Komprimieren als `DCTDecode`-Bilder eingebettet, die Seitengröße
  ergibt sich aus Pixelmaß und Auflösung (300 dpi, A4 → 595 × 842 pt).
  Es wird also keine zusätzliche PDF-Software benötigt.

---

## Entwickler

**IDO GmbH**  
Anderslebener Str. 40  
39387 Oschersleben

© 2026 IDO GmbH
