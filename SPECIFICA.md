# Specifica del formato QR — Libretto Digitale Immersioni (LDI) v2

> **Stato:** **VERSIONE 2** dei dati del 23/11/2026. Nasce dalle richieste di un diving che usa il programma:
> nella stessa uscita c'è chi va con la guida e chi in coppia per conto suo, il tipo «tecnica», la profondità
> programmata di ciascuno, il responsabile del primo soccorso. Le differenze sono riassunte nel paragrafo 4.9.
> La **versione 1** (22/11/2026) resta valida: i verificatori leggono tutte e due. Il prefisso `LDI1:` e il formato
> del pacchetto non cambiano: cambia solo il numero `v` dentro i dati.
> Storia della v1: bozza 5 (19/11/2026) identità dell'emittente con il **codice di controllo**, file `ldi.json` come possibilità
> futura, esiti in tre colori; bozza 4 libretto di annullamento (`ann`) e brevetto facoltativo per `mot = pro`;
> bozza 3 motivi `pro` e `acc`.
> **Nome dello standard:** «LDI – Libretto Digitale Immersioni», prefisso `LDI1:`.
> **Licenze:** testo CC BY 4.0 (libero citando la fonte), codice della libreria MIT.
> **Repository pubblico:** https://github.com/sgambaroapps/ldi — pagina di verifica: https://sgambaroapps.github.io/ldi/

## 1. A cosa serve

Un diving o un'associazione sportiva (l'**emittente**) consegna a ogni partecipante una scheda dell'immersione con un QR code.
Il QR contiene **tutti i dati** dell'immersione di quel partecipante e una **firma digitale** dell'emittente, così:

- chiunque può **leggere** i dati (non sono cifrati: sono del partecipante);
- chiunque può **verificare** che non siano stati modificati dopo l'emissione;
- chi conosce la chiave pubblica dell'emittente sa anche **chi** l'ha emessa;
- tutto funziona **senza internet** (internet serve solo per il controllo facoltativo dell'identità dell'emittente).

Programmi che lo useranno da subito: *Nautilus - Registro Immersioni* (emette), la pagina web di verifica e *Nautilus - DiveKit* (verificano e importano).

## 2. Due tipi di QR

| Tipo | Codice `t` | Dove si stampa | Contenuto |
|---|---|---|---|
| **Libretto individuale** | `lib` | scheda del singolo partecipante | tutti i dati dell'immersione + i dati di quel partecipante |
| **Riepilogo immersione** | `reg` | logbook cumulativo (documento interno dell'emittente) | dati dell'immersione + elenco dei nomi dei partecipanti |

## 3. Come è fatto il QR (in sintesi)

```
testo del QR = "LDI1:" + Base45( zlib( pacchetto ) )

pacchetto  = [1 byte: versione = 1]
           + [32 byte: chiave pubblica Ed25519 dell'emittente]
           + [64 byte: firma Ed25519]
           + [N byte: dati, cioè JSON in UTF-8]

firma      = Ed25519( chiave privata, "LDI1" + dati )
```

Passo per passo, per chi emette:

1. Si scrivono i **dati** come JSON compatto (senza spazi), in UTF-8 (paragrafo 4).
2. Si firma la sequenza di byte `"LDI1"` seguita dai dati, con la chiave privata Ed25519 (RFC 8032).
3. Si compone il **pacchetto**: versione, chiave pubblica, firma, dati.
4. Si comprime il pacchetto con **zlib** (RFC 1950).
5. Si codifica in **Base45** (RFC 9285): usa solo caratteri che il QR memorizza in modo compatto (modalità alfanumerica).
6. Si mette davanti il prefisso **`LDI1:`** (serve a riconoscere subito il formato e la versione).
7. Si genera il QR con correzione d'errore **M** (oppure **H** se c'è il logo al centro).

Per chi verifica si fa il percorso al contrario (paragrafo 7).

