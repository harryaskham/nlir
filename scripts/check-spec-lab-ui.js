// Navigate an isolated playwright-cli session to /spec-lab/ first, then:
// playwright-cli -s=<session> run-code --filename=scripts/check-spec-lab-ui.js
async page => {
  const errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  await page.setViewportSize({width:1440,height:1000});
  await page.reload();
  await page.getByText('12/12 rules round-trip exactly',{exact:true}).waitFor();
  await page.locator('[data-view=loop]').click();
  await page.waitForFunction(()=>document.querySelector('#lcap')?.textContent.includes('r03'));
  const b=await page.locator('.loop-head').innerText();
  if (!b.includes('0.36') || !b.includes('clause F1')) throw new Error('Wrong strict B metric');
  if (!await page.getByRole('heading',{name:'Learning profile programs'}).isVisible()) throw new Error('Dataset experiment shown as a single rule');
  await page.locator('#loopRuns [data-file="trace-strict-a.json"]').click();
  await page.waitForFunction(()=>document.querySelector('#lcap')?.textContent.includes('r04'));
  const a=await page.locator('.loop-head').innerText();
  if (!a.includes('0.31') || !a.includes('clause F1')) throw new Error('Wrong strict A metric');
  await page.locator('#loopRuns [data-file="trace-strict-b.json"]').click();
  await page.waitForFunction(()=>document.querySelector('#lcap')?.textContent.includes('r03'));
  // A slow earlier fetch must not overwrite the user's later experiment selection.
  await page.route('**/trace-strict-a.json',async route=>{await page.waitForTimeout(300);await route.continue();});
  await page.locator('#loopRuns [data-file="trace-strict-a.json"]').click();
  await page.locator('#loopRuns [data-file="trace.json"]').click();
  await page.waitForFunction(()=>document.querySelector('.loop-head')?.textContent.includes('holistic similarity'));
  await page.waitForTimeout(500);
  if (!await page.locator('#loopRuns [data-file="trace.json"][aria-pressed=true]').count()) throw new Error('Stale fetch replaced selected experiment');
  await page.unroute('**/trace-strict-a.json');
  await page.locator('#loopRuns [data-file="trace-strict-b.json"]').click();
  await page.waitForFunction(()=>document.querySelector('#lcap')?.textContent.includes('r03'));
  // Spec limits: the recorded counterexample test, per rule, with evidence on demand.
  // Clicking a tab during start-up must leave the clicked tab selected and its pane shown.
  await page.reload();
  await page.locator('[data-view=limits]').click();
  await page.getByText('12/12 rules round-trip exactly',{exact:true}).waitFor();
  await page.waitForTimeout(1200);
  const state=await page.evaluate(()=>({sel:document.querySelector('#view [aria-selected=true]')?.dataset.view,shown:['rule','policy','loop','back','limits'].filter(k=>!document.getElementById('pane-'+k).hidden)}));
  if (state.sel!=='limits' || state.shown.join()!=='limits') throw new Error('Tab and pane disagree after start-up: '+JSON.stringify(state));
  await page.locator('[data-view=limits]').click();
  await page.locator('ol.limits li').first().waitFor();
  const limits=await page.locator('#limits').innerText();
  if (!/clauses with a confirmed counterexample/.test(limits)) throw new Error('Spec limits summary missing');
  await page.locator('ol.limits details summary').first().click();
  if (!await page.locator('ol.limits details[open]').count()) throw new Error('Spec limits evidence did not open');
  await page.locator('.rule').nth(3).click();
  await page.waitForFunction(()=>!document.getElementById('pane-limits').hidden && document.querySelector('#limits .stat:nth-child(2) span')?.textContent.includes('CR V'));
  await page.locator('[data-view=loop]').click();
  await page.waitForFunction(()=>document.querySelector('#lcap')?.textContent.includes('r03'));
  await page.setViewportSize({width:390,height:844});
  await page.locator('#loopRuns').scrollIntoViewIfNeeded();
  if (await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)) throw new Error('Narrow document overflow');
  if (errors.length) throw new Error(errors.join('\n'));
  return {ok:true,strictA:a.split('\n')[0],strictB:b.split('\n')[0],staleResponseGuard:true,specLimits:limits.split('\n').slice(1,3).join(' '),browserErrors:0};
}
