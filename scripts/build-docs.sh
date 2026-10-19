#!/usr/bin/env bash
# Build the static nlir docs site from README.md + SPEC.md (bd-7d0ea0).
#
# Renders GitHub-flavoured markdown to a small self-contained HTML site that
# shares site/theme.css (tokens + base) and site/docs.css (document layout) with
# the workspace and spec lab, PLUS:
#   - renders examples/README.md plus each example script into examples.html;
#   - copies site/workspace and site/spec-lab (the in-browser evaluator pages);
#   - rewrites repo-relative links so the published Pages site never 404s
#     (SPEC.md -> spec.html, source files -> the GitHub blob URL).
# Used by .github/workflows/pages.yml to publish to GitHub Pages, and runnable
# locally: `scripts/build-docs.sh [OUT_DIR]` (default: ./_site). Requires pandoc.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
out="${1:-$root/_site}"
repo="https://github.com/harryaskham/nlir"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "build-docs: pandoc is required (apt-get install pandoc / nix)" >&2
  exit 1
fi

mkdir -p "$out"
cp "$root/site/theme.css" "$out/theme.css"
cp "$root/site/docs.css" "$out/docs.css"
cp "$root/site/panzoom.js" "$out/panzoom.js"
rm -f "$out/style.css"

# The evaluator pages (wasm pkg co-built into site/workspace/pkg by pages.yml).
has_wasm=0
for page in workspace spec-lab explain; do
  if [ -d "$root/site/$page" ] && ! [ "$out/$page" -ef "$root/site/$page" ]; then
    rm -rf "$out/$page"
    cp -a "$root/site/$page" "$out/$page"
  fi
done
[ -d "$root/site/workspace/pkg" ] && has_wasm=1

cat > "$out/.head.html" <<'HTML'
<meta name="a.skh.am:made" content="agents">
<meta name="color-scheme" content="light dark">
<meta property="og:title" content="nlir — natural-language IR">
<meta property="og:description" content="A small language for programs over data and meaning: exact structure and model-realised semantics in one evaluator — forwards and backwards.">
<meta property="og:image" content="og.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="og.png">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='7' fill='%23121418'/%3E%3Ctext x='16' y='22' font-family='monospace' font-size='15' font-weight='700' fill='%235cc6a8' text-anchor='middle'%3En·%3C/text%3E%3C/svg%3E">
HTML

# nav <current-page>: one bar for every page, the current link marked.
nav() {
  local cur="$1" link
  printf '<header class="bar"><a class="mark" href="index.html">nlir<i>·</i><small>natural-language IR</small></a>\n'
  for link in "index.html|Guide" "spec.html|Spec" "workspace/|Workspace" "spec-lab/|Spec lab" "explain/|Explain" "examples.html|Examples"; do
    local href="${link%%|*}" label="${link#*|}"
    case "$href" in workspace/|spec-lab/) [ "$has_wasm" = 1 ] || continue;; esac
    if [ "$href" = "$cur" ]; then
      printf '<a class="nav" href="%s" aria-current="page">%s</a>\n' "$href" "$label"
    else
      printf '<a class="nav" href="%s">%s</a>\n' "$href" "$label"
    fi
  done
  printf '<a class="nav hide-sm" href="%s">GitHub ↗</a></header>\n' "$repo"
}

if [ "$has_wasm" = 1 ] && [ -f "$root/site/hero-live.html" ]; then
  cp "$root/site/hero-live.html" "$out/.hero.html"
else
  cat > "$out/.hero.html" <<'HTML'
<section class="hero">
  <div>
    <h1>Shorthand in.<br><em>Prose</em> out.</h1>
    <p class="lede">A small language for programs over data and meaning: exact structure and model-realised semantics in one evaluator.</p>
    <div class="actions"><a class="btn primary" href="spec.html">Read the spec</a><a class="btn" href="examples.html">Examples</a></div>
  </div>
  <div class="console live"><div class="row"><input value="'lmk if any Qs' :: formal" readonly aria-label="nlir expression"></div>
  <div class="out"><div class="prose-out"><span class="arrow">→</span><span>Please let me know if you have any questions.</span></div></div></div>
</section>
HTML
fi

