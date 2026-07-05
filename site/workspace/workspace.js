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

const DEFAULT_CONFIG = `# nlir config (excerpt) — the operators the workspace knows.
# Reset restores this; the real build seeds the full config.example.yaml.
operators:
  "@": { name: formal,   fixity: prefix,  arity: 1, priority: 30, prompt: "Rewrite in a formal register: {NLIR_ARGS}" }
  "~": { name: summary,  fixity: prefix,  arity: 1, priority: 30, prompt: "Give the essence of: {NLIR_ARGS}" }
  ":": { name: simplify, fixity: prefix,  arity: 1, priority: 30, prompt: "Strip jargon from: {NLIR_ARGS}" }
  ">": { name: expand,   fixity: prefix,  arity: 1, priority: 30, prompt: "Elaborate: {NLIR_ARGS}" }
  "<": { name: shorten,  fixity: prefix,  arity: 1, priority: 30, prompt: "Shorten, keep every fact: {NLIR_ARGS}" }
  "#": { name: subject,  fixity: prefix,  arity: 1, priority: 30, prompt: "The subject/category of: {NLIR_ARGS}" }
  "!": { name: not,      fixity: prefix,  arity: 1, priority: 40, template: "not ({NLIR_ARGS})" }
  "?": { name: question, fixity: postfix, arity: 1, priority: 40, template: "{NLIR_ARGS}?" }
  "&": { name: and,      fixity: infix,   arity: 2, priority: 10, join: " and " }
  "|": { name: or,       fixity: infix,   arity: 2, priority: 10, join: " or " }
  "+": { name: add,      fixity: infix,   arity: 2, priority: 20, reduce: add }
  "-": { name: subtract, fixity: infix,   arity: 2, priority: 20, reduce: sub }
  "*": { name: multiply, fixity: infix,   arity: 2, priority: 21, reduce: mul }
  "/": { name: divide,   fixity: infix,   arity: 2, priority: 21, reduce: div }
  "**":{ name: power,    fixity: infix,   arity: 2, priority: 22, reduce: pow, assoc: right }
  "_": { name: echo,     fixity: infix,   arity: 2, priority: 22, command: "for i in $(seq \${NLIR_ARGS[1]}); do echo \${NLIR_ARGS[0]}; done" }
`;

// operators() mock — mirrors nlir help (aur-2's summary()/is_deterministic()).
const MOCK_OPERATORS = [
  ['#','subject','topic label — folds a list to its shared category', false],
  ['~','summary','the gist/essence — saturates, folds to consensus', false],
  ['@','formal','formal register — saturates, distributes over &', false],
  [':','simplify','strip jargon — reliably maps over a list', false],
  ['>','expand','elaborate — forks over |, integrates over &', false],
  ['<','shorten','shorten but keep every fact (info floor)', false],
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
  version(){ return { crate:'mock', git:'—' }; },
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
      async evaluate(e,c,x,md){ return O(await m.evaluate(e,c,x,md)); },
      async step(e,c,x,md){ const r = O(await m.step(e,c,x,md)); if (r.steps) r.steps = A(r.steps); return r; },
      operators(c){ return A(m.operators(c)); },
      parse(e,c){ return O(m.parse(e,c)); },
      version(){ return O(m.version()); },
    };
    wasmReal = true;
    const v = nlir.version() || {};
    $('verBadge').textContent = 'wasm: ' + (v.crate || 'live') + (v.git && v.git!=='unknown' ? ' · '+String(v.git).slice(0,7) : '');
    renderOps();
  } catch (err) {
    console.info('nlir-wasm pkg/ not present — using mock evaluator.', err && err.message);
  }
})();

