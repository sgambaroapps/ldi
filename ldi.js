// Lettura e verifica di un QR LDI (Libretto Digitale Immersioni), specifica v2 (legge anche la v1), paragrafo 7.
// Porta in JavaScript della libreria di riferimento in Dart (packages/ldi di «Nautilus - Registro Immersioni"):
// stessi controlli, stessi esiti, stessi motivi. Tutto avviene nel browser: nessun dato esce dal dispositivo.
//
// testo del QR = "LDI1:" + Base45( zlib( [versione 1][chiave pubblica 32][firma 64][dati JSON] ) )
// firma        = Ed25519( chiave privata, "LDI1" + dati JSON )
import { verifyAsync } from './lib/ed25519.js';

export const PREFISSO = 'LDI1:';
const VERSIONE_PACCHETTO = 1;
const VERSIONE_DATI = 2; // legge la 1 e la 2 (specifica 4.9)
const MAX_CARATTERI_QR = 7000;
const MAX_BYTE_DECOMPRESSI = 16 * 1024;
const MAX_NOTE = 100;
const CONTESTO = new TextEncoder().encode('LDI1');

// Codici dei motivi (le spiegazioni sono nelle sei lingue, in testi.js).
export const MOTIVO = {
  VERSIONE: 'versione',        // È un libretto LDI di una versione più recente: aggiorna il programma.
  NON_LDI: 'nonLdi',           // Questo QR non è un libretto delle immersioni LDI.
  TROPPO_GRANDE: 'grande',     // Il QR è troppo grande per essere un libretto LDI.
  DANNEGGIATO: 'danneggiato',  // Il QR è danneggiato o è stato modificato.
  INCOMPLETO: 'incompleto',    // Il QR è incompleto.
  FIRMA: 'firma',              // La firma non corrisponde: i dati sono stati modificati dopo l'emissione.
  ILLEGGIBILE: 'illeggibile',  // Il QR è firmato ma i dati non sono leggibili.
  MANCANO_DATI: 'mancano',     // Il QR è firmato ma mancano dati obbligatori.
};

// Codici degli avvisi (non cambiano l'esito).
export const AVVISO = { ORARI: 'orari', FUTURO: 'futuro', PROFONDITA: 'profondita' };

export const AUTORESPIRATORI = ['OC-MONO', 'OC-BI', 'OC-SM', 'CCR', 'SCR', 'ALTRO'];
export const MOTIVI = ['ric', 'cor', 'tec', 'soc', 'pro', 'acc', 'alt']; // 'tec' solo v2
export const MODALITA = ['gui', 'org']; // solo v2: guidata, organizzata

// ---------------------------------------------------------------- codifiche

const ALFABETO45 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:';

/** Base45 (RFC 9285). Lancia un errore se il testo non è Base45 valido. */
export function base45Decodifica(testo) {
  const valori = [];
  for (const car of testo) {
    const v = ALFABETO45.indexOf(car);
    if (v < 0) throw new Error(`Carattere non valido in Base45: "${car}"`);
    valori.push(v);
  }
  if (valori.length % 3 === 1) throw new Error('Lunghezza non valida per Base45');
  const out = [];
  for (let i = 0; i < valori.length; i += 3) {
    if (i + 2 < valori.length) {
      const n = valori[i] + valori[i + 1] * 45 + valori[i + 2] * 45 * 45;
      if (n > 0xffff) throw new Error('Gruppo Base45 fuori intervallo');
      out.push(n >> 8, n & 0xff);
    } else {
      const n = valori[i] + valori[i + 1] * 45;
      if (n > 0xff) throw new Error('Gruppo Base45 fuori intervallo');
      out.push(n);
    }
  }
  return new Uint8Array(out);
}

/** zlib (RFC 1950) con un tetto alla dimensione, contro i QR costruiti apposta. */
async function zlibDecomprimi(byte) {
  const flusso = new Blob([byte]).stream().pipeThrough(new DecompressionStream('deflate'));
  const lettore = flusso.getReader();
  const pezzi = [];
  let totale = 0;
  for (;;) {
    const { done, value } = await lettore.read();
    if (done) break;
    totale += value.length;
    if (totale > MAX_BYTE_DECOMPRESSI) {
      await lettore.cancel();
      throw new Error('Dati decompressi troppo grandi');
    }
    pezzi.push(value);
  }
  const out = new Uint8Array(totale);
  let pos = 0;
  for (const p of pezzi) { out.set(p, pos); pos += p.length; }
  return out;
}

