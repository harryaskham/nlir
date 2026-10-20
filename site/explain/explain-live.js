// Live mode for the explainer: the concept-layer program, the backward pass and the consistency check run in
// the browser on your own OpenAI-compatible endpoint (the spec lab's saved endpoint is shared). Every model
// call's prompt is captured as it is sent, so the lanes and the prompt view show exactly what happened.
import { loadEndpoint } from '../spec-lab/run.js';

const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const unmap = v => (v instanceof Map ? Object.fromEntries(v) : v);
const strip = t => t.split('\n').filter(l => !l.trim().startsWith('--')).join('\n').trim().replace(/;\s*$/, '');
const PARTS = ['APPLICABILITY', 'DECISION BOUNDARY', 'MET', 'NOT MET', 'UNCERTAIN'];
const NAME = { APPLICABILITY: 'app', 'DECISION BOUNDARY': 'db', MET: 'met', 'NOT MET': 'notmet', UNCERTAIN: 'unc' };
const LS = 'nlir.endpoint.v1';

let nlir, cfgJson = '{}', SRC = {}, ep = loadEndpoint(), busy = false;

const ready = new Promise(res => (window.EXPLAIN ? res() : document.addEventListener('explain-ready', res, { once: true })));

async function boot() {
  const [m, lib, prog, back, check, route, patch] = await Promise.all([
    import('../workspace/pkg/nlir_wasm.js'),
    ...['profile.nlir', 'program-b-concepts.nlir', 'lens-concepts.nlir', 'lens-check.nlir', 'patch-route.nlir', 'patch.nlir'].map(f => fetch('../spec-lab/' + f).then(r => r.text())),
  ]);
  if (m.default) await m.default();
  nlir = m;
  cfgJson = m.defaultConfigJson?.() || '{}';
  // patch-route.nlir ends with {changed, route} for standalone use; joined to patch.nlir only its definitions are kept.
  SRC = { lib: strip(lib), prog: strip(prog), back: strip(back), check: strip(check),
          routeDefs: strip(route).replace(/\{changed=\$changed, route=\$route\}\s*$/, '').trim().replace(/;\s*$/, ''),
          patch: strip(route).replace(/\{changed=\$changed, route=\$route\}\s*$/, '').trim().replace(/;\s*$/, '') + ';\n' + strip(patch) };
}

function realiser(model, log) {
  const base = ep.baseUrl.trim().replace(/\/+$/, ''), key = (ep.apiKey || '').trim();
  return {
    llm: async call => {
      const c = unmap(call), vars = unmap(c.vars) || {};
      const entry = { model, prompt: vars.NLIR_PROMPT || '', t0: performance.now() };
      const res = await fetch(base + '/chat/completions', {
        method: 'POST', headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: 'Bearer ' + key } : {}) },
        body: JSON.stringify({ model, messages: [{ role: 'user', content: entry.prompt }] }),
      });
      if (!res.ok) { let d = ''; try { d = (await res.text()).slice(0, 200); } catch (_) {} throw new Error(`endpoint ${res.status} ${d}`); }
      const j = await res.json();
      entry.reply = j?.choices?.[0]?.message?.content ?? '';
      entry.ms = Math.round(performance.now() - entry.t0);
      log?.(entry);
      return entry.reply;
    },
  };
}

async function evaluate(expr, ctx, model, log) {
  const r = unmap(await nlir.evaluate(expr, cfgJson, JSON.stringify({ ...ctx, _seed: 0 }), 'llm', realiser(model, log)));
  if (!r.ok) throw new Error(r.error);
  return r.result;
}

