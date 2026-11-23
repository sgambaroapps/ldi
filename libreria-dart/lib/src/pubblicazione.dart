// Il file ldi.json che l'emittente pubblica sul suo sito (specifica, paragrafo 6),
// e il controllo dell'identità dell'emittente (paragrafo 7, punto 7).
import 'dart:convert';

import 'codec.dart';
import 'chiave.dart';
import 'testi.dart';

/// Indirizzi dove cercare il file, nell'ordine.
List<Uri> indirizziFileLdi(String dominio) => [
      Uri.https(dominio, '/.well-known/ldi.json'),
      Uri.https(dominio, '/ldi.json'),
    ];

/// Una chiave elencata nel file pubblico.
class LdiVoceChiave {
  /// Chiave pubblica, 32 byte.
  final List<int> chiave;
  final String impronta;
  final String? sede;

  /// Valida dal (AAAA-MM-GG).
  final String dal;

  /// Revocata dal (AAAA-MM-GG): da quel giorno le firme di questa chiave non valgono più.
  final String? revocataDal;

  const LdiVoceChiave(
      {required this.chiave, required this.impronta, this.sede, required this.dal, this.revocataDal});

  /// Crea la voce di una chiave calcolando l'impronta.
  static Future<LdiVoceChiave> da(List<int> chiave, {required String dal, String? sede, String? revocataDal}) async =>
      LdiVoceChiave(
          chiave: chiave, impronta: await improntaLdi(chiave), sede: sede, dal: dal, revocataDal: revocataDal);

  Map<String, Object?> toJson() => {
        'k': base64UrlSenzaUguale(chiave),
        'impronta': impronta,
        if (sede != null) 'sede': sede,
        'dal': dal,
        if (revocataDal != null) 'revocata_dal': revocataDal,
      };

  factory LdiVoceChiave.fromJson(Map<String, Object?> j) => LdiVoceChiave(
        chiave: base64UrlDecodifica(j['k'] as String),
        impronta: (j['impronta'] as String?) ?? '',
        sede: j['sede'] as String?,
        dal: (j['dal'] as String?) ?? '',
        revocataDal: j['revocata_dal'] as String?,
      );
}

/// Il contenuto del file ldi.json.
class LdiFilePubblico {
  final String nome;
  final String? partitaIva;
  final List<LdiVoceChiave> chiavi;

  const LdiFilePubblico({required this.nome, this.partitaIva, required this.chiavi});

  Map<String, Object?> toJson() => {
        'standard': 'LDI',
        'v': 1,
        'n': nome,
        if (partitaIva != null) 'piva': partitaIva,
        'chiavi': [for (final c in chiavi) c.toJson()],
      };

  /// Testo del file, leggibile anche a occhio.
  String comeTesto() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Legge il file. Lancia [FormatException] se non è un file LDI valido.
  factory LdiFilePubblico.daTesto(String testo) {
    try {
      final j = (jsonDecode(testo) as Map).cast<String, Object?>();
      if (j['standard'] != 'LDI') throw const FormatException('Non è un file LDI');
      return LdiFilePubblico(
        nome: (j['n'] as String?) ?? '',
        partitaIva: j['piva'] as String?,
        chiavi: [for (final c in j['chiavi'] as List) LdiVoceChiave.fromJson((c as Map).cast<String, Object?>())],
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('File LDI non valido: $e');
    }
  }
}

/// Esito del controllo dell'identità dell'emittente.
enum LdiIdentita {
  /// La chiave del QR è nel file pubblicato dall'emittente e non era revocata alla data di emissione.
  verificato,

  /// La chiave c'è, ma era già revocata quando il QR è stato emesso: il QR NON è valido.
  revocata,

  /// La chiave non è nel file: l'identità dell'emittente resta non verificata.
  nonTrovata,
}

bool _stessiByte(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Confronta la chiave di un QR letto con il file pubblicato dall'emittente.
LdiIdentita controllaEmittente(LdiLettura lettura, LdiFilePubblico file) {
  final chiave = lettura.chiavePubblica;
  final documento = lettura.documento;
  if (!lettura.valida || chiave == null || documento == null) return LdiIdentita.nonTrovata;
  final emesso = documento.emesso.substring(0, 10); // AAAA-MM-GG
  for (final voce in file.chiavi) {
    if (!_stessiByte(voce.chiave, chiave)) continue;
    final revoca = voce.revocataDal;
    if (revoca != null && revoca.compareTo(emesso) <= 0) return LdiIdentita.revocata;
    return LdiIdentita.verificato;
  }
  return LdiIdentita.nonTrovata;
}
