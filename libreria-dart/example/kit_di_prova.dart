// Kit di prova per chi verifica o importa i QR LDI (pagina web di verifica, Nautilus - DiveKit).
// Crea un QR per ogni caso, con l'esito che il verificatore deve dare, e controlla che la libreria dia proprio quello.
//
//   dart run example/kit_di_prova.dart <cartella di uscita>
//
// Poi `py tools/kit_immagini.py <cartella>` (nella cartella del programma) trasforma le griglie in PNG e PDF.
//
// ATTENZIONE: usa chiavi DIMOSTRATIVE fisse (i semi dei test 1 e 2 dell'RFC 8032, pubblici):
// non vanno mai usate per emettere libretti veri.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ldi/ldi.dart';
import 'package:qr/qr.dart';

const _seme1 = '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';
const _seme2 = '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb';

List<int> _esadecimale(String s) => [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)];

const _diving = LdiEmittente(
    nome: 'Diving di Esempio ASD',
    tipo: 'A',
    indirizzo: 'Via del Porto 1, 16034 Portofino (GE)',
    partitaIva: '01234567890',
    dominio: 'esempio.it');
const _luogo = LdiLuogo(nome: "Secca dell'Isuela", latitudine: 44.30312, longitudine: 9.21455);
const _guide = [
  LdiGuida(nome: 'Marco Bianchi', qualifica: 'Istruttore 2*', ente: 'CMAS', responsabile: true),
  LdiGuida(nome: 'Laura Verdi', qualifica: 'Guida', ente: 'PADI'),
];
const _mario = LdiPartecipante(
    nome: 'Mario Rossi', dataNascita: '1978-04-12', brevetto: 'Open Water Diver', ente: 'SSI', numeroBrevetto: 'SSI-778812');

LdiLibretto _libretto({
  String id = 'KITlibRossi00001',
  int revisione = 1,
  String? sostituisce,
  String emesso = '2026-11-18T12:41+01:00',
  String inizio = '2026-11-18T09:35+01:00',
  String fine = '2026-11-18T10:22+01:00',
  LdiPartecipante partecipante = _mario,
  String motivo = 'cor',
  String? corso = 'Advanced Open Water',
  double raggiunta = 28.4,
  String? note = 'Avvistata una cernia bruna e due murene.',
  String? annullamento,
}) =>
    LdiLibretto(
      id: id,
      idImmersione: 'KITimmersione001',
      revisione: revisione,
      sostituisce: sostituisce,
      emesso: emesso,
      emittente: _diving,
      inizio: inizio,
      fine: fine,
      luogo: _luogo,
      guide: _guide,
      profonditaPianificata: 30,
      profonditaRaggiunta: raggiunta,
      partecipante: partecipante,
      motivo: motivo,
      corso: corso,
      autorespiratore: 'OC-MONO',
      miscela: 'EAN32',
      note: note,
      annullamento: annullamento,
    );

/// Cambia i dati dentro un QR senza rifare la firma (come farebbe un falsario).
String _altera(String testo, String da, String a) {
  final compresso = base45Decodifica(testo.substring(prefissoLdi.length));
  final pacchetto = const ZLibDecoder().decodeBytes(compresso);
  final dati = utf8.decode(pacchetto.sublist(97));
  if (!dati.contains(da)) throw StateError('«$da» non c\'è nei dati');
  final nuovo = [...pacchetto.sublist(0, 97), ...utf8.encode(dati.replaceFirst(da, a))];
  return prefissoLdi + base45Codifica(const ZLibEncoder().encodeBytes(nuovo, level: 9));
}

class _Caso {
  final String file;
  final String titolo;
  final String testo;

  /// verde = firma valida; giallo = annullato; rosso = non valida.
  final String colore;
  final String pagina;
  final String divekit;
  const _Caso(this.file, this.titolo, this.testo, this.colore, this.pagina, this.divekit);
}

