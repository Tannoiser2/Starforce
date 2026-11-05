extends RefCounted
## Dati di StarForce: Alpha Centauri (SPI, 1974, di Redmond A. Simonsen).
## Sistemi stellari letti dalla mappa originale (Stellar Display), tabelle del regolamento e scenari.

## Sistemi stellari: [esagono, zulu, classe, nome]. Classe: h = sistema natale, s = secondario, t = terziario.
const STARS := [
	["0622", 2, "t", "Wolf 424"],
	["0627", 4, "t", "Lalande 25372"],
	["0715", 5, "t", "BD+20°"],
	["0717", 13, "t", "Lalande 21258"],
	["0732", -7, "s", "CD-20°"],
	["0913", 16, "t", "BD+45°"],
	["0920", 0, "t", "Ross 128"],
	["1006", -7, "t", "Luyten 674-15"],
	["1032", -2, "t", "Wolf 562"],
	["1112", 16, "t", "BD+53°"],
	["1132", -13, "t", "CD-40°"],
	["1216", 11, "t", "BD+50°"],
	["1319", 1, "t", "Wolf 359"],
	["1321", -19, "t", "Luyten 68-28"],
	["1418", 5, "t", "Lalande 21185"],
	["1420", -13, "t", "CC 658"],
	["1511", 1, "t", "Procione"],
	["1520", -8, "t", "Stella di Innes"],
	["1521", 16, "t", "AC 79"],
	["1532", -3, "t", "BD-12°"],
	["1606", 12, "t", "Ross 986"],
	["1608", 1, "t", "Stella di Luyten"],
	["1636", -8, "s", "36 Ophiuchi"],
	["1637", -8, "t", "CD-26°"],
	["1705", 11, "t", "Wolf 294"],
	["1715", -18, "t", "Luyten 97-12"],
	["1731", -11, "t", "CD-44°"],
	["1734", 14, "t", "BD+45° (2)"],
	["1807", -2, "t", "Ross 614"],
	["1812", -2, "t", "Sirio"],
	["1821", -4, "s", "Alpha Centauri"],
	["1830", -11, "t", "CD-46°"],
	["1926", 14, "t", "BD+68°"],
	["1931", -16, "t", "UC 48"],
	["1938", -7, "t", "CD-21°"],
	["2002", -7, "t", "CD-21° (2)"],
	["2020", 0, "h", "Sol"],
	["2026", 0, "t", "Stella di Barnard"],
	["2036", 1, "h", "70 Ophiuchi"],
	["2126", 10, "t", "BD+59°"],
	["2202", 5, "t", "Ross 47"],
	["2211", -9, "t", "Stella di Kapteyn"],
	["2228", -4, "t", "Ross 154"],
	["2326", 17, "h", "Sigma Draconis"],
	["2420", -21, "s", "Beta Hydri"],
	["2427", -18, "s", "Delta Pavonis"],
	["2433", -14, "t", "Luyten 347-14"],
	["2523", -10, "s", "Epsilon Indi"],
	["2537", 2, "t", "BD+4°"],
	["2623", 11, "t", "Krueger 60"],
	["2626", 7, "s", "61 Cygni"],
	["2707", -2, "t", "40 Eridani"],
	["2713", -2, "s", "Epsilon Eridani"],
	["2718", -2, "t", "Luyten 726-8"],
	["2721", 7, "t", "Ross 248"],
	["2727", -8, "t", "CD-39°"],
	["2734", 2, "t", "Altair"],
	["2819", 8, "t", "Groombridge 34"],
	["2826", -12, "t", "CD-49°"],
	["2832", -14, "t", "CD-45°"],
	["2833", -11, "s", "HR 7703"],
	["2922", -7, "t", "CD-36°"],
	["3009", -14, "s", "82 Eridani"],
	["3015", -3, "s", "Tau Ceti"],
	["3018", 15, "s", "Eta Cassiopeiae"],
	["3024", 11, "t", "EV Lacertae"],
	["3024", -3, "t", "Luyten 789-6"],
	["3116", -18, "s", "p Eridani"],
	["3220", -9, "t", "CD-37°"],
	["3223", 17, "s", "HR 8832"],
	["3318", 1, "t", "Stella di Van Maanen"],
	["3325", -5, "t", "CD-27°"],
	["3424", -4, "t", "Ross 780"],
	["3922", 0, "t", "Lalande 46650"],
]

## Limiti Zulu per anello (distanza planare da Sol): fino a 6 = +/-21, 11 = +/-19, 14 = +/-17, 17 = +/-14, 19 = +/-11.
const ZULU_RINGS := [[6, 21], [11, 19], [14, 17], [17, 14], [19, 11]]
const MAP_RADIUS := 19

