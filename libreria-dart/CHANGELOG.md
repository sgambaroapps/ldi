## 2.0.0 — 23/11/2026

- Dati LDI **versione 2** (specifica, paragrafo 4.9): si scrive `v: 2`, si leggono la 1 e la 2.
- Libretto: motivo `tec` (tecnica), `mod` guidata/organizzata e `con` (guida seguita o compagni); niente
  responsabile (`r`) e guide anche vuote.
- Riepilogo: `ru` responsabile dell'uscita (obbligatorio) e `ps` responsabile del primo soccorso, con il telefono.
- Nuovi: `LdiDocumento.versione`, `LdiContatto`, `modalitaLdi`; i controlli seguono la versione del documento.

## 1.0.0 — 22/11/2026

- Specifica LDI v1 definitiva, dopo le prove incrociate con la pagina di verifica e Nautilus DiveKit.
- Rispetto alla 0.1.0: libretto di annullamento (campo `ann`), motivi `pro` e `acc`, brevetto facoltativo per
  `mot = pro`, kit di prova in `esempi/kit-di-prova`.

## 0.1.0 — 18/11/2026

- Prima versione: emissione e lettura dei QR LDI v1 (libretto individuale e riepilogo), firma Ed25519,
  Base45, impronta delle chiavi, file pubblico ldi.json e controllo dell'identità dell'emittente.
