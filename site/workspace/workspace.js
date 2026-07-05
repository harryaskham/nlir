/* nlir workspace — prototype app logic.
 *
 * The evaluator here is a MOCK. When P1 (crates/nlir-wasm, bd-3fcf96) lands, swap
 * the `nlir` object below for the real wasm bindings — the agreed P1<->P2 contract:
 *
 *   import init, { evaluate, step, operators, parse, version } from './pkg/nlir_wasm.js';
 *   await init();
 *   evaluate(expr, configJson, contextJson, mode, realisers?) -> Promise<{ok, result|error}>
 *   step(expr, configJson, contextJson, mode, realisers?)     -> Promise<{ok, steps: string[]}>  // msm-0: Vec<String>, each = expr-at-step
 *   operators(configJson) -> [{op,name,description,arity,priority,fixity,det}]
 *   parse(expr, configJson)  -> {ok, ast|error}   // aur-0: grammar is config-defined, tokenize needs op sigils
 *
 * P1 increment 1 (aur-0): version/parse/operators/det-evaluate + det step (step_trace) — the
 * key-free path — land first; llm evaluate/step arrive with the JsRealiser + msm-0's step_async.
 *
 * det-mode needs NO realiser (det never awaits); llm-mode passes realisers (P3+).
 * The crate parses configJson -> Config at its boundary; the widget stays format-agnostic.
 */

const LS_KEY = 'nlir.workspace.v1';

// The FULL operator set in the real name-keyed schema (operators keyed by NAME,
// sigil in `op:`) so the wasm evaluator actually parses it — the old sigil-keyed
// excerpt failed to parse (`unknown field name`), which is why the ops list only
// showed a few operators (bd-799000). Reset restores this; on the live build the
// workspace fetches the full config.example.yaml (which also seeds prompts+types).
// `demo` is a placeholder model so det-mode + the ops list work offline; llm mode
// uses the fetched config or the Settings BYO endpoint.
const DEFAULT_CONFIG = `# nlir config (workspace default) — the full operator set, offline-parseable.
# Reset restores this; the live site uses the evaluator's own bundled config.
models:
  demo: { type: command, format: text, command: "echo %" }
defaults:
  mode: det
  model: { small: demo, medium: demo, large: demo }
operators:
  subject:  { op: "#",  fixity: prefix,  arity: 1,   model: medium, prompt: "Subject of: %", description: "topic label — folds a list to its shared category" }
  summary:  { op: "~",  fixity: prefix,  arity: 1,   model: medium, prompt: "Summarise: %", description: "the gist/essence — saturates, folds to consensus" }
  formal:   { op: "@",  fixity: prefix,  arity: 1,   model: medium, prompt: "Formal register: %", description: "formal register — saturates, distributes over &" }
  simplify: { op: ":",  fixity: prefix,  arity: 1,   model: medium, prompt: "Plain language: %", description: "plain language — reliably maps over a list" }
  expand:   { op: ">",  fixity: prefix,  arity: 1,   model: medium, prompt: "Elaborate: %", description: "expand — forks over |, integrates over &" }
  shorten:  { op: "<",  fixity: prefix,  arity: 1,   model: medium, prompt: "Shorten, keep every fact: %", description: "shorten to the info floor (vs ~ = the gist)" }
  diff:     { op: "Δ",  fixity: infix,   arity: 2,   model: medium, prompt: "What changed, first to second: %", description: "directional diff — non-commutative" }
  implies:  { op: "~>", fixity: infix,   arity: 2,   model: medium, prompt: "Does the first imply the second? %", description: "implication check — integrates over &" }
  imply:    { op: "~>?",fixity: mixfix,  arity: ">0",model: medium, prompt: "What do these imply? %", description: "implication inference — integrates over &" }
  not:      { op: "!",  fixity: prefix,  arity: 1,   template: "not (%)", description: "negate, clause-wise (involution: !!a = a)" }
  question: { op: "?",  fixity: postfix, arity: 1,   priority: 40, template: "%?", description: "turn into a question (postfix)" }
  and:      { op: "&",  fixity: mixfix,  arity: ">0", join: " and ", description: "join as a plan (nullary & folds the stack)" }
  or:       { op: "|",  fixity: mixfix,  arity: ">0", join: " or ", description: "a genuine choice between options" }
  add:      { op: "+",  fixity: mixfix,  arity: ">0", priority: 11, operands: number, result: number, reduce: add, description: "numeric addition (variadic)" }
  subtract: { op: "-",  fixity: infix,   arity: 2,   priority: 11, operands: number, result: number, reduce: sub, description: "numeric subtract (left-assoc: 2-3-4 = -5)" }
  multiply: { op: "*",  fixity: mixfix,  arity: ">0", priority: 12, operands: number, result: number, reduce: mul, description: "numeric multiply (variadic)" }
  divide:   { op: "/",  fixity: infix,   arity: 2,   priority: 12, operands: number, result: number, reduce: div, description: "numeric divide (guards /0)" }
  power:    { op: "**", fixity: infix,   arity: 2,   priority: 13, assoc: right, operands: number, result: number, reduce: pow, description: "power (right-assoc: 2**3**2 = 512)" }
  echo:     { op: "_",  fixity: infix,   arity: 2,   priority: 14, command: "for i in $(seq \${NLIR_ARGS[1]}); do echo \${NLIR_ARGS[0]}; done", description: "repeat N times (shell-realised)" }
`;

