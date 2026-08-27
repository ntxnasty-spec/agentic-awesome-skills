# God's Eye View lokal starten

Setup-Kit für [**God's Eye View**](https://github.com/bilawalsidhu/gods-eye-view) von Bilawal Sidhu –
eine Echtzeit-Intelligence-Konsole für die Erde: fotorealistischer 3D-Globus mit Live-Flugzeugen,
Schiffen, Satelliten, Erdbeben und öffentlichen Kameras, dazu Sprachsteuerung.

Die Skripte hier klonen das Projekt, legen die Konfiguration an, installieren die
Abhängigkeiten und starten den lokalen Server – auf Windows, macOS und Linux.

> God's Eye View ist ein eigenständiges MIT-Projekt und **nicht** Teil dieses Repositories.
> Die Skripte laden es bei Bedarf nach; verändert wird nichts am Original.

---

## Voraussetzungen

| Was | Details | Warum |
|-----|---------|-------|
| **Node.js 24 LTS** | `24.14.0` – `24.x` oder `26.x` | Vom Projekt in `package.json` erzwungen |
| **Git** | aktuelle Version | Zum Klonen und Aktualisieren |
| **Chrome / Chromium / Edge** | aktuelle Version | Cesium braucht WebGL 2 – Chromium-Browser sind hier am robustesten |
| **GPU** | irgendeine mit WebGL 2 | Ohne Hardwarebeschleunigung ruckelt der Globus |
| **Speicher** | ca. 1 GB frei | `node_modules` liegt bei ~250 MB, dazu kommt Puppeteers Chromium-Download, falls dein npm Postinstall-Skripte ausführt |
| **Google-Maps-Key** | siehe [API-Keys](#api-keys) | Der einzige Pflicht-Key |

Node prüfen: `node --version`. Passt die Version nicht, meldet sich das Setup mit einem Hinweis
statt mit einem kryptischen Build-Fehler.

---

## Schnellstart

### Windows

1. Diesen Ordner (`tools/gods-eye-view/`) öffnen.
2. Doppelklick auf **`START_GODS_EYE_VIEW.bat`**.
3. Beim ersten Lauf fragt das Skript nach dem Google-Maps-Key – einfügen und Enter.
4. Nach der Installation öffnet sich der Browser auf `http://localhost:4173/`.

Das `.bat` startet nur `setup.ps1` mit `-ExecutionPolicy Bypass`; an den PowerShell-Einstellungen
des Systems ändert sich dauerhaft nichts.

Alternativ direkt in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

### macOS / Linux

```bash
chmod +x setup.sh
./setup.sh
```

### Ohne Skripte, von Hand

```bash
git clone https://github.com/bilawalsidhu/gods-eye-view.git
cd gods-eye-view
cp .env.example .env          # danach GOOGLE_MAPS_API_KEY eintragen
npm install
npm run dev -- --host localhost --port 4173
```

Standard-Zielordner der Skripte ist `%USERPROFILE%\gods-eye-view` bzw. `~/gods-eye-view`.
Ist er bereits vorhanden, wird per `git pull --ff-only` aktualisiert statt neu geklont.

---

## API-Keys

Zehn der dreizehn Live-Ebenen laufen **ohne jeden Key**: Flüge (anonym), Militärverkehr,
Satelliten, Erdbeben, CCTV, Radio, Bikesharing, Weltraummissionen, kartierte Anlagen und alle
mitgelieferten Datensätze.

Alle Keys landen in der `.env` im geklonten Projektordner. Diese Datei ist dort per `.gitignore`
ausgeschlossen und verlässt deinen Rechner nicht.

| Key | Wofür | Pflicht? | Kosten |
|-----|-------|----------|--------|
| `GOOGLE_MAPS_API_KEY` | Fotorealistischer 3D-Globus (Map Tiles API) | **ja** | Nach Nutzung abgerechnet |
| `OPENAI_API_KEY` | Sprachsteuerung + KI-HUD-Zusammenfassung | nein | Nach Nutzung abgerechnet |
| `AISSTREAM_API_KEY` | Live-Schiffe weltweit | nein | Kostenloser Entwicklerzugang |
| `FIRMS_MAP_KEY` | Aktive Brände (NASA FIRMS) | nein | Kostenloser Entwicklerzugang |
| `TOMTOM_API_KEY` | Echter Verkehr statt Simulation | nein | Kostenloses Kontingent |
| `CESIUM_ION_TOKEN` | Bing-Luftbilder als Kartenebene | nein | Abhängig vom Tarif |

Zum Google-Key, weil er der einzige metered Pflicht-Key ist:

1. In der [Google Cloud Console](https://console.cloud.google.com/) ein Projekt anlegen und
   **Abrechnung aktivieren**.
2. **Map Tiles API** aktivieren (ohne sie bleibt der Globus schwarz, obwohl der Key gültig ist).
3. Den Key einschränken – API-Restriktion auf Map Tiles, HTTP-Referrer auf `http://localhost:4173/*`.
4. Unter *Billing → Budgets & alerts* ein Budget mit Benachrichtigung setzen.

Preise und Freikontingente ändern sich; verlass dich auf die
[aktuelle Preisseite](https://developers.google.com/maps/billing-and-pricing/pricing), nicht auf
Zahlen aus irgendeinem Blogpost. Details zu allen Quellen stehen in `DATA_SOURCES.md` im Projekt.

Die Keys `GOOGLE_MAPS_API_KEY` und `CESIUM_ION_TOKEN` landen bauartbedingt im Browser-Bundle und
sind in den DevTools sichtbar – deshalb einschränken statt verstecken. Alle übrigen Keys bleiben
serverseitig.

---

## Optionen

| PowerShell | Bash | Wirkung |
|------------|------|---------|
| `-InstallDir <pfad>` | `--dir <pfad>` | Anderer Zielordner |
| `-Port <nummer>` | `--port <nummer>` | Anderer Port (Default 4173) |
| `-SetupOnly` | `--setup-only` | Nur einrichten, nicht starten |
| `-Reinstall` | `--reinstall` | `node_modules` löschen und neu installieren |
| `-SkipNodeCheck` | `--skip-node-check` | Node-Versionsprüfung übergehen |
| `-NoBrowser` | `--no-browser` | Browser nicht automatisch öffnen |
| `-NonInteractive` | `--non-interactive` | Keine Rückfragen (für Automatisierung) |

Beispiel:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -InstallDir D:\apps\gev -Port 5173
```

```bash
./setup.sh --dir ~/apps/gev --port 5173
```

---

## Was getestet wurde

Auf Linux mit Node 24.20.0 gegen den Stand vom 27.08.2026 (Commit `880a672`):

- `npm install` läuft ohne Fehler durch (Exit-Code 0).
- `npm run dev` startet in ca. 0,3 s; `http://localhost:4173/` liefert HTTP 200.
- Ein Headless-Chromium-Smoke-Test zeigt: Cesium-Canvas erzeugt, HUD gerendert,
  Mission-Control-Karte sichtbar, **keine JavaScript-Fehler** auf der Seite.
- Die verbleibenden Konsolenmeldungen im Test waren reine Netzwerkfehler der Sandbox
  (kein Zugang zu Google/OpenSky) plus HTTP 400 vom absichtlich gefälschten Test-Key.

Nicht getestet: ein Lauf auf echtem Windows und der Betrieb mit gültigen API-Keys – für beides
fehlt der Zugriff. Die Windows-Skripte sind gegen die dokumentierten Anforderungen des Projekts
geschrieben, nicht gegen eine laufende Windows-Maschine.

---

## Wenn etwas klemmt

**„Node ... wird vom Projekt nicht unterstützt"**
Node 24 LTS installieren (`winget install --id OpenJS.NodeJS.LTS -e`) oder mehrere Versionen
parallel über [nvm-windows](https://github.com/coreybutler/nvm-windows) bzw.
[nvm](https://github.com/nvm-sh/nvm) verwalten. Danach ein **neues** Terminal öffnen.

**Warnungen wie „3 packages have install scripts not yet covered by allowScripts"**
Neuere npm-Versionen führen Postinstall-Skripte nicht mehr automatisch aus (`esbuild`,
`puppeteer`, `sharp`). Für den Dev-Server ist das folgenlos – die Binaries kommen aus den
plattformspezifischen Paketen. Nur die QA-Skripte des Projekts, die Puppeteer brauchen, laufen
dann nicht.

**Port 4173 ist belegt**
Mit `-Port` / `--port` einen anderen wählen. Unter Windows den Blockierer finden:
`netstat -ano | findstr :4173`.

**Der Globus bleibt schwarz oder grau**
Meist ist der Key da, aber die **Map Tiles API** im Google-Projekt nicht aktiviert – oder die
Referrer-Einschränkung passt nicht zum tatsächlichen Port. Die DevTools-Konsole (F12) nennt den
Grund.

**„WebGL not supported"**
Hardwarebeschleunigung im Browser einschalten (Chrome: Einstellungen → System) und den
Grafiktreiber aktualisieren. Unter `chrome://gpu` steht, ob WebGL 2 aktiv ist.

**Das Mikrofon meldet „voice unavailable"**
Erwartetes Verhalten ohne `OPENAI_API_KEY`. Der Rest der App läuft normal weiter.

**Die App startet, aber es fliegt nichts**
Die Flug-Ebene braucht die Netzwerkfreigabe für den lokalen Server. Prüfe außerdem, ob in der
`.env` `OPENSKY_AUTH_MODE=anon` steht, wenn du keine OpenSky-Zugangsdaten hinterlegt hast – das
setzen die Skripte automatisch. Steht dort `oauth` ohne Zugangsdaten, bleibt die Ebene leer.

---

## Sicherheit

Der Dev-Server bindet bewusst nur an `localhost` – erreichbar ausschließlich von diesem Rechner.
Er vermittelt deine API-Keys an die Upstream-Dienste, deshalb ist eine Freigabe ins LAN
(`--host 0.0.0.0`) eine bewusste Entscheidung: Wer den Server erreicht, verbraucht dein Kontingent.
Wenn du das trotzdem brauchst, setze vorher die Drosseln `GEV_RATELIMIT_OPENAI_PER_MIN` und
`GEV_RATELIMIT_GOOGLE_PER_MIN` aus der `.env.example` – und vor allem die Budget-Limits beim
Anbieter selbst. Die Drosseln sind App-Schutz, keine Abrechnungsgrenze.

Die `.env` niemals committen. Im geklonten Projekt ist sie bereits durch `.gitignore` geschützt.

Das vollständige Bedrohungsmodell steht in `SECURITY.md` im Projekt-Repository.

---

## Quelle und Lizenz

God's Eye View stammt von [Bilawal Sidhu](https://github.com/bilawalsidhu) und steht unter der
MIT-Lizenz. Die mitgelieferten und live abgerufenen Datensätze haben eigene Nutzungsbedingungen –
siehe `DATA_SOURCES.md` im Projekt.

Die App visualisiert öffentliche und Drittanbieter-Daten zur Erkundung. Die Daten können verzögert,
unvollständig, modelliert oder schlicht falsch sein: nicht für Navigation, Notfalleinsätze oder
andere sicherheitskritische Zwecke verwenden.