**Perché così:** è lo stesso schema del Green Pass europeo (prefisso + Base45 + zlib + firma), già collaudato su miliardi di QR;
il JSON invece del formato binario CBOR rende lo standard molto più semplice da adottare per altri programmatori.
La firma è calcolata sui **byte esatti** dei dati, quindi non serve nessuna regola di «normalizzazione» del JSON.

## 4. I dati (JSON)

Nomi dei campi brevi per tenere piccolo il QR. Tutte le misure sono **metriche** (metri). Le date seguono ISO 8601.
Gli orari portano il **fuso orario** (es. `+01:00`), così l'immersione è univoca anche all'estero.

### 4.1 Campi comuni ai due tipi

| Campo | Obbl. | Tipo | Significato | Esempio |
|---|---|---|---|---|
| `t` | sì | testo | tipo: `lib` o `reg` | `"lib"` |
| `v` | sì | numero | versione dei dati: `2`; i documenti emessi con la v1 hanno `1` e restano validi (4.9) | `2` |
| `imm` | sì | testo | codice univoco dell'immersione (16 caratteri casuali Base64url), uguale per tutti i partecipanti | `"Qm9wZ3Rx2kLc8sVw"` |
| `em` | sì | data-ora | momento dell'emissione | `"2026-11-18T12:41+01:00"` |
| `c` | sì | oggetto | emittente (4.2) | |
| `ini` | sì | data-ora | inizio immersione (orario di partenza, L. 70/2026 art. 12 c. 3) | `"2026-11-18T09:35+01:00"` |
| `fin` | sì | data-ora | fine immersione (art. 12 c. 4) | `"2026-11-18T10:22+01:00"` |
| `l` | sì | oggetto | luogo (4.3) | |
| `g` | sì | lista | guide/istruttori dell'immersione (4.4). v2: può essere vuota (nessuno va con una guida). v1: almeno uno, quello con `r:1` è il responsabile | |
| `pp` | sì | numero | profondità massima **pianificata**, metri; nel libretto è quella **del partecipante** | `30` |
| `pr` | sì | numero | profondità massima **raggiunta**, metri (1 decimale); nel libretto è quella **del partecipante** | `28.4` |
| `x` | no | oggetto | estensioni libere di altri programmi: chi non le conosce le ignora | |

### 4.2 Emittente `c`

| Campo | Obbl. | Significato |
|---|---|---|
| `n` | sì | ragione sociale / nome |
| `tipo` | sì | `D` = diving (attività commerciale), `A` = associazione/club |
| `ind` | sì | indirizzo in una riga |
| `piva` | no | partita IVA o codice fiscale dell'ente |
| `dom` | no | dominio del sito dove è pubblicata la chiave (paragrafo 6), es. `divingportofinoblu.example` |

### 4.3 Luogo `l`

| Campo | Obbl. | Significato |
|---|---|---|
| `n` | sì | nome del punto d'immersione |
| `lat`, `lon` | no | coordinate in gradi decimali, 5 decimali (≈ 1 m) |

### 4.4 Guida/istruttore (elementi della lista `g`)

| Campo | Obbl. | Significato |
|---|---|---|
| `n` | sì | nome e cognome |
| `br` | no | qualifica (es. «Istruttore 2*», «Guida») |
| `e` | no | ente/didattica (es. CMAS, PADI, SSI, FIPSAS) |
| `r` | no | **solo v1:** `1` = responsabile dell'immersione (art. 12 c. 3); uno solo. In v2 non si usa: il responsabile sta nel riepilogo (`ru`, 4.6) |

### 4.5 Solo libretto individuale (`t = "lib"`)

