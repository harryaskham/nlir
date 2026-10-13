#!/usr/bin/env bash
# Build the static nlir docs site from README.md + SPEC.md (bd-7d0ea0).
#
# Renders GitHub-flavoured markdown to a small self-contained HTML site that
# shares site/theme.css (tokens + base) and site/docs.css (document layout) with
# the workspace and spec lab, PLUS:
#   - copies showcase/*.png into the site so the README's image cards resolve;
#   - generates a showcase.html gallery of every card;
#   - copies site/workspace and site/spec-lab (the in-browser evaluator pages);
#   - rewrites repo-relative links so the published Pages site never 404s
#     (SPEC.md -> spec.html, ./showcase -> showcase.html, source files -> the
#     GitHub blob URL).
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
rm -f "$out/style.css"

# The evaluator pages (wasm pkg co-built into site/workspace/pkg by pages.yml).
has_wasm=0
for page in workspace spec-lab; do
  if [ -d "$root/site/$page" ] && ! [ "$out/$page" -ef "$root/site/$page" ]; then
    rm -rf "$out/$page"
    cp -a "$root/site/$page" "$out/$page"
  fi
done
[ -d "$root/site/workspace/pkg" ] && has_wasm=1

cat > "$out/.head.html" <<'HTML'
<meta name="color-scheme" content="light dark">
<meta property="og:title" content="nlir — natural-language IR">
<meta property="og:description" content="Shorthand in, prose out: a small language that mixes exact data operations with model-backed text operators.">
<meta property="og:image" content="showcase/nlir-showreel.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="showcase/nlir-showreel.png">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='7' fill='%23121418'/%3E%3Ctext x='16' y='22' font-family='monospace' font-size='15' font-weight='700' fill='%235cc6a8' text-anchor='middle'%3En·%3C/text%3E%3C/svg%3E">
HTML

# nav <current-page>: one bar for every page, the current link marked.
nav() {
  local cur="$1" link
  printf '<header class="bar"><a class="mark" href="index.html">nlir<i>·</i><small>natural-language IR</small></a>\n'
  for link in "index.html|Guide" "spec.html|Spec" "workspace/|Workspace" "spec-lab/|Spec lab" "showcase.html|Showcase"; do
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
    <p class="lede">A small language for the prompt window: exact data operations and model-backed text operators in one evaluator.</p>
    <div class="actions"><a class="btn primary" href="spec.html">Read the spec</a><a class="btn" href="showcase.html">Showcase</a></div>
  </div>
  <div class="console live"><div class="row"><input value="@'lmk if any Qs'" readonly aria-label="nlir expression"></div>
  <div class="out"><div class="prose-out"><span class="arrow">→</span><span>Please let me know if you have any questions.</span></div></div></div>
</section>
HTML
fi

cat > "$out/.foot.html" <<HTML
<footer class="foot"><span>nlir · a config-defined operator language. Generated from README.md and SPEC.md.</span><span><a href="$repo">github.com/harryaskham/nlir</a></span></footer>
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

# Showcase cards: copy so README image links + the gallery resolve on Pages.
if [ -d "$root/showcase" ]; then
  rm -rf "$out/showcase"
  cp -a "$root/showcase" "$out/showcase"
fi

gen_gallery() {
  printf '%s\n' '<!DOCTYPE html>' '<html lang="en"><head>' \
    '<meta charset="utf-8">' \
    '<meta name="viewport" content="width=device-width, initial-scale=1">' \
    '<title>nlir — showcase</title>' \
    '<link rel="stylesheet" href="theme.css"><link rel="stylesheet" href="docs.css">'
  cat "$out/.head.html"
  printf '%s\n' '</head><body>'
  nav "showcase.html"
  printf '%s\n' \
    '<main class="wide">' \
    '<h1>Showcase</h1>' \
    '<p class="lead">Expressions and the prose they become. Deterministic outputs are exact; model outputs are real captures.</p>'
  if [ -f "$out/showcase/nlir-showreel.png" ]; then
    printf '%s\n' '<p><a href="showcase/nlir-showreel.png"><img src="showcase/nlir-showreel.png" alt="nlir showreel — a grid of expression-to-language cards"></a></p>'
  fi
  emit_fig() {
    local base="$1" cap
    [ -e "$out/showcase/$base" ] || return 0
    cap="${base#nlir-}"; cap="${cap%.png}"; cap="${cap//-/ }"
    printf '<figure><a href="showcase/%s"><img src="showcase/%s" alt="%s" loading="lazy"></a><figcaption>%s</figcaption></figure>\n' \
      "$base" "$base" "$cap" "$cap"
  }
  # Featured: the language-of-thought moves, in curated order; every other card
  # follows under "All cards" automatically.
  featured="considered-reply honest-yes reasoned-no counter-offer weighed-decision pitch-check brain-dump grounded-counter self-summarizing-memo full-layered-reply composer-reply empathetic-redirect weighed-recommendation catchup exec-brief two-sides handoff tone-knob perspective-wheel deliberation"
  printf '%s\n' '<h2>Reusable moves</h2>' '<div class="gallery">'
  for name in $featured; do emit_fig "nlir-$name.png"; done
  printf '%s\n' '</div>' '<h2>All cards</h2>' '<div class="gallery">'
  if [ -d "$out/showcase" ]; then
    for png in "$out"/showcase/*.png; do
      [ -e "$png" ] || continue
      base="$(basename "$png")"
      [ "$base" = "nlir-showreel.png" ] && continue
      nm="${base#nlir-}"; nm="${nm%.png}"
      case " $featured " in *" $nm "*) continue;; esac
      emit_fig "$base"
    done
  fi
  printf '%s\n' '</div>' '</main>'
  cat "$out/.foot.html"
  printf '%s\n' '</body></html>'
}
gen_gallery > "$out/showcase.html"

# Link hygiene: rewrite repo-relative links so the published site doesn't 404.
for f in "$out/index.html" "$out/spec.html"; do
  sed -i \
    -e 's#href="\./SPEC\.md"#href="spec.html"#g' \
    -e 's#href="SPEC\.md"#href="spec.html"#g' \
    -e 's#href="\./README\.md"#href="index.html"#g' \
    -e 's#href="README\.md"#href="index.html"#g' \
    -e 's#href="\./showcase"#href="showcase.html"#g' \
    -e "s#href=\"\./#href=\"$repo/blob/main/#g" \
    "$f"
done

# GitHub Pages: skip Jekyll so underscore-prefixed assets are served verbatim.
touch "$out/.nojekyll"
rm -f "$out/.nav.html" "$out/.foot.html" "$out/.head.html" "$out/.hero.html" "$out/.mainopen.html" "$out/.mainclose.html"

echo "build-docs: wrote $out/{index,spec,showcase}.html + theme.css/docs.css + showcase/ ($(ls "$out/showcase" 2>/dev/null | wc -l | tr -d ' ') assets)"