## Tabella degli spostamenti massimi [7.5]: codice -> [sicuro, A, B, C, D, E] (F = oltre E)
const SHIFT_TABLE := {
	"S": [5, 6, 7, 8, 9, 10],
	"ES": [10, 11, 12, 13, 14, 15],
	"GS": [10, 11, 12, 13, 14, 15],
	"EGS": [15, 16, 17, 18, 19, 20],
	"GGS": [20, 22, 24, 26, 28, 30],
	"GL": [20, 20, 20, 20, 20, 20],
}
## Spazio ignoto (scenari Xenofobi)
const SHIFT_UNKNOWN := {
	"S": [1, 2, 3, 4, 5, 6],
	"GS": [5, 6, 7, 8, 9, 10],
}
## Risultati dell'oltre-spostamento: riga = chit 0-9, colonne A-F
const OVERSHIFT := [
	"SSSSSR", "SSSSSR", "SSSSMR", "SSMMMR", "SSMMRR",
	"SMMRRR", "SMMRRR", "MMRRRR", "MRRRRR", "MRRRRR",
]

## Tabella dei risultati del combattimento strategico (gioco base): colonne -3..+6, righe chit 0-9
const SCRT := [
	[0, 0, 0, 0, 0, 0, 1, 1, 2, 2],
	[0, 0, 0, 0, 0, 0, 1, 1, 2, 2],
	[0, 0, 0, 0, 0, 1, 1, 1, 2, 3],
	[0, 0, 0, 0, 1, 1, 1, 2, 3, 3],
	[0, 0, 0, 1, 1, 1, 2, 2, 3, 4],
	[0, 0, 1, 1, 1, 1, 2, 2, 3, 4],
	[0, 1, 1, 1, 1, 1, 2, 3, 4, 5],
	[1, 1, 1, 1, 2, 2, 2, 3, 4, 5],
	[1, 1, 1, 1, 2, 2, 3, 3, 5, 6],
	[1, 1, 1, 1, 2, 3, 3, 4, 5, 6],
]

## Tabella di risoluzione delle proiezioni [14.6]: colonne 0, +1, +2/3, +4/7, +8/15, +16/31, +32
const CAST_TABLE := [
	"....DDD", "....DDD", "...DDDR", "...DDRR", "...DDRR",
	"..DDDRR", "..DDDRR", ".DDDRRR", ".DRRRRR", "DDRRRRR",
]

## Costo in TelePunti del Tac-spostamento [13.13]: per StarForce in modo stellare (distanza 1-10)
## e in modo battaglia (distanza 1-5)
const TAC_COST_STELLAR := [0, 16, 16, 24, 24, 28, 28, 30, 30, 32, 32]
const TAC_COST_BATTLE := [0, 32, 48, 56, 60, 64]
const TELE_STELLAR := 32
const TELE_BATTLE := 64
const TELE_GATE := 64
const CAST_LEVELS := [2, 4, 8, 16, 32, 64]
const BREAKOFF_COST := 16
## FakerForce [33.0]: una sola TeleNave, un quarto di StarForce (tabella 13.13 sulla mappa)
const FF_COST_STELLAR := [0, 4, 4, 6, 6, 7, 7, 8, 8, 8, 8]
const FF_COST_BATTLE := [0, 8, 12, 14, 15, 16]
const FF_TELE_STELLAR := 8
const FF_TELE_BATTLE := 16
const FF_BREAKOFF_COST := 4

## Regole opzionali (32.0-36.0): chiave -> [nome, descrizione]
const OPTIONS := {
	"riserve": ["StarForce di riserva", "Fino a un terzo delle StarForce può restare in riserva e intervenire in una LiteZulu contesa dal secondo segmento (o dal terzo Tac-turno)."],
	"faker": ["FakerForce", "Una StarForce si può dividere in quattro FakerForce di una sola TeleNave, che il nemico scambia per StarForce vere."],
	"gatelink": ["GateLink", "Catene di StarGate amiche, ognuna entro 20 Lite dalla successiva, per spostamenti sicuri molto lunghi."],
	"continuita": ["Continuità della situazione", "Un combattimento non risolto prosegue nel turno seguente invece di finire con una ritirata obbligata."],
	"fatica": ["Fatica degli equipaggi", "Due turni di fila in modo battaglia rallentano la StarForce; al quarto resta neutralizzata."],
}

## Randomizzatore stellare: 43 chit [numero in alto, zulu in basso]
static func stellar_chits() -> Array:
	var out := []
	for n in range(1, 21):
		out.append(["%02d" % n, n])
	for n in range(21, 40):
		out.append(["%02d" % n, -(n - 20)])
	out.append(["Dstr", 21])
	out.append(["Dstr", -20])
	out.append(["Dstr", -21])
	out.append(["Brkf", 0])
	return out

