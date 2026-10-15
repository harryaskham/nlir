// Pan and zoom for graph panes (v2 §G). Dependency-free: wheel zooms around the
// cursor, drag pans, double-click or "fit" resets, and +/−/0 work from the keyboard.
// `mount(container)` wraps whatever SVG the container holds; call `refit()` after
// replacing it.
export function panzoom(container) {
  container.classList.add('pz');
  container.tabIndex = 0;
  const bar = document.createElement('div');
  bar.className = 'pz-bar';
  bar.innerHTML = '<button type="button" data-z="in" aria-label="Zoom in">+</button><button type="button" data-z="out" aria-label="Zoom out">−</button><button type="button" data-z="fit" aria-label="Fit to pane">fit</button>';
  let s = 1, x = 0, y = 0, drag = null;
  const svg = () => container.querySelector('svg');
  const apply = () => { const g = svg(); if (g) g.style.transform = `translate(${x}px, ${y}px) scale(${s})`; };
  const zoomAt = (factor, cx, cy) => {
    const n = Math.min(8, Math.max(0.25, s * factor));
    x = cx - (cx - x) * (n / s); y = cy - (cy - y) * (n / s); s = n; apply();
  };
  const refit = () => {
    s = 1; x = 0; y = 0;
    const g = svg();
    if (g) { g.style.transformOrigin = '0 0'; g.style.cursor = 'grab'; }
    apply();
    if (!bar.isConnected) container.appendChild(bar);
  };
  container.addEventListener('wheel', e => {
    if (!svg()) return;
    e.preventDefault();
    const r = container.getBoundingClientRect();
    zoomAt(Math.exp(-e.deltaY * 0.0015), e.clientX - r.left, e.clientY - r.top);
  }, { passive: false });
  container.addEventListener('pointerdown', e => {
    if (e.target.closest('.pz-bar') || !svg()) return;
    drag = { px: e.clientX, py: e.clientY, x, y };
    container.setPointerCapture(e.pointerId);
    svg().style.cursor = 'grabbing';
  });
  container.addEventListener('pointermove', e => {
    if (!drag) return;
    x = drag.x + e.clientX - drag.px; y = drag.y + e.clientY - drag.py; apply();
  });
  const end = () => { drag = null; const g = svg(); if (g) g.style.cursor = 'grab'; };
  container.addEventListener('pointerup', end);
  container.addEventListener('pointercancel', end);
  container.addEventListener('dblclick', refit);
  bar.addEventListener('click', e => {
    const z = e.target.dataset && e.target.dataset.z;
    const r = container.getBoundingClientRect();
    if (z === 'in') zoomAt(1.25, r.width / 2, r.height / 2);
    else if (z === 'out') zoomAt(0.8, r.width / 2, r.height / 2);
    else if (z === 'fit') refit();
  });
  container.addEventListener('keydown', e => {
    const r = container.getBoundingClientRect();
    if (e.key === '+' || e.key === '=') zoomAt(1.25, r.width / 2, r.height / 2);
    else if (e.key === '-') zoomAt(0.8, r.width / 2, r.height / 2);
    else if (e.key === '0') refit();
    else return;
    e.preventDefault();
  });
  refit();
  return { refit };
}
