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
:root { --fg:#1a1a1a; --muted:#666; --bg:#fdfdfd; --accent:#7a3cff; --code:#f4f2fb; }
* { box-sizing: border-box; }
body { margin:0; font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,sans-serif; color:var(--fg); background:var(--bg); }
nav { position:sticky; top:0; background:var(--bg); border-bottom:1px solid #eee; padding:.75rem 1.25rem; z-index:10; }
nav a { color:var(--accent); text-decoration:none; margin-right:1.1rem; font-weight:600; }
nav a:hover { text-decoration:underline; }
main { max-width:52rem; margin:0 auto; padding:2rem 1.25rem 4rem; }
main.wide { max-width:72rem; }
h1,h2,h3 { line-height:1.25; }
h2 { margin-top:2.2rem; border-bottom:1px solid #eee; padding-bottom:.3rem; }
a { color:var(--accent); }
img { max-width:100%; height:auto; }
main > p > img, .hero img { border:1px solid #eee; border-radius:10px; display:block; }
pre { background:var(--code); padding:1rem; border-radius:8px; overflow:auto; }
code { background:var(--code); padding:.1em .35em; border-radius:4px; font-size:.9em; }
pre code { background:none; padding:0; }
table { border-collapse:collapse; margin:1rem 0; }
th,td { border:1px solid #ddd; padding:.4rem .7rem; text-align:left; vertical-align:top; }
td img { border:1px solid #eee; border-radius:6px; }
blockquote { color:var(--muted); border-left:3px solid #ddd; margin:1rem 0; padding:.2rem 1rem; }
footer { color:var(--muted); font-size:.85rem; border-top:1px solid #eee; margin-top:3rem; padding-top:1rem; }
.gallery { display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:1.2rem; margin:1.5rem 0; }
.gallery figure { margin:0; }
.gallery img { width:100%; border:1px solid #eee; border-radius:8px; display:block; }
.gallery figcaption { color:var(--muted); font-size:.9rem; margin-top:.4rem; text-transform:capitalize; }
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
  <a href="index.html">nlir</a>
  <a href="spec.html">SPEC</a>
  <a href="showcase.html">Showcase</a>
  <a href="https://github.com/harryaskham/nlir">GitHub</a>
</nav>
HTML

cat > "$out/.foot.html" <<'HTML'
<footer>Generated from README.md + SPEC.md by scripts/build-docs.sh.</footer>
HTML

render() { # render <src.md> <title> <out.html>
  pandoc --from=gfm --to=html5 --standalone \
    --metadata title="$2" \
    --css style.css \
    --include-in-header="$out/.head.html" \
    --include-before-body="$out/.nav.html" \
    --include-after-body="$out/.foot.html" \
    --output "$3" "$1"
}

render "$root/README.md" "nlir — natural-language IR" "$out/index.html"
render "$root/SPEC.md"   "nlir — SPEC"                "$out/spec.html"

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
    '<p>Terse shorthand in, fluent English out — the full set of expression-to-language cards. Deterministic outputs are exact; LLM outputs are real <code>claude-sonnet-5</code> captures. Click any card for the full-resolution PNG.</p>'
  if [ -f "$out/showcase/nlir-showreel.png" ]; then
    printf '%s\n' '<p class="hero"><a href="showcase/nlir-showreel.png"><img src="showcase/nlir-showreel.png" alt="nlir showreel — a grid of expression-to-language cards"></a></p>'
  fi
  printf '%s\n' '<div class="gallery">'
  if [ -d "$out/showcase" ]; then
    for png in "$out"/showcase/*.png; do
      [ -e "$png" ] || continue
      base="$(basename "$png")"
      [ "$base" = "nlir-showreel.png" ] && continue
      cap="${base#nlir-}"; cap="${cap%.png}"; cap="${cap//-/ }"
      printf '<figure><a href="showcase/%s"><img src="showcase/%s" alt="%s" loading="lazy"></a><figcaption>%s</figcaption></figure>\n' \
        "$base" "$base" "$cap" "$cap"
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
rm -f "$out/.nav.html" "$out/.foot.html" "$out/.head.html"

echo "build-docs: wrote $out/{index,spec,showcase}.html + style.css + showcase/ ($(ls "$out/showcase" 2>/dev/null | wc -l | tr -d ' ') assets)"
