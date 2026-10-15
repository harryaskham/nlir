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
  await page.setViewportSize({width:390,height:844});
  await page.locator('#loopRuns').scrollIntoViewIfNeeded();
  if (await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)) throw new Error('Narrow document overflow');
  if (errors.length) throw new Error(errors.join('\n'));
  return {ok:true,strictA:a.split('\n')[0],strictB:b.split('\n')[0],staleResponseGuard:true,browserErrors:0};
}