// operators() mock — mirrors nlir help (aur-2's summary()/is_deterministic()).
const MOCK_OPERATORS = [
  ['#','subject','topic label — folds a list to its shared category', false],
  ['~','summary','the gist/essence — saturates, folds to consensus', false],
  ['@','formal','formal register — saturates, distributes over &', false],
  [':','simplify','strip jargon — reliably maps over a list', false],
  ['>','expand','elaborate — forks over |, integrates over &', false],
  ['<','shorten','shorten but keep every fact (info floor)', false],
  ['Δ','diff','directional diff — what changed, first → second (non-commutative)', false],
  ['~>','implication-check','does the first imply the second? — integrates over &', false],
  ['~>?','implication-infer','the implication of its arguments — integrates over &', false],
  ['!','not','negate, clause-wise (involution: !!a = a)', true],
  ['?','question','turn into a question (postfix)', true],
  ['&','and','join as a plan (nullary & folds the stack)', true],
  ['|','or','a genuine choice between options', true],
  ['_','echo','repeat N times (shell-realised)', true],
  ['+','add','numeric addition', true],
  ['*','multiply','numeric multiply', true],
  ['-','subtract','numeric subtract (left-assoc: 2-3-4 = -5)', true],
  ['/','divide','numeric divide (guards /0)', true],
  ['**','power','power (right-assoc: 2**3**2 = 512)', true],
].map(([op,name,description,det]) => ({op,name,description,det,arity:1,priority:0,fixity:''}));

// Known-example outputs so the demo reads real (still badged "mock" for llm ops).
const EXAMPLES = [
  { expr: "2**3**2",           mode:'det' },
  { expr: "2-3-4",             mode:'det' },
  { expr: "@'lmk if any Qs'",  mode:'llm', out:"Please let me know if you have any questions." },
  { expr: "~'the mobile team is blocked on the shared auth library, which is late'", mode:'llm', out:"The mobile team is blocked by the late shared auth library." },
  { expr: "'too many steps';'users drop off';&;~$", mode:'llm', out:"Users drop off because there are too many steps." },
  { expr: "#['login broken','OAuth 500s','reset fails']", mode:'llm', out:"Authentication." },
];

// ---- MOCK evaluator (swap for real wasm at P1) ----
const NUMERIC = /^[\s\d+\-*/().]+$/;
function tryNumeric(expr){
  const e = expr.replace(/\s+/g,'');
  if (!NUMERIC.test(e) || !/[-+*/]/.test(e)) return null;
  try { const v = Function('"use strict";return('+e+')')(); return Number.isFinite(v) ? String(v) : null; }
  catch { return null; }
}
function knownOut(expr){ const m = EXAMPLES.find(x => x.expr === expr); return m && m.out; }

