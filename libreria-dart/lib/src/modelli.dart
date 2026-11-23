// I dati contenuti in un QR LDI (specifica LDI v1, paragrafo 4).
// Ogni classe sa trasformarsi in JSON (toJson) e ricostruirsi dal JSON (fromJson);
// la funzione [controllaDocumento] dice se i dati rispettano lo standard.
import 'testi.dart';

/// Versione dei dati gestita da questa libreria.
const int versioneDatiLdi = 1;

/// Lunghezza massima delle note dentro il QR (in caratteri).
const int maxCaratteriNote = 100;

/// Autorespiratori ammessi (specifica 4.7).
const Map<String, String> autorespiratoriLdi = {
  'OC-MONO': 'Circuito aperto (ARA), monobombola',
  'OC-BI': 'Circuito aperto (ARA), bibombola',
  'OC-SM': 'Circuito aperto, sidemount',
  'CCR': 'Rebreather a circuito chiuso',
  'SCR': 'Rebreather a circuito semichiuso',
  'ALTRO': 'Altro (vedi note)',
};

/// Motivi dell'immersione ammessi (specifica 4.5).
const Map<String, String> motiviLdi = {
  'ric': 'Ricreativa',
  'cor': 'Corso',
  'soc': 'Attività sociale',
  'pro': 'Prova / battesimo',
  'acc': 'Accompagnamento',
  'alt': 'Altro',
};

final RegExp _miscela = RegExp(r'^(AIR|O2|EAN(\d{2})|TX(\d{1,2})/(\d{1,2}))$');

/// true se il codice della miscela è valido: AIR, O2, EAN22…EAN99, TXoo/hh (ossigeno + elio ≤ 100).
bool miscelaValida(String? codice) {
  if (codice == null) return false;
  final m = _miscela.firstMatch(codice);
  if (m == null) return false;
  if (m.group(2) != null) {
    final o2 = int.parse(m.group(2)!);
    return o2 >= 22 && o2 <= 99;
  }
  if (m.group(3) != null) {
    final o2 = int.parse(m.group(3)!);
    final he = int.parse(m.group(4)!);
    return o2 >= 5 && he >= 1 && o2 + he <= 100;
  }
  return true;
}

/// Numero nel JSON: 30 invece di 30.0, al massimo un decimale.
num _numero(num v) {
  final arrotondato = (v * 10).round() / 10;
  return arrotondato == arrotondato.roundToDouble() ? arrotondato.round() : arrotondato;
}

double? _leggiNumero(Object? v) => v is num ? v.toDouble() : null;
String? _leggiTesto(Object? v) => v is String ? v : null;

Map<String, Object?> _senzaVuoti(Map<String, Object?> m) =>
    Map.fromEntries(m.entries.where((e) => e.value != null && e.value != ''));

/// Chi emette il libretto: diving o associazione (specifica 4.2).
class LdiEmittente {
  final String nome;

  /// 'D' = diving (attività commerciale), 'A' = associazione/club.
  final String tipo;
  final String indirizzo;
  final String? partitaIva;

  /// Dominio del sito dove è pubblicato il file ldi.json, es. "divingportofinoblu.example".
  final String? dominio;

  const LdiEmittente({
    required this.nome,
    required this.tipo,
    required this.indirizzo,
    this.partitaIva,
    this.dominio,
  });

  Map<String, Object?> toJson() =>
      _senzaVuoti({'n': nome, 'tipo': tipo, 'ind': indirizzo, 'piva': partitaIva, 'dom': dominio});

  factory LdiEmittente.fromJson(Map<String, Object?> j) => LdiEmittente(
        nome: _leggiTesto(j['n']) ?? '',
        tipo: _leggiTesto(j['tipo']) ?? '',
        indirizzo: _leggiTesto(j['ind']) ?? '',
        partitaIva: _leggiTesto(j['piva']),
        dominio: _leggiTesto(j['dom']),
      );
}

/// Punto d'immersione (specifica 4.3).
class LdiLuogo {
  final String nome;
  final double? latitudine;
  final double? longitudine;