// The concept program, cut down to what one step needs: the model alone, or one part with the model pinned.
function headLines() { const s = SRC.prog; return s.slice(0, s.indexOf('\nparts=')).split('\n'); }
function modelExpr() { const h = headLines(); return SRC.lib + ';\n' + h.slice(0, h.findIndex(l => l.startsWith('modeltext='))).join('\n') + '\n$json%$model'; }
function partExpr(part) {
  const others = Object.values(NAME).filter(n => n !== NAME[part]);
  const h = headLines().filter(l => !others.some(n => l.startsWith(n + '=')));
  return SRC.lib + ';\n' + h.join('\n') + `\n$${NAME[part]}`;
}
const clean = t => {
  // the program's own deterministic clean-up of a part (label prefix, quote marker), as rendered in the profile
  let x = String(t).trim().replace(/^(>\s*)+/, '').replace(/^\W*(Applicability|Decision boundary|NOT MET|MET|UNCERTAIN)\b\s*[:.\-–—]?\s*/i, '');
  return x.charAt(0).toUpperCase() + x.slice(1);
};

function segments(prompt, shared) {
  const A = 'BOUND WORKED EXAMPLES:\n', P = '\n\nRULE PACKET:\n', F = '\n\nFIELD:\n';
  const a = prompt.indexOf(A), b = prompt.indexOf(P), d = prompt.indexOf(F);
  if (a < 0 || b < 0 || d < 0) return [{ kind: 'program', text: prompt }];
  const ex = prompt.slice(a + A.length, b), pk = prompt.slice(b + P.length, d);
  const out = [{ kind: 'program', text: prompt.slice(0, a + A.length) }, ex === shared.examples ? { kind: 'examples', ref: 'examples' } : { kind: 'examples', text: ex },
    { kind: 'program', text: P }, pk === shared.packet ? { kind: 'packet', ref: 'packet' } : { kind: 'packet', text: pk }, { kind: 'program', text: F }];
  const rest = prompt.slice(d + F.length), f = rest.indexOf('\n\nRULE MODEL');
  if (f < 0) return [...out, { kind: 'field', text: rest }];
  const g = rest.indexOf(':\n', f) + 2, h = rest.lastIndexOf('\n');
  return [...out, { kind: 'field', text: rest.slice(0, f) }, { kind: 'program', text: rest.slice(f, g) }, { kind: 'model', text: rest.slice(g, h) }, { kind: 'derive', text: rest.slice(h) }];
}

function status(msg, err) { $('liveStatus').innerHTML = err ? `<span class="err">${esc(msg)}</span>` : esc(msg); }

// One forward pass: the model, then each part (model pinned), shown step by step as each call returns.
async function forward(base, model0, label) {
  const p = { ...base.packet }, examples = JSON.parse(base.shared.examples);
  const steps = [], parts = {};
  let model = model0;
  if (!model) {
    status('Extracting the rule model…');
    let call;
    model = JSON.parse(await evaluate(modelExpr(), { p, examples }, ep.writer, e => (call = e)));
    steps.push({ id: 'model', label: 'Extract the rule model', segments: segments(call.prompt, base.shared), response: JSON.stringify(model, null, 1) });
  }
  for (const part of PARTS) {
    status(`${label}: writing ${part}…`);
    let call;
    const text = await evaluate(partExpr(part), { p: { ...p, _pin: { model } }, examples }, ep.writer, e => (call = e));
    parts[part] = clean(text);
    steps.push({ id: part, label: part, segments: call ? segments(call.prompt, base.shared) : [], response: parts[part] });
  }
  return { model, parts, steps };
}

async function check(base, model, parts) {
  status('Checking consistency…');
  return JSON.parse(await evaluate(SRC.check, { p: base.packet, model, profile: parts }, ep.judge));
}

function liveEntry() {
  const E = window.EXPLAIN, R = E.rule();
  return R.live ? R : null;
}

async function guard(fn) {
  if (busy) return;
  if (!ep.baseUrl.trim()) { status('Set an endpoint first.', true); $('live').open = true; return; }
  busy = true; for (const b of document.querySelectorAll('#live button')) b.disabled = true;
  try { await nlir || await boot(); await fn(); } catch (e) { status(String(e.message || e), true); }
  finally { busy = false; for (const b of document.querySelectorAll('#live button')) b.disabled = false; syncEditors(); }
}

