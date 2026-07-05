#!/usr/bin/env bash
# Build the static nlir docs site from README.md + SPEC.md (bd-7d0ea0).
#
# Renders GitHub-flavoured markdown to a small self-contained HTML site with a
# shared nav + stylesheet, PLUS:
#   - copies showcase/*.png into the site so the README's image cards resolve;
#   - generates a showcase.html gallery of every card (+ a Showcase nav link);
#   - rewrites repo-relative links so the published Pages site never 404s
#     (SPEC.md -> spec.html, ./showcase -> showcase.html, source files -> the
#     GitHub blob URL).
# Used by .github/workflows/pages.yml to publish to GitHub Pages, and runnable
# locally: `scripts/build-docs.sh [OUT_DIR]` (default: ./site). Requires pandoc.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
out="${1:-$root/site}"
repo="https://github.com/harryaskham/nlir"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "build-docs: pandoc is required (apt-get install pandoc / nix)" >&2
  exit 1
fi

mkdir -p "$out"

cat > "$out/style.css" <<'CSS'
@import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;700&family=Fira+Sans:wght@400;500;600;700&display=swap');
:root {
  --fg:#efeaff; --body:#ded6f5; --muted:#b9a8e6; --dim:#8b7bbf;
  --violet:#c084fc; --violet-hi:#e879f9; --teal:#7dd3fc; --mint:#a7f3d0;
  --panel-border:rgba(168,85,247,.22); --code-bg:#100a24; --code-border:rgba(168,85,247,.32);
  --mono:'Fira Code',ui-monospace,SFMono-Regular,monospace; --sans:'Fira Sans','DejaVu Sans',system-ui,sans-serif;
}
* { box-sizing:border-box; }
html { scroll-behavior:smooth; }
body {
  margin:0; font-family:var(--sans); font-size:16px; line-height:1.65; color:var(--body);
  background-color:#160e2e;
  background-image:
    radial-gradient(1100px 640px at 12% 4%, rgba(168,85,247,.28), transparent 60%),
    radial-gradient(920px 620px at 96% 102%, rgba(34,211,238,.14), transparent 55%),
    linear-gradient(150deg,#140c28 0%,#1b1040 48%,#221052 100%);
  background-attachment:fixed; min-height:100vh;
}
#title-block-header { display:none; }
::selection { background:rgba(168,85,247,.4); color:#fff; }
/* nav */
nav { position:sticky; top:0; z-index:30; display:flex; align-items:center; gap:1.25rem;
  padding:.7rem 1.6rem; backdrop-filter:blur(14px); -webkit-backdrop-filter:blur(14px);
  background:rgba(18,10,38,.72); border-bottom:1px solid rgba(168,85,247,.18); }
nav .brand { font-family:var(--mono); font-weight:700; font-size:1.12rem; color:#fff; margin-right:auto; letter-spacing:-.5px; }
nav .brand:hover { text-decoration:none; }
nav .brand .dot { color:var(--violet); }
nav .brand .sub { font-family:var(--sans); font-weight:400; font-size:.78rem; color:var(--muted); margin-left:.55rem; }
nav a { color:var(--muted); text-decoration:none; font-weight:500; font-size:.92rem; transition:color .15s; }
nav a:hover { color:var(--teal); }
nav a.gh { color:var(--dim); }
/* hero */
.hero { max-width:66rem; margin:0 auto; padding:5rem 1.5rem 2.5rem; text-align:center; }
.hero .wordmark { font-family:var(--mono); font-weight:700; font-size:clamp(2.8rem,8vw,5rem); color:#fff; letter-spacing:-2px; line-height:1; text-shadow:0 6px 40px rgba(168,85,247,.45); }
.hero .wordmark .dot { color:var(--violet); }
.hero .wordmark .sub { display:block; font-family:var(--sans); font-weight:400; font-size:.9rem; letter-spacing:4px; text-transform:uppercase; color:var(--muted); margin-top:1rem; }
.hero .tag { font-size:clamp(1.05rem,2.3vw,1.35rem); color:var(--muted); max-width:40rem; margin:1.4rem auto 0; line-height:1.5; }
.hero .demo { display:inline-flex; align-items:center; gap:1rem; margin:2rem auto 0; flex-wrap:wrap; justify-content:center; }
.hero .demo code { font-family:var(--mono); background:var(--code-bg); border:1px solid var(--code-border); border-radius:12px; padding:.65rem 1.05rem; color:#efeaff; box-shadow:0 14px 40px rgba(0,0,0,.45); font-size:1rem; }
.hero .demo .o { color:var(--violet-hi); } .hero .demo .s { color:var(--teal); }
.hero .demo .arrow { color:var(--dim); font-family:var(--mono); }
.hero .demo .out { color:#fff; font-style:italic; }
.hero .cta { display:flex; gap:.85rem; justify-content:center; margin:2.3rem 0 0; flex-wrap:wrap; }
.hero .cta a { font-family:var(--mono); font-size:.92rem; text-decoration:none; padding:.68rem 1.35rem; border-radius:999px; transition:transform .15s, box-shadow .15s; }
.hero .cta a.primary { background:linear-gradient(135deg,#a855f7,#7c3aed); color:#fff; box-shadow:0 12px 32px rgba(124,58,237,.45); }
.hero .cta a.ghost { border:1px solid rgba(52,211,153,.4); color:var(--mint); background:rgba(16,185,129,.08); }
.hero .cta a:hover { transform:translateY(-2px); box-shadow:0 16px 40px rgba(124,58,237,.55); }
/* main */
main { max-width:52rem; margin:0 auto; padding:2.2rem 1.5rem 5rem; }
main.wide { max-width:76rem; }
h1,h2,h3,h4 { font-family:var(--sans); font-weight:700; line-height:1.25; color:#fff; }
h1 { font-size:2rem; letter-spacing:-.5px; }
h2 { font-size:1.5rem; margin-top:2.8rem; padding-bottom:.45rem; border-bottom:1px solid rgba(168,85,247,.2); }
h3 { font-size:1.18rem; color:var(--violet); margin-top:1.9rem; }
a { color:var(--teal); text-decoration:none; } a:hover { text-decoration:underline; }
p { color:var(--body); } strong { color:#fff; } em { color:var(--muted); }
ul,ol { color:var(--body); } li { margin:.25rem 0; }
hr { border:none; border-top:1px solid rgba(168,85,247,.18); margin:2.6rem 0; }
/* code */
code { font-family:var(--mono); font-size:.86em; background:rgba(168,85,247,.15); color:#f3ecff; padding:.13em .42em; border-radius:5px; }
pre { background:var(--code-bg); border:1px solid var(--code-border); border-radius:14px; padding:1.1rem 1.3rem; overflow:auto; box-shadow:0 16px 44px rgba(0,0,0,.42); }
pre code { background:none; padding:0; color:#efeaff; font-size:.9rem; line-height:1.5; }
/* tables — glassy panels */
table { border-collapse:separate; border-spacing:0; width:100%; margin:1.5rem 0; font-size:.92rem;
  border:1px solid var(--panel-border); border-radius:14px; overflow:hidden; box-shadow:0 12px 34px rgba(0,0,0,.3); }
th,td { padding:.62rem .9rem; text-align:left; vertical-align:top; border-bottom:1px solid rgba(168,85,247,.12); }
th { background:rgba(168,85,247,.16); color:#fff; font-family:var(--mono); font-weight:600; font-size:.84rem; }
tbody tr:last-child td { border-bottom:none; } tbody tr:hover { background:rgba(168,85,247,.06); }
td code, th code { background:rgba(125,211,252,.12); color:var(--teal); }
td img { border-radius:8px; }
/* blockquote */
blockquote { border-left:3px solid var(--violet); background:rgba(168,85,247,.08); margin:1.3rem 0; padding:.6rem 1.15rem; border-radius:0 10px 10px 0; color:var(--muted); }
blockquote p { color:var(--muted); }
/* images */
img { max-width:100%; height:auto; }
main > p > img { border:1px solid var(--panel-border); border-radius:16px; box-shadow:0 18px 50px rgba(0,0,0,.45); display:block; margin:1.6rem auto; }
/* gallery */
.gallery { display:grid; grid-template-columns:repeat(auto-fill,minmax(340px,1fr)); gap:1.5rem; margin:1.9rem 0; }
.gallery figure { margin:0; }
.gallery a { display:block; border-radius:16px; overflow:hidden; border:1px solid var(--panel-border);
  box-shadow:0 14px 38px rgba(0,0,0,.36); transition:transform .18s, box-shadow .18s, border-color .18s; }
.gallery a:hover { transform:translateY(-5px); box-shadow:0 26px 60px rgba(0,0,0,.5); border-color:rgba(192,132,252,.55); }
.gallery img { width:100%; display:block; }
.gallery figcaption { color:var(--muted); font-family:var(--mono); font-size:.85rem; margin-top:.55rem; text-transform:capitalize; text-align:center; }
.lead { font-size:1.1rem; color:var(--muted); max-width:44rem; }
/* footer */
footer { max-width:52rem; margin:0 auto; padding:2.4rem 1.5rem 3.5rem; color:var(--dim); font-size:.82rem; border-top:1px solid rgba(168,85,247,.14); }
footer a { color:var(--muted); }
CSS

cat > "$out/.head.html" <<'HTML'
<meta property="og:title" content="nlir — natural-language IR">
<meta property="og:description" content="Terse sigil shorthand in, fluent English out.">
<meta property="og:image" content="showcase/nlir-showreel.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="showcase/nlir-showreel.png">
HTML

cat > "$out/.nav.html" <<'HTML'
<nav>
  <a class="brand" href="index.html">nlir<span class="dot">·</span><span class="sub">natural-language IR</span></a>
  <a href="spec.html">SPEC</a>
  <a href="showcase.html">Showcase</a>
  <a class="gh" href="https://github.com/harryaskham/nlir">GitHub ↗</a>
</nav>
HTML

cat > "$out/.hero.html" <<'HTML'
<section class="hero">
  <div class="wordmark">nlir<span class="dot">·</span><span class="sub">natural-language IR</span></div>
  <p class="tag">Terse sigil shorthand in, fluent English out — a compressed language of thought for your prompt window.</p>
  <div class="demo">
    <code><span class="o">@</span><span class="s">'lmk if any Qs'</span></code>
    <span class="arrow">→</span>
    <span class="out">“Please let me know if you have any questions.”</span>
  </div>
  <div class="cta">
    <a class="primary" href="showcase.html">Explore the showcase →</a>
    <a class="ghost" href="spec.html">Read the SPEC</a>
    <a class="ghost" href="https://github.com/harryaskham/nlir">GitHub</a>
  </div>
</section>
HTML

cat > "$out/.mainopen.html" <<'HTML'
<main>
HTML

cat > "$out/.mainclose.html" <<'HTML'
</main>
HTML

cat > "$out/.foot.html" <<'HTML'
<footer>nlir · natural-language IR — a config-defined operator language. Site generated from README.md + SPEC.md + the showcase cards by <a href="https://github.com/harryaskham/nlir/blob/main/scripts/build-docs.sh">build-docs.sh</a>.</footer>
HTML

# --- workspace (nlir-wasm P2/P4): the in-browser playground. P7 (pages.yml) co-builds
# the wasm pkg/ + copies config.example.yaml into site/workspace/ BEFORE this runs; we copy
# the whole dir and surface it (nav link + hero "Try it live") ONLY when pkg/ is present, so
# the live site debuts the real evaluator, never the standalone mock. ---
if [ -d "$root/site/workspace" ]; then
  rm -rf "$out/workspace"
  cp -a "$root/site/workspace" "$out/workspace"
  if [ -d "$root/site/workspace/pkg" ]; then
    sed -i 's#<a href="showcase.html">Showcase</a>#<a href="workspace/">Workspace</a>\n  <a href="showcase.html">Showcase</a>#' "$out/.nav.html"
    sed -i 's#<div class="cta">#<div class="cta">\n    <a class="primary" href="workspace/">Try it live →</a>#' "$out/.hero.html"
    sed -i 's#<a class="primary" href="showcase.html">Explore the showcase →</a>#<a class="ghost" href="showcase.html">Explore the showcase</a>#' "$out/.hero.html"
  fi
fi

render() { # render <src.md> <title> <out.html> [hero:0|1]
  local hero=()
  [ "${4:-0}" = 1 ] && hero=(--include-before-body="$out/.hero.html")
  pandoc --from=gfm --to=html5 --standalone \
    --metadata title="$2" \
    --css style.css \
    --include-in-header="$out/.head.html" \
    --include-before-body="$out/.nav.html" \
    "${hero[@]}" \
    --include-before-body="$out/.mainopen.html" \
    --include-after-body="$out/.mainclose.html" \
    --include-after-body="$out/.foot.html" \
    --output "$3" "$1"
}

render "$root/README.md" "nlir — natural-language IR" "$out/index.html" 1
render "$root/SPEC.md"   "nlir — SPEC"                "$out/spec.html"  0

# Copy the showcase image cards into the site so the README's <img> refs resolve.
if [ -d "$root/showcase" ]; then
  rm -rf "$out/showcase"
  cp -a "$root/showcase" "$out/showcase"
fi

# Generate a gallery page for the full set of cards (linked from the README's
# "the full set lives in showcase/"), so that link resolves to a real page.
gen_gallery() {
  printf '%s\n' \
    '<!DOCTYPE html>' '<html lang="en"><head>' \
    '<meta charset="utf-8">' \
    '<meta name="viewport" content="width=device-width, initial-scale=1">' \
    '<title>nlir — showcase</title>' \
    '<link rel="stylesheet" href="style.css">'
  cat "$out/.head.html"
  printf '%s\n' '</head><body>'
  cat "$out/.nav.html"
  printf '%s\n' \
    '<main class="wide">' \
    '<h1>nlir showcase</h1>' \
    '<p class="lead">Terse shorthand in, fluent English out — the full set of expression-to-language cards. Deterministic outputs are exact; LLM outputs are real <code>claude-sonnet-5</code> captures. Click any card for the full-resolution PNG.</p>'
  if [ -f "$out/showcase/nlir-showreel.png" ]; then
    printf '%s\n' '<p><a href="showcase/nlir-showreel.png"><img src="showcase/nlir-showreel.png" alt="nlir showreel — a grid of expression-to-language cards"></a></p>'
  fi
  # helper: emit one <figure> for a card file (nlir-<name>.png), if it exists.
  emit_fig() {
    local base="$1" cap
    [ -e "$out/showcase/$base" ] || return 0
    cap="${base#nlir-}"; cap="${cap%.png}"; cap="${cap//-/ }"
    printf '<figure><a href="showcase/%s"><img src="showcase/%s" alt="%s" loading="lazy"></a><figcaption>%s</figcaption></figure>\n' \
      "$base" "$base" "$cap" "$cap"
  }
  # Featured: the language-of-thought MOVES (all four lanes), in curated order, so
  # visitors see the headline feature first instead of an alphabetical pile. New
  # cards teammates add fall into "All cards" below automatically (no maintenance).
  featured="considered-reply honest-yes reasoned-no counter-offer weighed-decision pitch-check brain-dump grounded-counter self-summarizing-memo full-layered-reply composer-reply empathetic-redirect weighed-recommendation catchup exec-brief two-sides handoff tone-knob perspective-wheel deliberation"
  printf '%s\n' '<h2>The language of thought — reusable moves</h2>' \
    '<p>The moves you can retype yourself: reply to an agent with your amendment, weigh a decision, dump a thought, pressure-test a pitch — a few sigils each. Full phrasebook in <a href="https://github.com/harryaskham/nlir/blob/main/examples/POWERMOVES.md">POWERMOVES.md</a>.</p>' \
    '<div class="gallery">'
  for name in $featured; do emit_fig "nlir-$name.png"; done
  printf '%s\n' '</div>'
  printf '%s\n' '<h2>All cards</h2>' '<div class="gallery">'
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
#   SPEC.md / README.md -> the generated html pages
#   ./showcase (the directory link) -> the gallery page
#   any other ./source-file link -> the GitHub blob URL (always resolvable)
# (Image <img src="showcase/…png"> use src=, not ./, so they are untouched.)
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

echo "build-docs: wrote $out/{index,spec,showcase}.html + style.css + showcase/ ($(ls "$out/showcase" 2>/dev/null | wc -l | tr -d ' ') assets)"
