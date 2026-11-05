# StarForce: Alpha Centauri, versione digitale

Versione digitale del classico SPI del 1974 di Redmond A. Simonsen: conflitto interstellare nel XXV
secolo fra le 74 stelle entro venti anni luce dal Sole, in un Volume a tre dimensioni.

Si gioca nel browser: https://tannoiser2.github.io/Starforce/ (e sulla ludoteca privata).

## Cosa c'è

- **Gioco base** (combattimento con la tabella strategica), **base con randomizzatore** (gioco base
  modificato con neutralizzazione e randomizzatore stellare) e **gioco avanzato** sul Tactical Display
  (modi stellare e battaglia, TelePunti, proiezioni e anti-proiezioni).
- **Tutti gli scenari**: i quindici del regolamento (le guerre umane, il contatto con i L'Chal-Dah, le
  guerre con i Rame, i due scenari a tre giocatori, le due incursioni degli Xenofobi con movimento
  nascosto, spazio ignoto, attacco a sorpresa e nova, la missione di soccorso in solitario), la versione a
  due dello scenario 11, i sei scenari di *Beyond 3000* (Moves: terza incursione, guerra delle
  FakerForce, RxPexy, Unione dei Senzienti, incrociatori a tachioni, Operazione Cartagine in solitario)
  e la campagna economica **Outleap** (scenario 100, per due o tre giocatori).
- **Regole opzionali** (32.0-36.0) attivabili dal menu: StarForce di riserva, FakerForce, GateLink,
  continuità della situazione, fatica degli equipaggi. La nova si innesca anche sul Tactical Display
  (31.52).
- **Tre tutorial guidati**: le basi, il Tactical Display, salti e informazioni nascoste.
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
- `scripts/core/ai.gd`: avversario automatico (anche per l'economia dell'Outleap).
- `scripts/core/outleap.gd`: la campagna Outleap: entrate, spese, organizzazione, sbarchi, consolidamento.
- `scripts/ui/`: menu, schermata di gioco, scena 3D (`board3d.gd`), modelli (`ships.gd`), effetti
  (`fx.gd`), regole.
- `scripts/net/`: Firebase (stanze, registro delle mosse, salvataggi) e partita online in lockstep.
- `firebase/starforce.rules.json`: le regole del ramo `starforce` del database condiviso.

## Prove

```
godot --headless --path . -s tests/autoplay.gd            # tutti gli scenari, IA contro IA
godot --headless --path . -s tests/autoplay.gd -- 5 avanzato 3
xvfb-run godot --path . -s tests/shot.gd -- 3 avanzato reborn 6 /tmp/foto.png 1 plot
OPZ=all godot --headless --path . -s tests/autoplay.gd     # con tutte le regole opzionali
godot --headless --path . -s tests/salva_carica.gd         # un salvataggio rigioca la stessa partita
xvfb-run godot --path . -s tests/tutorial.gd -- 2          # tutorial simulato
xvfb-run godot --path . -s tests/eco_ui.gd                 # Outleap dall'interfaccia
python3 tools/controlla_glifi.py                           # ogni carattere esiste nei font
```

## Pubblicazione

Solo su richiesta: Actions, *Pubblica*, *Run workflow*, oppure un commit su `main` con `[pubblica]` nel
messaggio. Il workflow costruisce la versione web con
Godot 4.7 e la pubblica su GitHub Pages e, se ci sono i segreti `CLOUDFLARE_API_TOKEN` e
`CLOUDFLARE_ACCOUNT_ID`, su `starforce.ludoteca-digitale.com`.

## Semplificazioni

- Outleap: niente fase diplomatica a voce e niente tabella delle tregue (non è nel materiale): le guerre si
  dichiarano a inizio anno e finiscono con l'anno; tre turni stellari, cinque se c'è una guerra; vittoria
  economica a tempo.
- Operazione Cartagine: la tabella delle risposte xenofobe dell'articolo non è nel materiale; il
  trasporto tenta la ritirata con due probabilità su dieci per Tac-turno.
- Riserve: chi arriva dalla riserva nel gioco avanzato agisce solo nella seconda fase; la "risoluzione
  per maggior coinvolgimento" (32.43) non serve perché le riserve vengono chiamate a combattimento iniziato.

## Materiale

Mappa, pedine e regolamento vengono dal modulo Tabletop Simulator di StarForce (SPI 1974). Caratteri
liberi (OFL): Audiowide, Orbitron, Exo 2, Share Tech Mono.