| Campo | Obbl. | Tipo | Significato | Esempio |
|---|---|---|---|---|
| `id` | sì | testo | codice univoco di questa scheda (16 caratteri Base64url) | `"bG9nYm9vazAwMDE"` |
| `rev` | sì | numero | revisione: 1 alla prima emissione, poi 2, 3… se corretta | `1` |
| `sost` | no | testo | `id` della scheda che questa sostituisce | |
| `s` | sì | oggetto | partecipante: `n` nome e cognome, `dn` data di nascita, `br` brevetto, `e` ente, `nb` numero brevetto (facoltativo). `br` ed `e` possono mancare solo se `mot = pro` (prova / battesimo: chi non ha ancora un brevetto) | |
| `mot` | sì | testo | motivo: `ric` ricreativa, `cor` corso, `tec` tecnica (solo v2), `soc` attività sociale, `pro` prova / battesimo, `acc` accompagnamento (guida o istruttore che accompagna il gruppo), `alt` altro | `"cor"` |
| `mod` | v2 | testo | **solo v2**, obbligatorio tranne che con `mot = acc`: `gui` immersione **guidata** (segue una guida), `org` immersione **organizzata** (il diving dà barca, bombole e assistenza; il sub va in coppia o in terzetto per conto suo) | `"org"` |
| `con` | v2 | lista | **solo v2**, obbligatorio con `mod`: lista di nomi. Con `gui` un solo nome, la guida seguita; con `org` i compagni di coppia o di terzetto (uno o più) | `["Anna Verdi"]` |
| `cor` | no | testo | nome del corso (se `mot = cor`) o descrizione (se `alt`) | `"Advanced Open Water"` |
| `ar` | sì | testo | autorespiratore (tabella 4.7) | `"OC-MONO"` |
| `mx` | sì | testo | miscela (tabella 4.8) | `"EAN32"` |
| `note` | no | testo | note brevi, **massimo 100 caratteri** (le note complete restano sulla stampa) | |
| `ann` | no | testo | **annullamento** (bozza 4): se presente, il documento annulla il libretto indicato in `sost`; il testo è il motivo, massimo 100 caratteri. Gli altri dati sono quelli del libretto annullato, con `rev` successivo | `"Immersione non fatta"` |

**Mai nel QR:** certificato medico, indirizzo, telefono, email del partecipante, allegati.
**Mai nel libretto (v2):** il responsabile dell'uscita e il responsabile del primo soccorso. Servono alle autorità in caso
di controllo e restano nel riepilogo (`reg`) e nei dati dell'emittente; il libretto resta per anni al sub, e i dati
di terzi lì non servono.

### 4.6 Solo riepilogo immersione (`t = "reg"`)

| Campo | Obbl. | Significato |
|---|---|---|
| `p` | sì | lista dei partecipanti, ciascuno `{"n": nome, "id": id della sua scheda}` |
| `np` | sì | numero dei partecipanti (controllo) |
| `ru` | v2 | **solo v2**, obbligatorio: **responsabile dell'uscita** (art. 12 c. 3), `{"n": nome e cognome, "tel": telefono}` (`tel` facoltativo). Può essere una guida, un istruttore o personale che resta in barca |
| `ps` | no | **solo v2**: **responsabile del primo soccorso** dell'uscita, `{"n": nome e cognome, "tel": telefono}` (`tel` facoltativo) |

Il riepilogo non porta date di nascita né brevetti: è un documento interno, il QR serve solo a dimostrare che l'elenco stampato
non è stato modificato. Oltre 15 partecipanti il QR diventa troppo fitto: il programma stampa allora più QR (al massimo 15 nomi ciascuno) (`np` resta il totale,
più il campo `pag`: `"1/2"`, `"2/2"`).

### 4.7 Codici autorespiratore `ar`

| Codice | Significato |
|---|---|
| `OC-MONO` | circuito aperto (ARA), monobombola |
| `OC-BI` | circuito aperto, bibombola |
| `OC-SM` | circuito aperto, sidemount |
| `CCR` | rebreather a circuito chiuso |
| `SCR` | rebreather a circuito semichiuso |
| `ALTRO` | altro (descrivere nelle note) |

### 4.8 Codici miscela `mx`

| Codice | Significato |
|---|---|
| `AIR` | aria |
| `EAN32` | nitrox al 32% di ossigeno (il numero è la % di O₂, da 22 a 99) |
| `TX21/35` | trimix: 21% O₂, 35% elio |
| `O2` | ossigeno puro |

### 4.9 Versione 2 rispetto alla versione 1

