// Run tab: execute a learned profile program on the selected rule through the reader's own
// OpenAI-compatible endpoint (base URL and key stay in this browser and go only to that
// endpoint), then compare runs: re-samples of the same input (the noise floor), packet edits
// (what the packet controls), the authored profile, and an optional strict clause judge.
//
// Same-seed runs replay any model call whose prompt is unchanged (the wasm evaluator's cache is
// keyed by the filled prompt and `_seed`); a new seed draws a fresh sample.

const LS = 'nlir.endpoint.v1', WS = 'nlir.workspace.v1';
// The endpoint panel, for hosts without their own markup (the spec lab ships it in index.html).
const ENDPOINT_HTML = `<details class="endpoint" id="endpoint">
  <summary>Model endpoint <span class="muted" id="epStatus"></span></summary>
  <div class="ep-grid">
    <label>Base URL <input id="epBase" type="url" placeholder="https://your-proxy.example/v1" autocomplete="off" spellcheck="false"></label>
    <label>API key <input id="epKey" type="password" placeholder="optional" autocomplete="off" spellcheck="false"></label>
    <label>Writer model <input id="epWriter" list="epModels" spellcheck="false"></label>
    <label>Judge model <input id="epJudge" list="epModels" spellcheck="false"></label>
    <datalist id="epModels"></datalist>
  </div>
  <div class="ep-actions"><label class="check"><input type="checkbox" id="epRemember"> Remember the key in this browser</label><button class="ghost" id="epTest">Test connection</button><button class="ghost" id="epForget">Forget key</button><span class="muted" id="epTestOut"></span></div>
  <p class="muted">Any OpenAI-compatible endpoint (for example a LiteLLM proxy). Requests go straight from this page to it; the URL and key are kept only in this browser. The endpoint must allow cross-origin requests from this page.</p>
</details>`;
const DEFAULTS = { baseUrl: '', apiKey: '', remember: true, writer: 'gpt-6-luna', judge: 'gpt-6.1-sol' };
const PERTURB = {
  permissions: ['Remove permissions', p => { delete p.permissions; }],
  examples: ['Remove spec examples', p => { delete p.examples; }],
  definitions: ['Remove definitions', p => { delete p.definitions; }],
  scope: ['Remove scope', p => { delete p.scope; }],
};

let D, ep, programs = [], splits = null, clauses = null, judgeLib = '', ruleId = null, request = 0;
const runs = {}, packetCache = {}, authoredCache = {};
const $ = id => document.getElementById(id);
const unmap = v => (v instanceof Map ? Object.fromEntries(v) : v);
// wasm payloads nest JS Maps inside plain objects and arrays: convert all the way down.
const deep = v => (v instanceof Map ? Object.fromEntries([...v].map(([k, x]) => [k, deep(x)]))
  : Array.isArray(v) ? v.map(deep)
  : v && typeof v === 'object' ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, deep(x)])) : v);
// The lens's own requests (backward patches, the tension check, the PutGet similarity
// rating) go to the judge model; re-running the program goes to the writer.
const LENS_PROMPT = /You are computing a BACKWARD pass|Check whether the edited source now contradicts itself|The first <text> is a REFERENCE; the second <text> is a CANDIDATE/;
const words = t => (String(t || '').match(/[A-Za-z0-9'’-]+/g) || []);
const sentences = t => (String(t || '').match(/[^.!?]+[.!?]+(\s|$)/g) || [t]).filter(s => s.trim()).length;
const ruleCodes = t => (String(t || '').match(/\b[A-Z]{2} [VP] \d+(\.\d+)*\b/g) || []).length;

export function loadEndpoint() {
  try { const s = JSON.parse(localStorage.getItem(LS) || 'null'); if (s) return { ...DEFAULTS, ...s }; } catch (_) {}
  // First visit: reuse the workspace's saved endpoint on this origin, if any.
  try { const w = JSON.parse(localStorage.getItem(WS) || 'null'); if (w?.settings?.baseUrl) return { ...DEFAULTS, baseUrl: w.settings.baseUrl, apiKey: w.settings.apiKey || '' }; } catch (_) {}
  return { ...DEFAULTS };
}
function saveEndpoint() {
  const s = { ...ep }; if (!s.remember) s.apiKey = '';
  try { localStorage.setItem(LS, JSON.stringify(s)); } catch (_) {}
}
const endpointReady = () => !!ep.baseUrl.trim();

// One realiser per role: the program's own model calls go to the writer model, the judge's to
// the judge model. Every call is logged on the run (prompt, reply, time) as it happens.
function realiser(model, log) {
  const base = ep.baseUrl.trim().replace(/\/+$/, ''), key = ep.apiKey.trim();
  return {
    llm: async call => {
      const c = unmap(call), vars = unmap(c.vars) || {};
      const entry = { model, prompt: vars.NLIR_PROMPT || '', system: vars.NLIR_SYSTEM_PROMPT || '', status: 'running', t0: performance.now() };
      log?.(entry);
      try {
        const res = await fetch(base + '/chat/completions', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: 'Bearer ' + key } : {}) },
          body: JSON.stringify({ model, messages: [...(entry.system ? [{ role: 'system', content: entry.system }] : []), { role: 'user', content: entry.prompt }] }),
        });
        if (!res.ok) { let d = ''; try { d = (await res.text()).slice(0, 300).replace(/\s+/g, ' ').trim(); } catch (_) {} throw new Error(`endpoint ${res.status}${d ? ': ' + d : ''}`); }
        const j = await res.json();
        entry.reply = j?.choices?.[0]?.message?.content ?? '';
        entry.status = 'done';
        return entry.reply;
      } catch (e) {
        entry.status = 'failed'; entry.reply = String(e.message || e);
        throw e;
      } finally { entry.ms = Math.round(performance.now() - entry.t0); log?.(entry); }
    },
  };
}

// A host page passes its evaluator and helpers, and may supply its own data: `programs`
// [{key,label,src,graph,examples,train}], `splitOf(id) -> [label, why]`, `packetOf(id)`,
// `authoredOf(id) -> {md, fields}`, `fieldsOf(md)`, `clauses` {id: {PART: [clause]}} and
// `judgeLib`. Anything omitted falls back to the spec lab's toy files and projections.
export async function initRun(deps) {
  D = deps; ep = loadEndpoint();
  if (D.programs) {
    programs = D.programs; clauses = D.clauses || null; judgeLib = D.judgeLib ? strip(D.judgeLib) : '';
    return;
  }
  const [a, b, cl, judge, clean] = await Promise.all(['trace-strict-a.json', 'trace-strict-b.json', 'clauses.json', 'judge.nlir', 'program-b-clean.nlir'].map(f =>
    fetch(f).then(r => (r.ok ? (f.endsWith('.json') ? r.json() : r.text()) : null)).catch(() => null)));
  const chosen = t => t.rounds[Math.max(0, t.rounds.map((r, i) => (r.accepted ? i : -1)).filter(i => i >= 0).pop() ?? 0)];
  if (a && b) {
    const ra = chosen(a), rb = chosen(b);
    programs = [
      { key: 'B', label: `Learned B — two worked examples (r0${rb.round})`, src: rb.program, graph: rb.graph, examples: b.weights?.examples ?? 2, train: b.train_ids },
      { key: 'A', label: `Learned A — no worked examples (r0${ra.round})`, src: ra.program, graph: ra.graph, examples: 0, train: a.train_ids },
      { key: 'seed', label: 'Seed — one generic instruction (r00)', src: a.rounds[0].program, graph: a.rounds[0].graph, examples: 0, train: a.train_ids },
    ];
    // B·clean: learned B plus a deterministic clean-up of shape leaks (same model calls).
    if (clean) programs.splice(1, 0, { key: 'B·clean', label: 'B·clean — learned B plus a clean-up of shape leaks', src: clean, examples: b.weights?.examples ?? 2, train: b.train_ids });
    splits = { train: b.train_ids, test: b.test_ids };
  }
  clauses = cl; judgeLib = judge ? strip(judge) : '';
}

