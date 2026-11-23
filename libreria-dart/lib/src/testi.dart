// Piccole codifiche di supporto: Base32 (per l'impronta), Base64url senza "=", identificativi casuali,
// date e orari con il fuso orario.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

const _alfabeto32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// Base32 (RFC 4648) senza il riempimento "=".
String base32Codifica(List<int> byte) {
  final out = StringBuffer();
  var buffer = 0;
  var bit = 0;
  for (final b in byte) {
    buffer = (buffer << 8) | b;
    bit += 8;
    while (bit >= 5) {
      out.write(_alfabeto32[(buffer >> (bit - 5)) & 31]);
      bit -= 5;
    }
    buffer &= (1 << bit) - 1;
  }
  if (bit > 0) out.write(_alfabeto32[(buffer << (5 - bit)) & 31]);
  return out.toString();
}

/// Base64url (RFC 4648 §5) senza "=".
String base64UrlSenzaUguale(List<int> byte) => base64Url.encode(byte).replaceAll('=', '');

/// Decodifica Base64url con o senza "=". Lancia [FormatException] se non è valido.
Uint8List base64UrlDecodifica(String testo) => base64Url.decode(base64Url.normalize(testo));

final _casuale = Random.secure();

/// Nuovo identificativo univoco: 12 byte casuali = 16 caratteri Base64url.
String nuovoIdLdi() => base64UrlSenzaUguale(List<int>.generate(12, (_) => _casuale.nextInt(256)));

/// Un identificativo LDI valido: 16 caratteri Base64url.
final RegExp formatoIdLdi = RegExp(r'^[A-Za-z0-9_-]{16}$');

/// Data e ora con il fuso orario, es. 2026-11-18T09:35+01:00 (secondi facoltativi, oppure "Z").
final RegExp formatoDataOra =
    RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})$');

/// Data semplice, es. 1978-04-12.
final RegExp formatoData = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String _due(int n) => n.toString().padLeft(2, '0');

/// Scrive un orario locale nel formato LDI, con il fuso orario del computer (es. "+01:00").
String dataOraLdi(DateTime t) {
  final l = t.toLocal();
  final off = l.timeZoneOffset;
  final segno = off.isNegative ? '-' : '+';
  final min = off.inMinutes.abs();
  return '${l.year.toString().padLeft(4, '0')}-${_due(l.month)}-${_due(l.day)}'
      'T${_due(l.hour)}:${_due(l.minute)}$segno${_due(min ~/ 60)}:${_due(min % 60)}';
}

/// Scrive una data nel formato LDI (AAAA-MM-GG).
String dataLdi(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${_due(t.month)}-${_due(t.day)}';

/// Legge una data-ora LDI. Restituisce null se il formato non è valido.
DateTime? leggiDataOra(String? s) {
  if (s == null || !formatoDataOra.hasMatch(s)) return null;
  // data reale (niente 31 febbraio) e orario possibile (niente 25:70)
  if (leggiData(s.substring(0, 10)) == null) return null;
  final ora = int.parse(s.substring(11, 13));
  final minuti = int.parse(s.substring(14, 16));
  if (ora > 23 || minuti > 59) return null;
  return DateTime.tryParse(s);
}

/// Legge una data LDI (AAAA-MM-GG) controllando che esista davvero (niente 31 febbraio).
DateTime? leggiData(String? s) {
  if (s == null || !formatoData.hasMatch(s)) return null;
  final d = DateTime.tryParse(s);
  if (d == null || dataLdi(d) != s) return null;
  return d;
}
