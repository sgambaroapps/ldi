// Base45 (RFC 9285): la codifica usata anche dal Green Pass europeo.
// Usa solo i 45 caratteri che un QR code memorizza in modalità alfanumerica (la più compatta per il testo).
import 'dart:typed_data';

const _alfabeto = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ \$%*+-./:';

/// Codifica dei byte in Base45.
String base45Codifica(List<int> byte) {
  final out = StringBuffer();
  for (var i = 0; i < byte.length; i += 2) {
    if (i + 1 < byte.length) {
      var n = byte[i] * 256 + byte[i + 1];
      final c = n % 45;
      n ~/= 45;
      final d = n % 45;
      final e = n ~/ 45;
      out
        ..write(_alfabeto[c])
        ..write(_alfabeto[d])
        ..write(_alfabeto[e]);
    } else {
      final n = byte[i];
      out
        ..write(_alfabeto[n % 45])
        ..write(_alfabeto[n ~/ 45]);
    }
  }
  return out.toString();
}

/// Decodifica un testo Base45. Lancia [FormatException] se il testo non è Base45 valido.
Uint8List base45Decodifica(String testo) {
  final valori = <int>[];
  for (final car in testo.split('')) {
    final v = _alfabeto.indexOf(car);
    if (v < 0) throw FormatException('Carattere non valido in Base45: "$car"');
    valori.add(v);
  }
  if (valori.length % 3 == 1) {
    throw const FormatException('Lunghezza non valida per Base45');
  }
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < valori.length; i += 3) {
    if (i + 2 < valori.length) {
      final n = valori[i] + valori[i + 1] * 45 + valori[i + 2] * 45 * 45;
      if (n > 0xFFFF) throw const FormatException('Gruppo Base45 fuori intervallo');
      out
        ..addByte(n >> 8)
        ..addByte(n & 0xFF);
    } else {
      final n = valori[i] + valori[i + 1] * 45;
      if (n > 0xFF) throw const FormatException('Gruppo Base45 fuori intervallo');
      out.addByte(n);
    }
  }
  return out.toBytes();
}
