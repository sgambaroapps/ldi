# ldi — Libretto Digitale Immersioni

Libreria Dart di riferimento dello standard **LDI**: crea, firma, legge e verifica i QR code
dei libretti delle immersioni. Specifica completa: [`SPECIFICA.md`](../SPECIFICA.md) (repository https://github.com/sgambaroapps/ldi).

```dart
final chiave = await LdiChiave.genera();          // una volta, al primo avvio
final testoQr = await emettiLdi(libretto, chiave); // "LDI1:..." da mettere nel QR

final lettura = await leggiLdi(testoQr);          // chi scansiona
if (lettura.esito == LdiEsito.firmaValida) {
  final dati = lettura.documento as LdiLibretto;
  // facoltativo, se c'è internet: scaricare https://<dominio>/.well-known/ldi.json
  // e chiamare controllaEmittente(lettura, LdiFilePubblico.daTesto(testo))
}
```

- `example/esempio.dart` genera un QR di esempio (con una chiave **dimostrativa** pubblica, mai per libretti veri).
- `esempi/` contiene QR di esempio già pronti (testo, SVG, PNG con e senza logo).
- Test: `dart test` (vettori di prova ufficiali di Base45 RFC 9285 ed Ed25519 RFC 8032 inclusi).

Funziona in Dart puro su Windows, Android, iOS, macOS e web (dipendenze: `cryptography`, `archive`).

Licenza: MIT.