// A small preview graph (mock path, no pkg/): real dataflow graphs render on the
// site via graph()/graphFrames(). data-id groups let the highlight logic be tested.
const PLACEHOLDER_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 340 210"><rect x="1" y="1" width="338" height="208" rx="16" fill="#100a24" stroke="rgba(168,85,247,.28)"/><line x1="100" y1="132" x2="165" y2="70" stroke="rgba(168,85,247,.5)" stroke-width="1.6"/><line x1="240" y1="132" x2="175" y2="70" stroke="rgba(168,85,247,.5)" stroke-width="1.6"/><g data-id="0"><rect x="130" y="28" width="80" height="40" rx="10" fill="#241a45" stroke="#a855f7"/><text x="170" y="48" fill="#e879f9" text-anchor="middle" dominant-baseline="central" font-family="Fira Code,monospace" font-size="13">op</text></g><g data-id="0.0"><rect x="60" y="132" width="80" height="40" rx="10" fill="#170f2c" stroke="#4a3a6a"/><text x="100" y="152" fill="#cbb9f5" text-anchor="middle" dominant-baseline="central" font-family="Fira Code,monospace" font-size="13">a</text></g><g data-id="0.1"><rect x="200" y="132" width="80" height="40" rx="10" fill="#170f2c" stroke="#4a3a6a"/><text x="240" y="152" fill="#cbb9f5" text-anchor="middle" dominant-baseline="central" font-family="Fira Code,monospace" font-size="13">b</text></g></svg>';

const MOCK = {
  async evaluate(expr){
    const n = tryNumeric(expr);
    if (n !== null) return { ok:true, result:n, real:true };
    const k = knownOut(expr);
    return { ok:true, result: k || `⟨realised English for ${expr}⟩`, mock:true };
  },
  async step(expr){
    const n = tryNumeric(expr);
    if (n !== null) return { ok:true, steps:[{expr}, {expr:`= ${n}`}], real:true };
    const k = knownOut(expr) || '⟨realised⟩';
    return { ok:true, steps:[{expr}, {expr:`→ «${k}»`}], mock:true };
  },
  operators(){ return MOCK_OPERATORS; },
  parse(expr){ return { ok:true, ast:expr }; },
  graph(){ return { ok:true, svg:PLACEHOLDER_SVG, mock:true }; },
  graphFrames(){ return { ok:true, mock:true, frames:[
    { svg:PLACEHOLDER_SVG, reduced:null }, { svg:PLACEHOLDER_SVG, reduced:'0.0' },
    { svg:PLACEHOLDER_SVG, reduced:'0.1' }, { svg:PLACEHOLDER_SVG, reduced:'0' },
  ] }; },
  async graphFramesAsync(){ return this.graphFrames(); },
  version(){ return { crate:'mock', git:'—' }; },
  defaultConfigYaml(){ return DEFAULT_CONFIG; },
};

// Real nlir-wasm loads when ./pkg/ is present (CI-built + embedded by P7); else MOCK.
// O()/A() normalise serde_wasm_bindgen output (it may emit JS Maps for json! objects).
let nlir = MOCK;
let wasmReal = false;
(async function loadWasm(){
  try {
    const m = await import('./pkg/nlir_wasm.js');
    if (m.default) await m.default();
    const O = v => v instanceof Map ? Object.fromEntries(v) : v;
    const A = v => Array.isArray(v) ? v.map(O) : O(v);
    nlir = {
      async evaluate(e,c,x,md,r){ return O(await m.evaluate(e,c,x,md,r)); },
      async step(e,c,x,md,r){ const rr = O(await m.step(e,c,x,md,r)); if (rr.steps) rr.steps = A(rr.steps); return rr; },
      operators(c){ return A(m.operators(c)); },
      parse(e,c){ return O(m.parse(e,c)); },
      graph(e,c){ return O(m.graph(e,c)); },
      graphFrames(e,c,md){ const r = O(m.graphFrames(e,c,md)); if (r.frames) r.frames = A(r.frames); return r; },
      async graphFramesAsync(e,c,x,md,r){ const rr = O(await m.graphFramesAsync(e,c,x,md,r)); if (rr.frames) rr.frames = A(rr.frames); return rr; },
      version(){ return O(m.version()); },
      defaultConfigYaml(){ return m.defaultConfigYaml(); },
    };
    wasmReal = true;
    const v = nlir.version() || {};
    $('verBadge').textContent = 'wasm: ' + (v.crate || 'live') + (v.git && v.git!=='unknown' ? ' · '+String(v.git).slice(0,7) : '');
    // Anti-drift (bd-ca518b): the config is the wasm's own include_str! copy of config.example.yaml
    // (single source of truth, always in lockstep with the parser). Adopt it as the default.
    try { const cfg = nlir.defaultConfigYaml(); if (cfg && state.config === DEFAULT_CONFIG){ state.config = cfg; if ($('config')) $('config').value = cfg; save(); } } catch {}
    renderOps();
  } catch (err) {
    console.info('nlir-wasm pkg/ not present — using mock evaluator.', err && err.message);
  }
})();

