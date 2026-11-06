# StarForce: Alpha Centauri

Conflitto interstellare nel XXV secolo. Gioco di Redmond A. Simonsen, SPI 1974. Questa è una traduzione riassunta del regolamento, con le note su come funziona la versione digitale.

## L'idea del gioco

Ogni giocatore comanda le forze spaziali di una razza o di una fazione. Le astronavi non viaggiano attraverso lo spazio: si **spostano** (shift) istantaneamente da un punto all'altro, grazie alle Telestetiche e alle loro macchine pensanti. Ogni turno i giocatori scrivono in segreto dove andranno le loro StarForce, poi gli spostamenti avvengono tutti insieme. Quando forze nemiche si trovano nello stesso punto dello spazio si combatte.

La difficoltà, e il fascino, è la terza dimensione: due stelle vicine sulla mappa possono essere lontanissime in altezza.

## Il Volume e lo Stellar Display

- La mappa è il piano equatoriale terrestre: ogni esagono è largo un **Lite** (un anno luce) e ha un numero di quattro cifre (riga e colonna). Sol è in 2020.
- Ogni punto dello spazio è una **LiteZulu**: esagono più quota **Zulu**, cioè quanti Lite sopra (+) o sotto (-) il piano. Sol è in 2020/0, Alpha Centauri in 1821/-4.
- Il Volume è una specie di sfera: gli anelli concentrici della mappa danno il **limite Zulu** (+/-21 al centro, poi +/-19, +/-17, +/-14, +/-11 al bordo).
- Ci sono 74 sistemi stellari: i tre **natali** (Sol degli Umani, Sigma Draconis dei L'Chal-Dah, 70 Ophiuchi dei Rame), quattordici **secondari** colonizzabili e i **terziari**. Le stelle magenta sono sotto il piano, quelle bianche sopra, quelle rosa sul piano.
- **Distanza vera**: la distanza in linea retta nello spazio, cioè la radice della somma dei quadrati della distanza sul piano (in esagoni) e della differenza di Zulu, arrotondata. Nella versione digitale la calcola il gioco e la mostra quando passi sopra la mappa.

Nella vista 3D ogni stella e ogni flotta ha uno **stelo** fino al piano: così si legge subito la sua quota.

## Le unità

- **StarForce**: una flotta di quattro TeleNavi, l'unità mobile. È identificata da una lettera.
- **StarGate**: una stazione in orbita a una stella, immobile, numerata. Aiuta gli spostamenti delle StarForce amiche e combatte come una fortezza. Un solo StarGate per sistema.

## Il turno stellare

1. **Piano**: ognuno scrive in segreto la destinazione di ogni StarForce.
2. **Spostamenti**: prima quelli entro la portata sicura, poi gli oltre-spostamenti.
3. **Lettura delle Zulu**: si rivelano le posizioni dove serve (vedi più avanti).
4. **Combattimento**: in ogni LiteZulu dove ci sono unità nemiche.
5. **Recupero**: le unità neutralizzate nel turno precedente tornano normali.

## Gli spostamenti

La portata sicura dipende dal tipo di spostamento:

- **S**, normale: 5 Lite.
- **ES**, verso una LiteZulu rinforzata (da una StarGate amica, o da una StarForce amica che resta ferma a **rinforzare** la sua posizione): 10 Lite.
- **GS**, con l'aiuto della StarGate amica da cui si parte: 10 Lite.
- **EGS**, StarGate alla partenza e StarForce di rinforzo all'arrivo: 15 Lite.
- **GGS**, da una StarGate amica a un'altra: 20 Lite.

Una StarForce che rinforza resta ferma e aiuta una sola StarForce. Una StarGate ha capacità **due**: può aiutare due spostamenti (in partenza o in arrivo) per turno, oppure fino a **quattro** StarForce se fanno tutte esattamente lo stesso spostamento.

Nella versione digitale **il tipo di spostamento lo sceglie il gioco**: per ogni StarForce usa la combinazione più sicura fra le StarGate e i rinforzi disponibili, nel rispetto delle capacità. Tu indichi solo la destinazione (e, se vuoi, quali StarForce restano a rinforzare).

**StarGate nemiche.** Entrare nella LiteZulu di una StarGate nemica attiva costa **4 Lite in più**, a meno di iniziare il turno in una delle 20 LiteZulu adiacenti alla StarGate: da lì si entra sempre senza rischio.

**Oltre-spostamento.** Si può tentare uno spostamento più lungo della portata sicura. Secondo quanto si eccede (colonne A-F della tabella) si pesca un chit da 0 a 9:

- **S**: si arriva;
- **M**: spostamento a specchio, la StarForce finisce alla stessa distanza nella direzione opposta (con la Zulu invertita) e, nel gioco avanzato, resta neutralizzata;
- **R**: randomizzata. Nel gioco base esce dalla partita; nel gioco avanzato e in quello con randomizzatore finisce in un punto a caso del Volume (vedi più avanti), neutralizzata.

Per gli spostamenti GS e GGS uguali (stessa partenza e arrivo) si pesca un solo chit per tutto il gruppo.

## Le informazioni nascoste

Le posizioni sono **semi-nascoste**: dell'avversario si vede solo in quali esagoni ha StarForce (un segnalino per esagono, senza sapere quante sono né a che quota). La Zulu esatta si scopre solo:

- delle StarForce nelle 20 LiteZulu adiacenti a una propria StarGate;
- delle StarForce nemiche nello stesso esagono di proprie unità.

Il numero di StarForce si scopre solo quando si è nella stessa LiteZulu. Le StarGate sono sempre visibili. Nella vista 3D una flotta di cui non conosci la quota appare come un segnalino con il punto di domanda e una colonna trasparente che attraversa tutte le quote possibili.

## Il combattimento base

Si combatte quando unità nemiche sono nella stessa LiteZulu. In ogni **segmento** ognuno ripartisce in segreto i suoi punti fra **attacco** e **difesa**:

- StarGate: 5 punti;
- StarForce: 3 punti, ma 2 nel primo segmento se è appena arrivata;
- nel gioco con randomizzatore le unità neutralizzate valgono 1 (StarGate 0).

**Primo segmento.** Combattono solo le StarForce appena arrivate contro le StarForce che erano già lì; le StarGate non partecipano. Chi era già lì può rifiutare il combattimento in questo segmento.

**Risoluzione.** Ogni attaccante calcola attacco meno difesa nemica (sotto -3 l'attacco non è ammesso, oltre +6 vale +6), pesca un chit e legge la tabella: il numero è quante StarForce perde il nemico. Una StarGate vale due StarForce e cade solo con un risultato di almeno 2 quando le StarForce non bastano. I risultati si applicano insieme.

**Ritirata.** Dal secondo segmento una StarForce può ritirarsi: vale 2 punti, solo in difesa, ed esce alla fine del segmento verso la LiteZulu da cui era venuta (se non contesa), una StarGate amica entro 10 Lite, oppure una LiteZulu adiacente non contesa.

**Stallo.** Dopo sei segmenti senza perdite chi non ha la StarGate deve ritirarsi.

**StarGate distrutta.** Se chi la possedeva respinge comunque il nemico nello stesso turno, la StarGate ricompare il turno dopo (inutilizzabile) e torna normale il turno seguente se il nemico non è nella sua LiteZulu. Altrimenti è **neutralizzata in modo permanente**: è questo che conta per la vittoria.

## Il gioco avanzato: il Tactical Display

Nel gioco avanzato il combattimento si sposta sul **Tactical Display**, un volume di 91 esagoni (numerati con tre cifre: anello, sestante, posizione) per 11 livelli di **MiniZulu** (da -5 a +5). Ogni esagono è un MiniLite, un terzo di giorno luce.

**Schieramento.** La StarGate sta al centro (000/0); la stella del sistema, se c'è, a 000/-1. Chi era già nella LiteZulu si schiera dove vuole, anche in modo battaglia; chi è appena arrivato si schiera sull'anello esterno (serie 500) o a MiniZulu +/-5, in modo stellare, e chi arriva insieme dalla stessa LiteZulu resta entro un MiniLite.

**TeleValue.** Ogni Tac-turno le unità hanno dei **TelePunti** da spendere: StarForce in modo **stellare** 32, in modo **battaglia** 64, StarGate 64 in ciascuna delle due fasi. Quello che non si spende è l'**anti-proiezione**, la difesa per tutto il Tac-turno (per la StarGate, per la fase).

**Il Tac-turno.** Piano segreto, poi due fasi di esecuzione. In ogni fase una StarForce può fare **una** di queste cose:

- **Tac-spostamento**: il primo quinto della portata costa metà del TeleValue, ogni quinto in più metà di quello che resta. In modo stellare la portata è 10 MiniLite (1-2: 16 punti, 3-4: 24, 5-6: 28, 7-8: 30, 9-10: 32); in modo battaglia 5 (32, 48, 56, 60, 64).
- **Cambio di modo** (solo nella prima fase): costa metà del TeleValue del nuovo modo (32 per passare in battaglia, 16 per tornare in stellare).
- **Ritirata** (solo nella seconda fase, in modo stellare): 16 punti, verso le stesse destinazioni del gioco base; poi la StarForce resta neutralizzata per il turno seguente.
- **Proiezione** (cast): 2, 4, 8, 16, 32 o 64 punti in un cuneo di 60 gradi verso una delle ore 1, 3, 5, 7, 9, 11, verso l'alto o verso il basso. Ha portata 5 MiniLite e si dimezza per ogni MiniLite di distanza. La StarGate può fare fino a dodici proiezioni per fase, in direzioni diverse.

**Risoluzione.** Su ogni unità nemica si sommano le proiezioni che la raggiungono, si toglie la sua anti-proiezione e si pesca un chit sulla tabella: **D** = disgregata (TeleValue dimezzato fino al recupero; una StarForce già disgregata viene randomizzata), **R** = StarForce randomizzata, StarGate disgregata. Una StarGate che subisce una seconda R mentre è disgregata è **neutralizzata**: se alla fine restano solo nemici, è neutralizzata in modo permanente.

Se un'unità viene disgregata nella prima fase, il suo piano della seconda fase si dimezza: i Tac-spostamenti e le ritirate saltano (metà dei punti va in anti-proiezione), le proiezioni si fanno a metà.

**Posizioni.** Chi ha una StarGate attiva vede tutte le posizioni nemiche; altrimenti si vedono solo le unità nello stesso esagono e quelle colpite dalle proprie proiezioni. Una flotta di cui non si conosce la MiniZulu appare come segnalino con colonna trasparente.

**Fine.** Si combatte finché restano unità nemiche fra loro (le StarGate neutralizzate non contano). Dopo dodici Tac-turni senza proiezioni efficaci, chi non difende la StarGate deve ritirarsi.

## La randomizzazione

Una StarForce randomizzata finisce in un punto a caso: si pescano tre chit dal **randomizzatore stellare** (43 chit): i numeri in alto dei primi due formano l'esagono, quello in basso del terzo la Zulu. Un **Dstr** fra i primi due distrugge la StarForce; un **Brkf** la lascia neutralizzata dove si trova (o la costringe a ritirarsi, se era in combattimento). Se il punto è fuori dal Volume si riporta al bordo; se cade in una stella la StarForce è distrutta. La StarForce randomizzata riappare alla fine del turno, neutralizzata per il turno seguente.

## Gli scenari

Ogni scenario indica le StarGate e le StarForce di ogni giocatore e le condizioni di vittoria, quasi sempre la neutralizzazione permanente di StarGate nemiche o l'occupazione di un sistema (essere i soli nella sua LiteZulu alla fine di turni consecutivi).

**Cooperazione fra razze.** Le StarGate di razze diverse non possono collegarsi per un GGS, e una razza non può rinforzare l'arrivo di un'altra; una StarForce può però usare la StarGate di un'altra razza alleata per un normale GS. In combattimento collaborano pienamente.

**Tre giocatori.** Negli scenari 11 e 12 tutti sono nemici di tutti: gli accordi si fanno a voce. Nel combattimento base ognuno ripartisce il suo attacco fra gli avversari presenti.

## Gli Xenofobi (scenari 13 e 14)

- Le StarGate xenofobe sono fuori dal Volume conosciuto, due Lite oltre il limite Zulu, tutte dalla stessa parte: la Lega deve trovarle arrivando adiacente a esse.
- Il movimento è nascosto in entrambe le direzioni: si vedono solo le unità nella stessa LiteZulu o adiacenti alle proprie StarGate.
- **Spazio ignoto**: per la Lega è fuori dai limiti Zulu, per gli Xenofobi è dentro il Volume (o oltre 10 Lite dalle loro StarGate). Verso lo spazio ignoto lo spostamento normale sicuro è di un solo Lite e quello con la StarGate di cinque.
- Entrare in una StarGate nemica non costa i 4 Lite in più.
- Prima incursione: gli Xenofobi hanno fino a dieci turni preliminari e nel primo turno un **attacco a sorpresa** distrugge senza combattere una StarGate non natale dove arrivano almeno due loro StarForce. Seconda incursione: cinque turni preliminari, nessuna sorpresa.
- **Nova**: dove la StarGate della Lega è caduta, una StarForce xenofoba può innescare la nova della stella ritirandosi; il sistema è distrutto.
- Gli Xenofobi randomizzati tornano dopo tre turni in una loro StarGate. La Lega riceve una StarForce in più ogni turno pari.
- Si vince a punti (vedi lo scenario); gli Xenofobi perdono se restano quindici turni senza attaccare una StarGate.

## La missione di soccorso (solitario)

Una stella terziaria scelta a caso sta per esplodere. Dodici StarForce devono portare via 60 punti popolazione: per caricarne uno una StarForce vuota deve iniziare e finire il turno nella LiteZulu della stella (ordine **Carica / scarica**); per sbarcarlo deve iniziare e finire il turno nella LiteZulu di un altro sistema. Ogni turno si pesca dal sacchetto della nova: con due zeri di fila la stella esplode. Un punto per ogni punto popolazione salvato, tre in meno per ogni StarForce perduta: 60 vittoria decisiva, 50-59 sostanziale, 40-49 marginale.

## Le regole opzionali

Si attivano nel menu, sotto **Regole opzionali**; alcuni scenari ne attivano qualcuna da soli.

- **StarForce di riserva (32.0)**: fino a un terzo delle tue StarForce (almeno una) può restare **in riserva** invece di muoversi. Dopo gli spostamenti, quando si sa dove si combatte, scegli dove mandarle: arrivano dal secondo segmento (gioco base, con forza 2) o dal terzo Tac-turno (gioco avanzato, in modo stellare, solo con azioni della seconda fase), sulla posizione di un'unità amica. Possono sforare la portata. Il turno dopo una StarForce che è stata in riserva non può spostarsi. Se il nemico arriva proprio dove la riserva aspetta, la riserva è annullata e combatte lì.
- **FakerForce (33.0)**: una StarForce ferma si può dividere in **quattro FakerForce** di una sola TeleNave (al massimo il 10% delle tue StarForce). Il nemico le vede come StarForce vere finché non sono in una LiteZulu contesa, sul Tactical Display o accanto a una sua StarGate. Una FakerForce vale un quarto di StarForce per la capacità delle StarGate e per le perdite, mezzo punto nel combattimento base; sul Tactical Display ha 8 TelePunti in modo stellare e 16 in battaglia. Rinforza solo un'altra FakerForce. Quattro FakerForce nella stessa LiteZulu non contesa si possono **riunire**.
- **GateLink (34.0)**: tra due tue StarGate collegate da una catena di StarGate amiche della stessa razza, ognuna entro **20 Lite** dalla successiva, lo spostamento è sicuro qualunque sia la distanza (codice GL). Tutte le StarGate della catena usano la loro capacità. Il gioco lo sceglie da solo quando serve.
- **Continuità della situazione (35.0)**: un combattimento non risolto dopo sei segmenti (o dodici Tac-turni) non finisce con la ritirata obbligata ma **prosegue nel turno seguente** (dodici segmenti o ventiquattro Tac-turni per turno); chi arriva si unisce. Le StarGate coinvolte non aiutano gli spostamenti.
- **Fatica degli equipaggi (36.0)**: una StarForce che passa due turni di fila in **modo battaglia** (nel gioco base: che combatte con forza 3) il turno dopo aggiunge **2 Lite** ai suoi spostamenti e rinforzi (non GS e GGS), deve tenere almeno un punto in difesa e non può proiettare più di metà dei TelePunti. Dopo tre turni di fila resta **neutralizzata** per un turno.

## La nova nel gioco avanzato (31.52)

Per far esplodere una stella sul Tactical Display: la StarGate del sistema deve essere **disgregata o neutralizzata**; una StarForce in **modo stellare** deve iniziare il Tac-turno nel MiniLite della stella (**000/-1**, ci si arriva solo da un MiniLite di distanza) e scegliere **Innesca la nova** nella prima fase: costa metà dei TelePunti e occupa tutto il Tac-turno. Se alla fine del Tac-turno non è stata disgregata, l'innesco è piantato e la stella esplode nella prima fase del Tac-turno seguente, distruggendo chi è rimasto nel suo MiniLite. Il sistema è distrutto alla fine della sequenza tattica.

## Gli scenari del XXX secolo (15-20)

Da **Beyond 3000** (Moves): compare **Wandering's End** (2223/+8), il sistema natale dei Wanderers.

- **15, la terza incursione xenofoba**: regole degli Xenofobi, punteggi più alti; dopo la prima stella della Lega distrutta arrivano quattro StarForce in più.
- **16, la guerra delle FakerForce**: tre giocatori, tutte le StarForce divise in FakerForce, che non possono entrare nelle LiteZulu delle StarGate nemiche. La prima volta che una FakerForce entra in un sistema altrui si pesca un chit: con 8 o 9 viene randomizzata.
- **17, 18, 19**: i RxPexy e l'Unione dei Senzienti hanno **sistemi esterni**, fuori dal Volume conosciuto (che si estende di dieci Lite in altezza). Nel 18 Lega e RxPexy non si attaccano fino al turno 4 e Unione e RxPexy non sono nemici. Nel 19 la Lega è ferma finché a fine turno non esce un 9, e gli **incrociatori a tachioni** RxPexy si muovono di due Lite per turno, senza difesa, e neutralizzano per sempre una StarGate inattiva entrandoci.
- **20, Operazione Cartagine**: solitario sul Tactical Display del sistema natale xenofobo; bisogna innescare la nova prima che il trasporto si ritiri dal display.
- **21, la guerra per l'identità a due**: la Lega Umana è inattiva; ogni turno i due giocatori pescano un chit politico (dal 0 al 9, senza rimetterlo) e chi arriva a 23 ne prende il comando. Chi perde una StarGate coloniale prima salta la pesca seguente.

## Comandi della versione digitale

- **Telecamera**: trascina per ruotare, rotella o pizzico per avvicinare, tasto destro (o Maiusc + trascina, o due dita) per spostare la vista; da tastiera Q ed E ruotano, le frecce spostano, + e - avvicinano. Il pulsante **Vista dall'alto** mostra la mappa piatta come quella di carta, con la quota Zulu accanto a stelle e flotte; **Centra** riporta la vista sulle tue forze.
- **Piano**: clic su una tua flotta (o sull'elenco a destra), poi clic su un esagono o su una stella per la destinazione. La quota Zulu si cambia con i pulsanti o con i tasti W e S. La sfera azzurra è la portata sicura; le linee dei piani sono verdi (sicuro), gialle, arancioni o rosse secondo il rischio.
- **Piano dell'IA**: riempie il piano con i suggerimenti dell'avversario automatico, che puoi poi modificare.
- **Grafica**: Reborn (astronavi e StarGate in 3D, effetti di luce) oppure originale (la mappa e le pedine SPI).
- **Tabelle**: il pulsante in alto apre tutte le tabelle del gioco (spostamenti e oltre-spostamento, combattimento base, Tactical Display, Outleap). Le tabelle che servono compaiono anche da sole: la probabilità di arrivare quando un salto è oltre la portata, la tabella dei risultati nel combattimento, le unità colpite e la tabella delle proiezioni quando ne prepari una.
- **Salva**: salva la partita su Firebase e ti dà un codice da usare nel menu, anche su un altro dispositivo.
- **Online**: chi crea la stanza dà il codice agli amici; le decisioni sono segrete e simultanee, e se qualcuno si disconnette per un po' gioca l'IA al suo posto.
- Alla fine si può **rivedere la partita** dall'inizio, con tutte le posizioni scoperte, comprese le battaglie sul Tactical Display (schieramento, Tac-spostamenti, proiezioni e risultati, fase per fase). I pulsanti **Battaglia precedente** e **Battaglia successiva** saltano da uno scontro all'altro.
