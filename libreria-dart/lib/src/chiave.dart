// La coppia di chiavi Ed25519 dell'emittente (il suo «sigillo digitale»).
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'testi.dart';

final Ed25519 _ed25519 = Ed25519();

/// La coppia di chiavi di un emittente: la privata firma, la pubblica verifica.
class LdiChiave {
  final SimpleKeyPair _coppia;

  /// Chiave pubblica: 32 byte. Viaggia dentro ogni QR.
  final Uint8List pubblica;

  LdiChiave._(this._coppia, this.pubblica);

  /// Genera una chiave nuova (al primo avvio del programma).
  static Future<LdiChiave> genera() async {
    final coppia = await _ed25519.newKeyPair();
    return _da(coppia);
  }

  /// Ricrea la chiave dai 32 byte segreti (il «seme»), es. dalla copia di riserva.
  static Future<LdiChiave> daSeme(List<int> seme) async {
    if (seme.length != 32) throw ArgumentError('Il seme di una chiave Ed25519 deve essere di 32 byte');
    final coppia = await _ed25519.newKeyPairFromSeed(seme);
    return _da(coppia);
  }

  static Future<LdiChiave> _da(SimpleKeyPair coppia) async {
    final pub = await coppia.extractPublicKey();
    return LdiChiave._(coppia, Uint8List.fromList(pub.bytes));
  }

  /// I 32 byte segreti: da salvare SOLO cifrati (archivio sicuro di Windows o copia di riserva con password).
  Future<Uint8List> seme() async => Uint8List.fromList(await _coppia.extractPrivateKeyBytes());

  /// Firma dei byte: restituisce i 64 byte della firma.
  Future<Uint8List> firma(List<int> messaggio) async {
    final f = await _ed25519.sign(messaggio, keyPair: _coppia);
    return Uint8List.fromList(f.bytes);
  }

  /// Codice di controllo leggibile della chiave pubblica (es. MF3K-WXQ2-7HTA-LP4C).
  Future<String> impronta() => improntaLdi(pubblica);
}

/// Verifica una firma Ed25519 con una chiave pubblica di 32 byte.
Future<bool> verificaFirmaLdi(List<int> messaggio, List<int> firma, List<int> chiavePubblica) async {
  if (firma.length != 64 || chiavePubblica.length != 32) return false;
  try {
    return await _ed25519.verify(
      messaggio,
      signature: Signature(firma, publicKey: SimplePublicKey(chiavePubblica, type: KeyPairType.ed25519)),
    );
  } catch (_) {
    return false;
  }
}

/// Impronta di una chiave pubblica (specifica 5): primi 10 byte dello SHA-256, in Base32, a gruppi di 4.
Future<String> improntaLdi(List<int> chiavePubblica) async {
  final hash = await Sha256().hash(chiavePubblica);
  final testo = base32Codifica(hash.bytes.sublist(0, 10));
  return [for (var i = 0; i < testo.length; i += 4) testo.substring(i, i + 4)].join('-');
}