const ALFABETO32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function base32(byte) {
  let out = '', buffer = 0, bit = 0;
  for (const b of byte) {
    buffer = (buffer << 8) | b;
    bit += 8;
    while (bit >= 5) {
      out += ALFABETO32[(buffer >> (bit - 5)) & 31];
      bit -= 5;
    }
    buffer &= (1 << bit) - 1;
  }
  if (bit > 0) out += ALFABETO32[(buffer << (5 - bit)) & 31];
  return out;
}

/** Codice di controllo della chiave (specifica 5): primi 10 byte dello SHA-256, Base32, gruppi di 4. */
export async function improntaLdi(chiavePubblica) {
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', chiavePubblica));
  const t = base32(hash.slice(0, 10));
  return t.match(/.{1,4}/g).join('-');
}

// ---------------------------------------------------------------- date

const RE_ID = /^[A-Za-z0-9_-]{16}$/;
const RE_DATA_ORA = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})$/;
const RE_DATA = /^\d{4}-\d{2}-\d{2}$/;

/** Una data AAAA-MM-GG che esiste davvero (niente 31 febbraio). */
export function dataValida(s) {
  if (typeof s !== 'string' || !RE_DATA.test(s)) return false;
  const [a, m, g] = s.split('-').map(Number);
  const d = new Date(Date.UTC(a, m - 1, g));
  return d.getUTCFullYear() === a && d.getUTCMonth() === m - 1 && d.getUTCDate() === g;
}

/** Data-ora LDI → millisecondi, oppure null se il formato non è valido. */
export function leggiDataOra(s) {
  if (typeof s !== 'string' || !RE_DATA_ORA.test(s)) return null;
  if (!dataValida(s.slice(0, 10))) return null;
  if (Number(s.slice(11, 13)) > 23 || Number(s.slice(14, 16)) > 59) return null;
  const ms = Date.parse(s);
  return Number.isNaN(ms) ? null : ms;
}

const RE_MISCELA = /^(AIR|O2|EAN(\d{2})|TX(\d{1,2})\/(\d{1,2}))$/;

export function miscelaValida(c) {
  if (typeof c !== 'string') return false;
  const m = RE_MISCELA.exec(c);
  if (!m) return false;
  if (m[2] !== undefined) { const o2 = +m[2]; return o2 >= 22 && o2 <= 99; }
  if (m[3] !== undefined) { const o2 = +m[3], he = +m[4]; return o2 >= 5 && he >= 1 && o2 + he <= 100; }
  return true;
}

// ---------------------------------------------------------------- controllo dei campi

const testo = (v) => (typeof v === 'string' ? v : '');
const pieno = (v) => testo(v).trim() !== '';
const numero = (v, def) => (typeof v === 'number' && Number.isFinite(v) ? v : def);
const lunghezza = (s) => [...s].length;

function oggetto(v, campo) {
  if (v && typeof v === 'object' && !Array.isArray(v)) return v;
  throw new Error(`Il campo "${campo}" manca o non è un oggetto`);
}

function lista(v, campo) {
  if (Array.isArray(v)) return v.map((e) => oggetto(e, campo));
  throw new Error(`Il campo "${campo}" manca o non è una lista`);
}

/** Struttura minima (come i fromJson della libreria Dart): se manca, i dati «non sono leggibili». */
function struttura(d) {
  if (d.t !== 'lib' && d.t !== 'reg') throw new Error(`Tipo di documento LDI sconosciuto: ${d.t}`);
  oggetto(d.c, 'c');
  oggetto(d.l, 'l');
  lista(d.g, 'g');
  if (d.t === 'lib') oggetto(d.s, 's');
  else lista(d.p, 'p');
}

