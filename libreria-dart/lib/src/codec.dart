// Emissione e lettura del testo del QR LDI (specifica: paragrafi 3 e 7).
//
// testo del QR = "LDI1:" + Base45( zlib( [versione 1][chiave pubblica 32][firma 64][dati JSON] ) )
// firma        = Ed25519( chiave privata, "LDI1" + dati JSON )
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'base45.dart';
import 'chiave.dart';
import 'modelli.dart';

/// Prefisso di ogni QR LDI versione 1.
const String prefissoLdi = 'LDI1:';
const int _versionePacchetto = 1;
final List<int> _contestoFirma = ascii.encode('LDI1');

// Limiti di sicurezza contro QR anomali o costruiti apposta.
const int _maxCaratteriQr = 7000;
const int _maxByteDecompressi = 16 * 1024;

/// Errore in emissione: i dati non rispettano lo standard.
class LdiErroreEmissione implements Exception {
  final List<String> errori;
  const LdiErroreEmissione(this.errori);
  @override
  String toString() => 'Dati non validi per il QR LDI: ${errori.join('; ')}';
}

/// Crea il testo da mettere nel QR, firmato con [chiave].
/// Lancia [LdiErroreEmissione] se i dati non rispettano lo standard.
Future<String> emettiLdi(LdiDocumento documento, LdiChiave chiave) async {
  final controllo = controllaDocumento(documento);
  if (!controllo.valido) throw LdiErroreEmissione(controllo.errori);
  final dati = utf8.encode(jsonEncode(documento.toJson()));
  final firma = await chiave.firma([..._contestoFirma, ...dati]);
  final pacchetto = BytesBuilder(copy: false)
    ..addByte(_versionePacchetto)
    ..add(chiave.pubblica)
    ..add(firma)
    ..add(dati);
  final compresso = const ZLibEncoder().encodeBytes(pacchetto.toBytes(), level: 9);
  return prefissoLdi + base45Codifica(compresso);
}

/// Esito della lettura di un QR.
enum LdiEsito {
  /// Non è un QR LDI, è danneggiato, alterato o incompleto. Non va usato.
  nonValida,

  /// I dati sono integri e firmati; l'identità dell'emittente non è ancora confermata.
  firmaValida,
}

/// Risultato della lettura di un QR LDI.
class LdiLettura {
  final LdiEsito esito;

  /// Spiegazione in italiano semplice, da mostrare all'utente quando l'esito è [LdiEsito.nonValida].
  final String? motivo;

  /// Dettagli tecnici dell'errore (per chi sviluppa).
  final List<String> dettagli;

  /// Segnalazioni che non invalidano il QR (es. orario di fine prima dell'inizio).
  final List<String> avvisi;
  final LdiDocumento? documento;

  /// Chiave pubblica di chi ha firmato (32 byte).
  final Uint8List? chiavePubblica;

  /// Il testo originale del QR, da conservare per poter rifare la verifica.
  final String testo;

  const LdiLettura._(this.esito, this.testo,
      {this.motivo, this.dettagli = const [], this.avvisi = const [], this.documento, this.chiavePubblica});

  bool get valida => esito != LdiEsito.nonValida;
}

LdiLettura _nonValida(String testo, String motivo, [List<String> dettagli = const []]) =>
    LdiLettura._(LdiEsito.nonValida, testo, motivo: motivo, dettagli: dettagli);

/// Legge e verifica il testo di un QR. Non lancia eccezioni: ogni problema finisce in [LdiLettura.motivo].
/// [adesso] serve ai test; di norma è l'ora attuale.
Future<LdiLettura> leggiLdi(String testoQr, {DateTime? adesso}) async {
  final testo = testoQr.trim();
  if (!testo.startsWith(prefissoLdi)) {
    if (RegExp(r'^LDI\d+:').hasMatch(testo)) {
      return _nonValida(testo, 'È un libretto LDI di una versione più recente: aggiorna il programma.');
    }
    return _nonValida(testo, 'Questo QR non è un libretto delle immersioni LDI.');
  }
  if (testo.length > _maxCaratteriQr) return _nonValida(testo, 'Il QR è troppo grande per essere un libretto LDI.');

  final Uint8List pacchetto;
  try {
    final compresso = base45Decodifica(testo.substring(prefissoLdi.length));
    pacchetto = const ZLibDecoder()
        .decodeBytes(compresso, verify: true, throwOnError: true, maxOutputSize: _maxByteDecompressi);
  } catch (e) {
    return _nonValida(testo, 'Il QR è danneggiato o è stato modificato.', ['$e']);
  }
  if (pacchetto.length < 1 + 32 + 64 + 2) {
    return _nonValida(testo, 'Il QR è incompleto.');
  }
  if (pacchetto[0] != _versionePacchetto) {
    return _nonValida(testo, 'È un libretto LDI di una versione più recente: aggiorna il programma.');
  }
  final chiave = Uint8List.sublistView(pacchetto, 1, 33);
  final firma = Uint8List.sublistView(pacchetto, 33, 97);
  final dati = Uint8List.sublistView(pacchetto, 97);

  if (!await verificaFirmaLdi([..._contestoFirma, ...dati], firma, chiave)) {
    return _nonValida(testo, 'La firma non corrisponde: i dati sono stati modificati dopo l\'emissione.');
  }

  final LdiDocumento documento;
  try {
    final json = jsonDecode(utf8.decode(dati));
    if (json is! Map) throw const FormatException('I dati non sono un oggetto JSON');
    final mappa = json.cast<String, Object?>();
    if (mappa['v'] is! int || (mappa['v'] as int) > versioneDatiLdi) {
      return _nonValida(testo, 'È un libretto LDI di una versione più recente: aggiorna il programma.');
    }
    documento = LdiDocumento.fromJson(mappa);
  } catch (e) {
    return _nonValida(testo, 'Il QR è firmato ma i dati non sono leggibili.', ['$e']);
  }

  final controllo = controllaDocumento(documento, adesso: adesso);
  if (!controllo.valido) {
    return _nonValida(testo, 'Il QR è firmato ma mancano dati obbligatori.', controllo.errori);
  }
  return LdiLettura._(LdiEsito.firmaValida, testo,
      avvisi: controllo.avvisi, documento: documento, chiavePubblica: Uint8List.fromList(chiave));
}