  const LdiLuogo({required this.nome, this.latitudine, this.longitudine});

  Map<String, Object?> toJson() => _senzaVuoti({
        'n': nome,
        'lat': latitudine == null ? null : double.parse(latitudine!.toStringAsFixed(5)),
        'lon': longitudine == null ? null : double.parse(longitudine!.toStringAsFixed(5)),
      });

  factory LdiLuogo.fromJson(Map<String, Object?> j) => LdiLuogo(
        nome: _leggiTesto(j['n']) ?? '',
        latitudine: _leggiNumero(j['lat']),
        longitudine: _leggiNumero(j['lon']),
      );
}

/// Guida o istruttore (specifica 4.4).
class LdiGuida {
  final String nome;
  final String? qualifica;
  final String? ente;

  /// Responsabile dell'immersione (L. 70/2026 art. 12 c. 3): uno solo.
  final bool responsabile;

  const LdiGuida({required this.nome, this.qualifica, this.ente, this.responsabile = false});

  Map<String, Object?> toJson() =>
      _senzaVuoti({'n': nome, 'br': qualifica, 'e': ente, 'r': responsabile ? 1 : null});

  factory LdiGuida.fromJson(Map<String, Object?> j) => LdiGuida(
        nome: _leggiTesto(j['n']) ?? '',
        qualifica: _leggiTesto(j['br']),
        ente: _leggiTesto(j['e']),
        responsabile: j['r'] == 1,
      );
}

/// Il partecipante a cui è intestato il libretto (specifica 4.5, campo "s").
class LdiPartecipante {
  final String nome;

  /// Data di nascita, AAAA-MM-GG.
  final String dataNascita;
  final String brevetto;
  final String ente;
  final String? numeroBrevetto;

  const LdiPartecipante({
    required this.nome,
    required this.dataNascita,
    required this.brevetto,
    required this.ente,
    this.numeroBrevetto,
  });

  Map<String, Object?> toJson() =>
      _senzaVuoti({'n': nome, 'dn': dataNascita, 'br': brevetto, 'e': ente, 'nb': numeroBrevetto});

  factory LdiPartecipante.fromJson(Map<String, Object?> j) => LdiPartecipante(
        nome: _leggiTesto(j['n']) ?? '',
        dataNascita: _leggiTesto(j['dn']) ?? '',
        brevetto: _leggiTesto(j['br']) ?? '',
        ente: _leggiTesto(j['e']) ?? '',
        numeroBrevetto: _leggiTesto(j['nb']),
      );
}

/// Una riga dell'elenco partecipanti del riepilogo (specifica 4.6).
class LdiVoceRiepilogo {
  final String nome;

  /// id del libretto individuale di quel partecipante.
  final String idLibretto;

  const LdiVoceRiepilogo({required this.nome, required this.idLibretto});

  Map<String, Object?> toJson() => {'n': nome, 'id': idLibretto};

  factory LdiVoceRiepilogo.fromJson(Map<String, Object?> j) =>
      LdiVoceRiepilogo(nome: _leggiTesto(j['n']) ?? '', idLibretto: _leggiTesto(j['id']) ?? '');
}

/// Parte comune ai due tipi di QR (specifica 4.1).
sealed class LdiDocumento {
  /// 'lib' (libretto individuale) o 'reg' (riepilogo immersione).
  String get tipo;
  final String idImmersione;
  final String emesso;
  final LdiEmittente emittente;
  final String inizio;
  final String fine;
  final LdiLuogo luogo;
  final List<LdiGuida> guide;
  final double profonditaPianificata;
  final double profonditaRaggiunta;

  /// Estensioni libere (campo "x"): chi non le conosce le ignora.
  final Map<String, Object?>? estensioni;

  const LdiDocumento({
    required this.idImmersione,
    required this.emesso,
    required this.emittente,
    required this.inizio,
    required this.fine,
    required this.luogo,
    required this.guide,
    required this.profonditaPianificata,
    required this.profonditaRaggiunta,
    this.estensioni,
  });

