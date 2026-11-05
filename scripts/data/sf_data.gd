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
