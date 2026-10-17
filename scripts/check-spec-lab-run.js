// Run-program tab against a mock OpenAI-compatible endpoint (no network, no key).
// Navigate an isolated playwright-cli session to /spec-lab/ first, then:
// playwright-cli -s=<session> run-code --filename=scripts/check-spec-lab-run.js
async page => {
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  let calls = 0, judged = 0, lens = 0, lensModels = new Set();
  await page.route('https://mock.nlir.test/v1/**', async route => {
    const url = route.request().url();
    if (url.endsWith('/models')) return route.fulfill({ json: { data: [{ id: 'gpt-6-luna' }, { id: 'gpt-6.1-sol' }] } });
    const body = JSON.parse(route.request().postData() || '{}');
    const prompt = body.messages.at(-1).content;
    // The lens's own requests: a backward patch, the tension check, the PutGet rating.
    if (prompt.includes('You are computing a BACKWARD pass')) {
      lens++; lensModels.add(body.model);
      return route.fulfill({ json: { choices: [{ message: { content: JSON.stringify({ edits: [{ input: 0, find: 'Approving over unresolved blocking feedback', replace: 'Approving over unresolved blocking review feedback' }], why: 'the edit names review feedback' }) } }] } });
    }
    if (prompt.includes('contradicts itself')) { lens++; lensModels.add(body.model); return route.fulfill({ json: { choices: [{ message: { content: '{"tensions": []}' } }] } }); }
    if (prompt.includes('The first <text> is a REFERENCE')) { lens++; lensModels.add(body.model); return route.fulfill({ json: { choices: [{ message: { content: '0.80' } }] } }); }
    if (prompt.includes('You compare a CANDIDATE paragraph')) {
      judged++;
      const n = (prompt.split('REFERENCE CLAUSES:\n')[1] || '').split('\n\nCANDIDATE:')[0].split('\n').filter(Boolean).length;
      const reference = Array.from({ length: n }, (_, i) => ({ n: i + 1, status: i % 2 ? 'weakened' : 'present', note: i % 2 ? 'a qualifier is dropped' : '' }));
      return route.fulfill({ json: { choices: [{ message: { content: JSON.stringify({ reference, candidate: [{ text: 'A statement.', status: 'supported' }, { text: 'An extra statement.', status: 'extra' }] }) } }] } });
    }
    calls++;
    const field = (prompt.split('FIELD:\n')[1] || 'text').split('.')[0];
    const packet = (prompt.split('RULE PACKET:\n')[1] || prompt).split('\n\nFIELD:')[0];
    const noPerm = !packet.includes('"permissions"');
    const sample = body.model === 'gpt-6-luna' ? '' : ' (other model)';
    return route.fulfill({ json: { choices: [{ message: { content: `Mock ${field} paragraph${noPerm ? ' without permissions' : ''}${sample}. Call ${calls}.` } }] } });
  });
  await page.evaluate(() => localStorage.removeItem('nlir.endpoint.v1'));
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.reload();
  await page.getByText('12/12 rules round-trip exactly', { exact: true }).waitFor();
  await page.locator('.rule[data-id="CR V 1.3"]').click();
  await page.locator('[data-view=run]').click();
  await page.locator('#runProgram').waitFor();
  if (!(await page.locator('#endpoint').getAttribute('open') !== null)) throw new Error('Endpoint settings should open when unset');
  if (!(await page.locator('#run').innerText()).includes('held-out rule')) throw new Error('Split label missing');
  // Run without an endpoint focuses the settings instead of calling anything.
  await page.locator('#runGo').click();
  if (calls) throw new Error('Called a model without an endpoint');
  await page.locator('#epBase').fill('https://mock.nlir.test/v1');
  await page.locator('#epBase').dispatchEvent('change');
  await page.locator('#epKey').fill('sk-test');
  await page.locator('#epKey').dispatchEvent('change');
  await page.locator('#epTest').click();
  await page.waitForFunction(() => document.querySelector('#epTestOut')?.textContent.includes('both listed'));
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('nlir.endpoint.v1')));
  if (saved.baseUrl !== 'https://mock.nlir.test/v1' || saved.apiKey !== 'sk-test' || saved.writer !== 'gpt-6-luna' || saved.judge !== 'gpt-6.1-sol') throw new Error('Endpoint not saved: ' + JSON.stringify(saved));
  // Run 1: learned B on the spec packet.
  await page.locator('#runGo').click();
  await page.waitForFunction(() => document.querySelectorAll('.run-card').length === 1 && !document.querySelector('.run-card .state'));
  const first = await page.locator('.run-card').first().innerText();
  if (!first.includes('5 model calls') || !first.includes('APPLICABILITY') && !first.includes('Applicability')) throw new Error('Run 1 incomplete: ' + first.slice(0, 300));
  const afterFirst = calls;
  // Same input, same seed: every call replays from the cache.
  await page.locator('#runGo').click();
  await page.waitForFunction(() => document.querySelectorAll('.run-card').length === 2 && !document.querySelector('.run-card .state'));
  if (calls !== afterFirst) throw new Error('Same-seed rerun called the model again');
  // New sample: next seed, fresh calls.
  await page.locator('#runResample').click();
  await page.waitForFunction(() => document.querySelectorAll('.run-card').length === 3 && !document.querySelector('.run-card .state'));
  if (calls !== afterFirst + 5) throw new Error('New sample should make five fresh calls, made ' + (calls - afterFirst));
  // Packet edit: remove permissions, seed 0.
  await page.locator('[data-perturb=permissions]').click();
  if (!(await page.locator('#runPacketState').innerText()).includes('permissions removed')) throw new Error('Packet change not described');
  await page.locator('#runGo').click();
  await page.waitForFunction(() => document.querySelectorAll('.run-card').length === 4 && !document.querySelector('.run-card .state'));
  const summary = await page.locator('#runSummary').innerText();
  if (!summary.includes('A fresh sample of the same input changes') || !summary.includes('permissions removed')) throw new Error('Noise/edit summary missing: ' + summary);
  if (!(await page.locator('.run-card').first().innerText()).includes('without permissions')) throw new Error('Packet edit did not reach the prompt');
  // Step through: reductions stream, then the output replays from the cache.
  await page.locator('#runPacketReset').click();
  const beforeStep = calls;
  await page.locator('#runStep').click();
  await page.waitForFunction(() => document.querySelectorAll('.run-card').length === 5 && !document.querySelector('.run-card .state'));
  const steps = await page.locator('#runSteps details').count();
  if (steps < 3) throw new Error('Too few streamed steps: ' + steps);
  if (calls !== beforeStep) throw new Error('Stepping the seed-0 spec packet should replay, made ' + (calls - beforeStep));
  // Judge run 1 with the strict clause judge.
  await page.locator('.run-card').last().locator('[data-judge]').click();
  await page.waitForFunction(() => document.querySelector('.run-card:last-child .run-judge .state.ok')?.textContent.includes('strict F1'));
  if (judged !== 5) throw new Error('Judge should make one call per part, made ' + judged);
  const table = await page.locator('.run-table').innerText();
  if (!/0\.\d\d/.test(table)) throw new Error('Strict F1 missing from the table');
  // Backward: edit run 1's output; the lens proposes a packet edit and re-runs.
  const card1 = page.locator('.run-card').last();
  await card1.locator('.run-back > summary').click();
  const edit = card1.locator('[data-back-edit]');
  await edit.fill((await edit.inputValue()).replace('Mock applicability paragraph', 'Mock applicability paragraph about review feedback'));
  await card1.locator('[data-put]').click();
  await page.waitForFunction(() => document.querySelector('.run-card:last-child .back-report') || document.querySelector('.run-card:last-child .run-back .err'), null, { timeout: 60000 });
  const back = await page.locator('.run-card').last().locator('.run-back').innerText();
  if (!/proposed input edits/i.test(back) || !back.includes('title') || !back.includes('review')) throw new Error('Backward report: ' + back.slice(0, 600));
  if ([...lensModels].some(m => m !== 'gpt-6.1-sol')) throw new Error('Lens calls must use the judge model: ' + [...lensModels]);
  if (!/similar in meaning|reproduces your text/.test(back)) throw new Error('PutGet result missing');
  await page.locator('.run-card').last().locator('[data-apply]').click();
  if (!(await page.locator('#runPacket').inputValue()).includes('blocking review feedback')) throw new Error('Apply did not edit the packet');
  if (!(await page.locator('#runPacketState').innerText()).includes('title edited')) throw new Error('Packet state not updated after apply');
  // Compare against another run.
  await page.locator('#runAgainst').selectOption('1');
  if (!(await page.locator('.run-card').first().innerText()).includes('changed vs run 1')) throw new Error('Compare selector ignored');
  // Narrow layout must not overflow.
  await page.setViewportSize({ width: 390, height: 844 });
  if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1)) throw new Error('Narrow overflow in Run tab');
  await page.setViewportSize({ width: 1440, height: 1000 });
  if (errors.length) throw new Error(errors.join('\n'));
  return { ok: true, modelCalls: calls, judgeCalls: judged, lensCalls: lens, steps, summary: summary.split('\n').slice(-1)[0] };
}