  Map<String, Object?> _comuni() => {
        't': tipo,
        'v': versioneDatiLdi,
        'imm': idImmersione,
        'em': emesso,
        'c': emittente.toJson(),
        'ini': inizio,
        'fin': fine,
        'l': luogo.toJson(),
        'g': [for (final g in guide) g.toJson()],
        'pp': _numero(profonditaPianificata),
        'pr': _numero(profonditaRaggiunta),
      };

  Map<String, Object?> toJson();

  /// Ricostruisce il documento dal JSON. Lancia [FormatException] se il tipo è sconosciuto
  /// o la struttura è sbagliata (per il controllo dei singoli campi usare [controllaDocumento]).
  static LdiDocumento fromJson(Map<String, Object?> j) {
    switch (j['t']) {
      case 'lib':
        return LdiLibretto.fromJson(j);
      case 'reg':
        return LdiRiepilogo.fromJson(j);
      default:
        throw FormatException('Tipo di documento LDI sconosciuto: ${j['t']}');
    }
  }
}

Map<String, Object?> _mappa(Object? v, String campo) {
  if (v is Map) return v.cast<String, Object?>();
  throw FormatException('Il campo "$campo" manca o non è un oggetto');
}

List<Map<String, Object?>> _lista(Object? v, String campo) {
  if (v is List) return [for (final e in v) _mappa(e, campo)];
  throw FormatException('Il campo "$campo" manca o non è una lista');
}

/// Libretto individuale: una scheda per partecipante (t = "lib").
class LdiLibretto extends LdiDocumento {
  @override
  String get tipo => 'lib';
  final String id;
  final int revisione;
  final String? sostituisce;
  final LdiPartecipante partecipante;
  final String motivo;
  final String? corso;
  final String autorespiratore;
  final String miscela;
  final String? note;

  /// Bozza 4: se presente, questo documento ANNULLA il libretto [sostituisce]; il testo è il motivo.
  final String? annullamento;

  bool get annullato => annullamento != null;

  const LdiLibretto({
    required this.id,
    required super.idImmersione,
    this.revisione = 1,
    this.sostituisce,
    required super.emesso,
    required super.emittente,
    required super.inizio,
    required super.fine,
    required super.luogo,
    required super.guide,
    required super.profonditaPianificata,
    required super.profonditaRaggiunta,
    required this.partecipante,
    required this.motivo,
    this.corso,
    required this.autorespiratore,
    required this.miscela,
    this.note,
    this.annullamento,
    super.estensioni,
  });

  @override
  Map<String, Object?> toJson() => _senzaVuoti({
        ..._comuni(),
        'id': id,
        'rev': revisione,
        'sost': sostituisce,
        's': partecipante.toJson(),
        'mot': motivo,
        'cor': corso,
        'ar': autorespiratore,
        'mx': miscela,
        'note': note,
        'ann': annullamento,
        'x': estensioni,
      });

  factory LdiLibretto.fromJson(Map<String, Object?> j) => LdiLibretto(
        id: _leggiTesto(j['id']) ?? '',
        idImmersione: _leggiTesto(j['imm']) ?? '',
        revisione: j['rev'] is int ? j['rev'] as int : 0,
        sostituisce: _leggiTesto(j['sost']),
        emesso: _leggiTesto(j['em']) ?? '',
        emittente: LdiEmittente.fromJson(_mappa(j['c'], 'c')),
        inizio: _leggiTesto(j['ini']) ?? '',
        fine: _leggiTesto(j['fin']) ?? '',
        luogo: LdiLuogo.fromJson(_mappa(j['l'], 'l')),
        guide: [for (final g in _lista(j['g'], 'g')) LdiGuida.fromJson(g)],
        profonditaPianificata: _leggiNumero(j['pp']) ?? -1,
        profonditaRaggiunta: _leggiNumero(j['pr']) ?? -1,
        partecipante: LdiPartecipante.fromJson(_mappa(j['s'], 's')),
        motivo: _leggiTesto(j['mot']) ?? '',
        corso: _leggiTesto(j['cor']),
        autorespiratore: _leggiTesto(j['ar']) ?? '',
        miscela: _leggiTesto(j['mx']) ?? '',
        note: _leggiTesto(j['note']),
        annullamento: _leggiTesto(j['ann']),
        estensioni: j['x'] is Map ? (j['x'] as Map).cast<String, Object?>() : null,
      );
}

