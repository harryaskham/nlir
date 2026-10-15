import { panzoom } from '../panzoom.js';
// Spec lab: every projection below is an nlir expression evaluated by the wasm
// build against the bound spec tree ($spec) plus spec.nlir + profile.nlir. The page only lays out
// what nlir returns.
const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const norm = v => (v instanceof Map ? Object.fromEntries(v) : v);

let nlir, cfgJson = '{}', lib = '', spec = null, current = null, edited = false;

async function boot() {
  const [m, specText, specLib, profileLib] = await Promise.all([
    import('../workspace/pkg/nlir_wasm.js'),
    fetch('toy-spec.json').then(r => r.text()),
    fetch('spec.nlir').then(r => r.text()),
    fetch('profile.nlir').then(r => r.text()),
  ]);
  if (m.default) await m.default();
  nlir = m;
  spec = JSON.parse(specText);
  const strip = t => t.split('\n').filter(l => !l.trim().startsWith('--')).join('\n').trim().replace(/;\s*$/, '');
  lib = `${strip(specLib)};\n${strip(profileLib)}`;
  $('libsrc').innerHTML = highlight(`${specLib}\n${profileLib}`);
  try { cfgJson = JSON.stringify(window.jsyaml.load(m.defaultConfigYaml())); } catch (_) {}
}

// Evaluate `expr` after the libraries, with the spec (and any extra bindings) in context.
async function run(expr, extra = {}) {
  const r = norm(await nlir.evaluate(`${lib};\n${expr}`, cfgJson, JSON.stringify({ spec, ...extra }), 'det', {}));
  if (!r.ok) throw new Error(r.error);
  return r.result;
}
const runJson = async (expr, extra) => JSON.parse(await run(`$json%(${expr})`, extra));

function highlight(src) {
  return esc(src)
    .replace(/^(--.*)$/gm, '<span class="c">$1</span>')
    .replace(/(\$\$?[A-Za-z_][\w]*|\$\d)/g, '<span class="syn-bind">$1</span>')
    .replace(/(↦|⊘|%|\+\+|==|≈|=&gt;)/g, '<span class="syn-op">$1</span>');
}

// ---- tree rail ---------------------------------------------------------------
async function buildRail() {
  const dims = await runJson("{{id=$0.id, title=($node%$0.id).title, rules={{id=$0, title=($node%$0).title}}↦($flat%({$0.id}↦$0.children))}}↦$spec.hierarchy.children");
  const rail = $('rail');
  rail.innerHTML = `<div class="spec-title">${esc(spec.title)}</div>` + dims.map(d => `
    <div class="dim"><div class="dim-title">${esc(d.title)}</div>
    ${d.rules.map(r => `<button class="rule" data-id="${esc(r.id)}"><span class="code">${esc(r.id)}</span><span>${esc(r.title)}</span></button>`).join('')}
    </div>`).join('');
  rail.querySelectorAll('.rule').forEach(b => b.onclick = () => select(b.dataset.id));
}

// ---- one rule: spec ⇄ prose ---------------------------------------------------
async function select(id) {
  current = id; edited = false;
  document.querySelectorAll('.rule').forEach(b => b.classList.toggle('on', b.dataset.id === id));
  const head = await runJson(`{id=$id, title=($node%$id).title, dim=($node%($up%$id)).title, force=($node%$id).force}`, { id });
  $('crumbs').innerHTML = `${esc(head.dim)} <span>·</span> <span class="force">${esc(head.force)}</span>`;
  $('title').innerHTML = `<span class="code">${esc(id)}</span> ${esc(head.title)}`;
  await showSpec();
  $('prose').value = await run('$render%(($node%$id).profile)', { id });
  await reparse();
  setView('rule');
}

async function showSpec() {
  const mode = document.querySelector('#specMode .on').dataset.m;
  const expr = mode === 'node' ? '$node%$id' : '$packet%$id';
  const value = await runJson(expr, { id: current });
  $('spec').innerHTML = highlightJson(value);
  $('specExpr').textContent = expr;
}

