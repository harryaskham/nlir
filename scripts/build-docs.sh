#!/usr/bin/env bash
# Build the static nlir docs site from README.md + SPEC.md (bd-7d0ea0).
#
# Renders GitHub-flavoured markdown to a small self-contained HTML site with a
# shared nav + stylesheet. Used by .github/workflows/pages.yml to publish to
# GitHub Pages, and runnable locally: `scripts/build-docs.sh [OUT_DIR]`
# (default: ./site). Requires pandoc.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
out="${1:-$root/site}"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "build-docs: pandoc is required (apt-get install pandoc / nix)" >&2
  exit 1
fi

mkdir -p "$out"

cat > "$out/style.css" <<'CSS'
:root { --fg:#1a1a1a; --muted:#666; --bg:#fdfdfd; --accent:#7a3cff; --code:#f4f2fb; }
* { box-sizing: border-box; }
body { margin:0; font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,sans-serif; color:var(--fg); background:var(--bg); }
nav { position:sticky; top:0; background:var(--bg); border-bottom:1px solid #eee; padding:.75rem 1.25rem; }
nav a { color:var(--accent); text-decoration:none; margin-right:1.1rem; font-weight:600; }
nav a:hover { text-decoration:underline; }
main { max-width:52rem; margin:0 auto; padding:2rem 1.25rem 4rem; }
h1,h2,h3 { line-height:1.25; }
h2 { margin-top:2.2rem; border-bottom:1px solid #eee; padding-bottom:.3rem; }
a { color:var(--accent); }
pre { background:var(--code); padding:1rem; border-radius:8px; overflow:auto; }
code { background:var(--code); padding:.1em .35em; border-radius:4px; font-size:.9em; }
pre code { background:none; padding:0; }
table { border-collapse:collapse; margin:1rem 0; }
th,td { border:1px solid #ddd; padding:.4rem .7rem; text-align:left; }
blockquote { color:var(--muted); border-left:3px solid #ddd; margin:1rem 0; padding:.2rem 1rem; }
footer { color:var(--muted); font-size:.85rem; border-top:1px solid #eee; margin-top:3rem; padding-top:1rem; }
CSS

cat > "$out/.nav.html" <<'HTML'
<nav>
  <a href="index.html">nlir</a>
  <a href="spec.html">SPEC</a>
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
    --include-before-body="$out/.nav.html" \
    --include-after-body="$out/.foot.html" \
    --output "$3" "$1"
}

render "$root/README.md" "nlir — natural-language IR" "$out/index.html"
render "$root/SPEC.md"   "nlir — SPEC"                "$out/spec.html"

# GitHub Pages: skip Jekyll so underscore-prefixed assets are served verbatim.
touch "$out/.nojekyll"
rm -f "$out/.nav.html" "$out/.foot.html"

echo "build-docs: wrote $out/{index,spec}.html + style.css"