function syncEditors() {
  const L = liveEntry();
  $('liveModel').value = L ? JSON.stringify((L.concepts_edited || L.concepts).model, null, 1) : '';
  $('liveModel').disabled = !L; $('liveDerive').disabled = !L || busy; $('livePush').disabled = !L || busy; $('liveEdit').disabled = !L || busy;
  const part = $('livePart').value;
  $('liveSentence').value = L ? L.concepts.parts[part] || '' : '';
  $('liveSentence').disabled = !L;
}

async function main() {
  await ready;
  const E = window.EXPLAIN;
  if (E.D.patches?.sets?.exception && E.D.rules.some(r => r.concepts?.model)) {
    $('livePatch').hidden = false;
    $('lpRun').onclick = () => guard(async () => { try { await livePatch(); } catch (e) { $('lpStatus').textContent = String(e.message || e); throw e; } });
  }
  const f = $('liveForm');
  for (const [k, id] of [['baseUrl', 'liveBase'], ['apiKey', 'liveKey'], ['writer', 'liveWriter'], ['judge', 'liveJudge']]) {
    $(id).value = ep[k] || '';
    $(id).oninput = () => { ep[k] = $(id).value; try { localStorage.setItem(LS, JSON.stringify({ ...ep, apiKey: ep.remember ? ep.apiKey : '' })); } catch (_) {} };
  }
  $('liveRun').onclick = () => guard(async () => {
    const R = E.rule(), base = R.live ? E.D.rules.find(r => r.id === R.base) : R;
    const run = await forward(base, null, 'Forward');
    const entry = { id: `${base.id} · live`, base: base.id, title: base.title + ' (live)', packet: base.packet, shared: base.shared, live: true, concepts: run };
    E.show(entry, 'base', 0);
    $('badge').textContent = 'live run'; $('badge').classList.add('live');
    status('Done: step through the forward pass, then edit the model or a sentence below.');
  });
  $('liveDerive').onclick = () => guard(async () => {
    const L = liveEntry(); let model;
    if (E.state.editing && L.draft) model = JSON.parse(JSON.stringify(L.draft));
    else { try { model = JSON.parse($('liveModel').value); } catch (e) { throw new Error('The model is not valid JSON.'); } }
    E.state.editing = false; delete L.draft; delete L.draftParts; $('liveEdit').textContent = 'Edit inline';
    const base = E.D.rules.find(r => r.id === L.base);
    const run = await forward({ ...base }, model, 'Re-deriving');
    L.concepts_edited = { model, parts: run.parts, steps: run.steps, verdict: null };
    E.show(L, 'edit', 1);
    L.concepts_edited.check = await check(base, model, run.parts);
    E.show(L, 'edit', 7);
    status('Re-derived from your model and checked.');
  });
  $('livePart').onchange = syncEditors;
  $('liveEdit').onclick = () => {
    const L = liveEntry(); if (!L) return;
    E.state.editing = !E.state.editing;
    $('liveEdit').textContent = E.state.editing ? 'Stop editing inline' : 'Edit inline';
    if (E.state.editing) { E.state.scenario = 'base'; E.state.step = E.steps().length - 1; }
    E.render();
  };
  $('livePush').onclick = () => guard(async () => {
    const L = liveEntry();
    let part = $('livePart').value, neu = $('liveSentence').value.trim();
    if (E.state.editing && L.draftParts) {
      const changed = Object.keys(L.draftParts).find(k => L.draftParts[k] !== L.concepts.parts[k]);
      if (changed) { part = changed; neu = L.draftParts[changed]; }
    }
    E.state.editing = false; delete L.draft; delete L.draftParts; $('liveEdit').textContent = 'Edit inline';
    const old = L.concepts.parts[part];
    if (!neu || neu === old) throw new Error('Edit the sentence first.');
    const base = E.D.rules.find(r => r.id === L.base);
    status('Pushing the edit back to the rule model…');
    const back = JSON.parse(await evaluate(SRC.back, { model: L.concepts.model, p: base.packet, part, old, new: neu }, ep.judge));
    const model = applyEdits(L.concepts.model, back.edits || []);
    L.sentence = { part, old, new: neu, edits: back.edits || [], why: back.why || '', model, parts: { ...L.concepts.parts } };
    E.show(L, 'sentence', 1);
    const run = await forward({ ...base }, model, 'Re-deriving');
    L.sentence.parts = run.parts;
    E.show(L, 'sentence', 6);
    L.sentence.check = await check(base, model, run.parts);
    E.show(L, 'sentence', 7);
    status('Pushed back, re-derived and checked.');
  });
  E.D.rules.forEach(() => {});
  syncEditors();
  document.getElementById('rule').addEventListener('change', syncEditors);
}