/// Riepilogo dell'immersione per il logbook cumulativo (t = "reg").
class LdiRiepilogo extends LdiDocumento {
  @override
  String get tipo => 'reg';
  final List<LdiVoceRiepilogo> partecipanti;

  /// Numero totale dei partecipanti (anche se l'elenco è diviso su più QR).
  final int numeroPartecipanti;

  /// Pagina, es. "1/2", quando i partecipanti sono divisi su più QR.
  final String? pagina;

  const LdiRiepilogo({
    required super.idImmersione,
    required super.emesso,
    required super.emittente,
    required super.inizio,
    required super.fine,
    required super.luogo,
    required super.guide,
    required super.profonditaPianificata,
    required super.profonditaRaggiunta,
    required this.partecipanti,
    required this.numeroPartecipanti,
    this.pagina,
    super.estensioni,
  });

  @override
  Map<String, Object?> toJson() => _senzaVuoti({
        ..._comuni(),
        'p': [for (final p in partecipanti) p.toJson()],
        'np': numeroPartecipanti,
        'pag': pagina,
        'x': estensioni,
      });

  factory LdiRiepilogo.fromJson(Map<String, Object?> j) => LdiRiepilogo(
        idImmersione: _leggiTesto(j['imm']) ?? '',
        emesso: _leggiTesto(j['em']) ?? '',
        emittente: LdiEmittente.fromJson(_mappa(j['c'], 'c')),
        inizio: _leggiTesto(j['ini']) ?? '',
        fine: _leggiTesto(j['fin']) ?? '',
        luogo: LdiLuogo.fromJson(_mappa(j['l'], 'l')),
        guide: [for (final g in _lista(j['g'], 'g')) LdiGuida.fromJson(g)],
        profonditaPianificata: _leggiNumero(j['pp']) ?? -1,
        profonditaRaggiunta: _leggiNumero(j['pr']) ?? -1,
        partecipanti: [for (final p in _lista(j['p'], 'p')) LdiVoceRiepilogo.fromJson(p)],
        numeroPartecipanti: j['np'] is int ? j['np'] as int : -1,
        pagina: _leggiTesto(j['pag']),
        estensioni: j['x'] is Map ? (j['x'] as Map).cast<String, Object?>() : null,
      );
}

/// Esito del controllo dei campi: [errori] rendono il documento non valido, [avvisi] sono solo segnalazioni.
class LdiControllo {
  final List<String> errori;
  final List<String> avvisi;
  const LdiControllo(this.errori, this.avvisi);
  bool get valido => errori.isEmpty;
}