/** Errori (il documento non vale) e avvisi (solo segnalazioni), come controllaDocumento() della libreria. */
export function controllaDocumento(d, adesso = Date.now()) {
  const err = [], avv = [];
  const serve = (ok, msg) => { if (!ok) err.push(msg); };

  serve(d.v === 1 || d.v === 2, 'Versione dei dati non valida');
  const v1 = d.v === 1;
  serve(RE_ID.test(testo(d.imm)), "Codice dell'immersione non valido");
  const em = leggiDataOra(d.em), ini = leggiDataOra(d.ini), fin = leggiDataOra(d.fin);
  serve(em !== null, 'Data di emissione mancante o non valida');
  serve(ini !== null, 'Orario di inizio mancante o non valido');
  serve(fin !== null, 'Orario di fine mancante o non valido');

  const c = d.c;
  serve(pieno(c.n), "Manca il nome dell'emittente");
  serve(c.tipo === 'D' || c.tipo === 'A', 'Tipo di emittente non valido (D o A)');
  serve(pieno(c.ind), "Manca l'indirizzo dell'emittente");
  if (typeof c.dom === 'string') serve(/^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(c.dom), "Dominio dell'emittente non valido");

  serve(pieno(d.l.n), "Manca il luogo dell'immersione");
  const lat = numero(d.l.lat, null), lon = numero(d.l.lon, null);
  if (lat !== null || lon !== null) {
    serve(lat !== null && lon !== null && Math.abs(lat) <= 90 && Math.abs(lon) <= 180, 'Coordinate del luogo non valide');
  }

  const g = d.g;
  serve(g.every((x) => pieno(x.n)), 'Una guida o un istruttore non ha il nome');
  if (v1) {
    // v1: almeno una guida e un solo responsabile dentro "g"
    serve(g.length > 0, 'Serve almeno una guida o un istruttore');
    serve(g.filter((x) => x.r === 1).length === 1, "Deve esserci un solo responsabile dell'immersione");
  } else {
    // v2: il responsabile sta solo nel riepilogo ("ru"), mai tra le guide
    serve(g.every((x) => x.r === undefined), 'Nella versione 2 il responsabile non si segna tra le guide (r)');
  }

  const pp = numero(d.pp, -1), pr = numero(d.pr, -1);
  serve(pp > 0, 'Profondità pianificata mancante');
  serve(pr >= 0, 'Profondità raggiunta mancante');

  if (ini !== null && fin !== null && !(fin > ini)) avv.push(AVVISO.ORARI);
  if (em !== null && em > adesso + 10 * 60 * 1000) avv.push(AVVISO.FUTURO);
  if (pr > 350) avv.push(AVVISO.PROFONDITA);

  if (d.t === 'lib') {
    serve(RE_ID.test(testo(d.id)), 'Codice del libretto non valido');
    serve(Number.isInteger(d.rev) && d.rev >= 1, 'Numero di revisione non valido');
    if (typeof d.sost === 'string') serve(RE_ID.test(d.sost), 'Codice del libretto sostituito non valido');
    const s = d.s;
    serve(pieno(s.n), 'Manca il nome del partecipante');
    serve(dataValida(s.dn), 'Data di nascita del partecipante mancante o non valida');
    if (d.mot !== 'pro') {
      serve(pieno(s.br), 'Manca il brevetto del partecipante');
      serve(pieno(s.e), "Manca l'ente del brevetto del partecipante");
    }
    if (typeof d.ann === 'string') {
      serve(typeof d.sost === 'string', 'Un annullamento deve indicare il libretto annullato (sost)');
      serve(d.ann.trim() !== '', "Manca il motivo dell'annullamento");
      serve(lunghezza(d.ann) <= MAX_NOTE, "Motivo dell'annullamento troppo lungo");
    }
    serve(MOTIVI.includes(d.mot) && !(v1 && d.mot === 'tec'), "Motivo dell'immersione non valido");
    if (!v1 && d.mot !== 'acc') {
      // v2: guidata (con la guida seguita) oppure organizzata (con i compagni)
      serve(MODALITA.includes(d.mod), "Manca se l'immersione è guidata o organizzata");
      const con = Array.isArray(d.con) ? d.con : [];
      serve(con.length > 0 && con.every(pieno), d.mod === 'gui' ? 'Manca la guida seguita' : 'Mancano i compagni di coppia o di terzetto');
      if (d.mod === 'gui') serve(con.length <= 1, "In un'immersione guidata si indica una sola guida");
    }
    serve(AUTORESPIRATORI.includes(d.ar), 'Autorespiratore non valido');
    serve(miscelaValida(d.mx), 'Miscela non valida');
    if (typeof d.note === 'string') serve(lunghezza(d.note) <= MAX_NOTE, 'Note troppo lunghe');
  } else {
    const p = lista(d.p, 'p');
    serve(p.length > 0, "L'elenco dei partecipanti è vuoto");
    serve(p.every((x) => pieno(x.n) && RE_ID.test(testo(x.id))), 'Un partecipante non ha nome o codice valido');
    const np = Number.isInteger(d.np) ? d.np : -1;
    if (typeof d.pag !== 'string') {
      serve(np === p.length, 'Il numero dei partecipanti non corrisponde all\'elenco');
    } else {
      serve(/^\d+\/\d+$/.test(d.pag), 'Pagina non valida (es. 1/2)');
      serve(np >= p.length, "Il numero dei partecipanti è minore dell'elenco");
    }
    if (!v1) {
      serve(d.ru !== null && typeof d.ru === 'object' && pieno(d.ru.n), "Manca il responsabile dell'uscita");
      if (d.ps != null) serve(typeof d.ps === 'object' && pieno(d.ps.n), 'Manca il nome del responsabile del primo soccorso');
    }
  }
  return { errori: err, avvisi: avv };
}

