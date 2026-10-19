// Explain a spec ⇄ prose pass: recorded forward and edit passes of three programs over the invented
// code-review spec (traces.json, built by scripts/export-explain-traces.py). No model calls are made here.
(async () => {
  const $ = id => document.getElementById(id);
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const PARTS = ['APPLICABILITY', 'DECISION BOUNDARY', 'MET', 'NOT MET', 'UNCERTAIN'];
  const LABEL = { APPLICABILITY: 'Applicability', 'DECISION BOUNDARY': 'Decision boundary', MET: 'MET', 'NOT MET': 'NOT MET', UNCERTAIN: 'UNCERTAIN' };
  // Which node groups each part is written from (the concept program's derivation rules).
  const USES = { APPLICABILITY: ['action', 'conditions'], 'DECISION BOUNDARY': ['action', 'conditions', 'permissions'],
    MET: ['action', 'conditions', 'permissions'], 'NOT MET': ['action', 'conditions', 'permissions'], UNCERTAIN: ['facts'] };
  const PROGRAMS = { concepts: 'Concept layer', chained: 'Chained', flat: 'Flat' };

  let D;
  try { D = await fetch('traces.json').then(r => r.json()); }
  catch (e) { $('narrate').innerHTML = '<p class="err">traces.json is missing.</p>'; return; }

  const state = { rule: 0, program: 'concepts', scenario: 'base', step: 0, timer: null };
  const fromHash = () => {
    const h = new URLSearchParams(location.hash.slice(1));
    const i = D.rules.findIndex(r => r.id === h.get('rule'));
    if (i >= 0) state.rule = i;
    if (PROGRAMS[h.get('program')]) state.program = h.get('program');
    if (['base', 'edit'].includes(h.get('scenario'))) state.scenario = h.get('scenario');
    state.step = Math.max(0, Number(h.get('step')) || 0);
  };
  const toHash = () => history.replaceState(null, '', '#' + new URLSearchParams({ rule: rule().id, program: state.program, scenario: state.scenario, step: state.step }));
  const rule = () => D.rules[state.rule];

  // ---- word diff (LCS over words) ------------------------------------------------------------
  function diff(a, b) {
    // Word LCS, then each run of changes is shown as one deleted block followed by one inserted block
    // (a run continues across whitespace and across single shared short words), so a rewritten clause
    // reads as old -> new instead of interleaved confetti.
    const x = a.split(/(\s+)/), y = b.split(/(\s+)/), n = x.length, m = y.length;
    const L = Array.from({ length: n + 1 }, () => new Int32Array(m + 1));
    for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) L[i][j] = x[i] === y[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
    const ops = [];
    let i = 0, j = 0;
    while (i < n && j < m) {
      if (x[i] === y[j]) { ops.push(['eq', x[i]]); i++; j++; }
      else if (L[i + 1][j] >= L[i][j + 1]) ops.push(['del', x[i++]]);
      else ops.push(['ins', y[j++]]);
    }
    while (i < n) ops.push(['del', x[i++]]);
    while (j < m) ops.push(['ins', y[j++]]);
    const weak = t => /^\s*$/.test(t) || (t.length <= 3 && /^[a-z]+$/i.test(t));
    let out = '', k = 0;
    while (k < ops.length) {
      if (ops[k][0] === 'eq') { out += esc(ops[k][1]); k++; continue; }
      let del = '', ins = '', end = k;
      // extend the hunk while changes continue, absorbing shared whitespace or short words between them
      for (let t = k; t < ops.length; t++) {
        if (ops[t][0] !== 'eq') { end = t; continue; }
        const next = ops.slice(t).findIndex(o => o[0] !== 'eq');
        if (!weak(ops[t][1]) || next < 0 || ops.slice(t, t + next).some(o => !weak(o[1]))) break;
      }
      for (let t = k; t <= end; t++) { const [kind, tok] = ops[t]; if (kind !== 'ins') del += tok; if (kind !== 'del') ins += tok; }
      out += (del.trim() ? `<del>${esc(del)}</del>` : '') + (ins.trim() ? `<ins>${esc(ins)}</ins>` : '');
      k = end + 1;
    }
    return out;
  }

  // ---- the steps of each pass ------------------------------------------------------------------
  function steps() {
    const R = rule(), P = state.program, E = state.scenario === 'edit';
    const S = [];
    if (P === 'concepts' && !E) {
      S.push({ kind: 'start' }, { kind: 'call', id: 'model' }, ...PARTS.map(id => ({ kind: 'call', id })), { kind: 'done' });
    } else if (P === 'concepts') {
      S.push({ kind: 'edit-start' }, { kind: 'edit-node' }, ...PARTS.map(id => ({ kind: 'rederive', id })), { kind: 'verdict' });
    } else if (!E) {
      S.push({ kind: 'start' }, ...PARTS.map(id => ({ kind: 'write', id })), { kind: 'done' });
    } else if (P === 'chained') {
      S.push({ kind: 'edit-start' }, { kind: 'pin', id: 'MET' }, { kind: 'rederive', id: 'NOT MET' }, { kind: 'rederive', id: 'UNCERTAIN' }, { kind: 'verdict' });
    } else {
      S.push({ kind: 'edit-start' }, { kind: 'pin', id: 'MET' }, { kind: 'stuck' }, { kind: 'verdict' });
    }
    return S;
  }

  // The profile shown at a step: which parts are written yet, which changed, which is active.
  function profileAt(S, k) {
    const R = rule(), P = state.program, E = state.scenario === 'edit';
    const base = P === 'concepts' ? R.concepts.parts : R[P].parts;
    const edited = P === 'concepts' ? R.concepts_edited.parts : R[P].edited;
    const shown = {}, cur = S[k];
    if (!E) {
      const written = new Set(S.slice(0, k + 1).filter(s => s.kind === 'call' || s.kind === 'write').map(s => s.id));
      for (const p of PARTS) shown[p] = written.has(p) || cur.kind === 'done' ? { text: base[p] } : null;
    } else {
      const redone = new Set(S.slice(0, k + 1).filter(s => ['rederive', 'pin'].includes(s.kind)).map(s => s.id));
      const done = cur.kind === 'verdict' || cur.kind === 'stuck';
      for (const p of PARTS) {
        const now = redone.has(p) || done ? edited[p] : base[p];
        shown[p] = { text: now, diff: (redone.has(p) || done) && now !== base[p] ? diff(base[p], now) : null, unchanged: (redone.has(p) || done) && now === base[p] };
      }
    }
    return shown;
  }

  // ---- lanes -----------------------------------------------------------------------------------
  function passages(R) {
    const out = [];
    const add = (key, text) => { if (text && typeof text === 'string') out.push({ key, text }); };
    add('rule', R.packet.rule); add('scope', R.packet.scope);
    for (const [k, v] of Object.entries(R.packet)) {
      if (['id', 'title', 'force', 'rule', 'scope', '_pin'].includes(k)) continue;
      if (typeof v === 'string') add(k, v);
      else if (Array.isArray(v)) v.forEach((x, i) => add(`${k} ${i + 1}`, typeof x === 'string' ? x : x.text || x.description || JSON.stringify(x)));
      else if (v && typeof v === 'object') Object.entries(v).forEach(([a, b]) => add(`${k}: ${a}`, typeof b === 'string' ? b : JSON.stringify(b)));
    }
    return out;
  }
  const norm = s => String(s || '').replace(/\*\*/g, '').replace(/["“”‘’`]/g, '').replace(/\s+/g, ' ').trim().toLowerCase().replace(/^[\s.,;:]+|[\s.,;:…]+$/g, '');

  function renderSpec(R, active) {
    const cites = active.map(n => norm(n.source)).filter(s => s.length > 3 && !s.startsWith('(added'));
    const html = passages(R).map((p, i) => {
      const t = norm(p.text), hit = cites.some(c => t.includes(c) || (c.length > 24 && t.includes(c.slice(0, 24))));
      let body = esc(p.text.replace(/\*\*/g, ''));
      return `<div class="passage${hit ? ' hit' : ''}" data-passage="${i}"><span class="k">${esc(p.key)}</span>${body}</div>`;
    }).join('');
    $('lane-spec').querySelector('.body').innerHTML = `<p class="title">${esc(R.id)} · ${esc(R.title)}</p>${html}`;
  }

  function nodesOf(model) {
    const g = [];
    g.push({ group: 'action', id: 'act', text: model.action, source: '' });
    for (const k of ['conditions', 'permissions', 'facts']) for (const n of model[k] || []) g.push({ group: k, ...n });
    return g;
  }

  function renderModel(R, S, k) {
    const body = $('lane-model').querySelector('.body');
    const P = state.program, E = state.scenario === 'edit', cur = S[k];
    if (P === 'flat') {
      body.innerHTML = `<div class="empty"><b>No shared model.</b> Each of the five parts is one independent model call on the same packet and worked examples. Nothing connects MET to NOT MET, so an edit to one cannot reach the other.</div>`;
      return [];
    }
    if (P === 'chained') {
      const on = id => (cur.id === id ? ' on' : '');
      body.innerHTML = `<div class="chain"><div class="cnode${on('MET')}">MET<small>written from the packet</small></div><div class="carrow">↓ read by</div><div class="cnode${on('NOT MET')}">NOT MET<small>its exact contrast</small></div><div class="carrow">↓ both read by</div><div class="cnode${on('UNCERTAIN')}">UNCERTAIN<small>the facts that decide</small></div></div>
        <p class="muted small">Applicability and the decision boundary are written from the packet alone. Each verdict part reads the ones above it, which are authoritative where they narrow or extend the packet.</p>`;
      return [];
    }
    const extracted = E || S.slice(0, k + 1).some(s => s.id === 'model');
    if (!extracted) { body.innerHTML = '<div class="empty">Not extracted yet. The first model call will read the packet into a model of the rule.</div>'; return []; }
    const model = E && k >= 1 ? R.concepts_edited.model : R.concepts.model;
    const base = new Set(nodesOf(R.concepts.model).map(n => n.group + ':' + n.text));
    const nodes = nodesOf(model);
    const using = cur.kind === 'call' || cur.kind === 'rederive' ? USES[cur.id] || [] : cur.id === 'model' ? ['action', 'conditions', 'permissions', 'facts'] : [];
    const groups = [['action', 'Action being judged', ''], ['conditions', 'Conditions', 'all must hold for MET'], ['permissions', 'Exceptions', 'any one avoids a violation'], ['facts', 'Facts', 'decide UNCERTAIN']];
    body.innerHTML = groups.map(([g, name, note]) => {
      const ns = nodes.filter(n => n.group === g);
      const items = ns.length ? ns.map(n => {
        const added = !base.has(n.group + ':' + n.text);
        return `<div class="node ${g}${using.includes(g) ? ' on' : ''}${added ? ' added' : ''}" data-node="${esc(n.id)}"><span class="id">${esc(n.id)}</span>${esc(n.text)}${n.decides ? `<small>decides ${esc(n.decides.join(', '))}</small>` : ''}${added ? '<small class="addnote">added by the author — not in the spec</small>' : n.source ? `<small class="src" title="${esc(n.source)}">“${esc((t => t.length > 80 ? t.slice(0, 80) + '…' : t)(n.source.replace(/^["“”\s]+|["“”\s]+$/g, '').replace(/\*\*/g, '')))}”</small>` : ''}</div>`;
      }).join('') : '<div class="node none">none</div>';
      return `<div class="group"><h3>${name}${note ? ` <small>${note}</small>` : ''}</h3>${items}</div>`;
    }).join('');
    return nodes.filter(n => using.includes(n.group));
  }

  function renderProfile(S, k) {
    const shown = profileAt(S, k), cur = S[k];
    $('lane-profile').querySelector('.body').innerHTML = PARTS.map(p => {
      const x = shown[p];
      const on = cur.id === p && ['call', 'rederive', 'write', 'pin'].includes(cur.kind);
      const chip = x?.diff ? '<span class="chip changed">changed</span>' : x?.unchanged ? '<span class="chip">unchanged</span>' : '';
      return `<div class="part${on ? ' on' : ''}${x ? '' : ' pending'}" data-part="${esc(p)}"><h3>${LABEL[p]} ${chip}</h3><div class="ptext">${x ? (x.diff || esc(x.text)) : '<span class="muted">not written yet</span>'}</div></div>`;
    }).join('');
  }

  // ---- wires: passages → nodes → the active part -----------------------------------------------------
  function wires(activeNodes, part) {
    const svg = $('wires'), box = $('lanes').getBoundingClientRect();
    svg.setAttribute('viewBox', `0 0 ${box.width} ${box.height}`);
    const pt = (el, side) => { const r = el.getBoundingClientRect(); return [side === 'r' ? r.right - box.left : r.left - box.left, r.top - box.top + Math.min(r.height / 2, 18)]; };
    const path = ([x1, y1], [x2, y2], cls) => `<path class="${cls}" d="M${x1},${y1} C${(x1 + x2) / 2},${y1} ${(x1 + x2) / 2},${y2} ${x2},${y2}"/>`;
    let d = '';
    const hits = [...document.querySelectorAll('.passage.hit')];
    for (const n of activeNodes) {
      const el = document.querySelector(`.node[data-node="${CSS.escape(n.id)}"]`);
      if (!el) continue;
      for (const h of hits) if (norm(h.textContent).includes(norm(n.source).slice(0, 24)) && n.source) d += path(pt(h, 'r'), pt(el, 'l'), 'w-src');
      const pe = part && document.querySelector(`.part[data-part="${CSS.escape(part)}"]`);
      if (pe) d += path(pt(el, 'r'), pt(pe, 'l'), 'w-use');
    }
    svg.innerHTML = d;
  }

  // ---- the model call ------------------------------------------------------------------------------------------
  function renderCall(R, S, k) {
    const cur = S[k], P = state.program, E = state.scenario === 'edit';
    const box = $('call');
    let st = null;
    if (P === 'concepts' && cur.kind === 'call') st = R.concepts.steps.find(s => s.id === cur.id);
    if (P === 'concepts' && cur.kind === 'rederive') st = R.concepts_edited.steps.find(s => s.id === cur.id);
    if (!st) { box.innerHTML = ''; return; }
    const KIND = { program: 'program text', examples: 'worked examples (data)', packet: 'spec packet (data)', field: "this part's instruction", model: 'rule model (from step 1)', derive: 'derivation rule' };
    const seg = s => {
      if (s.ref) return `<details class="seg-${s.kind}"><summary>${KIND[s.kind]} · ${R.shared[s.ref].length.toLocaleString()} characters</summary><pre>${esc(R.shared[s.ref])}</pre></details>`;
      return `<span class="seg-${s.kind}" title="${KIND[s.kind]}">${esc(s.text)}</span>`;
    };
    const legend = [...new Set(st.segments.map(s => s.kind))].map(k2 => `<span class="key seg-${k2}">${KIND[k2]}</span>`).join('');
    box.innerHTML = `<h2>The model call · ${esc(st.id === 'model' ? 'extract the rule model' : LABEL[st.id])}</h2><div class="legend">${legend}</div>
      <div class="cols"><div><h3>Prompt sent to the writer</h3><div class="prompt">${st.segments.map(seg).join('')}</div></div>
      <div><h3>Response${st.id === 'model' ? ' (the rule model)' : ' (after the clean-up of labels and markers)'}</h3><pre class="resp">${esc(st.response)}</pre></div></div>`;
  }

  // ---- narration and verdicts ------------------------------------------------------------------------------------
  function narrate(R, S, k) {
    const cur = S[k], P = state.program, M = R.concepts.model;
    const derive = id => { const st = (state.scenario === 'edit' ? R.concepts_edited : R.concepts).steps.find(s => s.id === id); const d = st?.segments.find(s => s.kind === 'derive'); return d ? d.text.trim() : ''; };
    const cnt = (m, k2) => (m[k2] || []).length;
    const T = {
      start: P === 'concepts' ? 'The program has two inputs: this rule\'s spec packet (left) and two worked profiles from other rules, which show the authors\' style. Nothing has been called yet.'
        : P === 'chained' ? 'The chained program writes applicability, the decision boundary and MET from the packet, then NOT MET from MET, then UNCERTAIN from both.'
        : 'The flat program writes each of the five parts with its own model call on the same packet and worked examples. The calls do not see each other.',
      done: P === 'concepts' ? 'All five parts come from the same nodes, so they agree by construction: MET is the action with every condition and no exception; NOT MET is exactly the rest; UNCERTAIN names the deciding facts.'
        : P === 'chained' ? 'The verdict parts are linked by what they read; nothing else forces them to agree.' : 'Five independent paragraphs. They agree only as far as the same packet led each call to the same reading.',
      'edit-start': `An author adds an exception the spec does not contain: <q>${esc(R.exception)}</q>. Where does it go, and which parts follow?`,
      'edit-node': 'In the concept layer the exception becomes one new node — an exception marked as added by the author. Nothing else in the model changes; every part is now written again from it.',
      stuck: 'In the flat program nothing connects MET to the other parts, so NOT MET and UNCERTAIN stay exactly as they were — the profile now says one thing in MET and another in NOT MET.',
      verdict: 'A judge read each program\'s edited profile and answered three questions about the exception case.',
    };
    let html = T[cur.kind] || '';
    if (cur.kind === 'call' && cur.id === 'model') html = `<b>Step ${k + 1}.</b> One model call reads the packet and returns a small model of the rule: ${cnt(M, 'conditions')} condition${cnt(M, 'conditions') === 1 ? '' : 's'} that must all hold, ${cnt(M, 'permissions')} exception${cnt(M, 'permissions') === 1 ? '' : 's'}, ${cnt(M, 'facts')} fact${cnt(M, 'facts') === 1 ? '' : 's'} a verdict turns on. Each node quotes the passage it rests on — highlighted on the left.`;
    if (cur.kind === 'call' && cur.id !== 'model') html = `<b>Step ${k + 1}.</b> One model call writes <b>${LABEL[cur.id]}</b> from the rule model; the packet is still there for detail, but the model is authoritative. The program states how: <q>${esc(derive(cur.id))}</q> The highlighted nodes are the ones this part is built from.`;
    if (cur.kind === 'write') html = `<b>${LABEL[cur.id]}.</b> ${P === 'chained' && cur.id === 'NOT MET' ? 'Written from the packet <i>and</i> the MET paragraph above it, as its exact contrast.' : P === 'chained' && cur.id === 'UNCERTAIN' ? 'Written from the packet and both verdict paragraphs above it.' : 'Written from the packet and the worked examples only.'}`;
    if (cur.kind === 'pin') html = P === 'chained' ? 'The author pins an edited MET: the exception is added to it. A pinned part makes no model call; the parts after it are re-derived from it.' : 'The author edits MET: the exception is added to it.';
    if (cur.kind === 'rederive') {
      const ch = (P === 'concepts' ? R.concepts_edited.parts : R[P].edited)[cur.id] !== (P === 'concepts' ? R.concepts.parts : R[P].parts)[cur.id];
      html = `<b>${LABEL[cur.id]}</b> is written again from the ${P === 'concepts' ? 'edited model' : 'pinned MET'}. ${ch ? 'It changed — insertions underlined, deletions struck through.' : 'It came out unchanged.'}`;
    }
    $('narrate').innerHTML = `<p>${html}</p>`;
  }

  function renderVerdict(R, S, k) {
    const box = $('verdict');
    if (state.scenario !== 'edit' || S[k].kind !== 'verdict') { box.innerHTML = ''; return; }
    const mark = (v, good) => `<span class="${v === good ? 'ok' : 'bad'}">${v ? 'yes' : 'no'}</span>`;
    const row = (p, name) => { const v = (p === 'concepts' ? R.concepts_edited : R[p]).verdict, s = D.summary[p === 'flat' ? 'clean' : p];
      return `<tr${p === state.program ? ' class="cur"' : ''}><th>${name}</th><td>${mark(!!v.met_excludes, true)}</td><td>${mark(!!v.not_met_covers, true)}</td><td>${mark(!!v.overlap, false)}</td><td class="muted small">${s.not_met_covers}/8 cover · ${s.overlap}/8 overlap</td><td class="small">${esc(v.why || '')}</td></tr>`; };
    box.innerHTML = `<h2>Did the edit travel, consistently?</h2><p class="muted small">The judge (Sol) read each program's edited profile for this rule. The totals are over the eight rules.</p>
      <table><tr><th></th><th>MET excludes the exception</th><th>NOT MET covers it</th><th>MET and NOT MET overlap</th><th>all 8 rules</th><th>why (this rule)</th></tr>
      ${row('flat', 'Flat — edit MET only')}${row('chained', 'Chained — MET pinned')}${row('concepts', 'Concept layer — node added')}</table>`;
  }

  // ---- render ------------------------------------------------------------------------------------------------------
  function render() {
    const R = rule(), S = steps();
    state.step = Math.min(state.step, S.length - 1);
    const k = state.step, cur = S[k];
    $('rule').value = String(state.rule);
    for (const b of document.querySelectorAll('#program button')) b.setAttribute('aria-selected', String(b.dataset.program === state.program));
    for (const b of document.querySelectorAll('#scenario button')) b.setAttribute('aria-selected', String(b.dataset.scenario === state.scenario));
    $('stepno').textContent = `step ${k + 1} of ${S.length}`;
    $('prev').disabled = k === 0; $('next').disabled = k === S.length - 1;
    const active = renderModel(R, S, k);
    renderSpec(R, active);
    renderProfile(S, k);
    narrate(R, S, k);
    renderCall(R, S, k);
    renderVerdict(R, S, k);
    requestAnimationFrame(() => wires(active, ['call', 'rederive'].includes(cur.kind) && cur.id !== 'model' ? cur.id : null));
    toHash();
  }

  $('rule').innerHTML = D.rules.map((r, i) => `<option value="${i}">${esc(r.id)} · ${esc(r.title)}</option>`).join('');
  $('rule').onchange = e => { state.rule = Number(e.target.value); state.step = 0; render(); };
  for (const b of document.querySelectorAll('#program button')) b.onclick = () => { state.program = b.dataset.program; state.step = 0; render(); };
  for (const b of document.querySelectorAll('#scenario button')) b.onclick = () => { state.scenario = b.dataset.scenario; state.step = 0; render(); };
  const go = d => { const n = steps().length; state.step = Math.max(0, Math.min(n - 1, state.step + d)); render(); };
  $('prev').onclick = () => go(-1); $('next').onclick = () => go(1);
  $('play').onclick = () => {
    if (state.timer) { clearInterval(state.timer); state.timer = null; $('play').textContent = 'Play'; return; }
    state.step = 0; render(); $('play').textContent = 'Stop';
    state.timer = setInterval(() => { if (state.step >= steps().length - 1) { clearInterval(state.timer); state.timer = null; $('play').textContent = 'Play'; return; } go(1); }, 2200);
  };
  document.addEventListener('keydown', e => { if (e.target.closest('select, input, textarea')) return; if (e.key === 'ArrowRight') go(1); if (e.key === 'ArrowLeft') go(-1); });
  window.addEventListener('resize', () => render());
  window.addEventListener('hashchange', () => { fromHash(); render(); });
  $('foot').textContent = `Recorded passes: writer ${D.models.writer}; exceptions and judge ${D.models['exceptions and judge']}. ${D.method}`;
  fromHash();
  render();
})();