/// Controlla che un documento rispetti la specifica LDI v1.
/// [adesso] serve ai test; di norma è l'ora attuale.
LdiControllo controllaDocumento(LdiDocumento d, {DateTime? adesso}) {
  final err = <String>[];
  final avv = <String>[];
  void serve(bool ok, String messaggio) {
    if (!ok) err.add(messaggio);
  }

  serve(formatoIdLdi.hasMatch(d.idImmersione), 'Codice dell\'immersione non valido');
  final em = leggiDataOra(d.emesso);
  final ini = leggiDataOra(d.inizio);
  final fin = leggiDataOra(d.fine);
  serve(em != null, 'Data di emissione mancante o non valida');
  serve(ini != null, 'Orario di inizio mancante o non valido');
  serve(fin != null, 'Orario di fine mancante o non valido');

  final c = d.emittente;
  serve(c.nome.trim().isNotEmpty, 'Manca il nome dell\'emittente');
  serve(c.tipo == 'D' || c.tipo == 'A', 'Tipo di emittente non valido (D o A)');
  serve(c.indirizzo.trim().isNotEmpty, 'Manca l\'indirizzo dell\'emittente');
  if (c.dominio != null) {
    serve(RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(c.dominio!),
        'Dominio dell\'emittente non valido (es. divingesempio.it)');
  }

  serve(d.luogo.nome.trim().isNotEmpty, 'Manca il luogo dell\'immersione');
  final lat = d.luogo.latitudine, lon = d.luogo.longitudine;
  if (lat != null || lon != null) {
    serve(lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180, 'Coordinate del luogo non valide');
  }

  serve(d.guide.isNotEmpty, 'Serve almeno una guida o un istruttore');
  serve(d.guide.every((g) => g.nome.trim().isNotEmpty), 'Una guida o un istruttore non ha il nome');
  final responsabili = d.guide.where((g) => g.responsabile).length;
  serve(responsabili == 1, 'Deve esserci un solo responsabile dell\'immersione');

  serve(d.profonditaPianificata > 0, 'Profondità pianificata mancante');
  serve(d.profonditaRaggiunta >= 0, 'Profondità raggiunta mancante');

  if (ini != null && fin != null && !fin.isAfter(ini)) avv.add('L\'orario di fine non è dopo quello di inizio');
  final ora = adesso ?? DateTime.now();
  if (em != null && em.isAfter(ora.add(const Duration(minutes: 10)))) avv.add('La data di emissione è nel futuro');
  if (d.profonditaRaggiunta > 350) avv.add('Profondità raggiunta insolita (oltre 350 m)');

  switch (d) {
    case LdiLibretto l:
      serve(formatoIdLdi.hasMatch(l.id), 'Codice del libretto non valido');
      serve(l.revisione >= 1, 'Numero di revisione non valido');
      if (l.sostituisce != null) serve(formatoIdLdi.hasMatch(l.sostituisce!), 'Codice del libretto sostituito non valido');
      final s = l.partecipante;
      serve(s.nome.trim().isNotEmpty, 'Manca il nome del partecipante');
      serve(leggiData(s.dataNascita) != null, 'Data di nascita del partecipante mancante o non valida');
      // bozza 4: chi fa una prova / battesimo può non avere ancora un brevetto
      if (l.motivo != 'pro') {
        serve(s.brevetto.trim().isNotEmpty, 'Manca il brevetto del partecipante');
        serve(s.ente.trim().isNotEmpty, 'Manca l\'ente del brevetto del partecipante');
      }
      if (l.annullamento != null) {
        serve(l.sostituisce != null, 'Un annullamento deve indicare il libretto annullato (sost)');
        serve(l.annullamento!.trim().isNotEmpty, 'Manca il motivo dell\'annullamento');
        serve(l.annullamento!.runes.length <= maxCaratteriNote,
            'Motivo dell\'annullamento troppo lungo: massimo $maxCaratteriNote caratteri');
      }
      serve(motiviLdi.containsKey(l.motivo), 'Motivo dell\'immersione non valido');
      serve(autorespiratoriLdi.containsKey(l.autorespiratore), 'Autorespiratore non valido');
      serve(miscelaValida(l.miscela), 'Miscela non valida (es. AIR, EAN32, TX21/35, O2)');
      if (l.note != null) {
        serve(l.note!.runes.length <= maxCaratteriNote, 'Note troppo lunghe: massimo $maxCaratteriNote caratteri nel QR');
      }
    case LdiRiepilogo r:
      serve(r.partecipanti.isNotEmpty, 'L\'elenco dei partecipanti è vuoto');
      serve(r.partecipanti.every((p) => p.nome.trim().isNotEmpty && formatoIdLdi.hasMatch(p.idLibretto)),
          'Un partecipante dell\'elenco non ha nome o codice del libretto valido');
      if (r.pagina == null) {
        serve(r.numeroPartecipanti == r.partecipanti.length, 'Il numero dei partecipanti non corrisponde all\'elenco');
      } else {
        serve(RegExp(r'^\d+/\d+$').hasMatch(r.pagina!), 'Pagina non valida (es. 1/2)');
        serve(r.numeroPartecipanti >= r.partecipanti.length, 'Il numero dei partecipanti è minore dell\'elenco');
      }
  }
  return LdiControllo(err, avv);
}