// ---------------------------------------------------------------- lettura

const nonValida = (testoQr, motivo, dettagli = []) => ({ esito: 'rosso', testo: testoQr, motivo, dettagli, avvisi: [] });

/**
 * Legge e verifica il testo di un QR. Non lancia eccezioni.
 * Restituisce { esito: 'verde' | 'giallo' | 'rosso', motivo?, dettagli, avvisi, dati?, codice?, testo }.
 * Con il rosso non c'è nessun dato: potrebbero essere stati alterati.
 */
export async function leggiLdi(testoQr, adesso = Date.now()) {
  const t = String(testoQr ?? '').trim();
  if (!t.startsWith(PREFISSO)) {
    return nonValida(t, /^LDI\d+:/.test(t) ? MOTIVO.VERSIONE : MOTIVO.NON_LDI);
  }
  if (t.length > MAX_CARATTERI_QR) return nonValida(t, MOTIVO.TROPPO_GRANDE);

  let pacchetto;
  try {
    pacchetto = await zlibDecomprimi(base45Decodifica(t.slice(PREFISSO.length)));
  } catch (e) {
    return nonValida(t, MOTIVO.DANNEGGIATO, [String(e && e.message || e)]);
  }
  if (pacchetto.length < 1 + 32 + 64 + 2) return nonValida(t, MOTIVO.INCOMPLETO);
  if (pacchetto[0] !== VERSIONE_PACCHETTO) return nonValida(t, MOTIVO.VERSIONE);

  const chiave = pacchetto.slice(1, 33);
  const firma = pacchetto.slice(33, 97);
  const dati = pacchetto.slice(97);
  const messaggio = new Uint8Array(CONTESTO.length + dati.length);
  messaggio.set(CONTESTO);
  messaggio.set(dati, CONTESTO.length);

  let firmaOk = false;
  try {
    // zip215: false = regole severe dell'RFC 8032, come la libreria di riferimento
    firmaOk = await verifyAsync(firma, messaggio, chiave, { zip215: false });
  } catch {
    firmaOk = false;
  }
  if (!firmaOk) return nonValida(t, MOTIVO.FIRMA);

  let d;
  try {
    d = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(dati));
    if (!d || typeof d !== 'object' || Array.isArray(d)) throw new Error('I dati non sono un oggetto JSON');
    if (!Number.isInteger(d.v) || d.v > VERSIONE_DATI) return nonValida(t, MOTIVO.VERSIONE);
    struttura(d);
  } catch (e) {
    return nonValida(t, MOTIVO.ILLEGGIBILE, [String(e && e.message || e)]);
  }

  const controllo = controllaDocumento(d, adesso);
  if (controllo.errori.length) return nonValida(t, MOTIVO.MANCANO_DATI, controllo.errori);

  return {
    esito: d.t === 'lib' && typeof d.ann === 'string' ? 'giallo' : 'verde',
    testo: t,
    dati: d,
    codice: await improntaLdi(chiave),
    avvisi: controllo.avvisi,
    dettagli: [],
  };
}