function strip(src) {
  return src.split('\n').filter(l => !l.trim().startsWith('--')).join('\n').trim().replace(/;\s*$/, '');
}

function splitOf(id) {
  if (D.splitOf) return D.splitOf(id);
  if (!splits) return ['', ''];
  if (splits.train.includes(id)) return ['training rule', 'the editor saw this rule\'s authored profile while learning; scores here are optimistic'];
  if (splits.test.includes(id)) return ['held-out rule', 'never seen while learning or choosing the program'];
  return ['validation rule', 'used to choose between program versions, never shown to the editor'];
}

async function specPacket(id) {
  if (!packetCache[id]) packetCache[id] = D.packetOf ? structuredClone(await D.packetOf(id)) : await D.runJson('$packet%$id', { id });
  return packetCache[id];
}
async function authored(id) {
  if (!authoredCache[id]) {
    const { md, fields } = D.authoredOf ? await D.authoredOf(id)
      : { md: await D.run('$render%(($node%$id).profile)', { id }), fields: await D.runJson('($node%$id).profile', { id }) };
    authoredCache[id] = { md, fields, parts: D.mdParts(md) };
  }
  return authoredCache[id];
}
async function examplesFor(prog, id) {
  const pool = (prog.train || []).filter(x => x !== id).slice(0, prog.examples);
  return Promise.all(pool.map(async x => ({ id: x, input: await specPacket(x), output: (await authored(x)).md })));
}

// Word-level change between two texts: 1 − matched words / longer length.
function changed(a, b) {
  const A = words(a).map(w => w.toLowerCase()), B = words(b).map(w => w.toLowerCase());
  if (!A.length && !B.length) return 0;
  const n = A.length, m = B.length, L = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) L[i][j] = A[i] === B[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
  return 1 - L[0][0] / Math.max(n, m);
}
// Word-level diff (deleted and inserted words interleaved) for short, similar texts such as
// a proposed field edit. The runner carries its own so hosts need not supply one.
function wordDiff(a, b) {
  const A = String(a).split(/(\s+)/), B = String(b).split(/(\s+)/);
  const n = A.length, m = B.length, L = Array.from({ length: n + 1 }, () => new Uint32Array(m + 1));
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) L[i][j] = A[i] === B[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
  let i = 0, j = 0, out = '';
  while (i < n && j < m) {
    if (A[i] === B[j]) { out += D.esc(A[i]); i++; j++; }
    else if (L[i + 1][j] >= L[i][j + 1]) { out += `<del>${D.esc(A[i])}</del>`; i++; }
    else { out += `<ins>${D.esc(B[j])}</ins>`; j++; }
  }
  while (i < n) out += `<del>${D.esc(A[i++])}</del>`;
  while (j < m) out += `<ins>${D.esc(B[j++])}</ins>`;
  return out;
}

