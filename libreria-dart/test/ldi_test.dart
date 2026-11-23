import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ldi/ldi.dart';
import 'package:ldi/src/testi.dart' show base32Codifica;
import 'package:test/test.dart';

List<int> esa(String s) => [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)];

const emittente = LdiEmittente(
  nome: 'Diving Portofino Blu ASD',
  tipo: 'A',
  indirizzo: 'Via Roma 12, 16034 Portofino (GE)',
  partitaIva: '01234567890',
  dominio: 'divingportofinoblu.example',
);
const guide = [
  LdiGuida(nome: 'Marco Bianchi', qualifica: 'Istruttore 2*', ente: 'CMAS', responsabile: true),
  LdiGuida(nome: 'Laura Verdi', qualifica: 'Guida', ente: 'PADI'),
];
const luogo = LdiLuogo(nome: "Secca dell'Isuela", latitudine: 44.30312, longitudine: 9.21455);
final adesso = DateTime.parse('2026-11-18T13:00+01:00');

LdiLibretto libretto(
        {String? note = 'Avvistata una cernia bruna e due murene.',
        String miscela = 'EAN32',
        String motivo = 'cor',
        String brevetto = 'Open Water Diver',
        String ente = 'SSI',
        String? sostituisce,
        String? annullamento}) =>
    LdiLibretto(
      versione: 1, // i test qui sotto sono quelli della v1, che resta leggibile
      id: 'bG9nYm9vazAwMDE1',
      idImmersione: 'Qm9wZ3Rx2kLc8sVw',
      emesso: '2026-11-18T12:41+01:00',
      emittente: emittente,
      inizio: '2026-11-18T09:35+01:00',
      fine: '2026-11-18T10:22+01:00',
      luogo: luogo,
      guide: guide,
      profonditaPianificata: 30,
      profonditaRaggiunta: 28.4,
      sostituisce: sostituisce,
      annullamento: annullamento,
      partecipante: LdiPartecipante(nome: 'Mario Rossi', dataNascita: '1978-04-12', brevetto: brevetto, ente: ente),
      motivo: motivo,
      corso: 'Advanced Open Water',
      autorespiratore: 'OC-MONO',
      miscela: miscela,
      note: note,
    );

/// Riapre il pacchetto di un QR, permette di modificarlo e lo richiude SENZA rifirmarlo (simula un falsario).
String manometti(String qr, Uint8List Function(Uint8List pacchetto) modifica) {
  final pacchetto = const ZLibDecoder().decodeBytes(base45Decodifica(qr.substring(5)));
  return prefissoLdi + base45Codifica(const ZLibEncoder().encodeBytes(modifica(pacchetto), level: 9));
}