// ---- state ----
const state = load();
function load(){
  try { const s = JSON.parse(localStorage.getItem(LS_KEY)); if (s && s.config) return s; } catch {}
  return { config: DEFAULT_CONFIG, messages: [{role:'user', text:'Can we ship the auth change on Friday?'}], kv: [], settings:{ mode:'det', baseUrl:'', apiKey:'' } };
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
function renderExamples(){
  $('examples').innerHTML = '';
  EXAMPLES.forEach(ex => {
    const c = document.createElement('span');
    c.className = 'chip'; c.innerHTML = hl(ex.expr);
    c.onclick = () => { $('expr').value = ex.expr; setMode(ex.mode); run(); };
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
  if (state.settings.mode === 'llm' && state.settings.baseUrl){
    const base = state.settings.baseUrl.replace(/\/+$/,''), key = state.settings.apiKey;
    return {
      llm: async (call) => {
        const c = unmap(call), model = unmap(c.model), vars = unmap(c.vars);
        const res = await fetch(base + '/chat/completions', {
          method:'POST',
          headers: Object.assign({ 'Content-Type':'application/json' }, key ? { Authorization:'Bearer '+key } : {}),
          body: JSON.stringify({ model: model && model.model, messages:[{ role:'user', content: vars && vars.NLIR_PROMPT }] }),
        });
        if (!res.ok) throw new Error('llm endpoint ' + res.status);
        const j = await res.json();
        return (j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content) || '';
      },
    };
  }
  return {};
}
async function run(){
  const expr = $('expr').value.trim(); if (!expr) return;
  const out = $('output'); $('steps').innerHTML = '';
  out.innerHTML = '<span class="placeholder">running…</span>';
  const r = await nlir.evaluate(expr, configJson(), contextJson(), state.settings.mode, realisers());
  if (!r.ok){ out.innerHTML = `<span class="err">${r.error}</span>`; return; }
  out.innerHTML = `<span class="result">${r.result.replace(/</g,'&lt;')}</span>` + (r.mock ? '<span class="mock">preview mock — the live site runs the real wasm</span>' : '');
  save();
}
async function step(){
  const expr = $('expr').value.trim(); if (!expr) return;
  const out = $('output'); out.innerHTML = '';
  const box = $('steps'); box.innerHTML = '<span class="placeholder">stepping…</span>';
  const r = await nlir.step(expr, configJson(), contextJson(), state.settings.mode, realisers());
  box.innerHTML = '';
  if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
  r.steps.forEach((s,i) => {
    const d = document.createElement('div'); d.className = 'step';
    const txt = (s && typeof s === 'object') ? (s.expr ?? '') : s;
    d.innerHTML = `<span class="n">${i}</span><span class="x">${hl(String(txt))}</span>` + (i===r.steps.length-1 && r.mock ? '<span class="note">mock</span>' : '');
    box.appendChild(d);
  });
}
function setMode(m){
  state.settings.mode = m; save();
  document.querySelectorAll('#modeSeg button').forEach(b => b.classList.toggle('on', b.dataset.mode===m));
  $('modeBadge').textContent = m==='det' ? 'det · key-free' : 'llm · needs a realiser';
  $('modeBadge').className = 'badge' + (m==='llm' ? ' warn' : '');
  $('llmPanel').hidden = m!=='llm';
}

// ---- wire ----
function init(){
  $('config').value = state.config;
  $('cfgNote').textContent = 'Operators below reflect this config.';
  // best-effort: seed from the full shipped config if served alongside (P7 copies config.example.yaml)
  if (state.config === DEFAULT_CONFIG){
    fetch('config.example.yaml').then(r => r.ok ? r.text() : null).then(t => {
      if (t && state.config === DEFAULT_CONFIG){ state.config = t; $('config').value = t; save(); renderOps(); }
    }).catch(()=>{});
  }
  renderExamples(); renderOps(); renderMessages(); renderKvs();
  setMode(state.settings.mode);
  $('verBadge').textContent = 'wasm: ' + nlir.version().crate;
  $('baseUrl').value = state.settings.baseUrl; $('apiKey').value = state.settings.apiKey;

  $('runBtn').onclick = run;
  $('stepBtn').onclick = step;
  $('expr').addEventListener('keydown', e => { if (e.key==='Enter') run(); });
  document.querySelectorAll('#modeSeg button').forEach(b => b.onclick = () => setMode(b.dataset.mode));
  $('applyCfg').onclick = () => { state.config = $('config').value; save(); renderOps(); $('cfgNote').textContent = 'Applied. (Real operator parsing lands with P1.)'; };
  $('resetCfg').onclick = () => { state.config = DEFAULT_CONFIG; $('config').value = DEFAULT_CONFIG; save(); renderOps(); $('cfgNote').textContent = 'Reset to default config.'; };
  $('addMsg').onclick = () => { const t = $('newMsg').value.trim(); if(!t) return; state.messages.push({role:$('newRole').value, text:t}); $('newMsg').value=''; save(); renderMessages(); };
  $('addKv').onclick = () => { const k = $('newKey').value.trim(); if(!k) return; state.kv.push({k, v:$('newVal').value}); $('newKey').value=''; $('newVal').value=''; save(); renderKvs(); };
  $('baseUrl').oninput = e => { state.settings.baseUrl = e.target.value; save(); };
  $('apiKey').oninput = e => { state.settings.apiKey = e.target.value; save(); };
}
init();