function highlightJson(v) {
  return esc(JSON.stringify(v, null, 2))
    .replace(/^(\s*)("(?:[^"\\]|\\.)*")(\s*:)/gm, '$1<span class="syn-bind">$2</span>$3')
    .replace(/(:\s|^\s+)("(?:[^"\\]|\\.)*")(,?)$/gm, '$1<span class="syn-str">$2</span>$3');
}

// Prose → spec: push the (possibly edited) prose back through the projection with
// nlir's backward pass (`put`): each change lands on the exact spec field — or, for a
// heading or label edit, on the program literal that wrote it — and PutGet is checked
// by re-rendering.
const fieldLabel = (path, old) => {
  if (/applicability/.test(path)) return 'Applicability';
  const m = String(old || '').match(/^([^:\n]+):/);
  return m ? m[1].trim() : path.split('/').slice(-2).join(' ');
};

async function reparse() {
  const id = current;
  const prose = $('prose').value.replace(/\n$/, '');
  if (!nlir.put) return reparseFields();
  const r = norm(nlir.put(`${lib};\n$render%(($node%$id).profile)`, cfgJson, JSON.stringify({ spec, id }), prose));
  const st = $('state');
  if (!r.ok) {
    $('fields').innerHTML = `<div class="err">${esc(r.error)}</div>`;
    st.className = 'state warn'; st.textContent = 'not invertible';
    return;
  }
  const rep = norm(r.report);
  const edits = (rep.edits || []).map(norm);
  const rows = [];
  for (const e of edits) {
    for (const c of (e.changes || []).map(norm)) {
      if (e.kind === 'data') {
        const label = fieldLabel(c.path, c.old);
        rows.push(`<div class="field changed"><div class="label">${esc(label)}<span>spec</span></div><div class="path">${esc(c.path)}</div><div class="text">${wordDiff(String(c.old ?? ''), String(c.new ?? ''))}</div></div>`);
      } else {
        rows.push(`<div class="field changed prog"><div class="label">Template<span>program · ${esc(e.target)}</span></div><div class="text">${wordDiff(String(c.old ?? ''), String(c.new ?? ''))}</div></div>`);
      }
    }
  }
  for (const k of (rep.stuck || []).map(norm)) rows.push(`<div class="field stuck"><div class="label">Not invertible<span>${esc(k.at)}</span></div><div class="text">${esc(k.reason)}</div></div>`);
  for (const c of rep.conflicts || []) rows.push(`<div class="field stuck"><div class="label">Conflict</div><div class="text">${esc(c)}</div></div>`);
  $('fields').innerHTML = rows.join('') || '<div class="quiet">No edits: the prose is exactly what the spec renders to.</div>';
  const n = rows.length;
  if (!edits.length && !(rep.stuck || []).length) { st.className = 'state ok'; st.textContent = 'round trip exact'; }
  else if (rep.put_get) { st.className = 'state ok'; st.textContent = `${n} edit${n > 1 ? 's' : ''} · re-render reproduces your prose`; }
  else { st.className = 'state warn'; st.textContent = (rep.stuck || []).length ? 'part of the edit is not invertible' : 'edits do not reproduce the prose'; }
}

// Older evaluator builds without `put`: compare `$fields%$prose` with the spec.
async function reparseFields() {
  const id = current;
  let parsed, gold;
  try {
    [parsed, gold] = await Promise.all([
      runJson('$fields%$prose', { prose: $('prose').value }),
      runJson('($node%$id).profile', { id }),
    ]);
  } catch (e) {
    $('fields').innerHTML = `<div class="err">${esc(e.message || e)}</div>`;
    return;
  }
  const parts = p => [['Applicability', (p.applicability || []).join('\n\n')], ...(p.decision_boundary || []).map(x => {
    const i = x.indexOf(':'); return [x.slice(0, i).trim(), x.slice(i + 1).trim()];
  })];
  const g = parts(gold), c = parts(parsed);
  $('fields').innerHTML = g.map(([label, text]) => {
    const cand = (c.find(([l]) => l.toUpperCase() === label.toUpperCase()) || [label, ''])[1];
    return `<div class="field ${cand === text ? '' : 'changed'}"><div class="label">${esc(label)}</div><div class="text">${cand === text ? esc(text) : wordDiff(text, cand)}</div></div>`;
  }).join('');
}

