# Kit di prova LDI

QR di esempio per provare chi verifica o importa i libretti LDI (pagina web di verifica, Nautilus - DiveKit).
**Solo dati inventati**, firmati con chiavi **DIMOSTRATIVE** pubbliche (semi dei test 1 e 2 dell'RFC 8032): non vanno
mai usate per libretti veri.

- Chiave 1 («Diving di Esempio ASD»): codice di controllo **EH7D-DX5B-KSRG-CYTL**
- Chiave 2 (stesso nome, chiave diversa, caso 11): **HH3R-HUFG-IQST-6BCS**

## File
- `NN-nome.txt`: il testo esatto del QR (da incollare);
- `NN-nome.png`: il QR pulito;
- `01-libretto-foto.jpg`: il QR 01 ruotato e sfocato, come una foto col telefono;
- `kit-di-prova.pdf`: un foglio A4 con i QR 01, 05 e 07 di 4 cm (come i libretti stampati): devono uscire 3 esiti;
- `esiti.json`: per ogni caso il colore atteso (`verde` firma valida, `giallo` annullato, `rosso` non valida), cosa
  deve mostrare la pagina, cosa deve fare DiveKit, il codice di controllo e il motivo/avvisi dati dalla libreria;
- `*.griglia`: la matrice del QR in 0/1 (serve a rifare le immagini).

| Caso | Colore | In breve |
|---|---|---|
| 01 libretto | verde | corso, due guide, Nitrox 32 |
| 02 libretto-prova | verde | prova / battesimo, senza brevetto |
| 03 riepilogo | verde | riepilogo con 3 partecipanti (DiveKit non lo importa) |
| 04 correzione | verde | rev 2 che sostituisce 01 (DiveKit propone di aggiornare) |
| 05 annullamento | giallo | annulla 04 (DiveKit: resta segnata ANNULLATA) |
| 06 annullamento-sconosciuto | giallo | annulla un libretto mai importato (DiveKit non importa niente) |
| 07 alterato | rosso | profondità cambiata senza rifare la firma |
| 08 danneggiato | rosso | testo tagliato a metà |
| 09 versione-futura | rosso | prefisso `LDI2:` |
| 10 non-ldi | rosso | un QR qualsiasi |
| 11 altra-chiave | verde | stesso diving, codice diverso (DiveKit avvisa) |
| 12 avviso-orari | verde | ora di fine prima dell'inizio: avviso, resta verde |

## Sequenza per DiveKit (logbook vuoto)
1. 01 → importato; si ricorda EH7D-DX5B-KSRG-CYTL.
2. 01 di nuovo → «già importato».
3. 04 → propone di aggiornare la 01 (profondità 26,8 m).
4. 05 → l'immersione resta, segnata ANNULLATA con il motivo, fuori dalle statistiche.
5. 06 → non importa niente.
6. 11 → avviso: codice diverso da quello già visto per «Diving di Esempio ASD».
7. 03 → non si importa (riepilogo).
8. 07, 08, 09, 10 → rosso, non si importa.
Prova anche 05 con solo la 01 importata (senza la 04): va riconosciuta lo stesso.

## Rifare il kit
Nella cartella `packages/ldi`: `dart run example/kit_di_prova.dart esempi/kit-di-prova` (controlla anche che la
libreria dia gli esiti attesi); poi, dalla cartella del programma, `py tools/kit_immagini.py packages/ldi/esempi/kit-di-prova`.
