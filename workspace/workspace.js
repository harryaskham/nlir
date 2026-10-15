/* nlir workspace — prototype app logic.
 *
 * The evaluator here is a MOCK. When P1 (crates/nlir-wasm, bd-3fcf96) lands, swap
 * the `nlir` object below for the real wasm bindings — the agreed P1<->P2 contract:
 *
 *   import init, { evaluate, step, operators, parse, version, clearEvaluationCache } from './pkg/nlir_wasm.js';
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
const DEFAULT_CONFIG = `# nlir config (workspace fallback) — the v2 core, offline-parseable.
# The live site uses the evaluator's own bundled config (config.example.yaml).
models:
  demo: { type: command, format: text, command: "echo %" }
defaults:
  mode: det
  model: { small: demo, medium: demo, large: demo }
prelude: |
  gist={$0 .. 'its gist, in one short sentence'};
  formal={$0 :: 'a formal, professional register'};
  plain={$0 :: 'plain language a child could follow'};
  question={$0 :: 'a question with the same subject and meaning'}
operators:
  respond:  { op: "=>", fixity: prefix, arity: 1, model: medium, template: "response: %", prompt: "%", description: "obey an instruction and return only the result" }
  recast:   { op: "::", fixity: infix, arity: 2, priority: 15, model: medium, det: "{$1++': '++$0}", prompt: "Re-express the first text as the kind named by the second: %", description: "x :: kind — re-express x as a register, form or format" }
  project:  { op: "..", fixity: infix, arity: 2, priority: 16, model: medium, det: "{$1++' of: '++$0}", prompt: "The part of the first text the second describes: %", description: "x .. aspect — the part of x the aspect describes" }
  dual:     { op: "!",  fixity: prefix, arity: 1, model: medium, template: "not %", prompt: "The opposite of: %", description: "the opposite — an involution" }
  and:      { op: "&",  fixity: mixfix, arity: ">0", join: " and ", description: "product — one 'X and Y' statement" }
  or:       { op: "|",  fixity: mixfix, arity: ">0", join: " or ", description: "coproduct — one 'X or Y' choice" }
  change:   { op: "Δ",  fixity: infix, arity: 2, model: medium, template: "change: %0 -> %1", prompt: "What changed, first to second: %", description: "how the first text becomes the second" }
  apply:    { op: "▷",  fixity: infix, arity: 2, model: medium, template: "%0 (changed: %1)", prompt: "Apply the described change: %", description: "x ▷ change — a ▷ (a Δ b) ≈ b" }
  entails:  { op: "~>", fixity: infix, arity: 2, result: bool, model: medium, det: "{$contains%($0,$1)}", prompt: "Does the first imply the second? %", description: "does the first text imply the second" }
  concat:   { op: "++", fixity: mixfix, arity: ">0", priority: 10, operands: any, reduce: concat, description: "monoid append — text, lists, dicts" }
  compose:  { op: "∘",  fixity: mixfix, arity: ">0", priority: 17, builtin: compose, description: "(f ∘ g) % x = f % (g % x)" }
  mtimes:   { op: "_",  fixity: infix, arity: 2, priority: 17, builtin: mtimes, description: "n copies appended; a form composes n times" }
  length:   { op: "#",  fixity: prefix, arity: 1, priority: 14, builtin: len, description: "length of a list, dict or text" }
  mapop:    { op: "↦",  fixity: infix, arity: 2, priority: 8, builtin: map, description: "map a form over a list" }
  foldop:   { op: "⊘",  fixity: infix, arity: 2, priority: 8, builtin: fold, description: "fold a list with a binary form" }
  access:   { op: ".",  fixity: infix, arity: 2, priority: 19, builtin: access, description: "index, key or character" }
  add:      { op: "+",  fixity: mixfix, arity: ">0", priority: 11, operands: number, result: number, reduce: add, description: "sum" }
  sub:      { op: "-",  fixity: infix, arity: 2, priority: 12, operands: number, result: number, reduce: sub, description: "difference" }
  mul:      { op: "*",  fixity: mixfix, arity: ">0", priority: 11, operands: number, result: number, reduce: mul, description: "product" }
  div:      { op: "/",  fixity: infix, arity: 2, priority: 11, operands: number, result: number, reduce: div, description: "quotient" }
  pow:      { op: "**", fixity: infix, arity: 2, priority: 13, operands: number, result: number, reduce: pow, description: "power (right-assoc)" }
  at-least: { op: ">=", fixity: infix, arity: 2, priority: 5, operands: number, result: bool, reduce: ge, description: "numeric ≥" }
`;

// operators() mock — mirrors nlir help (aur-2's summary()/is_deterministic()).
const MOCK_OPERATORS = [
  ['=>','respond','obey an instruction and return only the result', false],
  ['::','recast','x :: kind — re-express x as a register, form or format', false],
  ['..','project','x .. aspect — the part of x the aspect describes', false],
  ['!','dual','the opposite — an involution', false],
  ['&','and','product — one "X and Y" statement', true],
  ['|','or','coproduct — one "X or Y" choice', true],
  ['Δ','change','how the first text becomes the second', false],
  ['▷','apply','x ▷ change — a ▷ (a Δ b) ≈ b', false],
  ['~>','entails','does the first text imply the second', false],
  ['≈','similarity','how fully the second keeps the meaning of the first', false],
  ['++','concat','monoid append — text, lists, dicts', true],
  ['∘','compose','(f ∘ g) % x = f % (g % x)', true],
  ['_','mtimes','n copies appended; a form composes n times', true],
  ['#','length','length of a list, dict or text', true],
  ['↦','map','map a form over a list', true],
  ['⊘','fold','fold a list with a binary form', true],
  ['+','add','sum', true],
  ['**','pow','power (right-assoc: 2**3**2 = 512)', true],
].map(([op,name,description,det]) => ({op,name,description,det,arity:1,priority:0,fixity:''}));

// Known-example outputs so the demo reads real (still badged "mock" for llm ops).
const EXAMPLES = [
  // Exact structure — key-free, in the browser.
  { expr: "{$0+$1}⊘(1..100)", mode:'det', out:"5050" },
  { expr: "orders=[{who=ada,total=12.5},{who=bo,total=40},{who=cy,total=7}];$join%({$0.who}↦($filter%({$0.total>=10},$orders)),', ')", mode:'det', out:"ada, bo" },
  { expr: "inc={$0+1};dbl={$0*2};($dbl ∘ $inc)↦[1,2,3]", mode:'det' },
  { expr: "_sep=', ';[1,2]++[3] ++ ({a=1,b=2}++{b=3})", mode:'det' },
  // Meaning — the semantic core (captured on gpt-6-luna; badged mock without a key).
  { expr: "'lmk if any Qs' :: formal", mode:'llm', out:"Please let me know if you have any questions." },
  { expr: "$gist%'the mobile team is blocked on the shared auth library, which is late, so the launch slips a week'", mode:'llm', out:"A late shared auth library delays the mobile launch by a week." },
  { expr: "'the planets from the sun'..3", mode:'llm', out:"Earth" },
  { expr: "a='Ship on Friday.';b='Ship on Friday, after the security review.';$a ▷ ($a Δ $b)", mode:'llm', out:"Ship on Friday after the security review." },
  // Exact over fuzzy — the model reads, the evaluator counts.
  { expr: "{$0+$1}⊘['3 apples','5 oranges','2 pears']", mode:'llm', out:"10" },
  { expr: "#($filter%({$0~>'a complaint'},['love the app','it keeps crashing','when is dark mode','checkout is totally broken']))", mode:'llm', out:"2" },
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
const PLACEHOLDER_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 340 210"><rect x="1" y="1" width="338" height="208" rx="14" fill="#111318" stroke="#262a33"/><line x1="100" y1="132" x2="165" y2="70" stroke="rgba(160,170,190,.42)" stroke-width="1.4"/><line x1="240" y1="132" x2="175" y2="70" stroke="rgba(160,170,190,.42)" stroke-width="1.4"/><g data-id="0"><rect x="130" y="28" width="80" height="40" rx="8" fill="#14231f" stroke="#3fa58c"/><text x="170" y="48" fill="#9be3c8" text-anchor="middle" dominant-baseline="central" font-family="JetBrains Mono,monospace" font-size="13">op</text></g><g data-id="0.0"><rect x="60" y="132" width="80" height="40" rx="8" fill="#18191f" stroke="#3a3f4b"/><text x="100" y="152" fill="#c9ced8" text-anchor="middle" dominant-baseline="central" font-family="JetBrains Mono,monospace" font-size="13">a</text></g><g data-id="0.1"><rect x="200" y="132" width="80" height="40" rx="8" fill="#18191f" stroke="#3a3f4b"/><text x="240" y="152" fill="#c9ced8" text-anchor="middle" dominant-baseline="central" font-family="JetBrains Mono,monospace" font-size="13">b</text></g></svg>';

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
  async stepStream(expr,c,x,md,r,onStep){ const res = await this.step(expr); (res.steps||[]).forEach(s => onStep((s && s.expr != null) ? s.expr : s)); return { ok:res.ok, count:(res.steps||[]).length, mock:true }; },
  operators(){ return MOCK_OPERATORS; },
  parse(expr){ return { ok:true, ast:expr }; },
  graph(){ return { ok:true, svg:PLACEHOLDER_SVG, mock:true }; },
  graphFrames(){ return { ok:true, mock:true, frames:[
    { svg:PLACEHOLDER_SVG, reduced:null }, { svg:PLACEHOLDER_SVG, reduced:'0.0' },
    { svg:PLACEHOLDER_SVG, reduced:'0.1' }, { svg:PLACEHOLDER_SVG, reduced:'0' },
  ] }; },
  async graphFramesAsync(){ return this.graphFrames(); },
  async graphFramesStreaming(e,c,x,md,r,onFrame){ const res = this.graphFrames(); (res.frames||[]).forEach(f => onFrame(f)); return { ok:true, count:(res.frames||[]).length, mock:true }; },
  version(){ return { crate:'mock', git:'—' }; },
  defaultConfigYaml(){ return DEFAULT_CONFIG; },
  clearEvaluationCache(){},
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
      async stepStream(e,c,x,md,r,onStep){ return O(await m.stepStream(e,c,x,md,r,onStep)); },
      operators(c){ return A(m.operators(c)); },
      parse(e,c){ return O(m.parse(e,c)); },
      graph(e,c){ return O(m.graph(e,c)); },
      outline(e,c){ return O(m.outline(e,c)); },
      graphFrames(e,c,md){ const r = O(m.graphFrames(e,c,md)); if (r.frames) r.frames = A(r.frames); return r; },
      async graphFramesAsync(e,c,x,md,r){ const rr = O(await m.graphFramesAsync(e,c,x,md,r)); if (rr.frames) rr.frames = A(rr.frames); return rr; },
      async graphFramesStreaming(e,c,x,md,r,onFrame){ return O(await m.graphFramesStreaming(e,c,x,md,r, f => onFrame(O(f)))); },
      version(){ return O(m.version()); },
      defaultConfigYaml(){ return m.defaultConfigYaml(); },
      clearEvaluationCache(){ m.clearEvaluationCache(); },
    };
    wasmReal = true;
    const v = nlir.version() || {};
    $('verBadge').textContent = 'wasm: ' + (v.crate || 'live') + (v.git && v.git!=='unknown' ? ' · '+String(v.git).slice(0,7) : '');
    // Anti-drift (bd-ca518b): the config is the wasm's own include_str! copy of config.example.yaml
    // (single source of truth, always in lockstep with the parser). Adopt it as the default.
    // A saved v1 config (instance glyphs like @ formal, ~>? infer; no prelude) is
    // upgraded to the bundled v2 config — the v1 vocabulary no longer parses.
    const isV1 = c => typeof c === 'string' && !/\nprelude:/.test(c) && /op: "(@|~>\?|~)"/.test(c);
    try { const cfg = nlir.defaultConfigYaml(); if (cfg && (state.config === DEFAULT_CONFIG || isV1(state.config))){ const upgraded = isV1(state.config); state.config = cfg; if ($('config')) $('config').value = cfg; save(); if (upgraded && $('cfgNote')) $('cfgNote').textContent = 'Updated your saved config to the v2 core (::, .., ▷, ∘ and the prelude).'; } } catch {}
    renderOps();
    // Real wasm is now live: re-run the det preview so a restored expression shows
    // the true evaluator's result-so-far (not the mock it may have shown at init).
    scheduleLivePreview();
  } catch (err) {
    console.info('nlir-wasm pkg/ not present — using mock evaluator.', err && err.message);
  }
})();

function clearEvalCache(){
  try { if (typeof nlir.clearEvaluationCache === 'function') nlir.clearEvaluationCache(); }
  catch { /* cache invalidation is an optimisation boundary, never a UI failure */ }
}

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
    cm.on('change', () => { state.settings.expr = cm.getValue(); save(); scheduleLivePreview(); });
  } else {
    // fallback: the raw textarea is already fullwidth + multiline (CSS); wire persistence + run.
    if (state.settings.expr) ta.value = state.settings.expr;
    ta.addEventListener('input', () => { state.settings.expr = ta.value; save(); scheduleLivePreview(); });
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
const SPECIAL_FORMS = [
  ['{ }', 'quote', 'a form, code as data: {a+b} is the form, (a+b) its value'],
  ['%', 'apply', 'call a form: {$0+1}%5 gives 6; f%(x,y) binds $0,$1'],
  ['=', 'assign', 'bind a name k to a value, then reuse it as $k'],
  ['$name', 'reference', 'read a binding; $0/$1 are positional args; interpolates in double-quoted strings'],
  [';', 'sequence', 'run in order; the value is the last statement (also the stack)'],
  ['( )', 'group', 'override precedence; preserved in output'],
  ['[ ]', 'list', 'a list; spreads into variadic ops or joins to text'],
  ['^', 'messages', 'chat views: ^ assistant, ^_ user, ^* thread, ^/ system; ^-1 last, ranges'],
  ['({f}_N)', 'do-N', 'compose a form N times: ({$0+1}_3)%5 gives 8'],
  ['$map $fold', 'map / fold', 'higher-order: $map%({f},list) maps f over each item; $fold%({f},list) reduces'],
  ['$scan $filter', 'scan / filter', '$scan%({f},list) is a running fold ([1,3,6,10]); $filter keeps items that pass'],
  ['f ∘ g', 'compose', 'pipelines from named forms: ($gist ∘ $formal)%x = gist of the formal x'],
  ['prelude', 'named forms', '$gist $formal $plain $question … are forms over :: and .., redefinable'],
  ['strings', 'quoting', 'double-quotes interpolate $name; single-quotes are literal'],
  ['backtick', 'serial', 'forces its right-hand subtree to evaluate serially'],
];
function renderForms(){
  const box = $('forms'); if (!box) return; box.innerHTML = '';
  const esc = s => String(s).replace(/</g,'&lt;').replace(/>/g,'&gt;');
  SPECIAL_FORMS.forEach(([sig, name, desc]) => {
    const d = document.createElement('div'); d.className = 'op';
    d.innerHTML = `<span class="sig">${esc(sig)}</span><span class="nm">${esc(name)}</span><span class="ds">${esc(desc)}</span>`;
    box.appendChild(d);
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
  // A value that parses as a JSON object/array binds as native data ($k.field, ↦);
  // anything else binds as text.
  state.kv.forEach(p => {
    if (!p.k) return;
    let v = p.v;
    if (/^\s*[\[{]/.test(v)) { try { v = JSON.parse(v); } catch (_) { /* keep text */ } }
    o[p.k] = v;
  });
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
          // Send the operator's system frame (prompts.system, or its own `system:` such as
          // => 's generative frame) as well as the filled prompt.
          body: JSON.stringify({ model: (state.settings.model || '').trim() || (model && model.model), messages: [
            ...(vars && vars.NLIR_SYSTEM_PROMPT ? [{ role:'system', content: vars.NLIR_SYSTEM_PROMPT }] : []),
            { role:'user', content: vars && vars.NLIR_PROMPT },
          ] }),
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
  // Live streaming (bd-89eb89): each reduction appends the moment its realisation resolves
  // (in llm mode you watch the reasoning unfold), via aur-2's stepStream export.
  let i = 0;
  const onStep = (txt) => {
    if (i === 0) box.innerHTML = '';
    const d = document.createElement('div'); d.className = 'step';
    d.innerHTML = `<span class="n">${i}</span><span class="x">${hl(String(txt))}</span>`;
    box.appendChild(d); i++;
  };
  try {
    const r = await nlir.stepStream(expr, configJson(), contextJson(), wasmMode(), realisers(), onStep);
    if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
    if (i === 0) box.innerHTML = '<span class="placeholder">(no steps)</span>';
    else if (r.mock && box.lastChild){ const note = document.createElement('span'); note.className = 'note'; note.textContent = 'mock'; box.lastChild.appendChild(note); }
  } catch (e){ box.innerHTML = `<span class="err">${e}</span>`; }
}

// ---- live det preview (bd-970e05): debounced, speculative eval as you type ----
// The web slice of the shared partial-result-display contract (matches the TUI,
// REPL, and Pi-plugin slices):
//   • debounce, not per-keystroke (~350ms) — one eval after you pause typing.
//   • DET is the safe-free-default: the preview ALWAYS evaluates in det mode
//     (offline, instant, key-free) regardless of the selected mode, so llm/paid
//     realisation is never fired on a keystroke — it stays gated behind Run.
//   • speculative ≠ committed: the preview lives in its own line, never clobbers
//     the Output pane, and never persists context writes (the wasm det path evals
//     a FRESH context per call, so `k=RHS` here has no side effect). It hides
//     silently on parse/eval errors (incl. an llm op in det mode) so it stays
//     unobtrusive while you compose — exactly like the REPL's dim ` → ` hint.
let livePreviewTimer = null;
let livePreviewSeq = 0;
const LIVE_PREVIEW_DEBOUNCE_MS = 350;
const LIVE_PREVIEW_MAX_LEN = 240;

function scheduleLivePreview(){
  clearTimeout(livePreviewTimer);
  livePreviewTimer = setTimeout(livePreviewTick, LIVE_PREVIEW_DEBOUNCE_MS);
}

async function livePreviewTick(){
  const el = $('livePreview'); if (!el) return;
  const hide = () => { el.hidden = true; el.innerHTML = ''; };
  const expr = getExpr().trim();
  const seq = ++livePreviewSeq;
  // Nothing to preview (empty) or too heavy to speculate on every pause — stay quiet.
  if (!expr || expr.length > LIVE_PREVIEW_MAX_LEN){ hide(); return; }
  let r;
  // ALWAYS det + no realisers: the speculative tier never spends an llm call.
  try { r = await nlir.evaluate(expr, configJson(), contextJson(), 'det', {}); }
  catch { if (seq === livePreviewSeq) hide(); return; }
  if (seq !== livePreviewSeq) return;                 // a newer keystroke superseded this eval
  if (!r || !r.ok || r.result == null || r.result === ''){ hide(); return; }
  const llmGated = state.settings.mode !== 'det';
  el.hidden = false;
  el.innerHTML = `<span class="arrow">→</span><span class="lp-result">${esc(String(r.result))}</span>`
    + (llmGated ? '<span class="lp-tag" title="typing stays free/det; Run or Step explicitly reuses cached llm subcalls">det preview · Run/Step for cached llm</span>' : '')
    + (r.mock ? '<span class="lp-tag mock-tag">mock</span>' : '');
}

// ---- graph (G5): dataflow graph panel + step-frame animation with node highlight ----
let animTimer = null;
let graphPZ = null;
function showGraph(){
  clearInterval(animTimer);
  const expr = getExpr().trim(); if (!expr) return;
  const box = $('graphsvg');
  $('graphview').hidden = false; $('scrub').hidden = true; $('framecap').textContent = '';
  box.innerHTML = '<span class="placeholder">rendering…</span>';
  const r = nlir.graph(expr, configJson());
  if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
  box.innerHTML = r.svg + (r.mock ? '<div class="mock" style="margin-top:.5rem">preview graph — the live site renders your expression</div>' : '');
  graphPZ && graphPZ.refit();
}
function showOutline(){
  clearInterval(animTimer);
  const expr = getExpr().trim(); if (!expr) return;
  const box = $('graphsvg');
  $('graphview').hidden = false; $('scrub').hidden = true; $('framecap').textContent = '';
  if (!nlir.outline){ box.innerHTML = '<span class="placeholder">the statement graph needs the live evaluator</span>'; return; }
  const r = nlir.outline(expr, configJson());
  if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
  box.innerHTML = r.svg;
  $('framecap').textContent = `${r.statements} statement(s) — drag to pan, scroll to zoom`;
  graphPZ && graphPZ.refit();
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
  const scrub = $('scrub'); scrub.hidden = false;
  const frames = [];
  const cap = (k, tag) => { const red = frames[k] && frames[k].reduced; $('framecap').textContent = `frame ${k+1}/${frames.length}` + (red ? ` · reduced ${red}` : '') + (tag ? ` · ${tag}` : ''); };

  if (md === 'llm'){
    // Live streaming (bd-89eb89): render each frame the moment its realisation resolves
    // — in llm mode the graph animation builds itself frame-by-frame as the model runs.
    const onFrame = (frame) => {
      if (!frames.length) box.innerHTML = '';
      frames.push(frame);
      const k = frames.length - 1; renderFrame(frame); scrub.max = k; scrub.value = k; cap(k, 'live');
    };
    let r;
    try { r = await nlir.graphFramesStreaming(expr, configJson(), contextJson(), md, realisers(), onFrame); }
    catch (e){ box.innerHTML = `<span class="err">${e}</span>`; return; }
    if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
    if (!frames.length){ box.innerHTML = '<span class="placeholder">(no frames)</span>'; return; }
    const show = k => { renderFrame(frames[k]); scrub.value = k; cap(k); };
    scrub.oninput = e => show(+e.target.value);
    show(frames.length - 1);
    return;
  }

  // det: batch frames + timed auto-advance animation (frames are instant)
  const r = nlir.graphFrames(expr, configJson(), md);
  if (!r.ok){ box.innerHTML = `<span class="err">${r.error}</span>`; return; }
  (r.frames || []).forEach(f => frames.push(f));
  if (!frames.length){ box.innerHTML = '<span class="placeholder">(no frames)</span>'; return; }
  scrub.max = frames.length - 1;
  let i = 0;
  const show = k => { i = k; renderFrame(frames[k]); scrub.value = k; cap(k, r.mock ? 'preview' : ''); };
  show(0);
  scrub.oninput = e => { clearInterval(animTimer); show(+e.target.value); };
  animTimer = setInterval(() => { if (i >= frames.length - 1){ clearInterval(animTimer); return; } show(i + 1); }, 950);
}

function setMode(m){
  state.settings.mode = m; save();
  document.querySelectorAll('#modeSeg button').forEach(b => b.classList.toggle('on', b.dataset.mode===m));
  $('modeBadge').textContent = m==='det' ? 'det · key-free' : m==='ondevice' ? 'on-device · private' : 'llm · needs a realiser';
  $('modeBadge').className = 'badge' + (m==='llm' ? ' warn' : ' live');
  $('llmPanel').hidden = m!=='llm';
  $('odPanel').hidden = m!=='ondevice';
  if (m==='ondevice') checkOnDevice();
  // Refresh the live det preview so its "det preview · Run for llm" tag tracks the
  // selected mode (the preview itself is always det; only the label depends on mode).
  scheduleLivePreview();
}

// ---- wire ----
function init(){
  $('config').value = state.config;
  $('cfgNote').textContent = 'Operators below reflect this config.';
  renderExamples(); renderOps(); renderForms(); renderMessages(); renderKvs();
  setMode(state.settings.mode);
  initEditor();
  $('verBadge').textContent = 'wasm: ' + nlir.version().crate;
  $('baseUrl').value = state.settings.baseUrl; $('apiKey').value = state.settings.apiKey; $('model').value = state.settings.model;

  $('runBtn').onclick = run;
  $('stepBtn').onclick = step;
  $('graphBtn').onclick = showGraph;
  $('outlineBtn').onclick = showOutline;
  import('../panzoom.js').then(m => { graphPZ = m.panzoom($('graphsvg')); }).catch(() => {});
  $('animBtn').onclick = animate;
  $('vimToggle').onclick = () => setVim(!state.settings.vim);
  document.querySelectorAll('#modeSeg button').forEach(b => b.onclick = () => setMode(b.dataset.mode));
  $('applyCfg').onclick = () => { clearEvalCache(); state.config = $('config').value; save(); renderOps(); $('cfgNote').textContent = 'Applied — operators + graphs reflect this config; LLM preview cache cleared.'; };
  $('resetCfg').onclick = () => { clearEvalCache(); state.config = DEFAULT_CONFIG; $('config').value = DEFAULT_CONFIG; save(); renderOps(); $('cfgNote').textContent = 'Reset to default config; LLM preview cache cleared.'; };
  $('addMsg').onclick = () => { const t = $('newMsg').value.trim(); if(!t) return; state.messages.push({role:$('newRole').value, text:t}); $('newMsg').value=''; save(); renderMessages(); };
  $('addKv').onclick = () => { const k = $('newKey').value.trim(); if(!k) return; state.kv.push({k, v:$('newVal').value}); $('newKey').value=''; $('newVal').value=''; save(); renderKvs(); };
  $('baseUrl').oninput = e => { clearEvalCache(); state.settings.baseUrl = e.target.value; save(); };
  $('apiKey').oninput = e => { clearEvalCache(); state.settings.apiKey = e.target.value; save(); };
  $('model').oninput = e => { clearEvalCache(); state.settings.model = e.target.value; save(); };
  // Seed the live det preview for a restored expression (wasm may still be
  // loading — the mock covers det numerics until it swaps in, then loadWasm
  // reschedules a tick so the real evaluator's result-so-far appears).
  scheduleLivePreview();
}
init();