Future<void> main(List<String> argomenti) async {
  final cartella = Directory(argomenti.isEmpty ? 'esempi/kit-di-prova' : argomenti.first)..createSync(recursive: true);
  final chiave1 = await LdiChiave.daSeme(_esadecimale(_seme1));
  final chiave2 = await LdiChiave.daSeme(_esadecimale(_seme2));
  final impronta1 = await chiave1.impronta();
  final impronta2 = await chiave2.impronta();

  final originale = await emettiLdi(_libretto(), chiave1);
  final corretto = await emettiLdi(
      _libretto(
          id: 'KITlibRossi00002',
          revisione: 2,
          sostituisce: 'KITlibRossi00001',
          emesso: '2026-11-18T15:02+01:00',
          raggiunta: 26.8,
          note: 'Profondità corretta: 26,8 m.'),
      chiave1);

  final casi = <_Caso>[
    _Caso('01-libretto', 'Libretto di un corso', originale, 'verde',
        'Firma valida + tutti i dati + codice di controllo $impronta1 + NOTA.',
        'Si importa. Ricorda: «Diving di Esempio ASD» ha il codice $impronta1.'),
    _Caso(
        '02-libretto-prova',
        'Libretto di una prova / battesimo, senza brevetto',
        await emettiLdi(
            _libretto(
                id: 'KITlibNeri000001',
                partecipante: const LdiPartecipante(nome: 'Giulia Neri', dataNascita: '2001-07-30', brevetto: '', ente: ''),
                motivo: 'pro',
                corso: null,
                raggiunta: 6,
                note: null),
            chiave1),
        'verde',
        'Firma valida; il sub non ha brevetto (non è un errore: è una prova). Tipo: «Prova / battesimo».',
        'Si importa.'),
    _Caso(
        '03-riepilogo',
        'Riepilogo dell\'immersione (registro del diving, non personale)',
        await emettiLdi(
            LdiRiepilogo(
              idImmersione: 'KITimmersione001',
              emesso: '2026-11-18T12:41+01:00',
              emittente: _diving,
              inizio: '2026-11-18T09:35+01:00',
              fine: '2026-11-18T10:22+01:00',
              luogo: _luogo,
              guide: _guide,
              profonditaPianificata: 30,
              profonditaRaggiunta: 28.4,
              partecipanti: const [
                LdiVoceRiepilogo(nome: 'Mario Rossi', idLibretto: 'KITlibRossi00001'),
                LdiVoceRiepilogo(nome: 'Giulia Neri', idLibretto: 'KITlibNeri000001'),
                LdiVoceRiepilogo(nome: 'Paolo Gialli', idLibretto: 'KITlibGialli0001'),
              ],
              numeroPartecipanti: 3,
            ),
            chiave1),
        'verde',
        'Firma valida; mostra l\'immersione e l\'elenco dei 3 partecipanti.',
        'NON si importa (non è un libretto personale): spiegarlo al sub.'),
    _Caso('04-correzione', 'Correzione del libretto 01 (rev 2, sostituisce KITlibRossi00001)', corretto, 'verde',
        'Firma valida; dire che è la versione 2 e che sostituisce il libretto precedente.',
        'Se 01 è già importato: propone di AGGIORNARE quell\'immersione (profondità 26,8 m). Se no: si importa.'),
    _Caso(
        '05-annullamento',
        'Annullamento del libretto 04',
        await emettiLdi(
            _libretto(
                id: 'KITannRossi00001',
                revisione: 3,
                sostituisce: 'KITlibRossi00002',
                emesso: '2026-11-19T09:10+01:00',
                raggiunta: 26.8,
                note: null,
                annullamento: 'Immersione registrata per errore'),
            chiave1),
        'giallo',
        'ANNULLATO + motivo «Immersione registrata per errore» + i dati del libretto annullato.',
        'Se 04 (o 01) è importato: resta nel logbook segnato ANNULLATA con il motivo, fuori dalle statistiche. '
            'Se non è importato: non importa niente.'),
    _Caso(
        '06-annullamento-sconosciuto',
        'Annullamento di un libretto mai importato',
        await emettiLdi(
            _libretto(
                id: 'KITannBlu0000001',
                revisione: 2,
                sostituisce: 'KITlibBlu0000001',
                emesso: '2026-11-19T09:12+01:00',
                partecipante: const LdiPartecipante(
                    nome: 'Anna Blu', dataNascita: '1990-02-14', brevetto: 'Open Water Diver', ente: 'PADI'),
                note: null,
                annullamento: 'Il sub non si è immerso'),
            chiave1),
        'giallo',
        'ANNULLATO + motivo «Il sub non si è immerso».',
        'Non importa niente (il libretto annullato non c\'è nel logbook).'),
    _Caso('07-alterato', 'Libretto 01 con la profondità cambiata da 28,4 a 18,4 m senza rifare la firma',
        _altera(originale, '"pr":28.4', '"pr":18.4'), 'rosso', 'NON VALIDO: la firma non corrisponde. Nessun dato.',
        'Non si importa.'),
    _Caso('08-danneggiato', 'Testo del libretto 01 tagliato a metà', originale.substring(0, originale.length ~/ 2),
        'rosso', 'NON VALIDO: QR danneggiato. Nessun dato.', 'Non si importa.'),
    _Caso('09-versione-futura', 'Un QR di una versione futura dello standard (LDI2:)',
        'LDI2:${originale.substring(prefissoLdi.length)}', 'rosso',
        'NON VALIDO con il motivo «versione più recente: aggiorna». Nessun dato.', 'Non si importa; suggerire di aggiornare l\'app.'),
    _Caso('10-non-ldi', 'Un QR qualsiasi (un indirizzo web)', 'https://www.example.com/', 'rosso',
        'NON VALIDO: non è un libretto LDI.', 'Non si importa.'),
    _Caso(
        '11-altra-chiave',
        'Stesso nome di diving, ma firmato con un\'altra chiave',
        await emettiLdi(_libretto(id: 'KITfalsoRossi001', emesso: '2026-11-18T13:00+01:00'), chiave2),
        'verde',
        'Firma valida, ma con il codice $impronta2 (diverso da 01): la NOTA serve proprio a questo.',
        'Se è già importato un libretto di «Diving di Esempio ASD» con $impronta1: AVVISA che il codice è diverso '
            'e chiede se importarlo lo stesso.'),
    _Caso(
        '12-avviso-orari',
        'Libretto con l\'ora di fine prima dell\'inizio',
        await emettiLdi(
            _libretto(id: 'KITorariRossi001', inizio: '2026-11-18T10:22+01:00', fine: '2026-11-18T09:35+01:00'), chiave1),
        'verde',
        'Firma valida, più l\'avviso «l\'ora di fine è prima dell\'inizio» (non lo rende non valido).',
        'Si importa, mostrando l\'avviso.'),
  ];

  final indice = <Map<String, Object?>>[];
  for (final c in casi) {
    final lettura = await leggiLdi(c.testo, adesso: DateTime.utc(2026, 11, 20));
    final doc = lettura.documento;
    final colore = !lettura.valida
        ? 'rosso'
        : (doc is LdiLibretto && doc.annullamento != null)
            ? 'giallo'
            : 'verde';
    if (colore != c.colore) throw StateError('${c.file}: la libreria dà $colore, il kit si aspetta ${c.colore}');
    File('${cartella.path}/${c.file}.txt').writeAsStringSync(c.testo);
    final qr = QrImage(QrCode(payload: QrPayload.fromString(c.testo), errorCorrectLevel: QrErrorCorrectLevel.medium));
    final griglia = StringBuffer();
    for (var r = 0; r < qr.moduleCount; r++) {
      for (var k = 0; k < qr.moduleCount; k++) {
        griglia.write(qr.isDark(r, k) ? '1' : '0');
      }
      griglia.writeln();
    }
    File('${cartella.path}/${c.file}.griglia').writeAsStringSync(griglia.toString());
    indice.add({
      'file': c.file,
      'titolo': c.titolo,
      'colore': c.colore,
      'pagina': c.pagina,
      'divekit': c.divekit,
      if (!lettura.valida) 'motivo_libreria': lettura.motivo,
      if (lettura.avvisi.isNotEmpty) 'avvisi_libreria': lettura.avvisi,
      if (lettura.chiavePubblica != null) 'codice_di_controllo': await improntaLdi(lettura.chiavePubblica!),
    });
    stdout.writeln('${c.file}: ${c.colore} (${c.testo.length} caratteri)');
  }
  File('${cartella.path}/esiti.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(indice));
  stdout.writeln('Codici di controllo: chiave 1 $impronta1, chiave 2 $impronta2');
}
