#!/bin/bash
# Builds the offline preview assets into Sources/Resources/preview/.
# Run after changing anything in preview-src/. Requires `npm install` first.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$SRC/../Sources/Resources/preview"

mkdir -p "$OUT/fonts"

# 1. Bundle markdown-it + plugins + highlight.js + app logic → app.js (IIFE).
"$SRC/node_modules/.bin/esbuild" "$SRC/main.js" \
  --bundle --minify --format=iife \
  --outfile="$OUT/app.js" --log-level=warning

# 2. Hand-authored shell + styles.
cp "$SRC/index.html" "$OUT/index.html"
cp "$SRC/styles.css" "$OUT/styles.css"

# 3. KaTeX (loaded as a global) + its CSS + fonts.
cp "$SRC/node_modules/katex/dist/katex.min.js"  "$OUT/katex.min.js"
cp "$SRC/node_modules/katex/dist/katex.min.css" "$OUT/katex.min.css"
cp "$SRC"/node_modules/katex/dist/fonts/* "$OUT/fonts/"

# 4. Mermaid (loaded as a global).
cp "$SRC/node_modules/mermaid/dist/mermaid.min.js" "$OUT/mermaid.min.js"

echo "Built preview assets → $OUT"
du -sh "$OUT" && ls "$OUT"
