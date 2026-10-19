// Live mode of the explainer against a mock OpenAI-compatible endpoint (no network, no key): run the
// concept layer forward, push a sentence edit back, re-derive and check. Open /explain/ in an isolated
// playwright-cli session first, then: playwright-cli -s=<session> run-code --filename=scripts/check-explain-live.js
async page => {
  const errors = [], calls = { model: 0, part: 0, back: 0, check: 0 };
  page.on('pageerror', e => errors.push(String(e)));
  const MODEL = { action: 'approving a change', conditions: [{ id: 'c1', text: 'Blocking feedback remains unresolved.', source: 'blocking feedback' }], permissions: [], facts: [{ id: 'f1', text: 'Whether the feedback was resolved.', decides: ['c1'] }] };
  await page.route('https://mock.nlir.test/v1/**', async route => {
    const body = JSON.parse(route.request().postData() || '{}');
    const prompt = body.messages.at(-1).content;
    const reply = c => route.fulfill({ json: { choices: [{ message: { content: c } }] } });
    if (prompt.includes('You are computing a BACKWARD pass through a rule model')) { calls.back++; return reply(JSON.stringify({ edits: [{ op: 'add', group: 'permissions', text: 'The on-call lead approves an urgent security patch.', source: '' }], why: 'the edit adds an exception' })); }
    if (prompt.includes('You check an evaluation profile and the rule model')) { calls.check++; return reply(JSON.stringify({ overlap: false, overlap_case: '', gap: false, gap_case: '', nodes: [{ id: 'p1', kind: 'addition', passage: '' }] })); }
    if (prompt.includes('rule model. Instead of a paragraph')) { calls.model++; return reply(JSON.stringify(MODEL)); }
    calls.part++;
    const field = (prompt.split('FIELD:\n')[1] || 'part').split('.')[0];
    const pinned = prompt.includes('urgent security patch') ? ' except an urgent security patch' : '';
    return reply(`Mock ${field} paragraph${pinned}.`);
  });
  const base = page.url().split('#')[0];
  await page.goto('about:blank');
  await page.goto(base + '#rule=CR+V+1.3&program=concepts&scenario=base&step=0');
  await page.waitForTimeout(1200);
  await page.locator('#live').evaluate(d => { d.open = true; });
  for (const [id, v] of [['#liveBase', 'https://mock.nlir.test/v1'], ['#liveWriter', 'gpt-6-luna'], ['#liveJudge', 'gpt-6.1-sol']]) { await page.fill(id, v); await page.locator(id).dispatchEvent('input'); }
  await page.locator('#liveRun').click();
  await page.waitForFunction(() => /^Done|Cannot|failed|JSON/.test(document.querySelector('#liveStatus').textContent), null, { timeout: 60000 });
  const st1 = await page.locator('#liveStatus').innerText();
  await page.locator('#next').click();
  await page.waitForTimeout(300);
  const nodes = await page.locator('#lane-model .node:not(.none)').count();
  if (!/^Done/.test(st1) || calls.model !== 1 || calls.part !== 5 || nodes !== 3) throw new Error(`forward: ${st1} calls=${JSON.stringify(calls)} nodes=${nodes}`);
  await page.fill('#liveSentence', 'Mock MET paragraph, unless the on-call lead approves an urgent security patch.');
  await page.locator('#livePush').click();
  await page.waitForFunction(() => /^Pushed|Cannot|failed|JSON|Edit the/.test(document.querySelector('#liveStatus').textContent), null, { timeout: 60000 });
  const st2 = await page.locator('#liveStatus').innerText();
  const checks = await page.locator('.verdict ul.checks li').count();
  const addition = (await page.locator('.verdict').innerText()).includes('an addition');
  await page.goto(page.url().replace(/step=\d+/, 'step=1'));
  await page.waitForTimeout(600);
  const added = await page.locator('#lane-model .node.added').count();
  if (!/^Pushed/.test(st2) || calls.back !== 1 || calls.check !== 1 || calls.part !== 10 || checks < 3 || !addition || added !== 1) throw new Error(`push: ${st2} calls=${JSON.stringify(calls)} checks=${checks} addition=${addition} added=${added}`);
  if (errors.length) throw new Error('page errors: ' + errors.join(' | '));
  return { ok: true, calls, nodes, checks, added };
}
