// The explainer page (site/explain/) over its recorded passes: open /explain/ in an isolated
// playwright-cli session first, then: playwright-cli -s=<session> run-code --filename=scripts/check-explain.js
async page => {
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  const base = page.url().split('#')[0];
  const at = async h => { await page.goto('about:blank'); await page.goto(base + '#' + h); await page.waitForTimeout(1200); };
  // Forward pass, concept layer: before extraction there is no model; after it, nodes; the MET step lights MET and its nodes.
  await at('rule=CR+V+1.3&program=concepts&scenario=base&step=0');
  const before = await page.locator('#lane-model .node').count();
  await at('rule=CR+V+1.3&program=concepts&scenario=base&step=4');
  const nodes = await page.locator('#lane-model .node:not(.none)').count();
  const onNodes = await page.locator('#lane-model .node.on').count();
  const onPart = await page.locator('.part.on').evaluateAll(ps => ps.map(p => p.dataset.part));
  const segs = await page.locator('#call .prompt > *').count();
  const hits = await page.locator('.passage.hit').count();
  if (before !== 0 || nodes < 3 || onNodes < 2 || onPart.join() !== 'MET' || segs < 6) throw new Error(`forward: before=${before} nodes=${nodes} on=${onNodes} part=${onPart} segs=${segs}`);
  // Edit pass, concept layer: the added node is marked; at the verdict every part shows its state and the table has three programs.
  await at('rule=CR+V+1.3&program=concepts&scenario=edit&step=1');
  const added = await page.locator('#lane-model .node.added').count();
  await at('rule=CR+V+1.3&program=concepts&scenario=edit&step=7');
  const chips = await page.locator('.part .chip').count();
  const rows = await page.locator('.verdict table tr').count();
  if (added !== 1 || chips !== 5 || rows !== 4) throw new Error(`edit: added=${added} chips=${chips} rows=${rows}`);
  // Flat: no shared model; the edit stays in MET.
  await at('rule=CR+V+1.3&program=flat&scenario=edit&step=2');
  const flatEmpty = await page.locator('#lane-model .empty').count();
  const flatNotMet = await page.locator('.part[data-part="NOT MET"] .chip').innerText();
  if (flatEmpty !== 1 || flatNotMet !== 'unchanged') throw new Error(`flat: empty=${flatEmpty} notmet=${flatNotMet}`);
  // Stepping with the keyboard and every rule loading.
  await page.keyboard.press('ArrowLeft');
  const rules = await page.locator('#rule option').count();
  if (errors.length) throw new Error('page errors: ' + errors.join(' | '));
  return { ok: true, nodes, onNodes, segs, hits, added, chips, rules };
}