// The run's own text, with words that the comparison text lacks highlighted. Deleted words are
// counted, not interleaved: two mostly different texts stay readable.
// Shared function words are not underlined: they match everywhere and say nothing.
const STOP = new Set('a an and are as at be by for from has have in is it its of on or that the their this to was were which with'.split(' '));
function marked(a, b, sharedMode = false) {
  const A = String(a || '').split(/(\s+)/), B = String(b || '').split(/(\s+)/), key = w => w.toLowerCase().replace(/[^a-z0-9'’-]/g, '');
  const n = A.length, m = B.length, L = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) L[i][j] = key(A[i]) === key(B[j]) ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
  let i = 0, j = 0, out = '', removed = 0;
  while (j < m) {
    if (i < n && key(A[i]) === key(B[j])) { out += sharedMode && B[j].trim() && !STOP.has(key(B[j])) ? `<mark class="same">${D.esc(B[j])}</mark>` : D.esc(B[j]); i++; j++; }
    else if (i < n && L[i + 1][j] >= L[i][j + 1]) { if (A[i].trim()) removed++; i++; }
    else { out += B[j].trim() && !sharedMode ? `<ins>${D.esc(B[j])}</ins>` : D.esc(B[j]); j++; }
  }
  for (; i < n; i++) if (A[i].trim()) removed++;
  return { html: out, removed };
}
// ---- style: is the output shaped like the authored profile? (mirrors style.py) -------------
// Per part: length match (min/max words) × sentence-count match × 1/(1+leaks), geometric mean;
// leaks are things authors never do (repeat the part's label, a quote marker, a rule code, a
// heading). Profile style = mean over the authored parts; combined = sqrt(strict F1 × style).
const sentenceCount = t => { t = String(t || '').trim(); return t ? Math.max(1, t.split(/(?<=[.!?])\s+/).filter(x => x.trim()).length) : 0; };
function partLeaks(label, text) {
  const head = label.toLowerCase() === 'decision boundary' ? 'Decision boundary' : label.split(' ')[0];
  const out = [];
  if (new RegExp('^\\W*' + head.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b', 'i').test(text || '')) out.push('echoed label');
  if (String(text || '').trimStart().startsWith('>')) out.push('quote marker');
  if (/\b[A-Z]{2} [VP] \d+(?:\.\d+)*\b/.test(text || '')) out.push('rule code');
  if (/(^|\n)\s*#{1,6} /.test(text || '')) out.push('heading');
  return out;
}
function styleOf(parts, authParts) {
  const ratio = (a, b) => (Math.max(a, b) ? Math.min(a, b) / Math.max(a, b) : 1);
  const per = (authParts || []).map(([label, gold]) => {
    const cand = partText(parts, label);
    if (!String(cand).trim()) return { label, style: 0, leaks: [] };
    const leaks = partLeaks(label, cand);
    return { label, leaks, style: Math.cbrt(ratio(words(cand).length, words(gold).length) * ratio(sentenceCount(cand), sentenceCount(gold)) / (1 + leaks.length)) };
  });
  return { style: per.length ? per.reduce((a, p) => a + p.style, 0) / per.length : 0, parts: per };
}

const partText = (parts, label) => (parts || []).find(p => p[0].toUpperCase() === label.toUpperCase())?.[1] ?? '';
const allText = parts => (parts || []).map(p => p[1]).join(' ');
const pct = x => `${Math.round(100 * x)}%`;

function packetChange(p, base) {
  const keys = new Set([...Object.keys(base), ...Object.keys(p)]);
  const out = [];
  for (const k of keys) {
    if (!(k in p)) out.push(`${k} removed`);
    else if (!(k in base)) out.push(`${k} added`);
    else if (JSON.stringify(p[k]) !== JSON.stringify(base[k])) out.push(`${k} edited`);
  }
  return out;
}

// ---- the pane ------------------------------------------------------------------------
export async function showRun(id) {
  ruleId = id;
  // Hosts that re-render their page (the health lab) get the endpoint panel back each time.
  const host = typeof D.endpointHost === 'function' ? D.endpointHost() : D.endpointHost;
  if (!$('endpoint') && host) host.insertAdjacentHTML('afterbegin', ENDPOINT_HTML);
  if ($('endpoint') && !$('endpoint').dataset.wired) { wireEndpoint(); $('endpoint').dataset.wired = '1'; }
  const token = ++request, box = $('run');
  if (!programs.length) { box.innerHTML = '<p class="muted">The recorded programs could not be loaded.</p>'; return; }
  const [packet, auth] = await Promise.all([specPacket(id), authored(id)]);
  if (token !== request) return;
  const [split, why] = splitOf(id);
  const progKey = $('runProgram')?.value || 'B';
  box.innerHTML = `
    <p class="sub">Run a learned program on <b>${D.esc(id)}</b> with your own model endpoint, then compare: the same input with a new seed shows sampling noise; an edited packet shows what the packet controls; the strict judge shows what a score means clause by clause. <span class="state ${/held-out|fresh/.test(split) ? 'ok' : 'warn'}" title="${D.esc(why)}">${split}</span></p>
    <div class="run-grid">
      <div class="run-inputs">
        <label class="run-label" for="runProgram">Program</label>
        <select id="runProgram">${programs.map(p => `<option value="${p.key}" ${p.key === progKey ? 'selected' : ''}>${D.esc(p.label)}</option>`).join('')}</select>
        <details class="run-src"><summary>Program source <span class="muted" id="runSrcState"></span></summary><textarea id="runSrc" spellcheck="false"></textarea><button class="ghost" id="runSrcReset">Reset program</button></details>
        <details class="run-anatomy" id="runAnatomy"><summary>Instruction sentences <span class="muted" id="runAnatomyState"></span></summary>
          <p class="muted">Switch a sentence off and Run: with the same seed, only the model calls whose prompt changed are re-made. The sweeps remove each sentence, each instruction, or each packet field in turn (after a baseline and three re-samples) and rank them by how much they change the output compared with a re-sample.</p>
          <div id="runSentences"></div>
          <div class="run-actions"><button class="ghost" id="runSweep" title="Switch each sentence off in turn">Sweep sentences</button><button class="ghost" id="runSweepGroups" title="Switch each statement's whole instruction off in turn">Sweep groups</button><button class="ghost" id="runSweepFields" title="Remove each packet field in turn (the rule text first, as a positive control)">Sweep packet fields</button><button class="ghost" id="runSentencesReset">All on</button><span class="muted" id="runSweepState"></span></div>
        </details>
        <details class="run-graph"><summary>Program graph</summary><div id="runGraph" class="graph"></div></details>
        <label class="run-label" for="runPacket">Packet <code>$p</code> <span class="muted" id="runPacketState">from the spec</span></label>
        <div class="run-perturb">${Object.entries(PERTURB).map(([k, [t]]) => `<button class="ghost" data-perturb="${k}" ${packet[k] === undefined ? 'disabled' : ''}>${t}</button>`).join('')}<button class="ghost" id="runPacketReset">Reset packet</button></div>
        <textarea id="runPacket" spellcheck="false"></textarea>
        <p class="muted" id="runExamples"></p>
        <div class="run-actions">
          <button class="primary" id="runGo">Run</button>
          <button class="ghost" id="runResample" title="Same program and packet, next seed: shows how much a fresh sample changes">New sample</button>
          <button class="ghost" id="runStep" title="Show each reduction as it happens">Step through</button>
        </div>
        <p class="muted" id="runNeed"></p>
        <div id="runSteps" class="run-steps"></div>
      </div>
      <div class="run-results">
        <div class="run-compare">Compare each run with <select id="runAgainst"></select></div>
        <div id="runSummary"></div>
        <div id="runCards"></div>
      </div>
    </div>`;
  $('runPacket').value = JSON.stringify(packet, null, 1);
  wirePane(packet);
  renderRuns();
}

// ---- program anatomy: the instruction sentences inside a program's string literals ---------
// A learned program is mostly natural-language instructions wrapped in string plumbing.
// Switching one sentence off and re-running (same seed, so untouched calls replay) shows
// whether it changes the output more than a re-sample does.
function instructionSentences(src) {
  const out = [];
  const lit = /"((?:[^"\\]|\\.)*)"/g;
  let m, li = 0;
  while ((m = lit.exec(src))) {
    const body = m[1], base = m.index + 1;
    if (body.length < 60) continue;
    // Owner: the statement name the literal is assigned under, and a field tag like "MET."
    // when the literal starts with one.
    const before = src.slice(0, m.index);
    const names = [...before.matchAll(/(?:^|;|\n)\s*([A-Za-z_][\w-]*)\s*=(?![=>])/g)];
    const owner = names.length ? names.at(-1)[1] : 'program';
    // "FIELD: MET\n…" (a header line) or "MET. …" (a leading tag) names the field.
    const tag = body.match(/^\s*FIELD:\s*([^\n]{2,40})\n/) || body.match(/^\s*([A-Za-z_ ]{2,24})\.\s/);
    const label = tag && tag[1].split(' ').length <= 3 ? `${owner} · ${tag[1].trim()}` : owner;
    let k = 0;
    // A sentence ends at . ! ? before a space or line break, or at a line break.
    const re = /[^.!?\n]+?(?:[.!?]+(?=\s|\\n|$)|(?=\n)|$)/g;
    let s;
    while ((s = re.exec(body))) {
      const raw = s[0];
      if (!raw.trim()) { re.lastIndex++; continue; }
      const text = raw.replace(/\\n/g, ' ').replace(/\s+/g, ' ').trim();
      if (text.split(' ').length >= 4) out.push({ id: `${li}.${k++}`, label, start: base + s.index, end: base + s.index + raw.length, text });
      if (s.index + raw.length >= body.length) break;
    }
    li++;
  }
  return out;
}

function ablate(src, sentences, off) {
  const spans = sentences.filter(x => off.has(x.id)).sort((a, b) => b.start - a.start);
  let out = src;
  for (const x of spans) {
    let end = x.end;
    while (out[end] === ' ') end++;
    out = out.slice(0, x.start) + out.slice(end);
  }
  return out;
}

let anatomy = { key: null, sentences: [], off: new Set() };

function currentProgram() {
  const p = programs.find(x => x.key === $('runProgram').value) || programs[0];
  const src = $('runSrc').value;
  return { ...p, src, edited: src !== p.src };
}

function wirePane(packet) {
  const loadProgram = () => {
    const p = programs.find(x => x.key === $('runProgram').value) || programs[0];
    $('runSrc').value = p.src; $('runSrcState').textContent = '';
    anatomy = { key: p.key, sentences: instructionSentences(p.src), off: new Set() };
    renderSentences();
    let graph = p.graph;
    // The statement-level outline stays legible for long programs; the expression graph does not.
    if (!graph && D.nlir.outline) { const g = D.norm(D.nlir.outline(strip(p.src), D.cfgJson)); graph = g?.ok ? g.svg : ''; }
    $('runGraph').innerHTML = graph || '<p class="muted">No graph for this program.</p>';
    const ex = (p.train || []).filter(x => x !== ruleId).slice(0, p.examples);
    $('runExamples').innerHTML = ex.length ? `Worked examples bound as <code>$examples</code>: ${ex.map(D.esc).join(', ')} (training rules: their packets and authored profiles).` : 'No worked examples: <code>$examples</code> is empty for this program.';
  };
  loadProgram();
  $('runProgram').onchange = loadProgram;
  $('runSrc').oninput = () => { $('runSrcState').textContent = currentProgram().edited ? '· edited' : ''; };
  $('runSrcReset').onclick = loadProgram;
  const packetState = () => {
    let p; try { p = JSON.parse($('runPacket').value); } catch (e) { $('runPacketState').textContent = 'not valid JSON'; return; }
    const c = packetChange(p, packet);
    $('runPacketState').textContent = c.length ? c.join(', ') : 'from the spec';
  };
  $('runPacket').oninput = packetState;
  document.querySelectorAll('[data-perturb]').forEach(b => b.onclick = () => {
    let p; try { p = JSON.parse($('runPacket').value); } catch (_) { return; }
    PERTURB[b.dataset.perturb][1](p);
    $('runPacket').value = JSON.stringify(p, null, 1); packetState();
  });
  $('runPacketReset').onclick = () => { $('runPacket').value = JSON.stringify(packet, null, 1); packetState(); };
  const need = () => { $('runNeed').innerHTML = endpointReady() ? '' : 'Set a model endpoint above to run programs.'; };
  need();
  $('runGo').onclick = () => execute({});
  $('runResample').onclick = () => execute({ resample: true });
  $('runStep').onclick = () => execute({ step: true });
  $('runAgainst').onchange = renderRuns;
  $('runSentencesReset').onclick = () => { anatomy.off.clear(); applyAblation(); };
  $('runSweep').onclick = () => sweep('sentences');
  $('runSweepGroups').onclick = () => sweep('groups');
  $('runSweepFields').onclick = () => sweep('fields');
}

function renderSentences() {
  const groups = {};
  for (const x of anatomy.sentences) (groups[x.label] ||= []).push(x);
  $('runSentences').innerHTML = Object.entries(groups).map(([label, xs]) => `<div class="sent-group"><div class="label">${D.esc(label)} <button class="ghost mini" data-group="${D.esc(label)}">${xs.every(x => anatomy.off.has(x.id)) ? 'all on' : 'all off'}</button></div>${xs.map(x => `<button class="sent ${anatomy.off.has(x.id) ? 'off' : ''}" data-sent="${x.id}" aria-pressed="${anatomy.off.has(x.id)}" title="${anatomy.off.has(x.id) ? 'Switched off — click to restore' : 'Click to switch off'}">${D.esc(x.text)}</button>`).join('')}</div>`).join('') || '<p class="muted">No long instruction literals in this program.</p>';
  $('runAnatomyState').textContent = `${anatomy.sentences.length} sentences${anatomy.off.size ? ` · ${anatomy.off.size} off` : ''}`;
  $('runSentences').querySelectorAll('[data-group]').forEach(b => b.onclick = () => {
    const xs = groups[b.dataset.group], allOff = xs.every(x => anatomy.off.has(x.id));
    for (const x of xs) allOff ? anatomy.off.delete(x.id) : anatomy.off.add(x.id);
    applyAblation();
  });
  $('runSentences').querySelectorAll('[data-sent]').forEach(b => b.onclick = () => {
    const id = b.dataset.sent;
    anatomy.off.has(id) ? anatomy.off.delete(id) : anatomy.off.add(id);
    applyAblation();
  });
}

function applyAblation() {
  const p = programs.find(x => x.key === anatomy.key);
  $('runSrc').value = ablate(p.src, anatomy.sentences, anatomy.off);
  $('runSrcState').textContent = anatomy.off.size ? `· ${anatomy.off.size} sentence${anatomy.off.size === 1 ? '' : 's'} off` : '';
  renderSentences();
}

// Switch each sentence off in turn (same seed, packet from the textarea), after making sure a
// baseline and one re-sample exist so each effect can be compared with sampling noise.
let sweeping = false;
async function sweep(unit = 'sentences') {
  if (sweeping || !endpointReady()) { if (!endpointReady()) { $('endpoint').open = true; } return; }
  sweeping = true;
  const p = programs.find(x => x.key === anatomy.key), xs = anatomy.sentences;
  anatomy.off.clear(); applyAblation();
  $('runPacketReset').click(); // every sweep run reads the spec packet, like its baseline
  const list = runs[ruleId] ||= [];
  const plain = r => r.program === p.key && r.src === p.src && r.packetNote === 'packet from the spec' && r.status === 'done';
  try {
    if (!list.some(r => plain(r) && r.seed === 0)) { $('runSweepState').textContent = 'baseline…'; await execute({}); }
    // Three re-samples: with no real effect a run then exceeds all of them one time in four.
    while (list.filter(r => plain(r) && r.seed > 0).length < 3) {
      $('runSweepState').textContent = `re-sample ${list.filter(r => plain(r) && r.seed > 0).length + 1}/3…`;
      await execute({ resample: true });
    }
    // A unit is one sentence, every sentence under one statement (a whole instruction), or one
    // packet field removed (the rule text first: a positive control that should change a lot).
    const spec = await specPacket(ruleId);
    const units = unit === 'fields'
      ? ['rule', 'permissions', 'definitions', 'examples', 'scope', 'policy'].filter(k => spec[k] !== undefined)
        .map(k => ({ ids: [], packet: Object.fromEntries(Object.entries(spec).filter(([f]) => f !== k)), without: { text: `packet without ${k}`, label: 'packet', group: true } }))
      : unit === 'groups'
      ? Object.entries(xs.reduce((g, x) => ((g[x.label] ||= []).push(x), g), {})).map(([label, ys]) => ({ ids: ys.map(y => y.id), without: { text: `all ${ys.length} sentences of ${label}`, label, group: true } }))
      : xs.map(x => ({ ids: [x.id], without: x }));
    let done = 0;
    const queue = units.slice();
    const worker = async () => {
      while (queue.length) {
        const u = queue.shift();
        await execute(u.packet ? { packet: u.packet, without: u.without } : { src: ablate(p.src, xs, new Set(u.ids)), without: u.without });
        $('runSweepState').textContent = `${++done}/${units.length} ${unit}`;
      }
    };
    await Promise.all([worker(), worker(), worker()]);
    $('runSweepState').textContent = `done: ${units.length} ${unit}`;
  } finally { sweeping = false; }
}

async function execute({ resample = false, step = false, src = null, without = null, packet = null }) {
  if (!endpointReady()) { $('endpoint').open = true; $('epBase').focus(); return; }
  const id = ruleId, base = currentProgram();
  const prog = src === null ? base : { ...base, src, edited: true };
  let p = packet;
  if (!p) { try { p = JSON.parse($('runPacket').value); } catch (e) { $('runNeed').textContent = 'The packet is not valid JSON.'; return; } }
  const list = (runs[id] ||= []);
  const samePrior = list.filter(r => r.program === prog.key && r.src === prog.src && r.packetJson === JSON.stringify(p));
  const seed = resample ? Math.max(0, ...samePrior.map(r => r.seed)) + 1 : 0;
  const change = packetChange(p, await specPacket(id));
  const run = {
    n: list.length + 1, id, program: prog.key, programLabel: prog.label.split(' — ')[0] + (without ? ' minus one sentence' : prog.edited ? ' (edited)' : ''), src: prog.src, without,
    seed, packetJson: JSON.stringify(p), packetNote: change.length ? change.join(', ') : 'packet from the spec',
    writer: ep.writer, calls: [], steps: [], status: 'running', t0: performance.now(),
  };
  list.push(run); renderRuns();
  const examples = await examplesFor(prog, id);
  const expr = `${D.profileLib};\n${strip(prog.src)}`;
  const ctx = JSON.stringify({ p, examples, _seed: seed });
  run.expr = expr; run.ctx = ctx;
  const log = entry => { if (!run.calls.includes(entry)) run.calls.push(entry); renderRuns(); };
  try {
    let r;
    if (step) {
      $('runSteps').innerHTML = '';
      const onStep = txt => { run.steps.push(String(txt)); const d = document.createElement('details'); d.className = 'step'; const s = String(txt); d.innerHTML = `<summary><span class="n">${run.steps.length - 1}</span> ${D.esc(s.slice(0, 140))}${s.length > 140 ? '…' : ''}</summary><pre>${D.esc(s.slice(0, 20000))}</pre>`; $('runSteps').appendChild(d); };
      r = D.norm(await D.nlir.stepStream(expr, D.cfgJson, ctx, 'llm', realiser(ep.writer, log), onStep));
      // The stream returns only a step count; the same seed replays every call from the cache,
      // so evaluating again yields the output with no further model calls.
      if (r.ok) r = D.norm(await D.nlir.evaluate(expr, D.cfgJson, ctx, 'llm', realiser(ep.writer, log)));
    } else {
      r = D.norm(await D.nlir.evaluate(expr, D.cfgJson, ctx, 'llm', realiser(ep.writer, log)));
    }
    if (!r.ok) throw new Error(r.error);
    run.md = r.result;
    run.parts = D.mdParts(run.md);
    run.status = run.parts.length ? 'done' : 'failed';
    if (!run.parts.length) run.error = 'The output does not have the profile layout, so no part can be compared (a strict score would be 0).';
  } catch (e) {
    run.status = 'failed'; run.error = String(e.message || e);
    if (/Failed to fetch|NetworkError|Load failed/i.test(run.error)) run.error += ' — the endpoint is unreachable from this page, or it does not allow cross-origin requests (CORS).';
  }
  run.secs = Math.round((performance.now() - run.t0) / 100) / 10;
  renderRuns();
}

async function judge(run) {
  if (!judgeLib || !clauses?.[run.id]) return;
  run.judge = { status: 'running', calls: [] };
  renderRuns();
  const gold = (await authored(run.id)).fields;
  const cand = D.fieldsOf ? await D.fieldsOf(run.md) : await D.runJson('$fields%$md', { md: run.md });
  const log = entry => { if (!run.judge.calls.includes(entry)) run.judge.calls.push(entry); renderRuns(); };
  try {
    const r = D.norm(await D.nlir.evaluate(judgeLib, D.cfgJson, JSON.stringify({ gold, cand, clauses: clauses[run.id], _seed: 0 }), 'llm', realiser(ep.judge, log)));
    if (!r.ok) throw new Error(r.error);
    run.judge = { ...JSON.parse(r.result), status: 'done', model: ep.judge, calls: run.judge.calls };
  } catch (e) { run.judge = { status: 'failed', error: String(e.message || e), calls: run.judge.calls }; }
  renderRuns();
}

// ---- backward: an edit to the output -> the packet edits that would produce it -----------
async function propose(run) {
  const back = run.back;
  back.status = 'running'; back.calls = []; back.report = null; back.error = null;
  renderRuns();
  const log = entry => { if (!back.calls.includes(entry)) back.calls.push(entry); renderRuns(); };
  const writer = realiser(ep.writer, log), judgeModel = realiser(ep.judge, log);
  const route = { llm: call => ((unmap(unmap(call).vars) || {}).NLIR_PROMPT || '').match(LENS_PROMPT) ? judgeModel.llm(call) : writer.llm(call) };
  try {
    const r = deep(D.norm(await D.nlir.putAsync(run.expr, D.cfgJson, run.ctx, back.edited, route)));
    if (!r.ok) throw new Error(r.error);
    back.report = r.report; back.status = 'done';
  } catch (e) { back.status = 'failed'; back.error = String(e.message || e); }
  renderRuns();
}

// Set `value` at a '/'-separated path inside `obj` (numeric segments index lists).
function setPath(obj, path, value) {
  const keys = path.split('/').filter(Boolean);
  if (!keys.length) return value;
  let o = obj;
  for (const k of keys.slice(0, -1)) o = o[Array.isArray(o) ? +k : k];
  const last = keys.at(-1);
  o[Array.isArray(o) ? +last : last] = value;
  return obj;
}

function applyPacketEdits(run) {
  let p; try { p = JSON.parse($('runPacket').value); } catch (_) { return; }
  for (const e of run.back.report.edits.filter(e => e.kind === 'data' && e.target === 'p')) for (const c of e.changes) p = setPath(p, c.path, c.new);
  $('runPacket').value = JSON.stringify(p, null, 1);
  $('runPacket').dispatchEvent(new Event('input'));
  $('runPacket').scrollIntoView({ block: 'center' });
}

function backHtml(r) {
  const b = r.back;
  const text = v => (typeof v === 'string' ? v : JSON.stringify(v));
  let out = '';
  if (b.status === 'running') out += `<p><span class="state">working · ${b.calls.length} call${b.calls.length === 1 ? '' : 's'}</span></p>`;
  if (b.error) out += `<p class="err">${D.esc(b.error)}</p>`;
  const rep = b.report;
  if (rep) {
    const data = rep.edits.filter(e => e.kind === 'data'), prog = rep.edits.filter(e => e.kind === 'program');
    const row = (label, c) => `<li><b>${D.esc(label)}</b> <span class="muted">${D.esc(c.path || '(whole value)')}</span><div class="text">${wordDiff(text(c.old), text(c.new))}</div></li>`;
    out += `<div class="back-report">`;
    out += data.length ? `<h4>Proposed input edits</h4><ul>${data.flatMap(e => e.changes.map(c => row(e.target === 'p' ? 'packet' : e.target === 'examples' ? 'worked example' : e.target, c))).join('')}</ul>` : '<p class="muted">No input edit was proposed.</p>';
    if (prog.length) out += `<h4>Edits to the program's own wording</h4><ul>${prog.flatMap(e => e.changes.map(c => row(e.target, c))).join('')}</ul>`;
    if (rep.stuck?.length) out += `<h4>Could not be pushed back</h4><ul>${rep.stuck.map(x => `<li>${D.esc(x.reason)} <span class="muted">at ${D.esc(String(x.at).slice(0, 80))}</span></li>`).join('')}</ul>`;
    if (rep.conflicts?.length) out += `<h4>Conflicting edits</h4><ul>${rep.conflicts.map(x => `<li>${D.esc(x)}</li>`).join('')}</ul>`;
    if (rep.tensions?.length) out += `<h4>Edits that pull against each other</h4><ul>${rep.tensions.map(x => `<li>${D.esc(x)}</li>`).join('')}</ul>`;
    const pg = rep.put_get === true ? 'Re-running the program on the edited inputs reproduces your text exactly.'
      : rep.put_get === false ? `Re-running the program on the edited inputs gives different text${rep.put_get_similarity != null ? ` (judged ${rep.put_get_similarity.toFixed(2)} similar in meaning)` : ''}: model steps are not exact inverses.`
      : 'Not re-run: some edits could not be pushed back.';
    out += `<p class="sub">${pg}</p>`;
    if (rep.put_get === false && rep.put_get_output) { const m = marked(b.edited, rep.put_get_output, changed(b.edited, rep.put_get_output) > 0.5); out += `<details><summary>Re-run output</summary><div class="text">${m.html}</div></details>`; }
    if (data.some(e => e.target === 'p')) out += `<div class="run-actions"><button class="ghost" data-apply="${r.n}">Apply the packet edits</button><span class="muted">then Run to see the forward result.</span></div>`;
    out += `</div>`;
  }
  if (b.calls?.length) out += `<details class="run-calls"><summary>Lens calls (${b.calls.length})</summary>${b.calls.map((c, i) => `<details><summary>${i + 1}. ${D.esc(c.model)} · ${D.esc(c.status)}${c.ms !== undefined ? ` · ${(c.ms / 1000).toFixed(1)}s` : ''}</summary><div class="run-io"><div><div class="label">prompt</div><pre>${D.esc(c.prompt)}</pre></div><div><div class="label">reply</div><pre>${D.esc(c.reply ?? '')}</pre></div></div></details>`).join('')}</details>`;
  return out;
}

// ---- results ---------------------------------------------------------------------------
// The seed-0 run of the unedited program on the spec packet: what every variation is read against.
function baselineOf(list, run) {
  const original = programs.find(p => p.key === run.program)?.src;
  return list.find(r => r !== run && r.status === 'done' && r.program === run.program && r.src === original && r.seed === 0 && r.packetNote === 'packet from the spec');
}

function renderRuns() {
  try { renderRunsInner(); } catch (e) {
    // A rendering bug must be visible, not a silent rejected promise.
    if ($('runCards')) $('runCards').insertAdjacentHTML('afterbegin', `<p class="err">Display error: ${D.esc(e.message || e)}</p>`);
    console.error(e);
  }
}

function renderRunsInner() {
  if (!$('runCards') || !ruleId) return;
  const list = runs[ruleId] || [], auth = authoredCache[ruleId];
  const sel = $('runAgainst'), prev = sel.value;
  sel.innerHTML = `<option value="authored">the authored profile</option>` + list.filter(r => r.status === 'done').map(r => `<option value="${r.n}">run ${r.n}</option>`).join('');
  sel.value = [...sel.options].some(o => o.value === prev) ? prev : 'authored';
  const against = sel.value === 'authored' ? { parts: auth?.parts, name: 'authored' } : (() => { const r = list.find(x => String(x.n) === sel.value); return { parts: r?.parts, name: `run ${r?.n}` }; })();
  $('runSummary').innerHTML = summary(list, auth);
  // A sweep makes one run per sentence: keep those cards together, folded.
  const main = list.filter(r => !r.without), swept = list.filter(r => r.without);
  const sweepOpen = $('runSweepCards')?.open ? 'open' : '';
  $('runCards').innerHTML = (swept.length ? `<details class="sweep-cards" id="runSweepCards" ${sweepOpen}><summary>Runs with one sentence switched off (${swept.length})</summary>${swept.slice().reverse().map(r => card(r, against, auth)).join('')}</details>` : '')
    + (main.slice().reverse().map(r => card(r, against, auth)).join('') || '<p class="muted">No runs yet for this rule.</p>');
  const byN = n => list.find(r => String(r.n) === n);
  $('runCards').querySelectorAll('[data-judge]').forEach(b => b.onclick = () => judge(byN(b.dataset.judge)));
  $('runCards').querySelectorAll('[data-back]').forEach(d => d.ontoggle = () => { byN(d.dataset.back).back.open = d.open; });
  $('runCards').querySelectorAll('[data-back-edit]').forEach(t => t.oninput = () => { byN(t.dataset.backEdit).back.edited = t.value; });
  $('runCards').querySelectorAll('[data-put]').forEach(b => b.onclick = () => propose(byN(b.dataset.put)));
  $('runCards').querySelectorAll('[data-apply]').forEach(b => b.onclick = () => applyPacketEdits(byN(b.dataset.apply)));
}

function summary(list, auth) {
  const all = list.filter(r => r.status === 'done');
  if (!all.length || !auth) return '';
  const done = all.filter(r => !r.without);
  const aw = words(allText(auth.parts)).length;
  const original = r => r.src === programs.find(p => p.key === r.program)?.src;
  const rows = done.map(r => {
    const base = baselineOf(list, r);
    const w = words(allText(r.parts)).length;
    const st = styleOf(r.parts, auth.parts).style, f1 = r.judge?.status === 'done' ? r.judge.score : null;
    return `<tr><td>run ${r.n}</td><td>${D.esc(r.programLabel)}</td><td>${r.seed}</td><td>${D.esc(r.packetNote)}</td><td>${w} <span class="muted">(${(w / Math.max(1, aw)).toFixed(1)}×)</span></td><td>${base ? pct(changed(allText(base.parts), allText(r.parts))) : '—'}</td><td>${pct(changed(allText(auth.parts), allText(r.parts)))}</td><td>${f1 !== null ? f1.toFixed(2) : '—'}</td><td>${st.toFixed(2)}</td><td>${f1 !== null ? Math.sqrt(f1 * st).toFixed(2) : '—'}</td></tr>`;
  }).join('');
  // Plain reading: sampling noise vs the effect of a packet edit, for the same program.
  const notes = [];
  const resamples = done.filter(r => r.seed > 0 && r.packetNote === 'packet from the spec' && original(r));
  const noise = resamples.map(r => { const b = baselineOf(list, r); return b ? changed(allText(b.parts), allText(r.parts)) : null; }).filter(x => x !== null);
  const edits = done.filter(r => r.packetNote !== 'packet from the spec' && original(r) && r.seed === 0).map(r => { const b = baselineOf(list, r); return b ? [r, changed(allText(b.parts), allText(r.parts))] : null; }).filter(Boolean);
  if (noise.length) notes.push(`A fresh sample of the same input changes ${pct(noise.reduce((a, b) => a + b, 0) / noise.length)} of the words.`);
  const most = noise.length ? Math.max(...noise) : null, samples = `${noise.length} re-sample${noise.length === 1 ? '' : 's'}`;
  for (const [r, x] of edits) notes.push(`Run ${r.n} (${D.esc(r.packetNote)}) changes ${pct(x)} of the words against run ${baselineOf(list, r).n}${most === null ? '; take a new sample to see how much change is just noise.' : x > most ? ` — more than any of the ${samples} so far (at most ${pct(most)})${noise.length < 3 ? '; more samples make this firmer' : ''}.` : ` — no more than the ${samples} (up to ${pct(most)}), so this edit cannot be told apart from a re-sample.`}`);
  return `<div class="run-table-wrap"><table class="run-table"><tr><th>run</th><th>program</th><th>seed</th><th>packet</th><th>words <span class="muted">(authored ${aw})</span></th><th>changed vs seed-0 run</th><th>changed vs authored</th><th title="meaning: authored clauses reproduced, statements supported">strict F1</th><th title="shape: length and sentence count against the authored parts, and no leaks (echoed labels, quote markers, rule codes, headings)">style</th><th title="sqrt(strict F1 × style)">combined</th></tr>${rows}</table></div>${notes.length ? `<p class="sub">${notes.join(' ')}</p>` : ''}${influence(list, all, resamples)}`;
}

// Which instruction sentences matter: for each sentence switched off, the parts whose text
// changed (untouched calls replay byte for byte) and by how much, against how much the same
// parts change on a plain re-sample.
function influence(list, all, resamples) {
  const swept = all.filter(r => r.without);
  if (!swept.length) return '';
  // Length change is |log(words / baseline words)|: shape effects (shorter, one sentence) are
  // far less noisy than wording, which a re-sample alone rewrites by half.
  const lenShift = (a, b) => Math.abs(Math.log(Math.max(1, words(b).length) / Math.max(1, words(a).length)));
  const noiseByPart = {}, lenNoise = {};
  for (const r of resamples) {
    const b = baselineOf(list, r);
    if (!b) continue;
    for (const [label, text] of r.parts) {
      noiseByPart[label] = Math.max(noiseByPart[label] ?? 0, changed(partText(b.parts, label), text));
      lenNoise[label] = Math.max(lenNoise[label] ?? 0, lenShift(partText(b.parts, label), text));
    }
  }
  const rows = swept.map(r => {
    const b = baselineOf(list, r);
    if (!b) return null;
    const moved = r.parts.map(([label, text]) => [label, changed(partText(b.parts, label), text)]).filter(([, x]) => x > 0);
    const effect = moved.length ? Math.max(...moved.map(([, x]) => x)) : 0;
    const noise = moved.length ? Math.max(...moved.map(([label]) => noiseByPart[label] ?? 0)) : 0;
    const lens = moved.map(([label]) => [label, lenShift(partText(b.parts, label), partText(r.parts, label))]);
    const len = lens.length ? lens.reduce((a, c) => (c[1] > a[1] ? c : a)) : null;
    const lenBeyond = !!len && resamples.length > 0 && len[1] > (lenNoise[len[0]] ?? 0);
    const lenText = len ? `${words(partText(b.parts, len[0])).length} → ${words(partText(r.parts, len[0])).length} words (${D.esc(len[0])})` : '—';
    return { r, moved, effect, noise, lenText, lenBeyond, beyond: moved.length > 0 && resamples.length > 0 && effect > noise };
  }).filter(Boolean).sort((a, b) => (b.effect - b.noise) - (a.effect - a.noise));
  const beyond = rows.filter(x => x.beyond).length, lenBeyond = rows.filter(x => x.lenBeyond).length;
  // With k re-samples and no real effect, an ablated run exceeds all k by chance 1 time in k+1.
  const k = resamples.length, chance = k ? Math.round(rows.length / (k + 1)) : null;
  const body = rows.map(({ r, moved, effect, noise, beyond, lenText, lenBeyond }) => `<tr class="${beyond && lenBeyond ? 'beyond' : ''}"><td title="${D.esc(r.without.text)}">${D.esc(r.without.text.length > 110 ? r.without.text.slice(0, 108) + '…' : r.without.text)}</td><td>${D.esc(r.without.label)}</td><td>${moved.map(([l]) => D.esc(l)).join(', ') || '—'}</td><td>${moved.length ? pct(effect) : '0%'}${moved.length && k ? ` <span class="muted">/ ${pct(noise)}</span>` : ''}</td><td>${lenText}${lenBeyond ? ' <b>*</b>' : ''}</td><td>${!k ? 'take a re-sample' : beyond && lenBeyond ? 'wording and length beyond re-samples' : lenBeyond ? 'length beyond re-samples' : beyond ? 'wording beyond re-samples' : moved.length ? 'within re-sample noise' : 'no change'}</td></tr>`).join('');
  return `<h4 class="run-h">What changes the output</h4><p class="sub">${rows.length} sentences, instruction groups or packet fields removed one at a time. Wording: <b>${beyond}</b> changed a part more than every re-sample did; length: <b>${lenBeyond}</b>.${k ? ` With ${k} re-sample${k === 1 ? '' : 's'} and no real effects, about <b>${chance}</b> would do so by chance — ${Math.max(beyond, lenBeyond) > 1.5 * chance ? 'more than chance, so some of these instructions matter' : 'so this sweep cannot tell real effects from chance; take more re-samples'}.` : ' Take a re-sample to compare against.'} Text change, not correctness: judge a run to see whether a change helps.</p><div class="run-table-wrap"><table class="run-table influence"><tr><th>sentence switched off</th><th>where</th><th>parts re-written</th><th>wording change <span class="muted">/ re-sample</span></th><th>length</th><th>reading</th></tr>${body}</table></div>`;
}

function card(r, against, auth) {
  const head = `<div class="run-head"><b>Run ${r.n}</b> · ${D.esc(r.programLabel)} · seed ${r.seed} · ${D.esc(r.packetNote)} · <span class="muted">${D.esc(r.writer)}</span>${r.secs !== undefined ? ` · ${r.secs}s` : ''} · ${r.calls.length} model call${r.calls.length === 1 ? '' : 's'}${r.status === 'running' ? ' <span class="state">running</span>' : ''}</div>`;
  const calls = r.calls.length ? `<details class="run-calls"><summary>Model calls (${r.calls.length}): prompts and replies</summary>${r.calls.map((c, i) => `<details><summary>${i + 1}. ${D.esc(c.status)}${c.ms !== undefined ? ` · ${(c.ms / 1000).toFixed(1)}s` : ''} · …${D.esc(c.prompt.slice(-110).replace(/\s+/g, ' '))}</summary><div class="run-io"><div><div class="label">prompt</div><pre>${D.esc(c.prompt)}</pre></div><div><div class="label">reply</div><pre>${D.esc(c.reply ?? '')}</pre></div></div></details>`).join('')}</details>` : '';
  if (r.status === 'failed') return `<article class="run-card failed">${head}<p class="err">${D.esc(r.error || 'failed')}</p>${calls}</article>`;
  if (r.status !== 'done') return `<article class="run-card">${head}${calls}</article>`;
  const verdicts = r.judge?.status === 'done' ? Object.fromEntries(r.judge.parts.map(p => [p.label.toUpperCase(), p])) : {};
  const styleParts = styleOf(r.parts, auth?.parts).parts;
  const parts = r.parts.map(([label, text]) => {
    const other = partText(against.parts, label), aw = words(partText(auth?.parts, label)).length, w = words(text).length;
    const v = verdicts[label.toUpperCase()];
    const judged = v ? `<details class="run-judged"><summary>F1 ${v.f1.toFixed(2)} · recall ${v.recall.toFixed(2)} · precision ${v.precision.toFixed(2)}</summary><ul>${v.reference.map(c => `<li class="j-${D.esc(c.status)}"><b>${D.esc(c.status)}</b> ${D.esc(c.clause)}${c.note ? ` <span class="muted">— ${D.esc(c.note)}</span>` : ''}</li>`).join('')}</ul><ul>${(v.candidate || []).map(c => `<li class="j-${D.esc(c.status)}"><b>${D.esc(c.status)}</b> ${D.esc(c.text)}</li>`).join('')}</ul></details>` : '';
    const ch = changed(other, text), m = marked(other, text, ch > 0.5);
    const codes = ruleCodes(text), sp = styleParts.find(x => x.label === label);
    return `<div class="field"><div class="label">${D.esc(label)}</div><div class="run-stats">${w} words · ${sentences(text)} sentence${sentences(text) === 1 ? '' : 's'} (authored ${aw} words)${sp ? ` · style ${sp.style.toFixed(2)}` : ''}${sp?.leaks.length ? ` · <b class="leak">${sp.leaks.join(', ')}</b>` : codes ? ` · ${codes} rule code${codes === 1 ? '' : 's'}` : ''}${other ? ` · ${pct(ch)} changed vs ${D.esc(against.name)} · ${ch > 0.5 ? 'underlined: content words shared with it' : 'highlighted: new'} · ${m.removed} of its words absent` : ''}</div><div class="text">${other ? m.html : D.esc(text)}</div>${judged}</div>`;
  }).join('');
  const judgeBtn = !judgeLib || !clauses?.[r.id] ? '' : r.judge?.status === 'running' ? '<span class="state">judging…</span>' : r.judge?.status === 'failed' ? `<p class="err">Judge failed: ${D.esc(r.judge.error)}</p><button class="ghost" data-judge="${r.n}">Retry judge</button>` : r.judge?.status === 'done' ? `<span class="state ok">strict F1 ${r.judge.score.toFixed(2)} · ${D.esc(r.judge.model)}</span>` : `<button class="ghost" data-judge="${r.n}" title="One judge call per part: each authored clause present / weakened / missing; each written statement supported / extra">Judge (strict clause F1)</button>`;
  r.back ||= { edited: r.md, open: false };
  const back = `<details class="run-back" data-back="${r.n}" ${r.back.open ? 'open' : ''}><summary>Backward: edit this output and see which packet change would produce it</summary>
    <p class="muted">Each model step is asked for the smallest edit to its own inputs that would give your text; the edits are pushed back through the program to the packet (or to the worked examples, or the program's own wording), then the program is re-run to check. About two calls per model step, plus a re-run.</p>
    <textarea class="back-edit" data-back-edit="${r.n}" spellcheck="false">${D.esc(r.back.edited)}</textarea>
    <div class="run-actions"><button class="ghost" data-put="${r.n}" ${r.back.status === 'running' ? 'disabled' : ''}>Propose packet edits</button></div>${backHtml(r)}</details>`;
  return `<article class="run-card">${head}<div class="run-judge">${judgeBtn}</div>${parts}${back}${calls}</article>`;
}

// ---- endpoint settings (shared by every page on this origin) ---------------------------------
function wireEndpoint() {
  const box = $('endpoint');
  if (!box) return;
  const status = () => { $('epStatus').textContent = endpointReady() ? `${ep.baseUrl.replace(/^https?:\/\//, '')} · writer ${ep.writer} · judge ${ep.judge}` : 'not set — enter an OpenAI-compatible base URL to run programs'; };
  $('epBase').value = ep.baseUrl; $('epKey').value = ep.apiKey; $('epRemember').checked = ep.remember;
  $('epWriter').value = ep.writer; $('epJudge').value = ep.judge;
  box.open = !endpointReady();
  const save = () => {
    ep = { baseUrl: $('epBase').value.trim(), apiKey: $('epKey').value.trim(), remember: $('epRemember').checked, writer: $('epWriter').value.trim() || DEFAULTS.writer, judge: $('epJudge').value.trim() || DEFAULTS.judge };
    saveEndpoint(); status();
    if ($('runNeed')) $('runNeed').textContent = endpointReady() ? '' : 'Set a model endpoint above to run programs.';
    D.nlir.clearEvaluationCache?.();
  };
  for (const id of ['epBase', 'epKey', 'epWriter', 'epJudge']) $(id).onchange = save;
  $('epRemember').onchange = save;
  $('epTest').onclick = async () => {
    save();
    const out = $('epTestOut'); out.textContent = 'checking…';
    try {
      const res = await fetch(ep.baseUrl.replace(/\/+$/, '') + '/models', { headers: ep.apiKey ? { Authorization: 'Bearer ' + ep.apiKey } : {} });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const ids = ((await res.json()).data || []).map(m => m.id).sort();
      $('epModels').innerHTML = ids.map(i => `<option value="${D.esc(i)}">`).join('');
      const missing = [ep.writer, ep.judge].filter(m => !ids.includes(m));
      out.textContent = `${ids.length} models available${missing.length ? ` · not listed: ${missing.join(', ')}` : ' · writer and judge both listed'}`;
    } catch (e) { out.textContent = `Could not list models: ${e.message || e}. Check the URL and key; the endpoint must allow cross-origin requests from this page.`; }
  };
  $('epForget').onclick = () => { $('epKey').value = ''; save(); };
  status();
}
