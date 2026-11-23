# LDI — Libretto Digitale Immersioni

Uno standard aperto per i **QR code firmati dei libretti delle immersioni**. Il diving o l'associazione che organizza
l'immersione consegna a ogni partecipante un libretto con un QR: il QR contiene i dati dell'immersione e una firma
digitale (Ed25519), così chiunque può leggerli e controllare che non siano stati modificati, anche senza internet.

- **Verifica un libretto:** https://sgambaroapps.github.io/ldi/ (fotocamera, foto o PDF; sei lingue; tutto nel browser,
  niente viene inviato).
- **Specifica:** [`SPECIFICA.md`](SPECIFICA.md) — dati versione 2 (23/11/2026; la versione 1 del 22/11/2026 resta leggibile), prefisso `LDI1:`.
- **Libreria di riferimento in Dart:** [`libreria-dart/`](libreria-dart/) — crea, firma, legge e verifica i QR.
- **Kit di prova:** [`libreria-dart/esempi/kit-di-prova/`](libreria-dart/esempi/kit-di-prova/) — 12 QR di esempio con
  dati inventati e chiavi dimostrative, ognuno con l'esito atteso (`esiti.json`), per provare un verificatore.

## Chi lo usa

- [*Nautilus - Registro Immersioni*](https://sgambaroapps.github.io/registroimmersioni/) (programma per Windows): emette i libretti.
- [*Nautilus DiveKit*](https://sgambaroapps.github.io/nautilusdivekit/) (app gratuita per Android e iOS): verifica i libretti e importa le immersioni nel logbook.
- La [pagina di verifica](https://sgambaroapps.github.io/ldi/) di questo repository (`index.html`, `ldi.js`): una versione JavaScript della libreria.

## In breve

```
testo del QR = "LDI1:" + Base45( zlib( [versione][chiave pubblica 32][firma 64][dati JSON] ) )
firma        = Ed25519( chiave privata, "LDI1" + dati )
```

Esiti: **firma valida** (verde), **annullato** (giallo, libretto di annullamento), **non valida** (rosso).
L'identità del diving si conferma con il **codice di controllo** della sua chiave, da confrontare con il diving stesso.

## Licenze

- Testo della specifica: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.it) — libero, citando la fonte.
- Codice (libreria Dart e pagina di verifica): [MIT](LICENSE).
- Le librerie di terzi nella cartella `lib/` hanno le loro licenze: [`lib/LICENZE-TERZI.txt`](lib/LICENZE-TERZI.txt).