// ---- state ----
const state = load();
function load(){
  const defaults = { config: DEFAULT_CONFIG, messages: [{role:'user', text:'Can we ship the auth change on Friday?'}], kv: [], settings:{ mode:'det', baseUrl:'', apiKey:'', model:'' } };
  try {
    const s = JSON.parse(localStorage.getItem(LS_KEY));
    // Deep-merge onto defaults so a state persisted before `settings` (or any
    // subfield) existed still yields a complete settings object — otherwise
    // `state.settings.mode`/`.baseUrl` are undefined and init()/realisers()
    // break (bd-09c89c: LLM url/key not persisting).
    if (s && s.config) return { ...defaults, ...s, settings: { ...defaults.settings, ...(s.settings || {}) } };
  } catch {}
  return defaults;
}
function save(){ localStorage.setItem(LS_KEY, JSON.stringify(state)); }

// ---- syntax highlight (tokenizer — never re-scans inserted markup) ----
const OP_SET = new Set("@~:><#!?&|+*/_=;".split(''));
function esc(x){ return x.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function hl(s){
  let out = '', i = 0;
  while (i < s.length){
    const c = s[i];
    if (c === "'"){ let j = i+1; while (j < s.length && s[j] !== "'") j++; out += `<span class="s">${esc(s.slice(i, Math.min(j+1, s.length)))}</span>`; i = j+1; continue; }
    if (/\d/.test(c)){ let j = i; while (j < s.length && /[\d.]/.test(s[j])) j++; out += `<span class="num">${s.slice(i,j)}</span>`; i = j; continue; }
    if (c === '*' && s[i+1] === '*'){ out += '<span class="o">**</span>'; i += 2; continue; }
    if (OP_SET.has(c)){ out += `<span class="o">${esc(c)}</span>`; i++; continue; }
    out += esc(c); i++;
  }
  return out;
}

// ---- render ----
const $ = id => document.getElementById(id);

// ---- expression editor (bd-98c6cc): fullwidth multiline; CodeMirror + optional
// vim keymap when the CDN loaded, else a raw <textarea> fallback. run/step/graph
// read the value via getExpr(); examples set it via setExpr(). ⌘/Ctrl+Enter runs.
let cm = null;
const vimAvailable = () => !!(window.CodeMirror && CodeMirror.keyMap && CodeMirror.keyMap.vim);
function getExpr(){ return (cm ? cm.getValue() : $('expr').value) || ''; }
function setExpr(v){ if (cm){ cm.setValue(v); cm.focus(); } else { $('expr').value = v; } }
function initEditor(){
  const ta = $('expr');
  if (window.CodeMirror){
    cm = CodeMirror.fromTextArea(ta, {
      lineWrapping: true,
      viewportMargin: Infinity,   // grow to content height (multiline, no inner scrollbar)
      keyMap: (state.settings.vim && vimAvailable()) ? 'vim' : 'default',
      extraKeys: { 'Cmd-Enter': () => run(), 'Ctrl-Enter': () => run() },
    });
    if (state.settings.expr) cm.setValue(state.settings.expr);
    cm.on('change', () => { state.settings.expr = cm.getValue(); save(); });
  } else {
    // fallback: the raw textarea is already fullwidth + multiline (CSS); wire persistence + run.
    if (state.settings.expr) ta.value = state.settings.expr;
    ta.addEventListener('input', () => { state.settings.expr = ta.value; save(); });
    ta.addEventListener('keydown', e => { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)){ e.preventDefault(); run(); } });
  }
  updateVimToggle();
}
function setVim(on){
  on = !!on; state.settings.vim = on; save();
  if (cm && vimAvailable()) cm.setOption('keyMap', on ? 'vim' : 'default');
  updateVimToggle();
  if (cm) cm.focus();
}
function updateVimToggle(){
  const b = $('vimToggle'); if (!b) return;
  if (!vimAvailable()){ b.textContent = 'vim: n/a'; b.disabled = true; b.title = 'vim keymap unavailable (offline?)'; b.setAttribute('aria-pressed','false'); return; }
  const on = !!state.settings.vim;
  b.textContent = 'vim: ' + (on ? 'on' : 'off');
  b.classList.toggle('on', on);
  b.setAttribute('aria-pressed', on ? 'true' : 'false');
}
function renderExamples(){
  $('examples').innerHTML = '';
  EXAMPLES.forEach(ex => {
    const c = document.createElement('span');
    c.className = 'chip'; c.innerHTML = hl(ex.expr);
    c.onclick = () => { setExpr(ex.expr); setMode(ex.mode); run(); };
    $('examples').appendChild(c);
  });
}
function renderOps(){
  const box = $('ops'); box.innerHTML = '';
  const ops = nlir.operators(configJson());
  if (!Array.isArray(ops)){ box.innerHTML = `<span class="err">config: ${(ops && ops.error) || 'parse error'}</span>`; return; }
  ops.forEach(o => {
    const d = document.createElement('div'); d.className = 'op';
    d.innerHTML = `<span class="sig">${String(o.op).replace(/</g,'&lt;').replace(/>/g,'&gt;')}</span><span class="nm">${o.name}</span><span class="ds">${o.description}</span><span class="tag ${o.det?'det':'llm'}">${o.det?'det':'llm'}</span>`;
    box.appendChild(d);
  });
}
function renderMessages(){
  const box = $('messages'); box.innerHTML = '';
  state.messages.forEach((m,i) => {
    const r = document.createElement('div'); r.className = 'row msg';
    r.innerHTML = `<select class="role"><option${m.role==='user'?' selected':''}>user</option><option${m.role==='assistant'?' selected':''}>assistant</option><option${m.role==='system'?' selected':''}>system</option></select><input class="txt" value="${m.text.replace(/"/g,'&quot;')}"><button class="x">✕</button>`;
    r.querySelector('select').onchange = e => { m.role = e.target.value; save(); };
    r.querySelector('.txt').oninput = e => { m.text = e.target.value; save(); };
    r.querySelector('.x').onclick = () => { state.messages.splice(i,1); save(); renderMessages(); };
    box.appendChild(r);
  });
}
function renderKvs(){
  const box = $('kvs'); box.innerHTML = '';
  state.kv.forEach((p,i) => {
    const r = document.createElement('div'); r.className = 'row';
    r.innerHTML = `<input class="k" value="${p.k.replace(/"/g,'&quot;')}"><span class="o">=</span><input class="v" value="${p.v.replace(/"/g,'&quot;')}"><button class="x">✕</button>`;
    const [ik,iv] = r.querySelectorAll('input');
    ik.oninput = e => { p.k = e.target.value; save(); };
    iv.oninput = e => { p.v = e.target.value; save(); };
    r.querySelector('.x').onclick = () => { state.kv.splice(i,1); save(); renderKvs(); };
    box.appendChild(r);
  });
}

