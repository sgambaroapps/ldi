// Pagina di verifica dei libretti LDI: interfaccia (lingue, fotocamera, file, esiti).
// I dati del QR non escono mai dal dispositivo: niente richieste di rete con i dati, niente statistiche.
import { leggiLdi } from './ldi.js';
import { LINGUE, NOMI_LINGUE, LOCALE, TESTI } from './testi.js';

const $ = (id) => document.getElementById(id);
let lingua = 'en';
let letture = [];          // ultimi esiti mostrati (si ridisegnano quando cambia la lingua)
let ultimoStato = null;    // { chiave, valori, errore }

// ---------------------------------------------------------------- lingua

function T(chiave, valori = {}) {
  const v = chiave.split('.').reduce((o, k) => (o == null ? o : o[k]), TESTI[lingua]);
  const testo = v == null ? chiave.split('.').reduce((o, k) => (o == null ? o : o[k]), TESTI.it) : v;
  return String(testo ?? chiave).replace(/\{(\w+)\}/g, (_, k) => (valori[k] ?? ''));
}

function scegliLinguaIniziale() {
  try {
    const salvata = localStorage.getItem('ldi-lingua');
    if (LINGUE.includes(salvata)) return salvata;
  } catch { /* archivio del browser non disponibile: si va avanti */ }
  for (const l of navigator.languages || [navigator.language || 'en']) {
    const due = String(l).slice(0, 2).toLowerCase();
    if (LINGUE.includes(due)) return due;
  }
  return 'en';
}

function impostaLingua(l) {
  lingua = l;
  try { localStorage.setItem('ldi-lingua', l); } catch { /* niente */ }
  document.documentElement.lang = l;
  document.title = T('titoloPagina');
  document.querySelectorAll('[data-t]').forEach((n) => { n.textContent = T(n.dataset.t); });
  $('testoQr').placeholder = T('segnapostoTesto');
  document.querySelectorAll('#lingue button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.l === l)));
  if (ultimoStato) mostraStato(ultimoStato.chiave, ultimoStato.valori, ultimoStato.errore);
  disegnaEsiti();
}

function preparaLingue() {
  const nav = $('lingue');
  for (const l of LINGUE) {
    const b = document.createElement('button');
    b.type = 'button';
    b.dataset.l = l;
    b.lang = l;
    b.textContent = NOMI_LINGUE[l];
    b.addEventListener('click', () => impostaLingua(l));
    nav.append(b);
  }
}

// ---------------------------------------------------------------- piccoli aiuti

/** Crea un elemento: i testi passano SEMPRE da textContent (i dati del QR non sono mai HTML). */
function el(tag, attributi = {}, ...figli) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attributi)) {
    if (v == null || v === false) continue;
    if (k === 'class') n.className = v;
    else n.setAttribute(k, v);
  }
  for (const f of figli.flat()) {
    if (f == null || f === false) continue;
    n.append(f instanceof Node ? f : document.createTextNode(String(f)));
  }
  return n;
}

function mostraStato(chiave, valori = {}, errore = false) {
  ultimoStato = chiave ? { chiave, valori, errore } : null;
  const s = $('stato');
  if (!chiave) { s.hidden = true; return; }
  s.hidden = false;
  s.className = 'stato' + (errore ? ' errore' : '');
  s.textContent = T(chiave, valori);
}

const piena = (v) => typeof v === 'string' && v.trim() !== '';

/** "2026-11-18T09:35+01:00" → parti, senza convertire nel fuso di chi guarda (l'ora è quella del luogo). */
function parti(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2})?(Z|[+-]\d{2}:\d{2})$/.exec(s || '');
  if (!m) return null;
  return { a: +m[1], me: +m[2], g: +m[3], h: m[4], mi: m[5], fuso: m[6] === 'Z' ? '+00:00' : m[6], giorno: `${m[1]}-${m[2]}-${m[3]}` };
}