## Razze e colori delle pedine
const RACES := {
	"umani": {"nome": "Umani", "agg": "umano"},
	"lcd": {"nome": "L'Chal-Dah", "agg": "L'Chal-Dah"},
	"rame": {"nome": "Rame", "agg": "Rame"},
	"xeno": {"nome": "Xenofobi", "agg": "xenofobo"},
	"psl": {"nome": "Lega Pan-Senziente", "agg": "della Lega"},
}
## Serie di pedine: lettere delle StarForce e numeri delle StarGate stampati
const SETS := {
	"blu": {"lettere": "ABCDEFGHJKLM", "porte": [1, 2, 3, 4, 5, 6, 7, 8], "col": Color("#2a9fd8"), "inchiostro": Color("#ffffff")},
	"verde": {"lettere": "NPQRSTUVWXYZ", "porte": [9, 10, 11, 12, 13, 14, 15, 16], "col": Color("#567f3f"), "inchiostro": Color("#f6b81c")},
	"grigio": {"lettere": "ABCDEFGHJKLM", "porte": [1, 2, 3, 4, 5, 6, 7, 8], "col": Color("#4e5649"), "inchiostro": Color("#ffffff")},
	"ocra": {"lettere": "NPQRSTUVWXYZ", "porte": [9, 10, 11, 12, 13, 14, 15, 16], "col": Color("#7d6a2c"), "inchiostro": Color("#f6b81c")},
}