// Live patch forward on the selected rule of the patch view: the reader's exception becomes a node of the recorded rule
// model; patch-route.nlir decides which fields read it and patch.nlir patches only those in the authored profile.
async function livePatch() {
  const E = window.EXPLAIN, P = E.D.patches?.sets?.exception;
  const rid = E.state.prule && P.rules[E.state.prule] ? E.state.prule : Object.keys(P.rules)[0];
  const rule = E.D.rules.find(r => r.id === rid), text = $('lpText').value.trim();
  if (!text) { $('lpStatus').textContent = 'Write an exception first.'; return; }
  const model = rule.concepts.model, perms = model.permissions || [];
  const after = { ...model, permissions: [...perms, { id: 'p' + (perms.length + 1), text, source: '(added by the reader)' }] };
  const profile = Object.fromEntries(Object.entries(P.rules[rid].fields).map(([l, f]) => [l, f.before]));
  const calls = [];
  $('lpStatus').textContent = 'Patching…';
  const routing = JSON.parse(await evaluate(SRC.routeDefs + ';\n$json%{changed=$changed, route=$route}', { model, after }, ep.judge));  // deterministic: no model call
  const out = JSON.parse(await evaluate(SRC.patch, { model, after, profile, note: 'An author added the exception: ' + text }, ep.judge, e => calls.push(e)));
  E.D.patches.sets.live = { label: `Live: your exception on ${rid}`, checks: [], note: `Patched in your browser with ${ep.judge}: ${calls.length} model call${calls.length === 1 ? '' : 's'}, one per routed field; the other fields are returned exactly as written.`,
    rules: { [rid]: { title: P.rules[rid].title, edit: 'You added the exception: ' + text, changed: routing.changed, route: routing.route, fields: Object.fromEntries(Object.keys(profile).map(l => [l, { before: profile[l], after: out[l] ?? profile[l] }])) } } };
  E.state.pset = 'live'; E.state.prule = rid;
  E.renderPatches();
  $('lpStatus').textContent = `Done: ${calls.length} routed field${calls.length === 1 ? '' : 's'} patched.`;
}

function applyEdits(model, edits) {
  const m = JSON.parse(JSON.stringify(model));
  for (const e of edits) {
    if (e.group === 'action') { if (e.op === 'edit') m.action = e.text ?? m.action; continue; }
    const list = (m[e.group] ||= []);
    if (e.op === 'add') list.push({ id: `${{ conditions: 'c', permissions: 'p', facts: 'f' }[e.group] || 'n'}${list.length + 1}`, text: e.text || '', source: e.source || '(not in the packet)' });
    else if (e.op === 'edit') for (const n of list) { if (n.id === e.id) { n.text = e.text ?? n.text; n.source = e.source || '(not in the packet)'; } }
    else if (e.op === 'remove') m[e.group] = list.filter(n => n.id !== e.id);
  }
  return m;
}

main();