| | v1 (22/11/2026) | v2 (23/11/2026) |
|---|---|---|
| `v` | `1` | `2` |
| `g` | almeno una guida, una con `r:1` | anche vuota; `r` **vietato** |
| responsabile dell'immersione | `r:1` dentro `g`, anche nel libretto | solo nel riepilogo: `ru` |
| responsabile del primo soccorso | — | solo nel riepilogo: `ps` |
| `mot` | ric, cor, soc, pro, acc, alt | in più `tec` (tecnica) |
| guidata / organizzata, compagni | — | `mod` e `con` nel libretto |
| `pp` nel libretto | dell'immersione | del partecipante |

Prefisso (`LDI1:`), pacchetto, firma e chiavi sono identici. Chi emette scrive la v2. Chi verifica accetta `v` = 1 e 2 e
applica a ciascuno le sue regole. Un programma che conosce solo la v1 trova `v = 2` e risponde «È un libretto LDI di una
versione più recente: aggiorna il programma», senza importare niente.

## 5. Le chiavi

- Algoritmo **Ed25519** (RFC 8032): chiave privata 32 byte, chiave pubblica 32 byte, firma 64 byte.
- La chiave pubblica viaggia **dentro ogni QR**: la firma si controlla sempre, anche offline.
- **Impronta** (per controlli a occhio, telefonate tra sedi, pagina del sito): i primi 10 byte dello SHA-256 della chiave pubblica,
  in Base32 (RFC 4648, senza `=`), a gruppi di 4 caratteri. Esempio: `MF3K-WXQ2-7HTA-LP4C`.
- Un emittente può avere **più chiavi** (più sedi, cambio di chiave): tutte valide, elencate nel file del paragrafo 6.

## 6. Pubblicazione delle chiavi dell'emittente (possibilità futura)

> **Per ora non si usa** (scelta del 19/11/2026): chi gestisce un diving spesso non gestisce il sito, e una
> pagina web non può comunque leggere i file di un altro sito senza un permesso apposito (CORS). L'identità si conferma
> con il codice di controllo (paragrafo 7, punto 7). Il formato resta qui per il futuro; il campo `c.dom` si scrive
> lo stesso, se il diving ha un sito, ma i verificatori per ora non lo usano.

L'emittente pubblica sul suo sito un file JSON a uno di questi indirizzi (il verificatore prova nell'ordine):

1. `https://<dom>/.well-known/ldi.json`
2. `https://<dom>/ldi.json` (per i siti su piattaforme che non permettono la cartella `.well-known`)

```json
{
  "standard": "LDI",
  "v": 1,
  "n": "Diving Portofino Blu ASD",
  "piva": "01234567890",
  "chiavi": [
    { "k": "<chiave pubblica in Base64url>", "impronta": "MF3K-WXQ2-7HTA-LP4C",
      "sede": "Portofino", "dal": "2026-11-18" },
    { "k": "<…>", "impronta": "PL6D-…", "sede": "Elba", "dal": "2025-03-01", "revocata_dal": "2026-11-18" }
  ]
}
```

Il file lo genera il programma dell'emittente con un pulsante («Esporta file per il sito»): non va scritto a mano.
Il dominio scritto nel QR (`c.dom`) dice al verificatore dove cercare. Un falsario può copiare il nome di un diving,
ma non può caricare file sul suo sito: per questo il dominio è la prova d'identità.

Per gli emittenti senza sito è prevista una lista pubblica di riserva (curata dal progetto, indirizzo da definire),
con lo stesso formato di voce.

## 7. Verifica (per chi legge il QR)

1. Il testo inizia con `LDI1:`? Altrimenti «non è un libretto LDI».
2. Base45 → zlib → pacchetto. Il primo byte è `1`? Altrimenti «versione non supportata».
   (Il primo byte è la versione del **pacchetto**, sempre 1; la versione dei **dati** è il campo `v`: 1 o 2.)
3. Separa chiave pubblica (32 byte), firma (64 byte) e dati.
4. Verifica la firma Ed25519 su `"LDI1" + dati`. Se fallisce → **NON VALIDA** (dati alterati o QR falso).
5. Legge il JSON. `v` più alto di quello che conosce → «versione più recente: aggiorna il programma». Poi controlla
   i campi obbligatori della sua versione (v1 o v2). Se mancano → **NON VALIDA**.