// ---- run / step ----
function configJson(){
  if (window.jsyaml){ try { return JSON.stringify(jsyaml.load(state.config) ?? {}); } catch { return '{}'; } }
  return '{}';
}
function contextJson(){
  const o = { _messages: state.messages.map(m => ({ role:m.role, content:m.text })) };
  state.kv.forEach(p => { if (p.k) o[p.k] = p.v; });
  return JSON.stringify(o);
}
// P3: build the llm realiser from the Settings panel (BYO base-url + key). det passes {} (unused).
// call = { vars:{NLIR_PROMPT,...}, model:{model:<id>,...}, operands:[...] } (aur-0's shape).
const unmap = v => (v instanceof Map ? Object.fromEntries(v) : v);
function realisers(){
  const baseUrl = (state.settings.baseUrl || '').trim();
  if (state.settings.mode === 'llm' && baseUrl){
    const base = baseUrl.replace(/\/+$/,''), key = (state.settings.apiKey || '').trim();
    return {
      llm: async (call) => {
        const c = unmap(call), model = unmap(c.model), vars = unmap(c.vars);
        const res = await fetch(base + '/chat/completions', {
          method:'POST',
          headers: Object.assign({ 'Content-Type':'application/json' }, key ? { Authorization:'Bearer '+key } : {}),
          body: JSON.stringify({ model: (state.settings.model || '').trim() || (model && model.model), messages:[{ role:'user', content: vars && vars.NLIR_PROMPT }] }),
        });
        if (!res.ok){ let d=''; try { d = (await res.text()).slice(0,300).replace(/\s+/g,' ').trim(); } catch (_) {} throw new Error('llm endpoint ' + res.status + (d ? ': ' + d : '')); }
        const j = await res.json();
        return (j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content) || '';
      },
    };
  }
  if (state.settings.mode === 'ondevice'){
    const LM = onDeviceApi();
    if (LM) return { llm: async (call) => {
      const c = unmap(call), vars = unmap(c.vars);
      let session;
      try { session = await LM.create(); }
      catch (e) {
        const msg = String((e && e.name ? e.name + ': ' + e.message : e) || e);
        if (/NotSupportedError|not enough space|space for downloading/i.test(msg))
          throw new Error('on-device unavailable: Chrome needs >22GB free on your profile drive to download Gemini Nano (a Chrome requirement, regardless of the ~few-GB model size). Free up space, or use llm mode with a hosted key.');
        throw new Error('on-device unavailable: ' + msg + ' — enable the Prompt API in chrome://flags, or use llm mode with a key.');
      }
      try { return await session.prompt((vars && vars.NLIR_PROMPT) || ''); }
      finally { try { session.destroy && session.destroy(); } catch (_) {} }
    } };
  }
  return {};
}
// On-device realiser (Chrome built-in Prompt API / window.ai): zero-key, zero-egress,
// capability-gated. Resolves the API across its naming variants; det + BYO-key stay baseline.
function onDeviceApi(){
  return self.LanguageModel || (self.ai && self.ai.languageModel) || (window.ai && window.ai.languageModel) || null;
}
async function checkOnDevice(){
  const el = $('odStatus'); if (!el) return;
  const LM = onDeviceApi();
  if (!LM){ el.textContent = '\u26a0 not available \u2014 this browser has no built-in AI (needs Chrome with the Prompt API).'; el.className = 'od-status warn'; return; }
  el.textContent = 'checking\u2026'; el.className = 'od-status';
  try {
    let a = 'unavailable';
    if (LM.availability) a = await LM.availability();
    else if (LM.capabilities){ const c = await LM.capabilities(); a = c && c.available; }
    const ready = a === 'available' || a === 'readily';
    const dl = a === 'downloadable' || a === 'downloading' || a === 'after-download';
    el.textContent = ready ? '\u2713 ready \u2014 Gemini Nano is available; run llm-mode with no key.'
      : dl ? '\u2b73 available after a one-time Gemini Nano download. Chrome needs >22GB free on your profile drive to fetch it (a Chrome requirement, not the model size).'
      : '\u26a0 not available on this device.';
    el.className = 'od-status' + (ready ? ' ok' : dl ? '' : ' warn');
  } catch (e){ el.textContent = '\u26a0 availability check failed: ' + e; el.className = 'od-status warn'; }
}
// The WASM eval knows only `det`/`llm`; on-device is an llm REALISER variant
// (Chrome built-in Prompt API), so it maps to `llm` mode with realisers()
// supplying the on-device callback. Without this the eval boundary rejects the
// UI's `ondevice` with `unknown mode "ondevice"` (bd-5c7306 follow-up).
function wasmMode(){ return state.settings.mode === 'det' ? 'det' : 'llm'; }

