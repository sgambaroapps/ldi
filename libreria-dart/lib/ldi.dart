/// LDI – Libretto Digitale Immersioni: libreria di riferimento.
///
/// Crea, firma, legge e verifica i QR code dei libretti delle immersioni.
/// Specifica: SPECIFICA.md in https://github.com/sgambaroapps/ldi. Licenza del codice: MIT.
library;

export 'src/base45.dart' show base45Codifica, base45Decodifica;
export 'src/chiave.dart' show LdiChiave, improntaLdi, verificaFirmaLdi;
export 'src/codec.dart' show emettiLdi, leggiLdi, LdiLettura, LdiEsito, LdiErroreEmissione, prefissoLdi;
export 'src/modelli.dart';
export 'src/pubblicazione.dart';
export 'src/testi.dart'
    show nuovoIdLdi, dataOraLdi, dataLdi, leggiDataOra, leggiData, base64UrlSenzaUguale, base64UrlDecodifica;