function data(a, me, g) {
  return new Intl.DateTimeFormat(LOCALE[lingua], { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' })
    .format(new Date(Date.UTC(a, me - 1, g)));
}

const dataSemplice = (s) => { const [a, me, g] = s.split('-').map(Number); return data(a, me, g); };
const ora = (p) => `${p.h}:${p.mi}`;
const metri = (v) => `${new Intl.NumberFormat(LOCALE[lingua], { maximumFractionDigits: 1 }).format(v)} m`;

function dataOraCompleta(s) {
  const p = parti(s);
  return p ? `${data(p.a, p.me, p.g)}, ${ora(p)} (UTC${p.fuso})` : s;
}

function miscela(c) {
  if (c === 'AIR') return T('aria');
  if (c === 'O2') return T('ossigeno');
  let m = /^EAN(\d{2})$/.exec(c);
  if (m) return T('nitrox', { o2: m[1] });
  m = /^TX(\d{1,2})\/(\d{1,2})$/.exec(c);
  if (m) return T('trimix', { o2: m[1], he: m[2] });
  return c;
}

function riquadro(titolo, righe, classe = '') {
  const dl = el('dl');
  for (const [etichetta, valore] of righe) {
    if (valore == null || valore === '') continue;
    dl.append(el('dt', {}, etichetta), el('dd', {}, valore));
  }
  return el('div', { class: 'riquadro ' + classe }, el('h3', {}, titolo), dl);
}

// ---------------------------------------------------------------- esiti

const ICONE = {
  verde: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>',
  giallo: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 12h12"/></svg>',
  rosso: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
};

function disegnaEsito(r, indice, totale) {
  const box = el('article', { class: 'esito ' + r.esito });
  if (totale > 1) box.append(el('div', { class: 'numero' }, T('qr', { n: indice + 1 })));

  const bollo = el('div', { class: 'bollo', 'aria-hidden': 'true' });
  bollo.innerHTML = ICONE[r.esito]; // icona fissa, nessun dato del QR
  const testi = el('div');
  if (r.esito === 'verde') {
    testi.append(el('h2', {}, T('verdeTitolo')), el('p', {}, T('verdeTesto')));
  } else if (r.esito === 'giallo') {
    testi.append(el('h2', {}, T('gialloTitolo')), el('p', {}, T('gialloTesto', { motivo: r.dati.ann })));
  } else {
    testi.append(el('h2', {}, T('rossoTitolo')), el('p', {}, T('rossoTesto')));
    if (r.motivo) testi.append(el('p', { class: 'motivo' }, T('motivi.' + r.motivo)));
  }
  box.append(el('div', { class: 'testata' }, bollo, testi));

  // Con il rosso NESSUN dato: potrebbero essere stati alterati.
  if (r.esito === 'rosso') return box;

  const d = r.dati;
  const corpo = el('div', { class: 'corpo' });
  corpo.append(el('div', { class: 'codice' },
    el('span', { class: 'etichetta' }, T('codice')),
    el('span', { class: 'valore' }, r.codice),
    el('p', { class: 'nota' }, T('nota', { nome: d.c.n }))));

  if (r.avvisi.length) {
    corpo.append(el('div', { class: 'avvisi' }, el('b', {}, T('avvisiTitolo')),
      el('ul', {}, r.avvisi.map((a) => el('li', {}, T('avvisi.' + a))))));
  }
  if (r.esito === 'giallo') corpo.append(el('p', { class: 'sottotitolo' }, T('datiAnnullato')));
  corpo.append(disegnaDati(d));
  box.append(corpo);
  return box;
}

function disegnaDati(d) {
  const griglia = el('div', { class: 'riquadri' });
  const c = d.c;
  // Il sito e l'indirizzo si mostrano come dati, mai come link o contatto da usare (NOTA).
  griglia.append(riquadro(T('rDiving'), [
    [T('nome'), c.n],
    [T('tipo'), c.tipo === 'D' ? T('tipoD') : T('tipoA')],
    [T('indirizzo'), c.ind],
    [T('piva'), c.piva],
    [T('sito'), c.dom],
  ]));

  const ini = parti(d.ini), fin = parti(d.fin);
  const stessoGiorno = ini && fin && ini.giorno === fin.giorno && ini.fuso === fin.fuso;
  const luogo = el('span', {}, d.l.n);
  if (typeof d.l.lat === 'number' && typeof d.l.lon === 'number') {
    const lat = d.l.lat.toFixed(5), lon = d.l.lon.toFixed(5);
    luogo.append(el('br'), `${lat}, ${lon} · `,
      el('a', { href: `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lon}#map=15/${lat}/${lon}`, target: '_blank', rel: 'noopener noreferrer' }, T('mappa')));
  }
  let tipo = T('motiviImm.' + d.mot);
  if (d.t === 'reg') tipo = null;
  griglia.append(riquadro(T('rImmersione'), [
    [T('data'), ini ? data(ini.a, ini.me, ini.g) : d.ini],
    [T('inizio'), ini ? `${ora(ini)} (UTC${ini.fuso})` : d.ini],
    [T('fine'), stessoGiorno ? `${ora(fin)} (UTC${fin.fuso})` : dataOraCompleta(d.fin)],
    [T('luogo'), luogo],
    [T('pp'), metri(d.pp)],
    [T('pr'), metri(d.pr)],
    [T('motivo'), tipo],
    [T('corso'), piena(d.cor) ? d.cor : null],
    [T('modalita'), d.t === 'lib' && piena(d.mod) ? T('modalitaV.' + d.mod) : null],
    [T(d.mod === 'gui' ? 'conGuida' : 'conCompagni'), d.t === 'lib' && Array.isArray(d.con) ? d.con.join(', ') : null],
    [T('emesso'), dataOraCompleta(d.em)],
  ]));

  if (d.t === 'lib') {
    const s = d.s;
    const senza = d.mot === 'pro' && !piena(s.br);
    griglia.append(riquadro(T('rSub'), [
      [T('nome'), s.n],
      [T('nascita'), dataSemplice(s.dn)],
      [T('brevetto'), senza ? T('senzaBrevetto') : s.br],
      [T('ente'), senza ? null : s.e],
      [T('nb'), s.nb],
    ]));
  } else {
    const titolo = T('rPartecipanti') + (piena(d.pag) ? ` · ${T('foglio', { n: d.pag.split('/')[0], tot: d.pag.split('/')[1] })}` : '');
    griglia.append(el('div', { class: 'riquadro' }, el('h3', {}, titolo),
      el('p', {}, T('riepilogo')),
      el('ul', { style: 'margin-top:8px' }, d.p.map((x) => el('li', {}, x.n))),
      el('p', { style: 'margin-top:8px' }, `${T('totale')}: ${d.np}`)));
  }

  // v2: il riepilogo porta il responsabile dell'uscita e quello del primo soccorso
  const persona = (x) => (x && typeof x === 'object' && piena(x.n) ? [x.n, x.tel].filter(piena).join(' · ') : null);
  if (d.t === 'reg' && (persona(d.ru) || persona(d.ps))) {
    griglia.append(riquadro(T('rResponsabili'), [[T('ru'), persona(d.ru)], [T('ps'), persona(d.ps)]]));
  }

  griglia.append(el('div', { class: 'riquadro' }, el('h3', {}, T('rGuide')),
    d.g.length === 0 ? el('p', {}, T('nessunaGuida')) : el('ul', {}, d.g.map((g) => {
      const qual = [g.br, g.e].filter(piena).join(' · ');
      return el('li', { class: g.r === 1 ? 'resp' : null }, g.n, qual ? ` — ${qual}` : '',
        g.r === 1 ? el('span', { class: 'etic' }, T('responsabile')) : null);
    }))));

  if (d.t === 'lib') {
    griglia.append(riquadro(T('rAttrezzatura'), [
      [T('ar'), T('autorespiratori.' + d.ar)],
      [T('mx'), miscela(d.mx)],
    ]));
    if (piena(d.note)) griglia.append(el('div', { class: 'riquadro largo' }, el('h3', {}, T('rNote')), el('p', {}, d.note)));
  }

  const fuori = el('div');
  fuori.append(griglia);
  if (d.t === 'lib' && (d.rev > 1 || piena(d.sost)) && !piena(d.ann)) {
    fuori.append(el('p', { class: 'sottotitolo' }, T('versione', { n: d.rev })));
  }
  const tecnici = el('dl');
  const voci = [[T('idImmersione'), d.imm]];
  if (d.t === 'lib') voci.push([T('idLibretto'), d.id], [T('revisione'), String(d.rev)], [T('sostituisce'), d.sost]);
  for (const [k, v] of voci) if (v) tecnici.append(el('dt', {}, k), el('dd', {}, v));
  fuori.append(el('details', { class: 'tecnici' }, el('summary', {}, T('rDettagli')), tecnici));
  return fuori;
}

function disegnaEsiti() {
  const box = $('esiti');
  box.replaceChildren(...letture.map((r, i) => disegnaEsito(r, i, letture.length)));
  $('ancora').hidden = letture.length === 0;
}

async function verificaTesti(testi) {
  const unici = [...new Set(testi.map((t) => t.trim()).filter(Boolean))];
  letture = [];
  for (const t of unici) letture.push(await leggiLdi(t));
  if (letture.length > 1) mostraStato('trovati', { n: letture.length });
  else mostraStato(null);
  disegnaEsiti();
  $('esiti').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// ---------------------------------------------------------------- lettura dei QR (zxing-wasm)

let zxingPronto = false;
function zxing() {
  if (!window.ZXingWASM) throw new Error('zxing non caricato');
  if (!zxingPronto) {
    window.ZXingWASM.prepareZXingModule({
      overrides: { locateFile: (path, prefix) => (path.endsWith('.wasm') ? new URL('lib/' + path, document.baseURI).href : prefix + path) },
    });
    zxingPronto = true;
  }
  return window.ZXingWASM;
}

async function leggiQr(immagine, molti) {
  const risultati = await zxing().readBarcodes(immagine, {
    formats: ['QRCode'], tryHarder: true, maxNumberOfSymbols: molti ? 30 : 1,
  });
  // in ordine di lettura: dall'alto in basso, poi da sinistra a destra
  return risultati.filter((r) => r.isValid && r.text)
    .sort((a, b) => (a.position.topLeft.y - b.position.topLeft.y) || (a.position.topLeft.x - b.position.topLeft.x))
    .map((r) => r.text);
}

async function leggiPdf(file) {
  const pdfjs = await import('./lib/pdf.min.mjs');
  pdfjs.GlobalWorkerOptions.workerSrc = new URL('lib/pdf.worker.min.mjs', document.baseURI).href;
  const caricamento = pdfjs.getDocument({ data: new Uint8Array(await file.arrayBuffer()), isEvalSupported: false });
  const doc = await caricamento.promise;
  const testi = [];
  for (let n = 1; n <= doc.numPages; n++) {
    mostraStato('leggoPagina', { n, tot: doc.numPages });
    const pagina = await doc.getPage(n);
    // circa 200 dpi: un QR di 4 cm (93 moduli) ha più di 3 pixel per modulo
    const vista = pagina.getViewport({ scale: 2.8 });
    const tela = document.createElement('canvas');
    tela.width = Math.ceil(vista.width);
    tela.height = Math.ceil(vista.height);
    const ctx = tela.getContext('2d', { willReadFrequently: true });
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, tela.width, tela.height);
    // intent 'print': pdf.js non aspetta requestAnimationFrame, così funziona anche se la scheda
    // non è in primo piano (per esempio mentre si cambia app sul telefono)
    await pagina.render({ canvasContext: ctx, canvas: tela, viewport: vista, intent: 'print' }).promise;
    testi.push(...await leggiQr(ctx.getImageData(0, 0, tela.width, tela.height), true));
    pagina.cleanup();
  }
  await caricamento.destroy();
  return testi;
}

async function apriFile(file) {
  chiudiFotocamera();
  $('pannelloIncolla').hidden = true;
  letture = [];
  disegnaEsiti();
  mostraStato('leggoFile');
  try {
    const pdf = file.type === 'application/pdf' || /\.pdf$/i.test(file.name);
    const testi = pdf ? await leggiPdf(file) : await leggiQr(file, true);
    if (!testi.length) { mostraStato('nessunQr', {}, true); return; }
    await verificaTesti(testi);
  } catch (e) {
    console.error(e);
    mostraStato('fileNonLetto', {}, true);
  }
}

// ---------------------------------------------------------------- fotocamera

let flusso = null;
let giro = 0;

async function apriFotocamera() {
  $('pannelloIncolla').hidden = true;
  mostraStato(null);
  try {
    flusso = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } }, audio: false,
    });
  } catch (e) {
    console.error(e);
    mostraStato('fotocameraNo', {}, true);
    return;
  }
  const video = $('video');
  video.srcObject = flusso;
  $('pannelloFotocamera').hidden = false;
  await video.play().catch(() => {});
  $('pannelloFotocamera').scrollIntoView({ behavior: 'smooth', block: 'center' });
  const mio = ++giro;
  const tela = document.createElement('canvas');
  const ctx = tela.getContext('2d', { willReadFrequently: true });
  const cerca = async () => {
    if (mio !== giro || !flusso) return;
    if (video.videoWidth) {
      tela.width = video.videoWidth;
      tela.height = video.videoHeight;
      ctx.drawImage(video, 0, 0);
      try {
        const testi = await leggiQr(ctx.getImageData(0, 0, tela.width, tela.height), false);
        if (testi.length && mio === giro) {
          chiudiFotocamera();
          await verificaTesti(testi);
          return;
        }
      } catch (e) { console.error(e); }
    }
    setTimeout(cerca, 200);
  };
  cerca();
}

