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

// Prose → spec: parse the (possibly edited) prose back into fields and compare
// with the stored spec, part by part.
async function reparse() {
  const id = current;
  let parsed, gold;
  try {
    [parsed, gold] = await Promise.all([
      runJson('$fields%$prose', { prose: $('prose').value }),
      runJson('($node%$id).profile', { id }),
    ]);
  } catch (e) {
    $('fields').innerHTML = `<div class="err">${esc(e.message || e)}</div>`;
    $('state').className = 'state warn'; $('state').textContent = 'unparseable';
    return;
  }
  const parts = p => [['Applicability', (p.applicability || []).join('\n\n')], ...(p.decision_boundary || []).map(x => {
    const i = x.indexOf(':'); return [x.slice(0, i).trim(), x.slice(i + 1).trim()];
  })];
  const g = parts(gold), c = parts(parsed);
  let changed = 0;
  $('fields').innerHTML = g.map(([label, text], i) => {
    const cand = (c.find(([l]) => l.toUpperCase() === label.toUpperCase()) || [label, ''])[1];
    const same = cand === text;
    if (!same) changed++;
    return `<div class="field ${same ? '' : 'changed'}"><div class="label">${esc(label)}${same ? '' : '<span>edited</span>'}</div><div class="text">${same ? esc(text) : wordDiff(text, cand)}</div></div>`;
  }).join('');
  const st = $('state');
  if (!changed) { st.className = 'state ok'; st.textContent = 'round trip exact'; }
  else { st.className = 'state warn'; st.textContent = `${changed} field${changed > 1 ? 's differ' : ' differs'} from the spec`; }
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
      <div class="stat"><b>${best.seed.mean.toFixed(2)} → ${best.best.mean.toFixed(2)}</b><span>held-out similarity, seed → learned</span></div>
      <div class="stat"><b>${(best.best.pass_rate * 100).toFixed(0)}%</b><span>held-out rules ≥ ${trace.threshold}</span></div>
      <div class="stat"><b>${rows.length - 1}</b><span>proposals · ${esc(trace.models.generation)} generates · ${esc(trace.models.judge)} judges</span></div>
    </div>
    <svg class="spark" viewBox="0 0 600 120" id="spark"></svg>
    <div class="stepper"><button id="lprev" aria-label="Previous round">◀</button><span id="lcap"></span><button id="lnext" aria-label="Next round">▶</button></div>
    <div class="loop-grid"><pre class="console code" id="lsrc"></pre><div id="lgraph" class="lgraph"></div></div>`;
  const W = 600, H = 120, P = 14, xs = i => P + i * (W - 2 * P) / Math.max(rows.length - 1, 1), ys = s => H - P - s * (H - 2 * P);
  let run = 0;
  const bestPath = rows.map((r, i) => { if (r.accepted) run = Math.max(run, r.score); return `${i ? 'L' : 'M'}${xs(i).toFixed(1)},${ys(run).toFixed(1)}`; }).join(' ');
  $('spark').innerHTML = `<line x1="${P}" x2="${W - P}" y1="${ys(trace.threshold)}" y2="${ys(trace.threshold)}" class="thr"/><path d="${bestPath}" class="best"/>` +
    rows.map((r, i) => `<circle cx="${xs(i)}" cy="${ys(r.score)}" r="4.5" class="${r.accepted ? 'kept' : 'rej'}" data-i="${i}"><title>r${i} ${r.score.toFixed(3)}</title></circle>`).join('');
  const show = () => {
    const r = rows[k];
    $('lcap').innerHTML = `<b>r${String(r.round).padStart(2, '0')}</b> · train ${r.score.toFixed(3)} · ${r.accepted ? 'kept' : 'rejected'}<br><span>${esc(r.note)}</span>`;
    $('lsrc').innerHTML = highlight(r.program);
    $('lgraph').innerHTML = r.graph || '';
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
  $('pane-rule').hidden = v !== 'rule'; $('pane-policy').hidden = v !== 'policy'; $('pane-loop').hidden = v !== 'loop';
  if (v === 'policy' && !$('policy').innerHTML) $('policy').innerHTML = mdToHtml(await run('$policymd'));
  if (v === 'loop' && !$('loop').innerHTML) await showLoop();
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
