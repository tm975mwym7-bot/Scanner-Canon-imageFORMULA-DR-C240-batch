<img src="logo.png" alt="IDO GmbH" width="260">

# Scannen unter Windows — Canon imageFORMULA DR-C240

Entwickelt von der **IDO GmbH**, Anderslebener Str. 40, 39387 Oschersleben.

Drei Dateien, die zusammengehören und im **selben Ordner** liegen müssen:

| Datei | Zweck |
|---|---|
| **`Scanner.bat`** | kleines Fenster mit den wichtigsten Einstellungen — Zielordner einmal einstellen, danach nur noch auf *Scannen* klicken |
| **`Scan.bat`** | die eigentliche Scan-Funktion; läuft auch allein auf der Kommandozeile und wird vom Fenster aufgerufen |
| **`Diagnose.bat`** | prüft bei Problemen Dienst, Treiber, Gerät und belegende Programme und schreibt einen Bericht auf den Desktop |

Beide laufen mit Bordmitteln: Windows-Bilderfassung (WIA) und Windows
PowerShell, ohne Installation. Das Ergebnis landet standardmäßig als
mehrseitige PDF-Datei unter **Eigene Dokumente\Scans**.

> **Für beidseitiges Scannen am DR-C240 wird zusätzlich [NAPS2](https://www.naps2.com)
> gebraucht** (kostenlos, deutschsprachig). Der Canon-WIA-Treiber nimmt die
> Duplex-Einstellung von außen nicht an; NAPS2 spricht denselben Scanner über
> **TWAIN** an, und darüber funktioniert es. Einseitig scannt das Programm auch
> ohne NAPS2. Siehe [Beidseitig scannen über NAPS2](#beidseitig-scannen-über-naps2).

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
| Gerät und Qualität | Scannerauswahl, *Suchen*, Farbmodus, Auflösung, **Scanweg** |
| Ablage | **Zielordner**, Dateiname, Namensvorschau, „Ergebnis öffnen" |
| Nachbearbeitung | schräge Seiten gerade richten, leere Seiten weglassen |
| Anzeige | Kachel unten rechts ein- oder ausschalten |
| Protokoll | vollständige Ausgabe des letzten Scans |
| Schaltflächen | Verknüpfung auf dem Desktop, Kennwort ändern, Service schließen |

**Scanweg** entscheidet, worüber gescannt wird:

| Einstellung | Wirkung |
|---|---|
| *Automatisch* (Standard) | beidseitige Scans über NAPS2, einseitige über Windows — ist NAPS2 nicht installiert, immer über Windows |
| *NAPS2 (TWAIN)* | immer über NAPS2 |
| *Windows (WIA)* | immer über die Windows-Bilderfassung, NAPS2 bleibt außen vor |

Rechts daneben steht im Klartext, was die Auswahl gerade bedeutet — und ob
NAPS2 auf diesem Rechner überhaupt gefunden wurde. Nach dem Nachinstallieren
von NAPS2 genügt ein Klick auf *Suchen*, dann sucht das Programm auch NAPS2
erneut.

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

Zielordner, Format, Farbe, Auflösung, Duplex, Dateiname, Scannerauswahl,
Scanweg sowie Sichtbarkeit und Position der Kachel werden gespeichert — bevorzugt als `einstellungen.json` **neben `Scanner.bat`**.
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
| `/naps2` | über NAPS2 scannen (TWAIN — der Weg, über den Duplex am DR-C240 geht) |
| `/wia` | über die Windows-Bilderfassung scannen |
| `/naps2pfad <Pfad>` | `NAPS2.Console.exe` von Hand angeben |
| `/treiber <Name>` | Treiber für NAPS2: `twain` (Standard), `wia`, `escl` |
| `/profil <Name>` | ein in NAPS2 angelegtes Profil verwenden |
| `/seite <Größe>` | Vorlagengröße für NAPS2, z. B. `a4`, `letter`, `legal` |
| `/dialog` | vor dem Scan die Einstellungen des Scanner-Treibers zeigen |
| `/einfach` | ohne eigene Geräteeinstellungen scannen (bei Treiberfehlern) |
| `/duplexwert <n>` | Duplex-Schreibweise fest vorgeben (`1`, `4` oder `5`) |
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
Scan.bat /duplex /naps2                           beidseitig über NAPS2 (TWAIN)
Scan.bat /wia /jpg                                bewusst über Windows, ohne NAPS2
```

Ohne `/naps2` oder `/wia` entscheidet das Programm selbst: **mit `/duplex` und
vorhandenem NAPS2 über NAPS2**, sonst über die Windows-Bilderfassung. Es sagt in
der Ausgabe, welchen Weg es genommen hat.

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
* **für beidseitiges Scannen:** [NAPS2](https://www.naps2.com) installiert
  (kostenlos) — das Programm findet es von allein

## Problembehandlung

**„Es wurde kein Scanner gefunden.“**
Gerät einschalten und USB-Kabel prüfen. Erscheint das Gerät im Geräte-Manager?
Prüfen, ob der WIA-Dienst läuft — in einer Eingabeaufforderung als Administrator:

```
net start stisvc
```

**„Schwerwiegender Fehler“ beim Scannen**
Das ist die Standardmeldung von Windows, wenn **ein anderes Programm den
Scanner hält**. Bei Canon ist das fast immer **CaptureOnTouch**, das sich mit
Windows startet und im Hintergrund auf den Tastendruck am Gerät wartet.

```
Diagnose.bat /freigeben
```

beendet alle Programme, die den Scanner belegen (CaptureOnTouch samt Lite- und
Hintergrundteil, Tastenüberwachung, Windows-Fax und -Scan, der Scan-Assistent,
NAPS2 und weitere) — danach lässt sich sofort wieder scannen. Im Fenster gibt
es dafür den Knopf **Scanner freigeben** im Servicebereich; und schlägt ein
Scan fehl, fragt das Programm von sich aus, ob es die störenden Programme
beenden soll, und wiederholt den Scan danach automatisch.

Damit CaptureOnTouch gar nicht erst stört, kann es im Autostart deaktiviert
werden: *Task-Manager → Autostart → CaptureOnTouch → Deaktivieren*.

Hilft das nicht, kann auch der Treiber über eine Einstellung stolpern:

```
Scan.bat /einfach
```

scannt dann ohne eigene Vorgaben mit dem, was im Treiber eingestellt ist.

**Fehler nur bei „Vorder- und Rückseite", einseitig geht es**

Dafür gibt es zwei Ursachen, und beide behandelt das Programm inzwischen.

**Erstens: das Bildformat.** Beim beidseitigen Scannen liefern manche Treiber
— der von Canon gehört dazu — **Vorder- und Rückseite zusammen in einer
einzigen Übertragung**. Das kann nur ein mehrseitenfähiges Format wie TIFF
aufnehmen; fordert die Anwendung JPEG an, bricht der Treiber mit
`0x8000FFFF` („unerwarteter Zustand") ab, nachdem er das Blatt bereits
eingezogen hat. Genau deshalb steht im Scanprofil von Windows für beidseitige
Scans standardmäßig **TIF**.

Das Programm fordert bei eingeschaltetem Duplex daher von vornherein TIFF an
und **zerlegt die gelieferte Datei anschließend wieder in einzelne Seiten**.
Für einseitige Scans bleibt es bei JPEG — das ist sparsamer.

**Zweitens: die Einstellung selbst** — manche WIA-Treiber nehmen sie nicht
entgegen.

Die Einzugsart gibt es in WIA nämlich **zweimal**: am Gerät *und* am
Scan-Element. Microsoft schreibt dazu zwei Dinge, die den Unterschied machen:
zuerst muss das **Element** gesetzt werden und danach das Gerät, und für
beidseitiges Scannen ist `FEEDER | DUPLEX | FRONT_FIRST` (Wert **13**)
vorgesehen — nicht nur `FEEDER | DUPLEX` (5).

Das Programm setzt die Einstellung deshalb an beiden Stellen in der richtigen
Reihenfolge und **liest sie zurück**: Nur wenn der Wert danach wirklich steht,
hat der Treiber ihn angenommen. Probiert werden der Reihe nach 13, 5 und 4 —
und das alles, bevor das erste Blatt eingezogen wird, also ohne Papier zu
verbrauchen. Nimmt der Treiber keine davon an, sagt das Programm es vor dem
Scan und scannt einseitig weiter, statt abzubrechen.

Welche Schreibweise Ihr Gerät annimmt, zeigt (ohne Papierverbrauch):

```
Diagnose.bat /duplextest
```

Der Test nennt die gültigen Werte des Treibers, welche Schreibweise er annimmt
und an welcher Stelle (Element, Gerät oder beide). Mit `/duplextest /scan` wird
die gefundene Variante zusätzlich mit einem echten Blatt gegengeprüft.

Die gefundene Variante lässt sich fest einstellen, dann entfallen alle
Fehlversuche:

```
Scan.bat /duplex /duplexwert 13
```

### Wenn der Treiber gar keine Duplex-Vorgabe annimmt

Manche WIA-Treiber — die von Canon gehören dazu — nehmen die Einstellung
schlicht nicht von außen entgegen. Typisches Bild: Der Scanner **zieht das
Blatt ein**, gibt das Bild aber nicht heraus, und es kommt `0x80004005`
(„Schwerwiegender Fehler"). Bei Brother- und HP-Geräten funktioniert derselbe
Weg dagegen anstandslos.

Dann muss die Einstellung **im Treiber selbst** stehen, und das Programm darf
sie nicht überschreiben:

```
Scan.bat /dialog
```

öffnet den Einstellungsdialog des Scanner-Treibers. Dort *Scanseite* bzw.
*Scanning Side* auf **Duplex** stellen, mit OK bestätigen — anschließend scannt
das Programm mit genau diesen Einstellungen und rührt die Einzugsart nicht an.

Bietet der Treiber der Automation keinen Dialog an (auch das kommt vor), führt
der Weg über das **Scanprofil von Windows**:

1. Windows-Taste + R, dann `control sticpl.cpl`
2. Scanner auswählen → *Scanprofile* → *Bearbeiten*
3. Bei *Quelle* nachsehen: Steht dort **„Einzug (beidseitiger Scan)"**, kann
   der Treiber Duplex über WIA. Fehlt der Eintrag, kann dieser WIA-Treiber es
   nicht, und beidseitiges Scannen bleibt CaptureOnTouch vorbehalten.

Das Profil ist zugleich aufschlussreich: Es steht dort auf **TIF** — eben
weil beidseitige Scans zwei Seiten je Blatt liefern. Die Einstellungen im
Profil gelten allerdings nur für *Windows-Fax und -Scan*; jede andere
Anwendung, auch diese hier, setzt sie selbst. Im Fenster
führt der Knopf **Treiber …** neben der Scannerauswahl (Servicebereich) zum
selben Dialog; viele Treiber merken sich die Wahl dauerhaft, dann genügt das
einmalig bei der Einrichtung.

Damit das Programm die Treibervorgabe nicht wieder überschreibt: Haken bei
*Vorder- und Rückseite* weglassen (oder `/einfach` verwenden) — die
Seitenzahl im PDF zeigt dann, ob der Treiber beidseitig liefert.

Nimmt der Treiber gar keine an, bleibt beidseitiges Scannen über die
Canon-Treibereinstellung oder CaptureOnTouch möglich — über WIA geht es bei
diesem Gerät dann nicht. **Der saubere Ausweg ist NAPS2**, siehe nächster
Abschnitt.

## Beidseitig scannen über NAPS2

Der Canon-WIA-Treiber nimmt die Duplex-Einstellung von außen nicht an: Das
Blatt wird eingezogen, aber kein Bild herausgegeben, und es kommt `0x8000FFFF`
oder `0x80004005`. Alle WIA-Schreibweisen (`1`, `4`, `5`, `13`), beide Stellen
der Eigenschaft und auch das mehrseitige TIFF ändern daran nichts — bei Brother
und HP funktioniert derselbe Weg dagegen anstandslos.

Canons eigene Software kann es, weil sie den Scanner nicht über WIA, sondern
über **TWAIN** anspricht. Genau das macht **NAPS2** auch — und NAPS2 bringt eine
Kommandozeile mit, über die dieses Programm es fernsteuern kann.

### Einrichten

1. [NAPS2](https://www.naps2.com) herunterladen und installieren (kostenlos,
   deutschsprachig, Installer oder portable Fassung).
2. `Scanner.bat` starten, Servicebereich öffnen und bei **Scanweg**
   *Automatisch* stehen lassen (oder fest auf *NAPS2 (TWAIN)* stellen).
3. Fertig. Der Hinweis neben der Auswahl bestätigt, dass NAPS2 gefunden wurde.

Gesucht wird NAPS2 in dieser Reihenfolge: `Programme\NAPS2`,
`Programme (x86)\NAPS2`, `%LOCALAPPDATA%\Programs\NAPS2`, `%ProgramData%\NAPS2`,
**neben `Scan.bat`** (für die portable Fassung genügt es, den NAPS2-Ordner
danebenzulegen), die Liste der installierten Programme in der Registrierung und
zuletzt der Suchpfad. Liegt es woanders, hilft `/naps2pfad`:

```
Scan.bat /duplex /naps2pfad "D:\Werkzeuge\NAPS2\NAPS2.Console.exe"
```

### Was das Programm dann tut

Es ruft `NAPS2.Console.exe` mit `--driver twain` und `--source duplex` auf,
lässt jede Seite einzeln als JPEG ablegen (`--split`) und übernimmt die Bilder
anschließend unverändert in die eigene Nachbearbeitung. **Leerseitenerkennung,
Geraderichten, PDF-Erzeugung, Dateiname und Zielordner bleiben also genau
gleich** — NAPS2 liefert nur die Rohseiten, alles andere macht weiterhin
`Scan.bat`. Auflösung, Farbmodus und JPEG-Qualität werden mit durchgereicht.

Ein in NAPS2 angelegtes Profil lässt sich ebenfalls verwenden — praktisch, wenn
dort Sondereinstellungen hinterlegt sind:

```
Scan.bat /naps2 /profil "DR-C240 Duplex"
```

### Prüfen, ob es klappt

```
Diagnose.bat /naps2
```

listet die Geräte auf, die NAPS2 über TWAIN sieht. Steht der DR-C240 dabei, ist
alles bereit. `Diagnose.bat` allein prüft in Abschnitt 10 ohnehin mit, ob NAPS2
installiert ist und wo.

### Wenn NAPS2 nicht da ist

Ohne NAPS2 scannt das Programm weiter über Windows — einseitig ohne
Einschränkung. Bei *Scanweg = NAPS2 (TWAIN)* und fehlendem NAPS2 bricht
`Scan.bat` mit Rückgabewert `7` ab und sagt, wo es NAPS2 gesucht hat.

**„Der Scanvorgang ist fehlgeschlagen“ / Scanner reagiert nicht**
Eine andere Anwendung belegt das Gerät (siehe oben), oder das Gerät hängt:
aus- und einschalten, USB-Kabel direkt am Rechner (kein Hub).

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

### Diagnose bei Problemen

`Diagnose.bat` per Doppelklick starten. Geprüft wird:

1. Windows- und PowerShell-Version
2. Dienst *Windows-Bilderfassung (WIA)* — läuft er?
3. alle von Windows gemeldeten Bildgeräte
4. Geräte-Manager samt Problemcodes (Code 28 = kein Treiber, Code 10 = startet
   nicht, Code 43 = angehalten …)
5. installierte Treiberarten (TWAIN-Quellen, Canon-Software)
6. **Programme, die den Scanner belegen**
7. Verbindungstest mit Fähigkeiten, Papierstatus und Bildformaten
8. Testscan (nur mit `/scan`)
9. Duplex-Test (nur mit `/duplextest`)
10. **NAPS2** — ist es installiert, wo liegt es, welche Geräte meldet es

Am Ende steht eine Bewertung im Klartext, was zu tun ist. Der vollständige
Bericht landet als Textdatei auf dem Desktop und lässt sich weitergeben.

| Aufruf | Wirkung |
|---|---|
| `Diagnose.bat` | nur prüfen |
| `Diagnose.bat /scan` | zusätzlich eine Testseite einziehen |
| `Diagnose.bat /freigeben` | Programme beenden, die den Scanner belegen |
| `Diagnose.bat /duplextest` | probiert aus, welche Duplex-Einstellung der Treiber annimmt |
| `Diagnose.bat /naps2` | listet die Geräte auf, die NAPS2 über TWAIN sieht |

### Rückgabewerte

| Wert | Bedeutung |
|---|---|
| 0 | erfolgreich |
| 2 | fehlerhafter Aufruf (Option oder Wert) |
| 3 | kein Scanner gefunden bzw. WIA nicht verfügbar |
| 4 | kein Papier eingezogen |
| 5 | Fehler während der Übertragung |
| 6 | Zielordner oder Zieldatei nicht beschreibbar |
| 7 | NAPS2 wurde nicht gefunden (bei `/naps2`) |
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

* Der Scan läuft wahlweise über **WIA** (`WIA.DeviceManager`) oder über
  **NAPS2** (`NAPS2.Console.exe`, TWAIN). Bei WIA werden Einzug, Duplex,
  Farbmodus, Auflösung und Scanbereich über die WIA-Eigenschaften gesetzt; nach
  einer Änderung der Auflösung wird der Scanbereich mitskaliert, damit die
  Seite nicht beschnitten wird.
* Bei WIA wird jede Seite einzeln übertragen, bis der Treiber „kein Papier“
  meldet; liefert der Treiber beide Seiten eines Blattes in einem Transfer,
  wird das mehrseitige TIFF aufgeteilt.
* Bei NAPS2 legt `--split` jede Seite als eigene JPEG-Datei ab; die Dateien
  werden nach Namen sortiert übernommen. Die Ausgabe von NAPS2 landet im
  Protokoll, damit im Fehlerfall die Meldung des TWAIN-Treibers sichtbar ist.
  Die Nachbearbeitung ist für beide Wege dieselbe.
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