function wordDiff(a, b) {
  const A = a.split(/(\s+)/), B = b.split(/(\s+)/);
  const n = A.length, m = B.length, L = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) L[i][j] = A[i] === B[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
  let i = 0, j = 0, out = '';
  while (i < n && j < m) {
    if (A[i] === B[j]) { out += esc(A[i]); i++; j++; }
    else if (L[i + 1][j] >= L[i][j + 1]) { out += `<del>${esc(A[i])}</del>`; i++; }
    else { out += `<ins>${esc(B[j])}</ins>`; j++; }
  }
  while (i < n) out += `<del>${esc(A[i++])}</del>`;
  while (j < m) out += `<ins>${esc(B[j++])}</ins>`;
  return out;
}

// ---- whole-policy prose ----------------------------------------------------------
function mdToHtml(md) {
  const inline = s => esc(s).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>').replace(/`([^`]+)`/g, '<code>$1</code>');
  return md.split(/\n{2,}/).map(block => {
    const h = block.match(/^(#{1,4}) (.*)$/);
    if (h) return `<h${h[1].length + 1}>${inline(h[2])}</h${h[1].length + 1}>`;
    if (block.startsWith('> ')) return `<blockquote>${inline(block.replace(/^> ?/gm, ''))}</blockquote>`;
    return `<p>${inline(block)}</p>`;
  }).join('');
}

// ---- learning-loop replay ------------------------------------------------------------
async function showLoop() {
  const box = $('loop');
  let trace;
  try { trace = await (await fetch('trace.json')).json(); }
  catch (_) { box.innerHTML = '<p class="muted">No recorded run.</p>'; return; }
  const rows = trace.rounds;
  let k = rows.length - 1;
  const best = trace.held_out;
  box.innerHTML = `
    <div class="loop-head">
      <div class="stat"><b>${best.seed.mean.toFixed(2)} → ${best.best.mean.toFixed(2)}</b><span>held-out similarity, seed → learned program</span></div>
      ${trace.ceiling ? `<div class="stat"><b>${trace.ceiling.mean.toFixed(2)}</b><span>ceiling: a faithful paraphrase of the reference</span></div>` : ''}
      <div class="stat"><b>${best.best.min.toFixed(2)}</b><span>worst held-out sample</span></div>
      <div class="stat"><b>${rows.length - 1}</b><span>proposals · ${esc(trace.models.generation)} writes · ${esc(trace.models.judge)} judges · ${esc(String(trace.models.proposer).split('/').pop())} edits the program</span></div>
    </div>
    <div class="parts" id="parts"></div>
    <svg class="spark" viewBox="0 0 600 120" id="spark"></svg>
    <div class="stepper"><button id="lprev" aria-label="Previous round">◀</button><span id="lcap"></span><button id="lnext" aria-label="Next round">▶</button></div>
    <div class="loop-grid"><pre class="console code" id="lsrc"></pre><div id="lgraph" class="lgraph"></div></div>`;
  // Held-out similarity by profile part: where the learned program matches the
  // human authors, and where their editorial judgement is still out of reach.
  const byPart = {};
  (trace.per_item || []).forEach(it => Object.entries(it.parts || {}).forEach(([k, v]) => (byPart[k] = byPart[k] || []).push(v)));
  $('parts').innerHTML = Object.entries(byPart).map(([k, v]) => {
    const m = v.reduce((a, b) => a + b, 0) / v.length;
    return `<div class="part"><span class="pl">${esc(k.toLowerCase())}</span><span class="bar"><i style="width:${(m * 100).toFixed(0)}%"></i>${trace.ceiling ? `<b style="left:${(trace.ceiling.mean * 100).toFixed(0)}%"></b>` : ''}</span><span class="pv">${m.toFixed(2)}</span></div>`;
  }).join('');
  const W = 600, H = 120, P = 14, xs = i => P + i * (W - 2 * P) / Math.max(rows.length - 1, 1), ys = s => H - P - s * (H - 2 * P);
  let run = 0;
  const bestPath = rows.map((r, i) => { if (r.accepted) run = Math.max(run, r.score); return `${i ? 'L' : 'M'}${xs(i).toFixed(1)},${ys(run).toFixed(1)}`; }).join(' ');
  const phaseLines = rows.map((r, i) => (i && r.phase !== rows[i - 1].phase) ? `<line x1="${xs(i - .5)}" x2="${xs(i - .5)}" y1="${P}" y2="${H - P}" class="phase"/><text x="${xs(i - .5) + 4}" y="${P + 9}" class="phase-l">phase ${r.phase}</text>` : '').join('');
  const ceil = trace.ceiling ? `<line x1="${P}" x2="${W - P}" y1="${ys(trace.ceiling.mean)}" y2="${ys(trace.ceiling.mean)}" class="ceil"/>` : '';
  $('spark').innerHTML = `${ceil}${phaseLines}<path d="${bestPath}" class="best"/>` +
    rows.map((r, i) => `<circle cx="${xs(i)}" cy="${ys(r.score)}" r="4.5" class="${r.accepted ? 'kept' : 'rej'}" data-i="${i}"><title>r${i} ${r.score.toFixed(3)}</title></circle>`).join('');
  const pz = panzoom($('lgraph'));
  const show = () => {
    const r = rows[k];
    const scores = r.val != null ? `validation ${r.val.toFixed(3)} · train ${r.train.toFixed(3)}` : `train ${r.score.toFixed(3)}`;
    $('lcap').innerHTML = `<b>r${String(r.round).padStart(2, '0')}</b> · ${scores} · ${r.accepted ? 'kept' : 'rejected'}${r.phase > 1 ? ' · phase ' + r.phase : ''}<br><span>${esc(r.note)}</span>`;
    $('lsrc').innerHTML = highlight(r.program);
    $('lgraph').innerHTML = r.graph || '';
    pz.refit();
    $('spark').querySelectorAll('circle').forEach(c => c.classList.toggle('cur', +c.dataset.i === k));
  };
  $('lprev').onclick = () => { k = (k + rows.length - 1) % rows.length; show(); };
  $('lnext').onclick = () => { k = (k + 1) % rows.length; show(); };
  $('spark').querySelectorAll('circle').forEach(c => c.onclick = () => { k = +c.dataset.i; show(); });
  show();
}

// ---- views ---------------------------------------------------------------------------
async function setView(v) {
  document.querySelectorAll('#view button').forEach(b => b.setAttribute('aria-selected', String(b.dataset.view === v)));
  for (const k of ['rule', 'policy', 'loop', 'back']) $(`pane-${k}`).hidden = v !== k;
  if (v === 'policy' && !$('policy').innerHTML) $('policy').innerHTML = mdToHtml(await run('$policymd'));
  if (v === 'loop' && !$('loop').innerHTML) await showLoop();
  if (v === 'back' && !$('back').innerHTML) await showBack();
}

// ---- recorded backward pass through a learned (model-backed) program ---------------
// A profile's parts: applicability, then each labelled decision-boundary paragraph.
function mdParts(md) {
  const parts = [];
  const app = md.match(/#### `applicability`\n\n([\s\S]*?)\n\n#### /);
  if (app) parts.push(['Applicability', app[1].replace(/^> ?/gm, '').trim()]);
  const db = md.split('#### `decision_boundary`')[1] || '';
  for (const block of db.split(/\n\n/)) {
    const m = block.replace(/^> ?/gm, '').match(/^([^:\n]+):\n([\s\S]*)$/);
    if (m) parts.push([m[1].trim(), m[2].trim()]);
  }
  return parts;
}

async function showBack() {
  const box = $('back');
  let doc;
  try { doc = await fetch('backward.json').then(r => r.json()); } catch (_) { box.innerHTML = '<p class="err">backward.json is missing.</p>'; return; }
  const before = mdParts(doc.output);
  box.innerHTML = `
    <div class="loop-head"><div><h2>Editing prose backwards, through a learned program</h2>
      <p class="sub">The program below was written by the learning loop: it renders rule ${esc(doc.rule)}'s profile from its packet with five model calls (${esc(doc.models.forward)}) and a deterministic layout. Edit the prose and <code>nlir put</code> runs it backwards: through the layout (an exact lens), through each <code>=&gt;</code> call (a ${esc(doc.models.backward)} request for minimal patches to the instruction), through <code>++</code> (which locates the patch in the packet) and <code>$json</code> (which parses it back) — ending on spec fields. Then the edited spec runs forward again, so you see what else it changes. Recorded with the CLI; the live Profile tab does the exact (model-free) half in your browser.</p></div>
      <div class="seg" id="backScen">${doc.scenarios.map((s, i) => `<button data-i="${i}" class="${i ? '' : 'on'}">${esc(s.name)}</button>`).join('')}</div></div>
    <div id="backBody"></div>
    <details class="source"><summary>the learned program</summary><pre class="console code">${highlight(doc.program)}</pre></details>`;
  const show = i => {
    const s = doc.scenarios[i];
    const edited = mdParts(s.edited), rerun = mdParts(s.rerun || '');
    const editedRows = before.map(([label, text], k) => {
      const e = (edited[k] || [label, text])[1];
      return e === text ? '' : `<div class="field changed"><div class="label">${esc(label)}<span>your edit</span></div><div class="text">${wordDiff(text, e)}</div></div>`;
    }).join('');
    const specRows = s.edits.flatMap(e => e.changes.map(c => `<div class="field changed"><div class="label">${esc(e.target)}.${esc(c.path.replace(/\//g, '.'))}<span>spec</span></div><div class="text">${wordDiff(String(c.old ?? ''), String(c.new ?? ''))}</div></div>`)).join('');
    const tension = s.tensions.length ? s.tensions.map(t => `<div class="callout warn"><b>Tension.</b> ${esc(t)}</div>`).join('') : '';
    const ripple = before.map(([label, text], k) => {
      const r = (rerun[k] || [label, ''])[1];
      const touched = (edited[k] || [label, text])[1] !== text;
      return `<div class="field ${r === text ? '' : 'changed'}"><div class="label">${esc(label)}<span>${touched ? 'edited part' : r === text ? 'unchanged' : 'ripple'}</span></div><div class="text">${r === text ? esc(text) : wordDiff(text, r)}</div></div>`;
    }).join('');
    const sim = s.similarity == null ? '—' : s.similarity.toFixed(2);
    $('backBody').innerHTML = `
      <p class="sub">${esc(s.blurb)}</p>
      <div class="back-grid">
        <article class="pane"><h2>1 · The edit</h2><div class="fields">${editedRows}</div></article>
        <article class="pane"><h2>2 · Backward → spec</h2><div class="fields">${specRows}</div>${tension}</article>
        <article class="pane"><h2>3 · Forward again <span class="state ${s.similarity >= 0.9 ? 'ok' : 'warn'}">keeps your edit's meaning: ${sim}</span></h2><div class="fields">${ripple}</div></article>
      </div>`;
  };
  box.querySelectorAll('#backScen button').forEach(b => b.onclick = () => {
    box.querySelectorAll('#backScen button').forEach(x => x.classList.toggle('on', x === b)); show(+b.dataset.i);
  });
  show(0);
}

async function roundTripBadge() {
  const n = await run("ok={$json%($fields%($render%(($node%$0).profile))) == $json%(($node%$0).profile)}; $len%($filter%($ok, $leaves)) ++ '/' ++ $len%$leaves");
  const b = $('trip'); b.textContent = `${n} rules round-trip exactly`; b.className = 'badge live';
}

let timer;
$('prose').addEventListener('input', () => { edited = true; clearTimeout(timer); timer = setTimeout(reparse, 220); });
$('reset').onclick = () => select(current);
document.querySelectorAll('#specMode button').forEach(b => b.onclick = () => {
  document.querySelectorAll('#specMode button').forEach(x => x.classList.toggle('on', x === b)); showSpec();
});
document.querySelectorAll('#view button').forEach(b => b.onclick = () => setView(b.dataset.view));

try {
  await boot();
  await buildRail();
  await select('CR V 1.1');
  roundTripBadge();
} catch (e) {
  document.querySelector('.stage').insertAdjacentHTML('afterbegin', `<div class="err">The evaluator did not load: ${esc(e.message || e)}</div>`);
}
