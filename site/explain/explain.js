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
  try { D = window.EXPLAIN_TRACES || await fetch('traces.json').then(r => r.json()); }
  catch (e) { $('narrate').innerHTML = '<p class="err">traces.json is missing.</p>'; return; }

  const state = { rule: 0, program: 'concepts', scenario: 'base', step: 0, timer: null };
  const fromHash = () => {
    const h = new URLSearchParams(location.hash.slice(1));
    const i = D.rules.findIndex(r => r.id === h.get('rule'));
    if (i >= 0) state.rule = i;
    if (PROGRAMS[h.get('program')]) state.program = h.get('program');
    if (['base', 'edit', 'sentence', 'negation'].includes(h.get('scenario'))) state.scenario = h.get('scenario');
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
    if (state.scenario === 'sentence' || state.scenario === 'negation') {
      if (P !== 'concepts' || !R[state.scenario]) return [{ kind: 'needs', id: state.scenario }];
      return [{ kind: 'sentence-edit', id: R[state.scenario].part || 'MET' }, { kind: 'backward' }, ...PARTS.map(id => ({ kind: 'rederive', id })), { kind: 'check' }];
    }
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
    const SC = state.scenario === 'sentence' || state.scenario === 'negation';
    const base = P === 'concepts' ? R.concepts.parts : R[P].parts;
    const edited = SC && R[state.scenario] ? R[state.scenario].parts : P === 'concepts' ? R.concepts_edited?.parts : R[P]?.edited;
    if (SC) {
      const shown = {}, cur = S[k], X = R[state.scenario];
      if (!X || cur.kind === 'needs') { for (const p of PARTS) shown[p] = { text: base[p] }; return shown; }
      const redone = new Set(S.slice(0, k + 1).filter(s => s.kind === 'rederive').map(s => s.id));
      for (const p of PARTS) {
        if (redone.has(p) || cur.kind === 'check') { const now = edited[p]; shown[p] = { text: now, diff: now !== base[p] ? diff(base[p], now) : null, unchanged: now === base[p] }; }
        else if (p === (X.part || 'MET')) shown[p] = { text: X.new, diff: diff(X.old, X.new), edited: true };
        else shown[p] = { text: base[p] };
      }
      return shown;
    }
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
    const SC = state.scenario === 'sentence' || state.scenario === 'negation';
    if (SC && cur.kind === 'needs') { body.innerHTML = '<div class="empty">This scenario pushes a sentence edit back to the rule model, so it needs the <b>concept layer</b> program' + (state.scenario === 'negation' && !R.negation ? ' — and it is recorded for CR V 1.3 only' : '') + '.</div>'; return []; }
    const extracted = E || SC || S.slice(0, k + 1).some(s => s.id === 'model');
    if (!extracted) { body.innerHTML = '<div class="empty">Not extracted yet. The first model call will read the packet into a model of the rule.</div>'; return []; }
    if (R.live && state.editing && state.scenario === 'base') return renderModelEditor(R, body);
    const model = SC ? (k >= 1 ? R[state.scenario].model : R.concepts.model) : E && k >= 1 ? R.concepts_edited.model : R.concepts.model;
    const baseText = new Map(nodesOf(R.concepts.model).map(n => [n.group + ':' + n.id, n.text]));
    const base = new Set(nodesOf(R.concepts.model).map(n => n.group + ':' + n.text));
    const nodes = nodesOf(model);
    const using = cur.kind === 'call' || cur.kind === 'rederive' ? USES[cur.id] || [] : cur.id === 'model' ? ['action', 'conditions', 'permissions', 'facts'] : [];
    const groups = [['action', 'Action being judged', ''], ['conditions', 'Conditions', 'all must hold for MET'], ['permissions', 'Exceptions', 'any one avoids a violation'], ['facts', 'Facts', 'decide UNCERTAIN']];
    body.innerHTML = groups.map(([g, name, note]) => {
      const ns = nodes.filter(n => n.group === g);
      const items = ns.length ? ns.map(n => {
        const was = baseText.get(n.group + ':' + n.id);
        const added = !base.has(n.group + ':' + n.text) && (was === undefined || !(SC || R.live));
        const changed = (SC || R.live) && was !== undefined && was !== n.text;
        const unsourced = !n.source || /not in the packet|added by the author/i.test(n.source);
        const note = added ? `<small class="addnote">${SC ? 'added by the backward pass' : 'added by the author'}${unsourced ? ' — not in the spec' : ''}</small>` : changed ? `<small class="addnote">changed by the backward pass${unsourced ? ' — not in the spec' : ''}</small>` : '';
        return `<div class="node ${g}${using.includes(g) || (cur.kind === 'backward' && (added || changed)) ? ' on' : ''}${added || changed ? ' added' : ''}" data-node="${esc(n.id)}"><span class="id">${esc(n.id)}</span>${esc(n.text)}${changed ? `<small class="was">was: ${esc(was)}</small>` : ''}${n.decides ? `<small>decides ${esc(n.decides.join(', '))}</small>` : ''}${g === 'permissions' && !added && R.lint?.[n.id] ? `<small class="lint ${R.lint[n.id].genuine ? 'genuine' : 'restates'}" title="${esc(R.lint[n.id].why || '')}">${R.lint[n.id].genuine ? 'carve-out: deleting it would make these cases violations' : 'restates a boundary a condition already draws: deleting it changes no verdict'}</small>` : ''}${note ? note : n.source ? `<small class="src" title="${esc(n.source)}">“${esc((t => t.length > 80 ? t.slice(0, 80) + '…' : t)(n.source.replace(/^["“”\s]+|["“”\s]+$/g, '').replace(/\*\*/g, '')))}”</small>` : ''}</div>`;
      }).join('') : '<div class="node none">none</div>';
      return `<div class="group"><h3>${name}${note ? ` <small>${note}</small>` : ''}</h3>${items}</div>`;
    }).join('');
    return nodes.filter(n => using.includes(n.group));
  }

  // Inline editor (live runs): node texts are editable in place; edits go to R.draft, read by the live module.
  function renderModelEditor(R, body) {
    R.draft ||= JSON.parse(JSON.stringify(R.concepts.model));
    const M = R.draft, groups = [['conditions', 'Conditions', 'all must hold for MET', 'c'], ['permissions', 'Exceptions', 'any one avoids a violation', 'p'], ['facts', 'Facts', 'decide UNCERTAIN', 'f']];
    body.innerHTML = `<p class="muted small">Editing the rule model: change any node's text, remove one (×) or add one, then press <b>Re-derive</b> in the live panel.</p>
      <div class="group"><h3>Action being judged</h3><div class="node action edit"><span class="id">act</span><span class="etext" contenteditable="true" data-g="action">${esc(M.action)}</span></div></div>` +
      groups.map(([g, name, note, pre]) => `<div class="group"><h3>${name} <small>${note}</small></h3>${(M[g] || []).map((n, i) => `<div class="node ${g} edit"><span class="id">${esc(n.id)}</span><span class="etext" contenteditable="true" data-g="${g}" data-i="${i}">${esc(n.text)}</span><button class="x" data-g="${g}" data-i="${i}" title="Remove this node">×</button></div>`).join('')}<button class="addnode" data-g="${g}" data-pre="${pre}">+ add ${name === 'Exceptions' ? 'an exception' : name === 'Facts' ? 'a fact' : 'a condition'}</button></div>`).join('');
    body.querySelectorAll('.etext').forEach(el => el.addEventListener('input', () => {
      const g = el.dataset.g;
      if (g === 'action') M.action = el.textContent.trim(); else M[g][Number(el.dataset.i)].text = el.textContent.trim();
    }));
    body.querySelectorAll('button.x').forEach(b => (b.onclick = () => { M[b.dataset.g].splice(Number(b.dataset.i), 1); render(); }));
    body.querySelectorAll('button.addnode').forEach(b => (b.onclick = () => {
      const list = (M[b.dataset.g] ||= []);
      list.push({ id: `${b.dataset.pre}${list.length + 1}`, text: 'New node: edit me', source: '(added by the author)', ...(b.dataset.g === 'facts' ? { decides: [] } : {}) });
      render();
      const last = [...body.querySelectorAll(`.etext[data-g="${b.dataset.g}"]`)].at(-1);
      if (last) { last.focus(); document.getSelection().selectAllChildren(last); }
    }));
    return [];
  }

  function renderProfile(S, k) {
    const RR = rule();
    if (RR.live && state.editing && state.scenario === 'base') {
      RR.draftParts ||= { ...RR.concepts.parts };
      $('lane-profile').querySelector('.body').innerHTML = `<p class="muted small">Or edit one part's sentence, then press <b>Push back</b> in the live panel.</p>` + PARTS.map(p => `<div class="part edit" data-part="${esc(p)}"><h3>${LABEL[p]}${RR.draftParts[p] !== RR.concepts.parts[p] ? ' <span class="chip changed">edited</span>' : ''}</h3><div class="ptext" contenteditable="true" data-p="${esc(p)}">${esc(RR.draftParts[p])}</div></div>`).join('');
      $('lane-profile').querySelectorAll('.ptext[contenteditable]').forEach(el => el.addEventListener('input', () => { RR.draftParts[el.dataset.p] = el.textContent.trim(); }));
      return;
    }
    const shown = profileAt(S, k), cur = S[k];
    $('lane-profile').querySelector('.body').innerHTML = PARTS.map(p => {
      const x = shown[p];
      const on = cur.id === p && ['call', 'rederive', 'write', 'pin', 'sentence-edit'].includes(cur.kind);
      const chip = x?.edited ? '<span class="chip changed">edited by the author</span>' : x?.diff ? '<span class="chip changed">changed</span>' : x?.unchanged ? '<span class="chip">unchanged</span>' : '';
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
    if (P === 'concepts' && cur.kind === 'rederive' && state.scenario === 'edit') st = R.concepts_edited?.steps.find(s => s.id === cur.id);
    if (cur.kind === 'backward' && R[state.scenario]) {
      const X = R[state.scenario];
      box.innerHTML = `<h2>The backward call · from the edited sentence to the rule model</h2>
        <p class="muted small">One model call (the judge model) reads the rule model, the packet and MET before and after the edit (<code>lens-concepts.nlir</code>), and replies with node edits — change a node, add one, remove one — each with the packet passage it rests on, or none. Applying them is deterministic.</p>
        <div class="cols"><div><h3>Edit</h3><div class="prompt">${diff(X.old, X.new)}</div></div><div><h3>Node edits returned</h3><pre class="resp">${esc(JSON.stringify(X.edits, null, 1))}</pre><p class="small"><b>Why:</b> ${esc(X.why)}</p></div></div>`;
      return;
    }
    if (P === 'concepts' && cur.kind === 'rederive' && R[state.scenario] && (state.scenario === 'sentence' || state.scenario === 'negation')) { box.innerHTML = `<h2>The model call · ${LABEL[cur.id]}</h2><p class="muted small">The same call as in the forward pass, with the edited rule model pinned in place of the extracted one.</p>`; return; }
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
      'edit-start': R.live ? 'You edited the rule model. Which parts follow?' : `An author adds an exception the spec does not contain: <q>${esc(R.exception)}</q>. Where does it go, and which parts follow?`,
      'edit-node': R.live ? 'Your edit, in the model: changed and added nodes are outlined, with the old text struck through. Every part is now written again from the edited model.' : 'In the concept layer the exception becomes one new node — an exception marked as added by the author. Nothing else in the model changes; every part is now written again from it.',
      stuck: 'In the flat program nothing connects MET to the other parts, so NOT MET and UNCERTAIN stay exactly as they were — the profile now says one thing in MET and another in NOT MET.',
      verdict: R.live ? 'The consistency check reads the re-derived profile, your model and the packet: do MET and NOT MET overlap, does a case fall between them, and is each node the spec does not state an addition or a contradiction?' : 'A judge read each program\'s edited profile and answered three questions about the exception case.',
      'sentence-edit': R.live ? `You edited ${LABEL[R.sentence?.part || 'MET']}'s sentence.` : state.scenario === 'negation' ? 'The author reverses MET: “does not approve” where the rule says approving is the violation. This edit contradicts the spec.' : `The author edits MET's sentence directly, appending the exception: <q>${esc(R.exception)}</q>.`,
      backward: 'The backward pass: one model call reads the rule model, the packet and the edit, and decides which nodes the edit changes. Changed and added nodes are outlined; a node with no packet passage behind it is marked as not in the spec.',
      check: 'The consistency check reads the re-derived profile, the rule model and the packet: do MET and NOT MET overlap, does any case fall between them, and is each node the spec does not state an addition (the spec is silent) or a contradiction (the spec says otherwise)?',
      needs: 'Pushing a sentence edit back needs a shared rule model to push it into. The flat and chained programs have none: switch to the concept layer.',
    };
    let html = T[cur.kind] || '';
    if (cur.kind === 'call' && cur.id === 'model') html = `<b>Step ${k + 1}.</b> One model call reads the packet and returns a small model of the rule: ${cnt(M, 'conditions')} condition${cnt(M, 'conditions') === 1 ? '' : 's'} that must all hold, ${cnt(M, 'permissions')} exception${cnt(M, 'permissions') === 1 ? '' : 's'}, ${cnt(M, 'facts')} fact${cnt(M, 'facts') === 1 ? '' : 's'} a verdict turns on. Each node quotes the passage it rests on — highlighted on the left.`;
    if (cur.kind === 'call' && cur.id !== 'model') html = `<b>Step ${k + 1}.</b> One model call writes <b>${LABEL[cur.id]}</b> from the rule model; the packet is still there for detail, but the model is authoritative. The program states how: <q>${esc(derive(cur.id))}</q> The highlighted nodes are the ones this part is built from.`;
    if (cur.kind === 'write') html = `<b>${LABEL[cur.id]}.</b> ${P === 'chained' && cur.id === 'NOT MET' ? 'Written from the packet <i>and</i> the MET paragraph above it, as its exact contrast.' : P === 'chained' && cur.id === 'UNCERTAIN' ? 'Written from the packet and both verdict paragraphs above it.' : 'Written from the packet and the worked examples only.'}`;
    if (cur.kind === 'pin') html = P === 'chained' ? 'The author pins an edited MET: the exception is added to it. A pinned part makes no model call; the parts after it are re-derived from it.' : 'The author edits MET: the exception is added to it.';
    if (cur.kind === 'rederive') {
      const SCn = (state.scenario === 'sentence' || state.scenario === 'negation') && R[state.scenario];
      const ch = (SCn ? R[state.scenario].parts : P === 'concepts' ? R.concepts_edited.parts : R[P].edited)[cur.id] !== (P === 'concepts' ? R.concepts.parts : R[P].parts)[cur.id];
      html = `<b>${LABEL[cur.id]}</b> is written again from the ${P === 'concepts' ? 'edited model' : 'pinned MET'}. ${ch ? 'It changed — insertions underlined, deletions struck through.' : 'It came out unchanged.'}`;
    }
    if (R.live && state.editing && state.scenario === 'base') {
      $('narrate').innerHTML = `<p><b>Editing.</b> Change the rule model's nodes (middle) and press <button class="act" data-act="liveDerive">Re-derive every part</button>, or change one part's sentence (right) and press <button class="act" data-act="livePush">Push it back to the model</button>. <button class="act ghost" data-act="liveEdit">Cancel</button></p>`;
      $('narrate').querySelectorAll('button.act').forEach(b => (b.onclick = () => $(b.dataset.act).click()));
      return;
    }
    $('narrate').innerHTML = `<p>${html}</p>`;
  }

  function checkHtml(C, v) {
    const flag = (b, txt) => `<li class="${b ? 'bad' : 'ok'}">${txt}</li>`;
    const nodes = (C.nodes || []).map(n => `<li><b>${esc(n.id)}</b> — ${n.kind === 'contradiction' ? `<span class="bad">contradicts the spec</span>${n.passage ? `: <q>${esc(n.passage.replace(/\*\*/g, '').replace(/"[a-z_]+":/gi, ' ').replace(/["{},]+/g, ' ').replace(/\s+/g, ' ').trim())}</q>` : ''}` : '<span class="ok">an addition: the spec is silent</span>'}</li>`).join('');
    return `<h2>Consistency check</h2><ul class="checks">${flag(C.overlap, C.overlap ? `MET and NOT MET overlap — e.g. ${esc(C.overlap_case)}` : 'MET and NOT MET do not overlap')}${flag(C.gap, C.gap ? `A case falls between them — e.g. ${esc(C.gap_case)}` : 'No case falls between MET, NOT MET and UNCERTAIN')}</ul>${nodes ? `<h3>Nodes the spec does not state</h3><ul class="checks">${nodes}</ul>` : ''}<p class="muted small">Warnings only: the check never edits. It is strict — on the authors' own toy profiles it reports gaps for 5 of 8 rules and overlaps for 6 — so read a flag as something to look at, not a defect.</p>`;
  }

  function renderVerdict(R, S, k) {
    const box = $('verdict');
    if (S[k].kind === 'check' && R[state.scenario]) {
      const X = R[state.scenario], C = X.check || {};
      if (R.live) { box.innerHTML = X.check ? checkHtml(X.check, null) : '<h2>Consistency check</h2><p class="muted">Running…</p>'; return; }
      const flag = (b, txt) => `<li class="${b ? 'bad' : 'ok'}">${txt}</li>`;
      const nodes = (C.nodes || []).map(n => `<li><b>${esc(n.id)}</b> — ${n.kind === 'contradiction' ? `<span class="bad">contradicts the spec</span>${n.passage ? `: <q>${esc(n.passage.replace(/\*\*/g, '').replace(/"[a-z_]+":/gi, ' ').replace(/["{},]+/g, ' ').replace(/\s+/g, ' ').trim())}</q>` : ''}` : '<span class="ok">an addition: the spec is silent</span>'}</li>`).join('');
      const v = X.verdict;
      box.innerHTML = `<h2>Consistency check</h2><ul class="checks">${flag(C.overlap, C.overlap ? `MET and NOT MET overlap — e.g. ${esc(C.overlap_case)}` : 'MET and NOT MET do not overlap')}${flag(C.gap, C.gap ? `A case falls between them — e.g. ${esc(C.gap_case)}` : 'No case falls between MET, NOT MET and UNCERTAIN')}</ul>${nodes ? `<h3>Nodes the spec does not state</h3><ul class="checks">${nodes}</ul>` : ''}${v ? `<p class="muted small">The propagation judge on this profile: MET excludes the exception — ${v.met_excludes ? 'yes' : 'no'}; NOT MET covers it — ${v.not_met_covers ? 'yes' : 'no'}; overlap — ${v.overlap ? 'yes' : 'no'}.</p>` : ''}<p class="muted small">Warnings only: the check never edits. Across the eight rules' sentence edits it found no overlap; it flagged exceptions added to absolute “must not” rules as contradicting them, and a few cases the re-derived NOT MET does not cover.</p>`;
      return;
    }
    if (state.scenario === 'edit' && S[k].kind === 'verdict' && R.live) {
      const C = R.concepts_edited?.check;
      box.innerHTML = C ? checkHtml(C, null) : '<h2>Consistency check</h2><p class="muted">Running…</p>';
      return;
    }
    if (state.scenario !== 'edit' || S[k].kind !== 'verdict') { box.innerHTML = ''; return; }
    const mark = (v, good) => `<span class="${v === good ? 'ok' : 'bad'}">${v ? 'yes' : 'no'}</span>`;
    const nRules = D.rules.filter(r => !r.live).length;
    const row = (p, name) => { const v = (p === 'concepts' ? R.concepts_edited : R[p]).verdict, s = D.summary[p === 'flat' ? 'clean' : p] || D.summary[p === 'concepts' ? 'node' : p];
      return `<tr${p === state.program ? ' class="cur"' : ''}><th>${name}</th><td>${mark(!!v.met_excludes, true)}</td><td>${mark(!!v.not_met_covers, true)}</td><td>${mark(!!v.overlap, false)}</td><td class="muted small">${s ? `${s.not_met_covers}/${nRules} cover · ${s.overlap}/${nRules} overlap` : ''}</td><td class="small">${esc(v.why || '')}</td></tr>`; };
    box.innerHTML = `<h2>Did the edit travel, consistently?</h2><p class="muted small">The judge (Sol) read each program's edited profile for this rule. The totals are over the ${nRules} rules.</p>
      <table><tr><th></th><th>MET excludes the exception</th><th>NOT MET covers it</th><th>MET and NOT MET overlap</th><th>all ${nRules} rules</th><th>why (this rule)</th></tr>
      ${row('flat', 'Flat — edit MET only')}${R.chained ? row('chained', 'Chained — MET pinned') : ''}${row('concepts', 'Concept layer — node added')}</table>`;
  }

  // ---- render ------------------------------------------------------------------------------------------------------
  // Programs and scenarios the data has for this rule (a host page may record fewer than the toy page).
  function available(R) {
    const prog = { concepts: true, chained: !!R.chained, flat: !!R.flat };
    const scen = { base: true, edit: !!(R.concepts_edited || R.live), sentence: !!R.sentence || !!R.live, negation: !!R.negation };
    return { prog, scen };
  }

  function render() {
    const R0 = rule(), A = available(R0);
    if (!A.prog[state.program]) state.program = 'concepts';
    if (!A.scen[state.scenario]) state.scenario = 'base';
    for (const b of document.querySelectorAll('#program button')) { b.disabled = !A.prog[b.dataset.program]; b.title = b.disabled ? 'Not recorded for this rule' : ''; }
    for (const b of document.querySelectorAll('#scenario button')) { b.disabled = !A.scen[b.dataset.scenario]; }
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

  // Shared concepts across rules (when the data has a library): concepts by how many rules use them, members, and a
  // recorded edit to one concept re-derived across every rule that uses it.
  function renderLibrary() {
    const box = $('library'), Lb = D.library;
    if (!Lb || !Lb.concepts?.length) { box.innerHTML = ''; return; }
    const cs = [...Lb.concepts].sort((a, b) => new Set(b.members.map(m => m.rule)).size - new Set(a.members.map(m => m.rule)).size);
    const edits = Lb.edits || (Lb.edit ? { [Lb.edit.concept]: Lb.edit } : {});
    const sel = cs.find(c => c.id === state.concept) || cs.find(c => edits[c.id]) || cs[0];
    const E = edits[sel.id] || null;
    const rows = sel.members.map(m => {
      const x = E?.results?.[m.rule], rw = x && Object.values(x.rewrites || {})[0];
      // The re-derived text with the phrase the judge cited marked; the full diff (the whole part is re-sampled) behind a toggle.
      const okB = x && (x.before_ok ?? x.judge_before?.requires_red_flags_and_timeframe ?? x.judge_before?.reflects), okA = x && (x.after_ok ?? x.judge_after?.requires_red_flags_and_timeframe ?? x.judge_after?.reflects);
      const cited = x ? [...String(x.where ?? x.judge_after?.where ?? '').matchAll(/["“]([^"”]{12,})["”]/g)].map(q => q[1].replace(/[….]+$/, '').trim()) : [];
      const mark = t => { let h = esc(t); for (const c of cited) { const e = esc(c); const i = h.indexOf(e); if (i >= 0) h = h.slice(0, i) + `<mark>${e}</mark>` + h.slice(i + e.length); } return h; };
      const parts = x ? ['MET', 'NOT MET'].map(p => `<div class="lpart"><b>${p}</b> ${mark(x.after[p])}${x.before[p] !== x.after[p] ? `<details><summary>diff against before</summary>${diff(x.before[p], x.after[p])}</details>` : ''}</div>`).join('') : '';
      const rel = m.rel === 'part' ? ' <span class="chip" title="the node is compound and this concept is one of its components">one part of the node</span>' : m.rel === 'exact' ? ' <span class="chip" title="the node states this concept itself">states it</span>' : '';
      return `<div class="lmember"><div class="lhead"><b>${esc(m.rule)}</b> <span class="muted small">${esc(Lb.titles?.[m.rule] || '')}</span>${rel}${x ? ` <span class="chip ${okA ? 'changed' : ''}">${okB ? 'before ✓' : 'before ✗'} → ${okA ? 'after ✓' : 'after ✗'}</span>` : ''}</div>
        <div class="node ${esc(sel.kind === 'permission' ? 'permissions' : sel.kind === 'fact' ? 'facts' : sel.kind === 'condition' ? 'conditions' : 'action')}"><span class="id">${esc(m.node)}</span>${rw ? `<del>${esc(rw.old)}</del> <ins>${esc(rw.new)}</ins>` : esc(Lb.text?.[m.rule + '|' + m.node] || '')}</div>${parts}</div>`;
    }).join('');
    box.innerHTML = `<h2>Shared concepts across rules</h2>
      <p class="muted small">${esc(Lb.note || '')}</p>
      <label>Concept <select id="concept">${cs.map(c => `<option value="${esc(c.id)}"${c.id === sel.id ? ' selected' : ''}>${esc(c.name)} · ${new Set(c.members.map(m => m.rule)).size} rules${edits[c.id] ? ' · edited' : ''}</option>`).join('')}</select></label>
      <p><b>${esc(sel.name)}</b> <span class="muted">(${esc(sel.kind)})</span> — ${E ? `<del>${esc(E.old)}</del> <ins>${esc(E.new)}</ins>` : esc(sel.definition)}</p>
      ${E ? `<p class="small">${esc(E.note || '')}</p>` : ''}
      <div class="lmembers">${rows}</div>`;
    $('concept').onchange = e => { state.concept = e.target.value; renderLibrary(); };
  }

  // Patch forward (when the data has patches): an edit made to the model and patched into the authors' own prose —
  // each field as a word diff against the authored text, untouched fields marked, with the judge's verdict before and after.
  // The routing behind one patch, as the program's own graph: the rule model's groups, the fields that read them (grey),
  // the groups the edit changed and the routes to the fields that read them (accent), and which routed fields changed.
  const GROUPS = [['setting', 'testing setting'], ['action', 'behaviour judged'], ['conditions', 'conditions'], ['permissions', 'exceptions'], ['facts', 'facts']];
  const READS = { APPLICABILITY: ['setting'], 'DECISION BOUNDARY': ['action'], MET: ['action', 'conditions', 'permissions'], 'NOT MET': ['action', 'conditions', 'permissions'], UNCERTAIN: ['facts'] };
  function routeSvg(R) {
    if (!R.changed) return '';
    const fields = Object.keys(READS), rowH = 30, top = 22, W = 560, H = top + rowH * 5 + 4, lx = 8, lw = 150, rx = 330, rw = 170;
    const gy = i => top + i * rowH, ch = new Set(R.changed), route = new Set(R.route || []);
    const edges = fields.flatMap((f, fi) => READS[f].map(g => {
      const gi = GROUPS.findIndex(x => x[0] === g), hot = ch.has(g);
      return `<line class="${hot ? 'rt' : 'dep'}" x1="${lx + lw}" y1="${gy(gi) + 11}" x2="${rx}" y2="${gy(fi) + 11}"/>`;
    })).sort((x, y) => (x.includes('"rt"') ? 1 : 0) - (y.includes('"rt"') ? 1 : 0)).join('');
    const gnodes = GROUPS.map(([g, label], i) => `<g class="node${ch.has(g) ? ' hot' : ''}"><rect x="${lx}" y="${gy(i)}" width="${lw}" height="22" rx="4"/><text x="${lx + lw / 2}" y="${gy(i) + 15}">${esc(label)}</text></g>`).join('');
    const fnodes = fields.map((f, i) => { const changed = R.fields[f] && R.fields[f].before.trim() !== R.fields[f].after.trim();
      const cls = changed ? ' patched' : route.has(f) ? ' routed' : '';
      return `<g class="node${cls}"><rect x="${rx}" y="${gy(i)}" width="${rw}" height="22" rx="4"/><text x="${rx + rw / 2}" y="${gy(i) + 15}">${esc(f)}</text><text class="note" x="${rx + rw + 8}" y="${gy(i) + 15}">${changed ? 'patched' : route.has(f) ? 'routed, no change needed' : 'kept as written'}</text></g>`; }).join('');
    return `<figure class="routefig"><svg viewBox="0 0 ${W + 120} ${H}" role="img" aria-label="Which profile fields read the model groups this edit changed"><text class="hd" x="${lx + lw / 2}" y="13">rule model</text><text class="hd" x="${rx + rw / 2}" y="13">profile</text>${edges}${gnodes}${fnodes}</svg>
      <figcaption class="small muted">Changed: ${esc([...ch].map(g => (GROUPS.find(x => x[0] === g) || [g, g])[1]).join(', ') || 'nothing')}. Only the fields that read a changed group are routed to the patch; the rest are returned exactly as written.</figcaption></figure>`;
  }

  function renderPatches() {
    const box = $('patches'), Pt = D.patches;
    if (!box) return;
    if (!Pt || !Pt.sets || !Object.keys(Pt.sets).length) { box.innerHTML = ''; return; }
    const keys = Object.keys(Pt.sets);
    const sk = keys.includes(state.pset) ? state.pset : keys[0], S = Pt.sets[sk];
    const rids = Object.keys(S.rules);
    const rid = rids.includes(state.prule) ? state.prule : rids[0], R = S.rules[rid];
    const chip = (ok, label) => `<span class="chip ${ok ? 'changed' : ''}">${esc(label)} ${ok ? '✓' : '✗'}</span>`;
    const verdict = v => (S.checks || []).map(c => chip(c.bad ? !v?.[c.key] : !!v?.[c.key], c.label)).join(' ');
    const fields = Object.entries(R.fields).map(([l, f]) => f.before.trim() === f.after.trim()
      ? `<div class="pfield same"><div class="phead"><b>${esc(l)}</b> <span class="chip">unchanged</span></div><p>${esc(f.before)}</p></div>`
      : `<div class="pfield"><div class="phead"><b>${esc(l)}</b> <span class="chip changed">patched</span></div><p>${diff(f.before, f.after)}</p></div>`).join('');
    box.innerHTML = `<h2>Keeping the authors' prose: patch forward</h2>
      <p class="muted small">${esc(Pt.note || '')}</p>
      <div class="prow"><label>Edit <select id="pset">${keys.map(k => `<option value="${esc(k)}"${k === sk ? ' selected' : ''}>${esc(Pt.sets[k].label)}</option>`).join('')}</select></label>
        <label>Rule <select id="prule">${rids.map(r => `<option value="${esc(r)}"${r === rid ? ' selected' : ''}>${esc(r)}${S.rules[r].title ? ' · ' + esc(S.rules[r].title) : ''}</option>`).join('')}</select></label></div>
      <p class="small"><b>Edit:</b> ${esc(R.edit || S.edit || '')}</p>
      <p class="small">Authored ${verdict(R.before)} &nbsp;→&nbsp; patched ${verdict(R.after)}</p>
      ${S.note ? `<p class="small muted">${esc(S.note)}</p>` : ''}
      ${R.textmerge ? `<p class="small muted">${esc(R.textmerge)}</p>` : ''}
      ${R.collateral ? `<p class="pwarn small">Also moves an adjacent case — review before applying: ${esc(R.collateral)}</p>` : ''}
      ${(R.warnings || []).map(w => { const g = (GROUPS.find(x => x[0] === w.group) || [w.group, w.group])[1]; const where = Object.keys(READS).filter(f => READS[f].includes(w.group)).join(' or ');
        return `<p class="pwarn small">Not applied: the backward pass also read this edit as a change to the rule's ${esc(g)} (“${esc(w.text || '')}”). An edit to ${esc(R.part || 'this field')} can change only what that field reads; if the author means it, edit ${esc(where)}.</p>`; }).join('')}
      ${(R.sources || []).length ? `<p class="small">Model edits, each quoting the passage it rests on: ${R.sources.map(x => `<span class="chip">${esc((GROUPS.find(g => g[0] === x.group) || [x.group, x.group])[1])}</span> ${esc(x.text)} <span class="muted">— “${esc(x.source)}”</span>`).join('; ')}</p>` : ''}
      ${R.readback ? `<p class="small" title="${esc(Pt.readback_note || '')}"><b>Reads back as:</b> ${R.readback.recovered ? '<span class="chip changed">the intended edit ✓</span>' : '<span class="chip">not the intended edit ✗</span>'}${R.readback.recovered && R.readback.other ? ` <span class="muted">+${R.readback.other} other</span>` : ''} ${(R.readback.edits || []).map(x => `<span class="chip" title="${esc(R.readback.why || '')}">${esc((GROUPS.find(g => g[0] === x.group) || [x.group, x.group])[1])}</span> ${esc(x.text)}`).join('; ')}</p>` : ''}
      ${routeSvg(R)}
      <div class="pfields">${fields}</div>`;
    $('pset').onchange = e => { state.pset = e.target.value; state.prule = null; renderPatches(); };
    $('prule').onchange = e => { state.prule = e.target.value; renderPatches(); };
  }

  // Questions for the authors (when the data has them): cases the authored profile leaves open — two judges, each asked for a
  // single verdict under the profile as written, disagree — listed by rule with both readings.
  function renderQuestions() {
    const box = $('questions'), Q = D.questions;
    if (!box) return;
    if (!Q || !Q.items?.length) { box.innerHTML = ''; return; }
    const byRule = {};
    for (const q of Q.items) (byRule[q.rule] = byRule[q.rule] || []).push(q);
    const chip = (who, v) => `<span class="chip" title="${esc(v.why || '')}">${esc(who)}: ${esc(v.verdict)}</span>`;
    box.innerHTML = `<h2>Questions for the authors</h2><p class="muted small">${esc(Q.note || '')}</p>` +
      Object.entries(byRule).map(([rid, qs]) => `<div class="qrule"><b>${esc(rid)}</b> <span class="muted small">${esc(Q.titles?.[rid] || '')}</span>` +
        qs.map(q => `<div class="qitem"><span class="chip">${q.kind === 'gap' ? 'neither MET nor NOT MET?' : 'both MET and NOT MET?'}</span> ${esc(q.case)}<div class="qv">${chip(Q.judges?.[0] || 'judge 1', q.a)} ${chip(Q.judges?.[1] || 'judge 2', q.b)}</div>` +
          (q.answers || []).map(ans => `<details class="qans"><summary>If the authors answer ${esc(ans.answer)} — ${ans.settled ? 'both judges then agree' : 'not settled'}</summary><p class="small muted">The authors add “${esc(ans.sentence)}” to ${esc(ans.answer)}; the loop patches the fields that read what it changed.</p>${Object.entries(ans.fields).filter(([, f]) => f.before.trim() !== f.after.trim()).map(([l, f]) => `<div class="pfield"><div class="phead"><b>${esc(l)}</b></div><p>${diff(f.before, f.after)}</p></div>`).join('')}</details>`).join('') + `</div>`).join('') + '</div>').join('');
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
  renderLibrary();
  renderPatches();
  renderQuestions();
  window.EXPLAIN = {
    D, state, render, steps, rule, renderPatches,
    // Add or replace a rule entry (a live run) and show it in the given scenario.
    show(entry, scenario, step = 0) {
      const i = D.rules.findIndex(r => r.id === entry.id);
      if (i >= 0) D.rules[i] = entry; else D.rules.push(entry);
      $('rule').innerHTML = D.rules.map((r, j) => `<option value="${j}">${esc(r.id)} · ${esc(r.title)}</option>`).join('');
      state.rule = D.rules.findIndex(r => r.id === entry.id); state.program = 'concepts'; state.scenario = scenario; state.step = step;
      render();
    },
  };
  document.dispatchEvent(new Event('explain-ready'));
})();