cat > "$out/.foot.html" <<HTML
<footer class="foot"><span>nlir · a config-defined operator language. Generated from README.md and SPEC.md.</span><span><a href="$repo">github.com/harryaskham/nlir</a></span></footer>
<div class="skh-made-wrap" style="display:flex;justify-content:flex-start;box-sizing:border-box;width:100%;max-width:1180px;margin:0 auto 22px;padding:0 24px"><a class="skh-made" data-made="agents" href="https://a.skh.am/made/" title="Made by agents: built by AI agents from specs and configuration, with light human steering" style="display:inline-block;margin:0;padding:0;border:0;background:none;line-height:0;text-decoration:none;vertical-align:middle"><svg role="img" aria-label="Made by agents" viewBox="0 0 120 120" width="112" height="112" style="display:block;width:112px;height:112px;max-width:none;margin:0;overflow:visible"><defs><linearGradient id="skh-seal-agents-foil" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e4f6fa"/><stop offset=".45" stop-color="#86c2d4"/><stop offset=".7" stop-color="#e4f6fa"/><stop offset="1" stop-color="#2a6a80"/></linearGradient><radialGradient id="skh-seal-agents-disk" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="#e4f6fa"/><stop offset=".6" stop-color="#86c2d4"/><stop offset="1" stop-color="#2a6a80"/></radialGradient><polygon id="skh-seal-agents-edge" points="60.0,2.0 64.6,7.0 70.1,2.9 73.8,8.6 79.8,5.5 82.5,11.8 89.0,9.8 90.5,16.4 97.3,15.6 97.6,22.4 104.4,22.7 103.6,29.5 110.2,31.0 108.2,37.5 114.5,40.2 111.4,46.2 117.1,49.9 113.0,55.4 118.0,60.0 113.0,64.6 117.1,70.1 111.4,73.8 114.5,79.8 108.2,82.5 110.2,89.0 103.6,90.5 104.4,97.3 97.6,97.6 97.3,104.4 90.5,103.6 89.0,110.2 82.5,108.2 79.8,114.5 73.8,111.4 70.1,117.1 64.6,113.0 60.0,118.0 55.4,113.0 49.9,117.1 46.2,111.4 40.2,114.5 37.5,108.2 31.0,110.2 29.5,103.6 22.7,104.4 22.4,97.6 15.6,97.3 16.4,90.5 9.8,89.0 11.8,82.5 5.5,79.8 8.6,73.8 2.9,70.1 7.0,64.6 2.0,60.0 7.0,55.4 2.9,49.9 8.6,46.2 5.5,40.2 11.8,37.5 9.8,31.0 16.4,29.5 15.6,22.7 22.4,22.4 22.7,15.6 29.5,16.4 31.0,9.8 37.5,11.8 40.2,5.5 46.2,8.6 49.9,2.9 55.4,7.0"/></defs><use href="#skh-seal-agents-edge" transform="translate(1.6 2.4)" style="fill:#000;fill-opacity:.32"/><use href="#skh-seal-agents-edge" style="fill:url(#skh-seal-agents-foil);stroke:#2a6a80;stroke-width:.8"/><circle cx="60" cy="60" r="49.5" style="fill:url(#skh-seal-agents-disk);stroke:#2a6a80;stroke-width:1.4"/><circle cx="60" cy="60" r="48" style="fill:none;stroke:#fff;stroke-opacity:.5;stroke-width:.8"/><circle cx="60" cy="60" r="34.5" style="fill:none;stroke:#2a6a80;stroke-width:1"/><circle cx="60" cy="60" r="33.4" style="fill:none;stroke:#fff;stroke-opacity:.45;stroke-width:.6"/><path id="skh-seal-agents-top" d="M 19.5 60 A 40.5 40.5 0 0 1 100.5 60" style="fill:none;stroke:none"/><text style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:8.6px;letter-spacing:1.4px;fill:#fff;fill-opacity:.55" transform="translate(0 .7)"><textPath href="#skh-seal-agents-top" startOffset="50%" text-anchor="middle">OFFICIAL · A.SKH.AM</textPath></text><text style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:8.6px;letter-spacing:1.4px;fill:#0b3240"><textPath href="#skh-seal-agents-top" startOffset="50%" text-anchor="middle">OFFICIAL · A.SKH.AM</textPath></text><path id="skh-seal-agents-bot" d="M 14.6 60 A 45.4 45.4 0 0 0 105.4 60" style="fill:none;stroke:none"/><text style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:8.6px;letter-spacing:1.4px;fill:#fff;fill-opacity:.55" transform="translate(0 .7)"><textPath href="#skh-seal-agents-bot" startOffset="50%" text-anchor="middle">SEAL OF ORIGIN</textPath></text><text style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:8.6px;letter-spacing:1.4px;fill:#0b3240"><textPath href="#skh-seal-agents-bot" startOffset="50%" text-anchor="middle">SEAL OF ORIGIN</textPath></text><polygon points="17.2,57.5 18.0,59.5 20.1,59.6 18.4,61.0 19.0,63.1 17.2,61.9 15.4,63.1 16.0,61.0 14.3,59.6 16.4,59.5" style="fill:#0b3240"/><polygon points="102.8,57.5 103.6,59.5 105.7,59.6 104.0,61.0 104.6,63.1 102.8,61.9 101.0,63.1 101.6,61.0 99.9,59.6 102.0,59.5" style="fill:#0b3240"/><text x="60" y="55.7" text-anchor="middle" style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:8.4px;letter-spacing:1px;fill:#fff;fill-opacity:.55" >MADE BY</text><text x="60" y="55" text-anchor="middle" style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:8.4px;letter-spacing:1px;fill:#0b3240" >MADE BY</text><text x="60" y="73.7" text-anchor="middle" style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:13.6px;letter-spacing:0.4px;fill:#fff;fill-opacity:.55" >AGENTS</text><text x="60" y="73" text-anchor="middle" style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;font-weight:800;font-size:13.6px;letter-spacing:0.4px;fill:#0b3240" >AGENTS</text><ellipse cx="46" cy="40" rx="26" ry="14" transform="rotate(-28 46 40)" style="fill:#fff;fill-opacity:.16"/></svg></a></div>
<script>
// TOC scroll-spy: mark the section currently in view.
(() => {
  const links = [...document.querySelectorAll('#TOC a')];
  if (!links.length) return;
  const byId = new Map(links.map(a => [decodeURIComponent(a.hash.slice(1)), a]));
  const io = new IntersectionObserver(es => {
    for (const e of es) if (e.isIntersecting) {
      links.forEach(a => a.classList.remove('on'));
      const a = byId.get(e.target.id); if (a) a.classList.add('on');
    }
  }, { rootMargin: '-15% 0px -75% 0px' });
  document.querySelectorAll('main.doc h2[id], main.doc h3[id]').forEach(h => byId.has(h.id) && io.observe(h));
})();
</script>
HTML

