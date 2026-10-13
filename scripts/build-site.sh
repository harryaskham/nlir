#!/usr/bin/env bash
# Build the nlir site into OUT (default _site): the in-browser evaluator compiled to
# wasm from THIS commit, the docs rendered from README/SPEC, and a static-tree check.
#
#   nix develop .#site --command bash scripts/build-site.sh _site
#
# The Pages workflow runs exactly this on the self-hosted nix runners (via the shared
# harryaskham.github.io publish-pages workflow); run it locally to preview.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
out="${1:-_site}"
case "$out" in /*) ;; *) out="$root/$out" ;; esac
rev="$(git rev-parse HEAD)"

# 1. The evaluator: cargo builds the wasm, wasm-bindgen emits the web glue. The
#    wasm-bindgen crate is pinned to the CLI version the flake provides.
export NLIR_WASM_GIT="$rev"
(cd crates/nlir-wasm && cargo build --release --target wasm32-unknown-unknown)
wasm="${CARGO_TARGET_DIR:-$root/crates/nlir-wasm/target}/wasm32-unknown-unknown/release/nlir_wasm.wasm"
rm -rf site/workspace/pkg
wasm-bindgen --target web --out-dir site/workspace/pkg "$wasm"
if command -v wasm-opt >/dev/null 2>&1; then
  wasm-opt -O2 --all-features site/workspace/pkg/nlir_wasm_bg.wasm -o site/workspace/pkg/nlir_wasm_bg.wasm.opt \
    && mv site/workspace/pkg/nlir_wasm_bg.wasm.opt site/workspace/pkg/nlir_wasm_bg.wasm
fi
cp config.example.yaml site/workspace/config.example.yaml
printf '%s\n' "$rev" > site/workspace/pkg/BUILD_COMMIT

# 2. The docs (copies site/workspace and site/spec-lab into the output).
bash scripts/build-docs.sh "$out" >/dev/null

# 3. Check the static tree: no symlinks, bounded size, every local link resolves.
python3 - "$out" <<'PY'
import html.parser, os, sys, urllib.parse
root = sys.argv[1]
total, problems = 0, []
class Links(html.parser.HTMLParser):
    def __init__(self): super().__init__(); self.refs = []
    def handle_starttag(self, tag, attrs):
        for k, v in attrs:
            if k in ("href", "src") and v: self.refs.append(v)
for dirpath, _, files in os.walk(root):
    for f in files:
        p = os.path.join(dirpath, f)
        if os.path.islink(p): problems.append(f"symlink {p}")
        size = os.path.getsize(p); total += size
        if size > 8 * 2**20: problems.append(f"{p} is {size >> 20} MiB")
        if not f.endswith(".html"): continue
        parser = Links(); parser.feed(open(p, encoding="utf-8").read())
        for ref in parser.refs:
            u = urllib.parse.urlparse(ref)
            if u.scheme or ref.startswith(("#", "mailto:", "data:", "//")): continue
            if ref.startswith("/"): problems.append(f"root-relative {ref} in {p}"); continue
            target = os.path.normpath(os.path.join(dirpath, urllib.parse.unquote(u.path)))
            if u.path and not os.path.exists(target) and not os.path.exists(os.path.join(target, "index.html")):
                problems.append(f"missing {ref} in {os.path.relpath(p, root)}")
for need in ("index.html", "workspace/pkg/nlir_wasm_bg.wasm", "spec-lab/index.html"):
    if not os.path.exists(os.path.join(root, need)): problems.append(f"missing {need}")
if total > 120 * 2**20: problems.append(f"site is {total >> 20} MiB")
for line in problems: print("build-site:", line, file=sys.stderr)
print(f"build-site: {total / 2**20:.1f} MiB checked, {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
PY
echo "build-site: $out built from $rev"