async function run(){
  const expr = getExpr().trim(); if (!expr) return;
  const out = $('output'); $('steps').innerHTML = '';
  out.innerHTML = '<span class="placeholder">running…</span>';
  const r = await nlir.evaluate(expr, configJson(), contextJson(), wasmMode(), realisers());
  if (!r.ok){ out.innerHTML = `<span class="err">${r.error}</span>`; return; }
  out.innerHTML = `<span class="result">${r.result.replace(/</g,'&lt;')}</span>` + (r.mock ? '<span class="mock">preview mock — the live site runs the real wasm</span>' : '');
  save();
}
async function step(){
  const expr = getExpr().trim(); if (!expr) return;
  const out = $('output'); out.innerHTML = '';
  const box = $('steps'); box.innerHTML = '<span class="placeholder">stepping…</span>';
  const r = await nlir.step(expr, configJson(), contextJson(), wasmMode(), realisers());
  box.innerHTML = '';
  if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
  r.steps.forEach((s,i) => {
    const d = document.createElement('div'); d.className = 'step';
    const txt = (s && typeof s === 'object') ? (s.expr ?? '') : s;
    d.innerHTML = `<span class="n">${i}</span><span class="x">${hl(String(txt))}</span>` + (i===r.steps.length-1 && r.mock ? '<span class="note">mock</span>' : '');
    box.appendChild(d);
  });
}

