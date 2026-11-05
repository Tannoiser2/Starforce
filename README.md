# StarForce: Alpha Centauri, versione digitale

Versione digitale del classico SPI del 1974 di Redmond A. Simonsen: conflitto interstellare nel XXV
secolo fra le 74 stelle entro venti anni luce dal Sole, in un Volume a tre dimensioni.

Si gioca nel browser: https://tannoiser2.github.io/Starforce/ (e sulla ludoteca privata).

## Cosa c'è

- **Gioco base** (combattimento con la tabella strategica), **base con randomizzatore** (gioco base
  modificato con neutralizzazione e randomizzatore stellare) e **gioco avanzato** sul Tactical Display
  (modi stellare e battaglia, TelePunti, proiezioni e anti-proiezioni).
- **Quindici scenari** del regolamento: le guerre umane, il contatto con i L'Chal-Dah, le guerre con i
  Rame, i due scenari a tre giocatori, le due incursioni degli Xenofobi (movimento nascosto, spazio
  ignoto, attacco a sorpresa, nova) e la missione di soccorso in solitario.
- **Mappa 3D** del Volume: stelle alla loro quota Zulu con lo stelo fino al piano, griglia e anelli dei
  limiti Zulu, posizioni semi-nascoste (una flotta di cui non si conosce la quota appare con una colonna
  trasparente). Due grafiche: **originale** (la mappa e le pedine SPI del modulo TTS) e **Reborn**
  (astronavi e StarGate in 3D per ogni razza, effetti di luce per spostamenti, oltre-spostamenti,
  combattimenti, proiezioni e nove).
- **IA** per qualsiasi lato, **gioco a turno** sullo stesso dispositivo con piani segreti, **online** con
  piani simultanei (Firebase), **salvataggi** su Firebase con codice, **replay** finale dell'intera
  partita senza segreti.
- Regolamento in italiano dentro il gioco (assets/regole.md).

## Struttura

- `scripts/data/sf_data.gd`: stelle (lette dalla mappa originale), tabelle, scenari.
- `scripts/core/hex.gd`: geometria dello Stellar Display (numerazione XXYY, distanze vere, specchio)
  e del Tactical Display (sigle a tre cifre, cuneo delle proiezioni).
- `scripts/core/engine.gd`: turno stellare, spostamenti, visibilità, combattimento base, randomizzazione,
  vittoria, Xenofobi, missione di soccorso.
- `scripts/core/tactical.gd`: la sequenza tattica del gioco avanzato.
- `scripts/core/ai.gd`: avversario automatico.
- `scripts/ui/`: menu, schermata di gioco, scena 3D (`board3d.gd`), modelli (`ships.gd`), effetti
  (`fx.gd`), regole.
- `scripts/net/`: Firebase (stanze, registro delle mosse, salvataggi) e partita online in lockstep.
- `firebase/starforce.rules.json`: le regole del ramo `starforce` del database condiviso.

## Prove

```
godot --headless --path . -s tests/autoplay.gd            # tutti gli scenari, IA contro IA
godot --headless --path . -s tests/autoplay.gd -- 5 avanzato 3
xvfb-run godot --path . -s tests/shot.gd -- 3 avanzato reborn 6 /tmp/foto.png 1 plot
python3 tools/controlla_glifi.py                           # ogni carattere esiste nei font
```

## Pubblicazione

Solo su richiesta: Actions, *Pubblica*, *Run workflow*. Il workflow costruisce la versione web con
Godot 4.7 e la pubblica su GitHub Pages e, se ci sono i segreti `CLOUDFLARE_API_TOKEN` e
`CLOUDFLARE_ACCOUNT_ID`, su `starforce.ludoteca-digitale.com`.

## Materiale

Mappa, pedine e regolamento vengono dal modulo Tabletop Simulator di StarForce (SPI 1974). Caratteri
liberi (OFL): Audiowide, Orbitron, Exo 2, Share Tech Mono.