function chiudiFotocamera() {
  giro++;
  if (flusso) flusso.getTracks().forEach((t) => t.stop());
  flusso = null;
  $('video').srcObject = null;
  $('pannelloFotocamera').hidden = true;
}

// ---------------------------------------------------------------- avvio

function supportato() {
  return typeof DecompressionStream === 'function' && window.crypto && crypto.subtle && typeof WebAssembly === 'object';
}

function avvio() {
  preparaLingue();
  impostaLingua(scegliLinguaIniziale());
  $('annoCopy').textContent = '© ' + new Date().getFullYear();

  if (!supportato()) {
    mostraStato('browserVecchio', {}, true);
    document.querySelectorAll('.azioni button').forEach((b) => { b.disabled = true; });
    return;
  }

  $('btnFotocamera').addEventListener('click', () => (flusso ? chiudiFotocamera() : apriFotocamera()));
  $('btnChiudiFotocamera').addEventListener('click', chiudiFotocamera);
  $('btnFile').addEventListener('click', () => $('sceltaFile').click());
  $('sceltaFile').addEventListener('change', (e) => {
    const f = e.target.files && e.target.files[0];
    e.target.value = '';
    if (f) apriFile(f);
  });
  $('btnIncolla').addEventListener('click', () => {
    chiudiFotocamera();
    const p = $('pannelloIncolla');
    p.hidden = !p.hidden;
    if (!p.hidden) $('testoQr').focus();
  });
  $('btnVerificaTesto').addEventListener('click', () => {
    const t = $('testoQr').value.trim();
    if (t) verificaTesti([t]);
  });
  $('btnAncora').addEventListener('click', () => {
    letture = [];
    disegnaEsiti();
    mostraStato(null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });
  // trascinare un file sulla pagina (comodo dal computer)
  document.addEventListener('dragover', (e) => e.preventDefault());
  document.addEventListener('drop', (e) => {
    e.preventDefault();
    const f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
    if (f) apriFile(f);
  });
}

avvio();