// ---- graph (G5): dataflow graph panel + step-frame animation with node highlight ----
let animTimer = null;
function showGraph(){
  clearInterval(animTimer);
  const expr = getExpr().trim(); if (!expr) return;
  const box = $('graphsvg');
  $('graphview').hidden = false; $('scrub').hidden = true; $('framecap').textContent = '';
  box.innerHTML = '<span class="placeholder">rendering…</span>';
  const r = nlir.graph(expr, configJson());
  if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
  box.innerHTML = r.svg + (r.mock ? '<div class="mock" style="margin-top:.5rem">preview graph — the live site renders your expression</div>' : '');
}
function renderFrame(frame){
  const box = $('graphsvg'); box.innerHTML = frame.svg;
  if (frame.reduced){ const g = box.querySelector(`[data-id="${frame.reduced}"]`); if (g) g.classList.add('reduced'); }
}
async function animate(){
  clearInterval(animTimer);
  const expr = getExpr().trim(); if (!expr) return;
  const box = $('graphsvg');
  $('graphview').hidden = false; box.innerHTML = '<span class="placeholder">building frames…</span>';
  const md = wasmMode();
  const r = md === 'llm'
    ? await nlir.graphFramesAsync(expr, configJson(), contextJson(), md, realisers())
    : nlir.graphFrames(expr, configJson(), md);
  if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
  const frames = r.frames || [];
  if (!frames.length){ box.innerHTML = '<span class="placeholder">(no frames)</span>'; return; }
  const scrub = $('scrub'); scrub.hidden = false; scrub.max = frames.length - 1;
  let i = 0;
  const show = k => {
    i = k; renderFrame(frames[k]); scrub.value = k;
    const red = frames[k].reduced;
    $('framecap').textContent = `frame ${k+1}/${frames.length}` + (red ? ` · reduced ${red}` : '') + (r.mock ? ' · preview' : '');
  };
  show(0);
  scrub.oninput = e => { clearInterval(animTimer); show(+e.target.value); };
  animTimer = setInterval(() => { if (i >= frames.length - 1){ clearInterval(animTimer); return; } show(i + 1); }, 950);
}

function setMode(m){
  state.settings.mode = m; save();
  document.querySelectorAll('#modeSeg button').forEach(b => b.classList.toggle('on', b.dataset.mode===m));
  $('modeBadge').textContent = m==='det' ? 'det · key-free' : m==='ondevice' ? 'on-device · private' : 'llm · needs a realiser';
  $('modeBadge').className = 'badge' + (m==='llm' ? ' warn' : '');
  $('llmPanel').hidden = m!=='llm';
  $('odPanel').hidden = m!=='ondevice';
  if (m==='ondevice') checkOnDevice();
}

// ---- wire ----
function init(){
  $('config').value = state.config;
  $('cfgNote').textContent = 'Operators below reflect this config.';
  renderExamples(); renderOps(); renderMessages(); renderKvs();
  setMode(state.settings.mode);
  initEditor();
  $('verBadge').textContent = 'wasm: ' + nlir.version().crate;
  $('baseUrl').value = state.settings.baseUrl; $('apiKey').value = state.settings.apiKey; $('model').value = state.settings.model;

  $('runBtn').onclick = run;
  $('stepBtn').onclick = step;
  $('graphBtn').onclick = showGraph;
  $('animBtn').onclick = animate;
  $('vimToggle').onclick = () => setVim(!state.settings.vim);
  document.querySelectorAll('#modeSeg button').forEach(b => b.onclick = () => setMode(b.dataset.mode));
  $('applyCfg').onclick = () => { state.config = $('config').value; save(); renderOps(); $('cfgNote').textContent = 'Applied — operators + graphs reflect this config.'; };
  $('resetCfg').onclick = () => { state.config = DEFAULT_CONFIG; $('config').value = DEFAULT_CONFIG; save(); renderOps(); $('cfgNote').textContent = 'Reset to default config.'; };
  $('addMsg').onclick = () => { const t = $('newMsg').value.trim(); if(!t) return; state.messages.push({role:$('newRole').value, text:t}); $('newMsg').value=''; save(); renderMessages(); };
  $('addKv').onclick = () => { const k = $('newKey').value.trim(); if(!k) return; state.kv.push({k, v:$('newVal').value}); $('newKey').value=''; $('newVal').value=''; save(); renderKvs(); };
  $('baseUrl').oninput = e => { state.settings.baseUrl = e.target.value; save(); };
  $('apiKey').oninput = e => { state.settings.apiKey = e.target.value; save(); };
  $('model').oninput = e => { state.settings.model = e.target.value; save(); };
}
init();
