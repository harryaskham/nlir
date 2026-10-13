#!/usr/bin/env bash
# Publish the nlir site to the gh-pages branch (GitHub Pages "legacy" branch source).
#
# Builds the in-browser evaluator (wasm) and the docs site from THIS commit, checks
# the static tree, then replaces the gh-pages tree from a temporary clone — no
# Actions runner, no artifacts. Credentials come from `gh auth git-credential`;
# no token touches argv, URLs, git config or logs.
#
#   scripts/publish-site.sh           build, validate, publish, request a Pages build
#   scripts/publish-site.sh --check   build and validate only
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
repo="${NLIR_PAGES_REPO:-harryaskham/nlir}"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "publish-site: bad repo slug $repo" >&2; exit 2; }
check_only=0
[ "${1:-}" = "--check" ] && check_only=1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

rev="$(git rev-parse HEAD)"
if [ -n "$(git status --porcelain -- site src crates config.example.yaml README.md SPEC.md showcase scripts)" ]; then
  echo "publish-site: uncommitted changes under the site sources; commit first so gh-pages names a real revision" >&2
  [ "$check_only" = 1 ] || exit 1
fi

# 1. The evaluator, co-built from this commit (the version stamp is the commit).
( cd crates/nlir-wasm && wasm-pack build --target web --out-dir pkg >/dev/null 2>&1 )
rm -rf site/workspace/pkg
cp -a crates/nlir-wasm/pkg site/workspace/pkg
cp config.example.yaml site/workspace/config.example.yaml
printf '%s\n' "$rev" > site/workspace/pkg/BUILD_COMMIT

# 2. The site.
out="$work/site"
bash scripts/build-docs.sh "$out" >/dev/null
rm -f "$out/workspace/pkg/.gitignore"

# 3. Validate: no symlinks, bounded size, every local href/src resolves inside the tree.
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
if not os.path.exists(os.path.join(root, "index.html")): problems.append("no index.html")
if total > 120 * 2**20: problems.append(f"site is {total >> 20} MiB")
for line in problems: print("publish-site:", line, file=sys.stderr)
print(f"publish-site: {total / 2**20:.1f} MiB checked, {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
PY

[ "$check_only" = 1 ] && { echo "publish-site: --check passed for $rev"; exit 0; }

# 4. Replace the gh-pages tree from a temporary clone.
git_gh() { git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"; }
remote="https://github.com/$repo.git"
pages="$work/pages"
if git_gh ls-remote --exit-code --heads "$remote" gh-pages >/dev/null 2>&1; then
  git_gh clone -q --depth 1 --branch gh-pages "$remote" "$pages"
else
  git init -q "$pages"
  git -C "$pages" checkout -q --orphan gh-pages
  git -C "$pages" remote add origin "$remote"
fi
find "$pages" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$out/." "$pages/"
touch "$pages/.nojekyll"
git -C "$pages" add -A
if git -C "$pages" diff --cached --quiet; then
  echo "publish-site: gh-pages already matches $rev"
else
  git -C "$pages" -c user.name="nlir site publisher" -c user.email="publisher@nlir.invalid" \
    commit -q -m "Publish site from ${rev:0:12}"
  git_gh -C "$pages" push -q origin gh-pages
  echo "publish-site: pushed gh-pages for $rev"
fi

# 5. Point Pages at the branch (only if it isn't already) and request a build.
mode="$(gh api "repos/$repo/pages" --jq '[.build_type, .source.branch, .source.path] | join(":")' 2>/dev/null || true)"
if [ "$mode" != "legacy:gh-pages:/" ]; then
  if [ -z "$mode" ]; then
    gh api -X POST "repos/$repo/pages" -f build_type=legacy -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null || true
  else
    gh api -X PUT "repos/$repo/pages" -f build_type=legacy -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null
  fi
  mode="$(gh api "repos/$repo/pages" --jq '[.build_type, .source.branch, .source.path] | join(":")')"
  [ "$mode" = "legacy:gh-pages:/" ] || { echo "publish-site: Pages mode is $mode" >&2; exit 1; }
fi
gh api -X POST "repos/$repo/pages/builds" --jq '.status' || true
echo "publish-site: $(gh api "repos/$repo/pages" --jq '.html_url')"