void main() {
  group('Base45 (vettori di prova RFC 9285)', () {
    final casi = {'AB': 'BB8', 'Hello!!': '%69 VD92EX0', 'base-45': 'UJCLQE7W581', 'ietf!': 'QED8WEX0'};
    casi.forEach((chiaro, codificato) {
      test('"$chiaro"', () {
        expect(base45Codifica(utf8.encode(chiaro)), codificato);
        expect(utf8.decode(base45Decodifica(codificato)), chiaro);
      });
    });
    test('testo non valido', () {
      expect(() => base45Decodifica('GGW'), throwsFormatException); // fuori intervallo
      expect(() => base45Decodifica('abc'), throwsFormatException); // minuscole
      expect(() => base45Decodifica('A'), throwsFormatException); // lunghezza
    });
  });

  test('Base32 (vettore di prova RFC 4648)', () {
    expect(base32Codifica(utf8.encode('foobar')), 'MZXW6YTBOI');
  });

  group('Ed25519 (vettori di prova RFC 8032)', () {
    test('test 1: messaggio vuoto', () async {
      final k = await LdiChiave.daSeme(esa('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'));
      expect(k.pubblica, esa('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'));
      final firma = await k.firma([]);
      expect(
          firma,
          esa('e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'));
      expect(await verificaFirmaLdi([], firma, k.pubblica), isTrue);
    });
    test('test 2: un byte', () async {
      final k = await LdiChiave.daSeme(esa('4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb'));
      expect(k.pubblica, esa('3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c'));
      final firma = await k.firma([0x72]);
      expect(
          firma,
          esa('92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00'));
      expect(await verificaFirmaLdi([0x73], firma, k.pubblica), isFalse);
    });
    test('seme salvato e ricaricato = stessa chiave', () async {
      final k = await LdiChiave.genera();
      final k2 = await LdiChiave.daSeme(await k.seme());
      expect(k2.pubblica, k.pubblica);
      expect(await k2.impronta(), await k.impronta());
    });
    test('impronta: 4 gruppi di 4 caratteri Base32', () async {
      final k = await LdiChiave.genera();
      expect(await k.impronta(), matches(RegExp(r'^[A-Z2-7]{4}(-[A-Z2-7]{4}){3}$')));
    });
  });

  group('Libretto individuale', () {
    test('emissione e lettura: i dati tornano identici', () async {
      final k = await LdiChiave.genera();
      final qr = await emettiLdi(libretto(), k);
      expect(qr, startsWith('LDI1:'));
      expect(qr, matches(RegExp(r'^LDI1:[0-9A-Z $%*+\-./:]+$')), reason: 'solo caratteri alfanumerici QR');
      final l = await leggiLdi(qr, adesso: adesso);
      expect(l.esito, LdiEsito.firmaValida, reason: '${l.motivo} ${l.dettagli}');
      expect(l.avvisi, isEmpty);
      expect(l.chiavePubblica, k.pubblica);
      expect(l.documento!.toJson(), libretto().toJson());
      final d = l.documento as LdiLibretto;
      expect(d.partecipante.nome, 'Mario Rossi');
      expect(d.profonditaRaggiunta, 28.4);
      expect(d.guide.first.responsabile, isTrue);
      // ignore: avoid_print
      print('Lunghezza del QR di esempio: ${qr.length} caratteri');
      expect(qr.length, lessThan(1000));
    });

    test('motivi «prova / battesimo» e «accompagnamento» (bozza 3)', () async {
      final chiave = await LdiChiave.genera();
      for (final m in ['pro', 'acc']) {
        final letto = await leggiLdi(await emettiLdi(libretto(motivo: m), chiave));
        expect(letto.esito, isNot(LdiEsito.nonValida), reason: m);
        expect((letto.documento as LdiLibretto).motivo, m);
      }
      expect(() => emettiLdi(libretto(motivo: 'xyz'), chiave), throwsA(isA<LdiErroreEmissione>()));
    });

    test('bozza 4: libretto di annullamento', () async {
      final chiave = await LdiChiave.genera();
      final testo = await emettiLdi(
          libretto(sostituisce: 'bG9nYm9vazAwMDE0', annullamento: 'Immersione non fatta: mare mosso'), chiave);
      final l = (await leggiLdi(testo)).documento as LdiLibretto;
      expect(l.annullato, isTrue);
      expect(l.annullamento, 'Immersione non fatta: mare mosso');
      expect(l.sostituisce, 'bG9nYm9vazAwMDE0');
      expect(() => emettiLdi(libretto(annullamento: 'senza sost'), chiave), throwsA(isA<LdiErroreEmissione>()),
          reason: 'un annullamento deve dire quale libretto annulla');
      expect((await leggiLdi(await emettiLdi(libretto(), chiave))).documento is LdiLibretto, isTrue);
      expect(((await leggiLdi(await emettiLdi(libretto(), chiave))).documento as LdiLibretto).annullato, isFalse);
    });

    test('bozza 4: prova / battesimo senza brevetto', () async {
      final chiave = await LdiChiave.genera();
      final l = (await leggiLdi(await emettiLdi(libretto(motivo: 'pro', brevetto: '', ente: ''), chiave))).documento;
      expect((l as LdiLibretto).partecipante.brevetto, '');
      expect(() => emettiLdi(libretto(motivo: 'ric', brevetto: '', ente: ''), chiave),
          throwsA(isA<LdiErroreEmissione>()), reason: 'per gli altri motivi il brevetto resta obbligatorio');
    });

    test('accenti e caratteri speciali', () async {
      final k = await LdiChiave.genera();
      final qr = await emettiLdi(libretto(note: 'Visibilità ottima, corrente €0 — ok 🐟'), k);
      final l = await leggiLdi(qr, adesso: adesso);
      expect((l.documento as LdiLibretto).note, 'Visibilità ottima, corrente €0 — ok 🐟');
    });

    test('un carattere cambiato nel QR viene scoperto', () async {
      final qr = await emettiLdi(libretto(), await LdiChiave.genera());
      for (final pos in [6, qr.length ~/ 2, qr.length - 2]) {
        final ch = qr[pos] == 'A' ? 'B' : 'A';
        final alterato = qr.substring(0, pos) + ch + qr.substring(pos + 1);
        final l = await leggiLdi(alterato, adesso: adesso);
        expect(l.esito, LdiEsito.nonValida, reason: 'posizione $pos');
      }
    });

    test('dati modificati senza rifirmare: firma non corrispondente', () async {
      final qr = await emettiLdi(libretto(), await LdiChiave.genera());
      final falso = manometti(qr, (p) {
        final testo = utf8.decode(p.sublist(97)).replaceFirst('"pr":28.4', '"pr":40');
        return Uint8List.fromList([...p.sublist(0, 97), ...utf8.encode(testo)]);
      });
      final l = await leggiLdi(falso, adesso: adesso);
      expect(l.esito, LdiEsito.nonValida);
      expect(l.motivo, contains('firma'));
    });

    test('firma di un\'altra chiave al posto di quella vera: non valida', () async {
      final vera = await LdiChiave.genera();
      final altra = await LdiChiave.genera();
      final qr = await emettiLdi(libretto(), vera);
      final falso = manometti(qr, (p) => Uint8List.fromList([p[0], ...altra.pubblica, ...p.sublist(33)]));
      expect((await leggiLdi(falso, adesso: adesso)).esito, LdiEsito.nonValida);
    });

    test('dati non validi: l\'emissione si rifiuta', () async {
      final k = await LdiChiave.genera();
      expect(() => emettiLdi(libretto(note: 'x' * 101), k), throwsA(isA<LdiErroreEmissione>()));
      expect(() => emettiLdi(libretto(miscela: 'EAN10'), k), throwsA(isA<LdiErroreEmissione>()));
      expect(() => emettiLdi(libretto(miscela: 'TX50/60'), k), throwsA(isA<LdiErroreEmissione>()));
      await emettiLdi(libretto(note: 'x' * 100), k); // 100 caratteri: ok
      await emettiLdi(libretto(note: null, miscela: 'TX21/35'), k);
    });

    test('QR non LDI, versione futura, testo vuoto', () async {
      expect((await leggiLdi('https://www.esempio.it')).esito, LdiEsito.nonValida);
      expect((await leggiLdi('')).esito, LdiEsito.nonValida);
      final futuro = await leggiLdi('LDI2:ABC');
      expect(futuro.motivo, contains('versione più recente'));
      final qr = await emettiLdi(libretto(), await LdiChiave.genera());
      final v2 = manometti(qr, (p) => Uint8List.fromList([2, ...p.sublist(1)]));
      expect((await leggiLdi(v2)).motivo, contains('versione più recente'));
    });

    test('avvisi di buon senso: fine prima dell\'inizio', () async {
      final d = LdiLibretto.fromJson({...libretto().toJson(), 'fin': '2026-11-18T09:00+01:00'});
      final l = await leggiLdi(await emettiLdi(d, await LdiChiave.genera()), adesso: adesso);
      expect(l.esito, LdiEsito.firmaValida);
      expect(l.avvisi, contains(contains('fine')));
    });

    test('date impossibili rifiutate', () {
      expect(leggiData('2026-02-31'), isNull);
      expect(leggiDataOra('2026-11-18T25:10+01:00'), isNull);
      expect(leggiDataOra('2026-11-18T09:35'), isNull, reason: 'manca il fuso orario');
      expect(leggiDataOra('2026-11-18T09:35+01:00'), isNotNull);
    });
  });

  group('Riepilogo immersione', () {
    test('emissione e lettura', () async {
      final r = LdiRiepilogo(
        versione: 1,
        idImmersione: 'Qm9wZ3Rx2kLc8sVw',
        emesso: '2026-11-18T12:45+01:00',
        emittente: emittente,
        inizio: '2026-11-18T09:35+01:00',
        fine: '2026-11-18T10:22+01:00',
        luogo: luogo,
        guide: guide,
        profonditaPianificata: 30,
        profonditaRaggiunta: 28.4,
        partecipanti: [
          for (var i = 0; i < 12; i++) LdiVoceRiepilogo(nome: 'Partecipante numero $i', idLibretto: nuovoIdLdi()),
        ],
        numeroPartecipanti: 12,
      );
      final qr = await emettiLdi(r, await LdiChiave.genera());
      final l = await leggiLdi(qr, adesso: adesso);
      expect(l.esito, LdiEsito.firmaValida, reason: '${l.motivo} ${l.dettagli}');
      expect((l.documento as LdiRiepilogo).partecipanti.length, 12);
      // ignore: avoid_print
      print('Lunghezza del QR di riepilogo (12 partecipanti): ${qr.length} caratteri');
    });
  });

  group('Versione 2 dei dati (23/11/2026)', () {
    LdiLibretto v2({String motivo = 'ric', String? modalita = 'org', List<String>? compagni = const ['Anna Verdi'],
            List<LdiGuida> guide = const []}) =>
        LdiLibretto(
          id: 'bG9nYm9vazAwMDE2',
          idImmersione: 'Qm9wZ3Rx2kLc8sVw',
          emesso: '2026-11-23T12:41+01:00',
          emittente: emittente,
          inizio: '2026-11-23T09:35+01:00',
          fine: '2026-11-23T10:22+01:00',
          luogo: luogo,
          guide: guide,
          profonditaPianificata: 18,
          profonditaRaggiunta: 17.6,
          partecipante: const LdiPartecipante(
              nome: 'Mario Rossi', dataNascita: '1978-04-12', brevetto: 'Open Water Diver', ente: 'SSI', numeroBrevetto: 'S-1'),
          motivo: motivo,
          modalita: modalita,
          compagni: compagni,
          autorespiratore: 'OC-MONO',
          miscela: 'AIR',
        );

    test('libretto organizzato, senza guide e senza responsabile: valido; v=2 nel JSON', () async {
      final k = await LdiChiave.genera();
      final l = await leggiLdi(await emettiLdi(v2(), k), adesso: adesso);
      expect(l.esito, LdiEsito.firmaValida, reason: '${l.motivo} ${l.dettagli}');
      final d = l.documento as LdiLibretto;
      expect([d.versione, d.modalita, d.compagni, d.guide], [2, 'org', ['Anna Verdi'], isEmpty]);
      expect(d.toJson()['v'], 2);
      expect(d.toJson().containsKey('ru'), isFalse);
    });

    test('guidata con la guida seguita; terzetto organizzato; tecnica', () async {
      final k = await LdiChiave.genera();
      const g = [LdiGuida(nome: 'Laura Verdi', qualifica: 'Guida', ente: 'PADI')];
      for (final d in [
        v2(modalita: 'gui', compagni: ['Laura Verdi'], guide: g),
        v2(compagni: ['Anna Verdi', 'Luca Neri']),
        v2(motivo: 'tec'),
        v2(motivo: 'acc', modalita: null, compagni: null, guide: g), // la guida che accompagna
      ]) {
        final l = await leggiLdi(await emettiLdi(d, k), adesso: adesso);
        expect(l.esito, LdiEsito.firmaValida, reason: '${d.toJson()} ${l.dettagli}');
      }
    });

    test('regole della v2: mod e con obbligatori, una sola guida seguita', () async {
      final k = await LdiChiave.genera();
      for (final d in [
        v2(modalita: null),
        v2(compagni: null),
        v2(compagni: const []),
        v2(modalita: 'xyz'),
        v2(modalita: 'gui', compagni: ['A', 'B']),
      ]) {
        expect(() => emettiLdi(d, k), throwsA(isA<LdiErroreEmissione>()), reason: '${d.toJson()}');
      }
    });

    test('la v1 resta com\'era: «tecnica» e guide vuote non valgono', () async {
      final k = await LdiChiave.genera();
      expect(() => emettiLdi(LdiLibretto.fromJson({...libretto().toJson(), 'mot': 'tec'}), k),
          throwsA(isA<LdiErroreEmissione>()));
      expect(() => emettiLdi(LdiLibretto.fromJson({...libretto().toJson(), 'g': []}), k),
          throwsA(isA<LdiErroreEmissione>()));
      expect((await leggiLdi(await emettiLdi(libretto(), k), adesso: adesso)).esito, LdiEsito.firmaValida);
    });

    test('riepilogo v2: responsabile dell\'uscita obbligatorio, primo soccorso con il telefono', () async {
      final k = await LdiChiave.genera();
      LdiRiepilogo r({LdiContatto? ru, LdiContatto? ps}) => LdiRiepilogo(
            idImmersione: 'Qm9wZ3Rx2kLc8sVw',
            emesso: '2026-11-23T12:45+01:00',
            emittente: emittente,
            inizio: '2026-11-23T09:35+01:00',
            fine: '2026-11-23T10:22+01:00',
            luogo: luogo,
            guide: const [],
            profonditaPianificata: 18,
            profonditaRaggiunta: 17.6,
            partecipanti: [LdiVoceRiepilogo(nome: 'Mario Rossi', idLibretto: nuovoIdLdi())],
            numeroPartecipanti: 1,
            responsabile: ru,
            primoSoccorso: ps,
          );
      expect(() => emettiLdi(r(), k), throwsA(isA<LdiErroreEmissione>()));
      expect(() => emettiLdi(v2(guide: guide), k), throwsA(isA<LdiErroreEmissione>()),
          reason: 'in v2 niente r:1 sulle guide');
      const luca = LdiContatto(nome: 'Luca Neri', telefono: '333 1234567');
      final l = await leggiLdi(await emettiLdi(r(ru: luca, ps: luca), k), adesso: adesso);
      expect(l.esito, LdiEsito.firmaValida, reason: '${l.motivo} ${l.dettagli}');
      final d = l.documento as LdiRiepilogo;
      expect([d.responsabile!.nome, d.primoSoccorso!.telefono], ['Luca Neri', '333 1234567']);
    });

    test('v = 3 (futura): «versione più recente»', () async {
      // firmato davvero, come farebbe un programma più nuovo
      final k = await LdiChiave.genera();
      final dati = utf8.encode(jsonEncode({...v2().toJson(), 'v': 3}));
      final firma = await k.firma([...utf8.encode('LDI1'), ...dati]);
      final pacchetto = Uint8List.fromList([1, ...k.pubblica, ...firma, ...dati]);
      final v3 = prefissoLdi + base45Codifica(const ZLibEncoder().encodeBytes(pacchetto, level: 9));
      final l = await leggiLdi(v3);
      expect(l.motivo, contains('versione più recente'));
    });
  });

  group('Identità dell\'emittente (file ldi.json)', () {
    test('verificato, revocato, non trovato', () async {
      final sede1 = await LdiChiave.genera();
      final sede2 = await LdiChiave.genera();
      final estranea = await LdiChiave.genera();
      final file = LdiFilePubblico(nome: emittente.nome, partitaIva: emittente.partitaIva, chiavi: [
        await LdiVoceChiave.da(sede1.pubblica, dal: '2026-11-01', sede: 'Portofino'),
        await LdiVoceChiave.da(sede2.pubblica, dal: '2025-03-01', sede: 'Elba', revocataDal: '2026-11-10'),
      ]);
      // il file si scrive e si rilegge senza perdere nulla
      final riletto = LdiFilePubblico.daTesto(file.comeTesto());
      expect(riletto.comeTesto(), file.comeTesto());

      Future<LdiIdentita> prova(LdiChiave k) async =>
          controllaEmittente(await leggiLdi(await emettiLdi(libretto(), k), adesso: adesso), riletto);
      expect(await prova(sede1), LdiIdentita.verificato);
      expect(await prova(sede2), LdiIdentita.revocata); // emesso il 18/11, revocata dal 10/11
      expect(await prova(estranea), LdiIdentita.nonTrovata);
    });

    test('indirizzi dove cercare il file', () {
      expect(indirizziFileLdi('divingesempio.it').map((u) => '$u'),
          ['https://divingesempio.it/.well-known/ldi.json', 'https://divingesempio.it/ldi.json']);
    });

    test('file non LDI rifiutato', () {
      expect(() => LdiFilePubblico.daTesto('{"ciao":1}'), throwsFormatException);
      expect(() => LdiFilePubblico.daTesto('non è json'), throwsFormatException);
    });
  });

  test('identificativi nuovi: 16 caratteri e tutti diversi', () {
    final ids = {for (var i = 0; i < 1000; i++) nuovoIdLdi()};
    expect(ids.length, 1000);
    expect(ids.every((id) => RegExp(r'^[A-Za-z0-9_-]{16}$').hasMatch(id)), isTrue);
  });
}
