// Crea un QR LDI di esempio e lo salva come immagine SVG (più una griglia di testo per le prove automatiche).
//
//   dart run example/esempio.dart <cartella di uscita>
//
// ATTENZIONE: usa una chiave DIMOSTRATIVA fissa (il seme del test 1 dell'RFC 8032, pubblico):
// non va mai usata per emettere libretti veri.
import 'dart:io';

import 'package:ldi/ldi.dart';
import 'package:qr/qr.dart';

const _semeDimostrativo = '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';

Future<void> main(List<String> argomenti) async {
  final cartella = Directory(argomenti.isEmpty ? 'esempi' : argomenti.first)..createSync(recursive: true);
  final chiave = await LdiChiave.daSeme([
    for (var i = 0; i < _semeDimostrativo.length; i += 2) int.parse(_semeDimostrativo.substring(i, i + 2), radix: 16)
  ]);

  final libretto = LdiLibretto(
    id: 'ESEMPIOlibretto1',
    idImmersione: 'ESEMPIOimmersio1',
    emesso: '2026-11-18T12:41+01:00',
    emittente: const LdiEmittente(
        nome: 'Diving di Esempio ASD', tipo: 'A', indirizzo: 'Via del Porto 1, 16034 Portofino (GE)', dominio: 'esempio.it'),
    inizio: '2026-11-18T09:35+01:00',
    fine: '2026-11-18T10:22+01:00',
    luogo: const LdiLuogo(nome: "Secca dell'Isuela", latitudine: 44.30312, longitudine: 9.21455),
    guide: const [
      LdiGuida(nome: 'Marco Bianchi', qualifica: 'Istruttore 2*', ente: 'CMAS', responsabile: true),
      LdiGuida(nome: 'Laura Verdi', qualifica: 'Guida', ente: 'PADI'),
    ],
    profonditaPianificata: 30,
    profonditaRaggiunta: 28.4,
    partecipante: const LdiPartecipante(
        nome: 'Mario Rossi', dataNascita: '1978-04-12', brevetto: 'Open Water Diver', ente: 'SSI'),
    motivo: 'cor',
    corso: 'Advanced Open Water',
    autorespiratore: 'OC-MONO',
    miscela: 'EAN32',
    note: 'Avvistata una cernia bruna e due murene.',
  );

  final testo = await emettiLdi(libretto, chiave);
  File('${cartella.path}/esempio-libretto.txt').writeAsStringSync(testo);

  for (final (nome, livello) in [('M', QrErrorCorrectLevel.medium), ('H', QrErrorCorrectLevel.high)]) {
    final immagine = QrImage(QrCode(payload: QrPayload.fromString(testo), errorCorrectLevel: livello));
    final n = immagine.moduleCount;
    const bordo = 4; // margine bianco obbligatorio di 4 moduli
    final svg = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${n + 2 * bordo} ${n + 2 * bordo}" '
          'shape-rendering="crispEdges"><rect width="100%" height="100%" fill="#fff"/><path fill="#000" d="');
    final griglia = StringBuffer();
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final scuro = immagine.isDark(r, c);
        if (scuro) svg.write('M${c + bordo} ${r + bordo}h1v1h-1z');
        griglia.write(scuro ? '1' : '0');
      }
      griglia.writeln();
    }
    svg.write('"/></svg>');
    File('${cartella.path}/esempio-libretto-$nome.svg').writeAsStringSync(svg.toString());
    File('${cartella.path}/esempio-libretto-$nome.griglia').writeAsStringSync(griglia.toString());
    stdout.writeln('Correzione $nome: versione ${immagine.typeNumber}, $n×$n moduli');
  }
  stdout.writeln('Testo del QR: ${testo.length} caratteri; impronta della chiave dimostrativa: ${await chiave.impronta()}');
}