6. Controlli di buon senso (solo avvisi): `fin` dopo `ini`; `em` non nel futuro; `pr` tra 0 e 350 m.
7. Identità dell'emittente: il verificatore mostra il **codice di controllo** della chiave che ha firmato (l'impronta del
   paragrafo 5) e una nota: chi vuole essere certo che sia stato davvero quell'emittente a firmare lo contatta e confronta
   il codice. Il contatto va cercato per conto proprio: il verificatore **non propone** telefoni o indirizzi presi dal QR.
   (L'emittente legge il suo codice nel programma, per esempio in Impostazioni → Sicurezza.)
8. Un verificatore che può ricordare (un'app, come DiveKit) **ricorda** il codice di controllo già visto per ogni emittente
   e avvisa se lo stesso emittente si presenta con un codice mai visto.

Esiti mostrati all'utente:
- **FIRMA VALIDA** (verde): con tutti i dati e il codice di controllo;
- **ANNULLATO** (giallo): firma valida e `ann` presente; mostra il motivo e i dati del libretto annullato;
- **NON VALIDA** (rosso): **nessun dato**, perché potrebbero essere stati alterati; solo la spiegazione.
Gli avvisi del punto 6 si mostrano insieme all'esito, senza cambiarlo.

## 8. Importazione in un logbook (es. Nautilus - DiveKit)

- Si importa solo un QR `lib` con firma valida.
- Il codice `id` evita i doppioni: lo stesso `id` non si importa due volte. Se arriva un `rev` più alto con lo stesso `id`
  o con `sost` uguale all'`id` già importato, si propone di **aggiornare** l'immersione.
- Un documento con `ann` (annullamento) e `sost` uguale all'`id` già importato: l'immersione si **segna come
  annullata**, mostrando il motivo, e si esclude da statistiche e numerazione (Nautilus DiveKit fa così); in alternativa
  si può proporre di toglierla dal logbook. Se il libretto annullato non era stato importato, non si importa niente.
- Chi verifica un annullamento (pagina web) mostra in grande **ANNULLATO** e il motivo.
- I dati firmati restano **in sola lettura** nel logbook; il sub può aggiungere i suoi (voto, foto, note personali).
- v2 con `mod = org`: i nomi di `con` possono riempire il campo «compagno» del logbook, se il sub non l'ha già scritto.
- Si conserva il testo originale del QR, così la verifica si può rifare in qualsiasi momento.

## 9. Dimensioni del QR (misurate il 18/11/2026 con la libreria di riferimento)

Esempio realistico (libretto individuale, due guide, coordinate, note di 40 caratteri): **863 caratteri** nel QR.

| Correzione d'errore | Versione QR | Moduli per lato | Lato minimo consigliato in stampa |
|---|---|---|---|
| M (senza logo) | 19 | 93 | 4 cm |
| H (con logo al centro) | 26 | 121 | 5,5 cm |

Prova di lettura automatica (lettore ZXing, immagine sfocata e rimpicciolita): entrambi letti correttamente
anche a circa 2 pixel per modulo, il logo al centro (22% del lato) non dà problemi con la correzione H.
Le prove con telefoni veri e libretti stampati (novembre 2026, con e senza logo) l'hanno confermato. Chi legge i QR
da un'immagine con lo sfondo trasparente (per esempio una pagina PDF trasformata in PNG) la metta prima su fondo
bianco: molti lettori trattano il trasparente come nero.

Riepilogo con 12 partecipanti: 1.073 caratteri (ogni partecipante costa circa 40 caratteri, per via del codice del suo libretto).

## 10. Esempi di dati

Libretto individuale v2: immersione organizzata, in coppia.

```json
{"t":"lib","v":2,"id":"bG9nYm9vazAwMDI","imm":"Qm9wZ3Rx2kLc8sVw","rev":1,
 "em":"2026-11-23T12:41+01:00",
 "c":{"n":"Diving Portofino Blu ASD","tipo":"A","ind":"Via Roma 12, 16034 Portofino (GE)","piva":"01234567890"},
 "ini":"2026-11-23T09:35+01:00","fin":"2026-11-23T10:22+01:00",
 "l":{"n":"Secca dell'Isuela"},
 "g":[{"n":"Marco Bianchi","br":"Istruttore 2*","e":"CMAS"}],
 "s":{"n":"Mario Rossi","dn":"1978-04-12","br":"Open Water Diver","e":"SSI","nb":"SSI-123456"},
 "mot":"ric","mod":"org","con":["Anna Verdi"],"pp":18,"pr":17.6,"ar":"OC-MONO","mx":"AIR"}
```

Riepilogo v2 (parte nuova): `"ru":{"n":"Luca Neri","tel":"333 1234567"},"ps":{"n":"Luca Neri","tel":"333 1234567"}`.

Libretto individuale v1 (com'era prima del 23/11/2026):

```json
{"t":"lib","v":1,"id":"bG9nYm9vazAwMDE","imm":"Qm9wZ3Rx2kLc8sVw","rev":1,
 "em":"2026-11-18T12:41+01:00",
 "c":{"n":"Diving Portofino Blu ASD","tipo":"A","ind":"Via Roma 12, 16034 Portofino (GE)",
      "piva":"01234567890","dom":"divingportofinoblu.example"},
 "ini":"2026-11-18T09:35+01:00","fin":"2026-11-18T10:22+01:00",
 "l":{"n":"Secca dell'Isuela","lat":44.30312,"lon":9.21455},
 "g":[{"n":"Marco Bianchi","br":"Istruttore 2*","e":"CMAS","r":1},{"n":"Laura Verdi","br":"Guida","e":"PADI"}],
 "s":{"n":"Mario Rossi","dn":"1978-04-12","br":"Open Water Diver","e":"SSI"},
 "mot":"cor","cor":"Advanced Open Water","pp":30,"pr":28.4,"ar":"OC-MONO","mx":"EAN32",
 "note":"Avvistata una cernia bruna e due murene."}
```

(Qui è su più righe per leggerlo; nel QR è su una riga sola, senza spazi.)

## 11. Decisioni (18/11/2026)

1. **Nome:** «LDI – Libretto Digitale Immersioni», prefisso `LDI1:`.
2. **Pubblicazione:** repository **pubblico** separato su GitHub (specifica, libreria di riferimento, esempi di prova):
   https://github.com/sgambaroapps/ldi, dal 22/11/2026.
3. **Licenze:** CC BY 4.0 per il testo, MIT per il codice.
4. **Note nel QR:** massimo 100 caratteri (il programma avvisa mentre si scrive; le note complete restano sulla stampa).
5. **Lista pubblica di riserva** per gli emittenti senza sito: rimandata. Per ora: sito dell'emittente + controllo dell'impronta
   (anche con un QR di presentazione dell'emittente da scansionare di persona). Il formato della voce è già quello del paragrafo 6.
6. **Versione 2 dei dati (23/11/2026):** decisa con Nautilus DiveKit. Il responsabile dell'uscita e quello del primo
   soccorso stanno solo nel riepilogo; guidata/organizzata con i compagni e il tipo «tecnica» nel libretto. Si scrive
   sempre la v2; la v1 resta leggibile.

## 12. Scelte tecniche per la libreria (verificate il 18/11/2026)

| Funzione | Pacchetto | Note |
|---|---|---|
| Firma Ed25519 | `cryptography` 2.9.0 (dint.dev, verificato) | gira in Dart puro su Windows e web; la correttezza si controlla con i vettori di prova ufficiali dell'RFC 8032 nei test |
| Compressione zlib | `archive` 4.7.x (molto attivo) | funziona anche sul web, dove `dart:io` non c'è |
| Base45 | scritto da noi | poche righe, con i vettori di prova dell'RFC 9285 |
| Disegno del QR | `qr` 4.0.1 + disegno nostro | `qr_flutter` è fermo dal 2023 e non è compatibile con `qr` 4 |