## Scenari. sistemi: [esagono, StarForce, razza facoltativa]; porta = false se il sistema non ha StarGate.
## vc = condizione di vittoria (vedi motore), formato consigliato: "base", "modificato", "avanzato".
const SCENARIOS := [
	{
		"id": 1, "nome": "La campagna di Alpha Centauri", "anno": "2341 d.C.",
		"orig": "The Alpha Centauri Campaign",
		"intro": "La colonia di Alpha Centauri ha proclamato l'indipendenza. Sol manda le sue StarForce a neutralizzare la StarGate ribelle: la prima guerra interstellare umana durò meno di un giorno.",
		"lati": [
			{"nome": "Egemonia Solare", "razza": "umani", "set": "blu", "sistemi": [["2020", 4]]},
			{"nome": "Alpha Centauri", "razza": "umani", "set": "verde", "sistemi": [["1821", 1]]},
		],
		"vc": "s1", "formato": "avanzato", "turni_max": 8,
		"vittoria": ["Sol vince se neutralizza in modo permanente la StarGate di Alpha Centauri entro 4 Tac-turni (o segmenti di combattimento) dal primo ingresso nel combattimento.", "Altrimenti vince Alpha Centauri."],
		"note": "Scenario di apprendimento, non bilanciato.",
	},
	{
		"id": 2, "nome": "La campagna di Epsilon Eridani", "anno": "2405 d.C.",
		"orig": "The Epsilon Eridani Campaign",
		"intro": "Epsilon Eridani si stacca dall'Egemonia Solare e cerca di impadronirsi del sistema abitabile di Epsilon Indi, appena raggiungibile.",
		"lati": [
			{"nome": "Egemonia Solare", "razza": "umani", "set": "blu", "sistemi": [["2020", 4]]},
			{"nome": "Epsilon Eridani", "razza": "umani", "set": "verde", "sistemi": [["2713", 3]], "spostamento_libero": true},
		],
		"vc": "s2", "formato": "base", "obiettivo": "2523",
		"vittoria": ["Vince chi occupa Epsilon Indi (2523/-10) all'inizio e alla fine di due turni stellari consecutivi, oppure neutralizza in modo permanente la StarGate nemica (che ha la precedenza)."],
		"note": "Epsilon Eridani fa uno spostamento libero prima del primo turno.",
	},
	{
		"id": 3, "nome": "L'ascesa della Lega Umana", "anno": "2415 d.C.",
		"orig": "The Rise of the Human League",
		"intro": "Crollata l'Egemonia Solare, nasce l'Egemonia Pan-Umana (EPU), ancora legata a Sol. La Lega Umana, più vicina alla frontiera, la sfida impadronendosi di Epsilon Indi (senza StarGate).",
		"lati": [
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 5], ["1821", 3]]},
			{"nome": "Lega Umana", "razza": "umani", "set": "verde", "sistemi": [["3015", 3], ["2713", 2], ["3009", 2]], "spostamento_libero": true},
		],
		"vc": "s3", "formato": "avanzato", "obiettivo": "2523",
		"vittoria": ["L'EPU vince neutralizzando due StarGate nemiche, oppure rioccupando Epsilon Indi e neutralizzandone una.", "La Lega Umana vince neutralizzando la StarGate di Sol o di Alpha Centauri.", "Se accade nello stesso turno vince la Lega Umana."],
		"note": "La Lega Umana fa uno spostamento libero prima del primo turno.",
	},
	{
		"id": 4, "nome": "La resa dei conti EPU - Lega Umana", "anno": "2430 d.C.",
		"orig": "PHH - HL Showdown",
		"intro": "Centralizzazione su Sol contro indipendenza e terraformazione: le due fazioni umane sono in equilibrio quando arriva la rottura finale. I sistemi vengono assegnati a sorte.",
		"lati": [
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": []},
			{"nome": "Lega Umana", "razza": "umani", "set": "verde", "sistemi": []},
		],
		"sorteggio": [["2020", 5], ["1821", 3], ["3015", 3], ["2713", 3], ["2523", 1], ["3009", 2], ["2427", 1]],
		"vc": "conta", "formato": "avanzato",
		"vittoria": ["Chi inizia con più StarForce deve neutralizzare due StarGate nemiche; l'altro ne basta una.", "A parità vince il primo che ne neutralizza due."],
		"note": "Ogni sistema va a un lato con una pesca di chit (pari o dispari).",
	},
	{
		"id": 5, "nome": "Il contatto con i L'Chal-Dah", "anno": "2451 d.C.",
		"orig": "L'Chal-Dah Contact",
		"intro": "Il primo contatto: una piccola flotta L'Chal-Dah da Sigma Draconis incappa in Eta Cassiopeiae, la colonia umana più vicina, difesa solo dalla sua StarGate.",
		"lati": [
			{"nome": "Umani", "razza": "umani", "set": "blu", "sistemi": [["2020", 2], ["1821", 1], ["3015", 1], ["2713", 1], ["3009", 0], ["2523", 1], ["3018", 0], ["2427", 0]]},
			{"nome": "L'Chal-Dah", "razza": "lcd", "set": "ocra", "sistemi": [["2326", 2], ["2626", 0], ["3223", 1]], "extra": [["3018/+15", 2]]},
		],
		"vc": "s5", "formato": "avanzato",
		"vittoria": ["Gli Umani vincono neutralizzando tutte le StarGate nemiche.", "I L'Chal-Dah vincono neutralizzando la StarGate di Sol o altre due StarGate umane."],
		"note": "Si comincia con un combattimento tattico a Eta Cassiopeiae.",
	},
	{
		"id": 6, "nome": "La seconda guerra EPU - Lega Umana", "anno": "2462 d.C.",
		"orig": "Second PHH - HL War",
		"intro": "La causa del conflitto non era risolta: le due parti si sono rafforzate e quando le ostilità riprendono gli schieramenti sono più netti.",
		"lati": [
			{"nome": "Lega Umana", "razza": "umani", "set": "verde", "sistemi": [["3015", 3], ["2713", 2]]},
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 4], ["1821", 2]]},
		],
		"sorteggio": [["3009", 2], ["2427", 2], ["2523", 1]],
		"vc": "conta", "formato": "avanzato",
		"vittoria": ["Chi inizia con più StarForce deve neutralizzare due StarGate nemiche; l'altro ne basta una.", "A parità vince il primo che ne neutralizza due."],
		"note": "I tre sistemi di fedeltà incerta vengono assegnati a sorte.",
	},
	{
		"id": 7, "nome": "La rivolta di Epsilon Indi", "anno": "2465 d.C.",
		"orig": "Revolt of Epsilon Indi",
		"intro": "Epsilon Indi si ribella all'EPU con l'appoggio della vecchia Lega Umana; Epsilon Eridani, battuta due volte, cambia campo. I L'Chal-Dah restano neutrali, pronti a schierarsi con chi vince.",
		"lati": [
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 4], ["1821", 2], ["2713", 1]]},
			{"nome": "Epsilon Indi", "razza": "umani", "set": "verde", "sistemi": [["2523", 2], ["3015", 2], ["2427", 2], ["3009", 1]]},
		],
		"rinforzi_lcd": [["2326", 2], ["2626", 1], ["3223", 1]],
		"vc": "s7", "formato": "avanzato",
		"vittoria": ["L'EPU vince neutralizzando la StarGate di Epsilon Indi o altre due StarGate nemiche.", "Epsilon Indi vince neutralizzando la StarGate di Sol o altre due StarGate nemiche."],
		"note": "Il primo che neutralizza una StarGate nemica riceve dal turno seguente le forze dei L'Chal-Dah.",
	},
	{
		"id": 8, "nome": "La guerra con i Rame", "anno": "2476 d.C.",
		"orig": "The War with the Rame",
		"intro": "Assorbiti i L'Chal-Dah come associati, la Lega Umana entra in contatto con una terza razza ancora più aliena, i Rame di 70 Ophiuchi, e tenta di sottometterla.",
		"lati": [
			{"nome": "Rame", "razza": "rame", "set": "verde", "sistemi": [["2036", 6], ["1636", 0], ["2833", 0]]},
			{"nome": "Lega Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 6], ["1821", 0], ["2326", 4, "lcd"], ["2626", 0, "lcd"]]},
		],
		"vc": "s8", "formato": "avanzato", "turni_max": 20,
		"vittoria": ["La Lega Umana vince neutralizzando tutte le StarGate dei Rame senza perdere quelle di Sol e di Sigma Draconis.", "I Rame vincono resistendo per 20 turni stellari."],
		"note": "Regole di cooperazione fra razze diverse (27.4).",
	},
	{
		"id": 9, "nome": "L'espansione dei L'Chal-Dah", "anno": "2480 d.C.",
		"orig": "L'Chal-Dah Expansion",
		"intro": "I L'Chal-Dah proseguono la loro politica di espansione cercando di rafforzarsi a spese dei Rame.",
		"lati": [
			{"nome": "L'Chal-Dah", "razza": "lcd", "set": "ocra", "sistemi": [["2326", 3], ["2626", 1], ["3223", 3]], "spostamento_libero": true},
			{"nome": "Rame", "razza": "rame", "set": "verde", "sistemi": [["2036", 3], ["1636", 1], ["2833", 1]]},
		],
		"vc": "casa_o_due", "formato": "avanzato",
		"vittoria": ["Vince il primo che neutralizza la StarGate del sistema natale nemico o altre due StarGate nemiche."],
		"note": "I L'Chal-Dah fanno uno spostamento libero prima del primo turno.",
	},
	{
		"id": 10, "nome": "La guerra della Lega di Difesa", "anno": "2482 d.C.",
		"orig": "War of the Defense League",
		"intro": "Sconfitti i Rame, i L'Chal-Dah formano con loro la Lega di Difesa, rinunciano allo status di associati dell'EPU e puntano a liberarsi dell'influenza umana.",
		"lati": [
			{"nome": "Lega di Difesa", "razza": "lcd", "set": "ocra", "sistemi": [["2036", 1, "rame"], ["1636", 1, "rame"], ["2833", 1, "rame"], ["2326", 2], ["2626", 1], ["3223", 1]]},
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 5], ["1821", 3], ["2713", 2]]},
		],
		"vc": "s10", "formato": "avanzato", "turni_max": 20,
		"vittoria": ["L'EPU vince neutralizzando le StarGate di Sigma Draconis e 70 Ophiuchi o altre quattro StarGate nemiche.", "La Lega di Difesa vince neutralizzando la StarGate di Sol o impedendo la vittoria dell'EPU per 20 turni."],
		"note": "L'Chal-Dah e Rame non possono aiutarsi negli spostamenti, ma combattono insieme.",
	},
	{
		"id": 11, "nome": "La guerra per l'identità", "anno": "2487 d.C.",
		"orig": "The War for Identity",
		"intro": "La Lega Umana con i suoi associati crolla: nascono la Lega Pan-Senziente (libertà per tutti i senzienti biologici e cibernetici), una Lega Umana ridotta e un'EPU risorta. Tre giocatori.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "lcd", "set": "ocra", "sistemi": [["2326", 4], ["3223", 0], ["2626", 0], ["2036", 3, "rame"], ["1636", 0, "rame"], ["2833", 0, "rame"]], "casa": ["2326", "2036"]},
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 3], ["2523", 2], ["1821", 2], ["3018", 1]], "casa": ["2020"]},
			{"nome": "Lega Umana", "razza": "umani", "set": "verde", "sistemi": [["3015", 2], ["2713", 2], ["3009", 2], ["2427", 1]], "casa": ["3015"]},
		],
		"vc": "ultimo", "formato": "modificato",
		"vittoria": ["Un giocatore perde quando gli vengono neutralizzate due StarGate coloniali o quella del sistema natale (per la Lega Umana è Tau Ceti).", "Vince l'ultimo giocatore che non ha perso."],
		"note": "Gioco base con il randomizzatore stellare. Le forze di razze diverse combattono insieme ma non si aiutano negli spostamenti.",
	},
	{
		"id": 21, "nome": "La guerra per l'identità (a due)", "anno": "2487 d.C.",
		"orig": "The War for Identity, Two-Player Version",
		"intro": "Versione a due giocatori dello scenario 11: la Lega Umana è indecisa e divisa in fazioni. Ogni turno i due giocatori pescano un chit politico: chi arriva per primo a 23 punti la convince a unirsi alla sua causa.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "lcd", "set": "ocra", "sistemi": [["2326", 4], ["3223", 0], ["2626", 0], ["2036", 3, "rame"], ["1636", 0, "rame"], ["2833", 0, "rame"]], "casa": ["2326", "2036"]},
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 3], ["2523", 2], ["1821", 2], ["3018", 1]], "casa": ["2020"]},
			{"nome": "Lega Umana", "razza": "umani", "set": "verde", "sistemi": [["3015", 2], ["2713", 2], ["3009", 2], ["2427", 1]], "casa": ["3015"], "inattivo": true, "neutrale": true},
		],
		"giocatori": 2, "politica": 23,
		"vc": "ultimo", "formato": "modificato",
		"vittoria": ["Come nello scenario 11: un giocatore perde quando gli vengono neutralizzate due StarGate coloniali o quella del sistema natale; vince l'altro.", "La Lega Umana non conta finché non si schiera: chi la convince ne comanda le forze dal turno seguente."],
		"note": "Chi perde una StarGate coloniale prima che la Lega Umana si schieri salta la pesca politica del turno seguente.",
	},
	{
		"id": 12, "nome": "La guerra per la Lega", "anno": "2505 d.C.",
		"orig": "The War for the League",
		"intro": "L'EPU torna al potere in due sistemi; Rame e L'Chal-Dah escono dalla Lega Pan-Senziente. Le tre parti si contendono la nuova colonia di Delta Pavonis, che non ha ancora la sua StarGate.",
		"lati": [
			{"nome": "Rame", "razza": "rame", "set": "verde", "sistemi": [["2036", 4], ["1636", 0], ["2833", 0]], "casa": ["2036"]},
			{"nome": "L'Chal-Dah", "razza": "lcd", "set": "ocra", "sistemi": [["2326", 4], ["3223", 0], ["2626", 0]], "casa": ["2326"]},
			{"nome": "Egemonia Pan-Umana", "razza": "umani", "set": "blu", "sistemi": [["2020", 5], ["2523", 0]], "casa": ["2020"]},
		],
		"vc": "s12", "formato": "modificato", "obiettivo": "2427",
		"vittoria": ["Perde chi si vede neutralizzare la StarGate del sistema natale.", "Vince chi controlla da solo Delta Pavonis (2427/-18) per quattro turni stellari consecutivi."],
		"note": "Gioco base con il randomizzatore stellare.",
	},
	{
		"id": 13, "nome": "La prima incursione xenofoba", "anno": "2775 d.C.",
		"orig": "The First Xenophobe Incursion",
		"intro": "Dopo due secoli e mezzo di pace la sfera della Lega Pan-Senziente viene invasa dagli Xenofobi, che fanno esplodere le stelle in nova per incenerire i pianeti. La Lega deve trovare le loro StarGate ai margini del Volume conosciuto.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu", "tutti_i_sistemi": 6, "rinforzi": 12, "esclusi": ["1511", "1812", "2734"]},
			{"nome": "Xenofobi", "razza": "xeno", "set": "grigio", "xeno_porte": 3, "xeno_sf": 12},
		],
		"vc": "xeno", "formato": "modificato", "xeno": 1,
		"vittoria": ["La partita finisce quando tutte le StarGate xenofobe sono distrutte o tutti i sistemi natali della Lega (Sol, Sigma Draconis, 70 Ophiuchi) sono esplosi in nova: vince chi ha più punti.", "Xenofobi: 20 punti per sistema natale distrutto, 10 per secondario, 3 per terziario, 5 per StarForce della Lega distrutta.", "Lega: 25 punti per StarGate xenofoba neutralizzata, 1 per StarForce xenofoba distrutta.", "Gli Xenofobi vincono subito se distruggono tutti i sistemi natali; perdono se restano 15 turni senza attaccare una StarGate."],
		"note": "Movimento nascosto, spazio ignoto, attacco a sorpresa e induzione delle nova (regole 31.0).",
	},
	{
		"id": 14, "nome": "La seconda incursione xenofoba", "anno": "2785 d.C.",
		"orig": "The Second Xenophobe Incursion",
		"intro": "Respinta la prima incursione, la Lega ha perso trenta miliardi di senzienti e ha meno Telestetiche. Dieci anni dopo gli Xenofobi tornano.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu", "tutti_i_sistemi": 4, "rinforzi": 8, "esclusi": ["1511", "1812", "2734", "2036", "2626", "3018", "1521", "1532", "2026", "2228", "2623"]},
			{"nome": "Xenofobi", "razza": "xeno", "set": "grigio", "xeno_porte": 2, "xeno_sf": 8},
		],
		"vc": "xeno", "formato": "modificato", "xeno": 2,
		"vittoria": ["Come nella prima incursione: vince chi ha più punti quando le StarGate xenofobe sono distrutte o i sistemi natali della Lega sono esplosi.", "Non c'è attacco a sorpresa: gli Xenofobi hanno cinque turni preliminari e cinque turni ufficiali per arrivare vicino a una StarGate della Lega."],
		"note": "70 Ophiuchi, 61 Cygni, Eta Cassiopeiae e altri cinque sistemi sono stati distrutti nella prima incursione.",
	},
	{
		"id": 15, "nome": "La terza incursione xenofoba", "anno": "2946 d.C.",
		"orig": "The Third Xenophobe Incursion",
		"intro": "Sedici decenni di pace hanno addormentato la Lega Pan-Senziente. Gli Xenofobi, che si credevano confinati sui loro pianeti, sfondano il blocco e tentano l'ultimo colpo. I Wanderers, che non li hanno mai combattuti, esitano finché una stella della Lega non esplode.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu", "tutti_i_sistemi": 2, "rinforzi": 6, "esclusi": ["1511", "1812", "2734"]},
			{"nome": "Xenofobi", "razza": "xeno", "set": "grigio", "xeno_porte": 2, "xeno_sf": 6},
		],
		"stelle_extra": [["2223", 8, "h", "Wandering's End"]],
		"case_lega": [2020, 2326, 2036, 2223],
		"vc": "xeno", "formato": "modificato", "xeno": 2,
		"vittoria": ["Xenofobi: 50 punti per sistema natale della Lega distrutto, 30 per secondario, 5 per terziario, 1 per StarForce della Lega distrutta.", "Lega: 80 punti per StarGate xenofoba neutralizzata, 10 per StarForce xenofoba distrutta.", "Gli Xenofobi vincono subito se distruggono tutti i sistemi natali (Sol, Sigma Draconis, 70 Ophiuchi, Wandering's End)."],
		"note": "Dal turno 2 la Lega riceve una StarForce ogni turno pari, fino a sei; dopo la prima stella della Lega distrutta ne arrivano altre quattro. Wandering's End (2223/+8) è il sistema natale dei Wanderers.",
	},
	{
		"id": 16, "nome": "La guerra delle FakerForce", "anno": "2981 d.C.",
		"orig": "The FakerWar",
		"intro": "Umani, L'Chal-Dah e Rame si contendono il Congresso della Lega. I comandanti dividono le StarForce in FakerForce e manovrano per intimidire i neutrali, soprattutto i Wanderers. Tre giocatori.",
		"lati": [
			{"nome": "Umani", "razza": "umani", "set": "blu", "sistemi": [["2020", 4], ["1821", 0], ["3015", 0], ["2523", 0], ["2713", 0], ["3009", 0], ["2427", 0]], "casa": ["2020"]},
			{"nome": "L'Chal-Dah", "razza": "lcd", "set": "ocra", "sistemi": [["2326", 4], ["2626", 0], ["3223", 0], ["3018", 0]], "casa": ["2326"]},
			{"nome": "Rame", "razza": "rame", "set": "verde", "sistemi": [["2036", 4], ["2833", 0], ["1636", 0], ["0732", 0]], "casa": ["2036"]},
		],
		"stelle_extra": [["2223", 8, "h", "Wandering's End"]],
		"opzioni": ["faker"], "tutte_faker": true,
		"vc": "s16", "formato": "modificato", "turni_max": 40,
		"vittoria": ["Vince il primo che tiene FakerForce in otto sistemi terziari non contesi per due turni di fila.", "Oppure il primo che ha otto FakerForce a Wandering's End (2223/+8) senza FakerForce nemiche."],
		"note": "Tutte le StarForce si dividono subito in FakerForce, che non possono assaltare le StarGate. La prima volta che una FakerForce entra in un sistema altrui si pesca un chit: con 8 o 9 la StarGate locale la scambia per un attacco e la randomizza.",
	},
	{
		"id": 17, "nome": "La disputa con i RxPexy", "anno": "3010 d.C.",
		"orig": "RxPexy Dispute",
		"intro": "Respinti dalla Lega Pan-Senziente, i RxPexy (alberi d'arancio che camminano, secondo il primo umano che li vide) cercano di cacciare i coloni della Lega dal loro spazio, e poi attaccano.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu", "tutti_i_sistemi": 16, "esclusi": [], "casuali": 4},
			{"nome": "RxPexy", "razza": "rxpexy", "set": "ocra", "casuali_vicino": 6, "sf_casuali": 8},
		],
		"stelle_extra": [["2223", 8, "h", "Wandering's End"]],
		"esteso": true,
		"vc": "punti", "formato": "avanzato", "turni_max": 30,
		"punti": {"0": {"porta": 10}, "1": {"casuale": 10, "t": 5, "s": 15, "h": 15}},
		"vittoria": ["Lega: 10 punti per StarGate RxPexy neutralizzata.", "RxPexy: 10 punti per StarGate della Lega nei sistemi esterni, 5 per sistema terziario, 15 per sistema secondario o natale.", "Dopo 30 turni (o quando un lato non ha più StarGate) vince chi ha più punti."],
		"note": "I sistemi esterni sono fuori dal Volume conosciuto, tutti dalla stessa parte; il Volume si estende di dieci Lite in altezza.",
	},
	{
		"id": 18, "nome": "La rivoluzione dell'Unione dei Senzienti", "anno": "3175 d.C.",
		"orig": "US Revolution",
		"intro": "I coloni dell'ex spazio xenofobo dichiarano l'indipendenza come Unione dei Senzienti. La Lega lancia una campagna svogliata per riportarli all'ordine, e i RxPexy ne approfittano. Tre giocatori.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu", "tutti_i_sistemi": 18, "esclusi": [], "casuali": 4},
			{"nome": "Unione dei Senzienti", "razza": "us", "set": "verde", "casuali_propri": 6, "sf_casuali": 6},
			{"nome": "RxPexy", "razza": "rxpexy", "set": "ocra", "casuali_vicino": 6, "sf_casuali": 6, "lato_opposto": true},
		],
		"stelle_extra": [["2223", 8, "h", "Wandering's End"]],
		"esteso": true,
		"pace": [[0, 2, 4], [1, 2, 999]],
		"vc": "punti", "formato": "modificato", "turni_max": 40,
		"punti": {"0": {"porta_1": 10, "porta_2": 5}, "1": {"porta": 20, "intatta": 100}, "2": {"t": 10, "casuale": 15, "s": 20, "h": 20}},
		"vittoria": ["Lega: 10 punti per StarGate dell'Unione neutralizzata, 5 per StarGate RxPexy.", "Unione: 100 punti se nessuna sua StarGate è neutralizzata al turno 40, 20 per StarGate della Lega.", "RxPexy: 10 per StarGate terziaria della Lega, 15 per i sistemi esterni, 20 per secondari e natali.", "Al turno 40 vince chi ha più punti."],
		"note": "Lega e RxPexy non si attaccano fino al turno 4; Unione e RxPexy non sono nemici. Lega e Unione sono in guerra dal primo turno.",
	},
	{
		"id": 19, "nome": "La guerra dell'obsolescenza e del tradimento", "anno": "3447 d.C.",
		"orig": "The War of Obsolescence and Treachery",
		"intro": "Uno sciopero dei Gnostech paralizza la Lega. I RxPexy ne approfittano e attaccano con i loro vecchi incrociatori a tachioni: lenti, fragili e pericolosi. Dopo qualche giorno i Gnostech tornano al lavoro.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu", "tutti_i_sistemi": 24, "esclusi": [], "casuali": 4, "casuali_extra": 6, "inattivo": true},
			{"nome": "RxPexy", "razza": "rxpexy", "set": "ocra", "casuali_vicino": 6, "sf_casuali": 5, "tachioni": true},
		],
		"stelle_extra": [["2223", 8, "h", "Wandering's End"]],
		"esteso": true,
		"vc": "punti", "formato": "modificato", "turni_max": 20,
		"punti": {"0": {"porta": 10, "intatta_sistemi": 40}, "1": {"t": 15, "casuale": 15, "s": 25, "h": 25}},
		"vittoria": ["Lega: 40 punti se al turno 20 nessun suo sistema è occupato, 10 per StarGate RxPexy neutralizzata.", "RxPexy: 15 punti per StarGate terziaria o esterna neutralizzata, 25 per secondarie e natali.", "Al turno 20 vince chi ha più punti."],
		"note": "La Lega è ferma: alla fine di ogni turno si pesca un chit e con il 9 le sue forze si attivano. Gli incrociatori a tachioni si muovono di due Lite per turno, non hanno difesa, e neutralizzano per sempre una StarGate inattiva entrando nella sua LiteZulu.",
	},
	{
		"id": 20, "nome": "Operazione Cartagine", "anno": "2947 d.C.",
		"orig": "Operation Carthage",
		"intro": "Sconfitta la terza incursione, una squadra della Lega salta sul sistema natale xenofobo. Una flotta di trasporto xenofoba sta fuggendo verso un rifugio segreto: bisogna neutralizzare la StarGate e far esplodere la stella prima che il trasporto lasci il display.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu"},
			{"nome": "Xenofobi", "razza": "xeno", "set": "grigio"},
		],
		"solitario": true, "solo_umano": 0, "esteso": true,
		"stelle_extra": [["2008", 20, "h", "Mondo natale xenofobo"]],
		"vc": "cartagine", "formato": "avanzato", "formati": ["avanzato"],
		"vittoria": ["Vinci se la stella esplode in nova prima che il trasporto xenofobo esca dal Tactical Display.", "Per la nova: StarGate disgregata o neutralizzata, poi una tua StarForce in modo stellare passa un intero Tac-turno nel MiniLite della stella (000/-1) a piantare l'innesco; la stella esplode nel Tac-turno seguente."],
		"note": "Solitario sul Tactical Display. La tabella delle risposte xenofobe dell'articolo originale non è nel materiale disponibile: il trasporto parte vicino al centro e dal secondo Tac-turno, ogni volta, ha due probabilità su dieci di ritirarsi dal display; la StarGate spara sulle tue StarForce più vicine.",
	},
	{
		"id": 38, "nome": "La missione di soccorso", "anno": "2776 d.C.",
		"orig": "The Rescue Mission (solitario)",
		"intro": "Un innesco difettoso ha destabilizzato la stella di un sistema abitato: la nova arriverà fra non più di dieci giorni. Dodici StarForce devono portare via i venti milioni di umani rimasti sul pianeta.",
		"lati": [
			{"nome": "Lega Pan-Senziente", "razza": "psl", "set": "blu", "sistemi": []},
		],
		"vc": "soccorso", "formato": "base", "solitario": true,
		"vittoria": ["Ogni punto popolazione salvato vale un punto; ogni StarForce perduta ne toglie tre.", "60 punti: vittoria decisiva; 50-59 sostanziale; 40-49 marginale; meno di 40 sconfitta."],
		"note": "Caricare richiede di iniziare e finire il turno nella LiteZulu della stella in pericolo; scaricare, nella LiteZulu di un altro sistema.",
	},
]

static func scenario(id: int) -> Dictionary:
	for s in SCENARIOS:
		if int(s["id"]) == id:
			return s
	return SCENARIOS[0]