render() { # render <src.md> <title> <out.html> <page-href> [hero:0|1]
  local hero=() cls="doc"
  nav "$4" > "$out/.nav.html"
  if [ "${5:-0}" = 1 ]; then hero=(--include-before-body="$out/.hero.html"); cls="doc index"; fi
  printf '<main class="%s">\n' "$cls" > "$out/.mainopen.html"
  printf '</main>\n' > "$out/.mainclose.html"
  pandoc --from=gfm --to=html5 --standalone \
    --toc --toc-depth=2 \
    --metadata pagetitle="$2" \
    --css theme.css --css docs.css \
    --include-in-header="$out/.head.html" \
    --include-before-body="$out/.nav.html" \
    "${hero[@]}" \
    --include-before-body="$out/.mainopen.html" \
    --include-after-body="$out/.mainclose.html" \
    --include-after-body="$out/.foot.html" \
    --output "$3" "$1"
}

render "$root/README.md" "nlir — natural-language IR" "$out/index.html" "index.html" 1
render "$root/SPEC.md"   "nlir — spec"                "$out/spec.html"  "spec.html"  0

# Examples: the canonical v2 programs (examples/README.md) with each script inlined.
cp "$root/site/og.png" "$out/og.png"
{
  sed 's#(\([a-z-]*\.sh\))#(\#\1)#g' "$root/examples/README.md"
  for script in "$root"/examples/*.sh; do
    name="$(basename "$script")"
    printf '\n## %s {#%s}\n\n```sh\n' "$name" "$name"
    cat "$script"
    printf '```\n'
  done
} > "$out/.examples.md"
render "$out/.examples.md" "nlir — examples" "$out/examples.html" "examples.html" 0
rm -f "$out/.examples.md" "$out/showcase.html"
rm -rf "$out/showcase"

# Link hygiene: rewrite repo-relative links so the published site doesn't 404.
for f in "$out/index.html" "$out/spec.html" "$out/examples.html"; do
  sed -i \
    -e 's#href="\./SPEC\.md"#href="spec.html"#g' \
    -e 's#href="SPEC\.md"#href="spec.html"#g' \
    -e 's#href="\.\./SPEC\.md#href="spec.html#g' \
    -e "s#href=\"\.\./#href=\"$repo/blob/main/#g" \
    -e 's#href="\./README\.md"#href="index.html"#g' \
    -e 's#href="README\.md"#href="index.html"#g' \
    -e "s#href=\"\./#href=\"$repo/blob/main/#g" \
    -E -e "s#href=\"((examples|docs|src|scripts|crates|test|extensions)/[^\"]*)\"#href=\"$repo/blob/main/\\1\"#g" \
    -E -e "s#href=\"([A-Za-z0-9_.-]+\\.(yaml|yml|toml|nix|json))\"#href=\"$repo/blob/main/\\1\"#g" \
    "$f"
done

# GitHub Pages: skip Jekyll so underscore-prefixed assets are served verbatim.
touch "$out/.nojekyll"
rm -f "$out/.nav.html" "$out/.foot.html" "$out/.head.html" "$out/.hero.html" "$out/.mainopen.html" "$out/.mainclose.html"

echo "build-docs: wrote $out/{index,spec,examples}.html + theme.css/docs.css + og.png"
