#!/usr/bin/env bash
# Renders docs/assets/hero.png (README) and docs/assets/og.png (social card) from the
# product-shot mockup in docs/index.html, using headless Google Chrome.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MOCK="$(sed -n '/<!--mock:start-->/,/<!--mock:end-->/p' "$ROOT/docs/index.html")"
CSS="file://$ROOT/docs/assets/mockup.css"

cat > "$TMP/hero.html" <<HTML
<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="$CSS">
<style>html,body{margin:0;background:transparent}.mock{width:1600px;border-radius:22px}</style>
$MOCK
HTML

cat > "$TMP/og.html" <<HTML
<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="$CSS">
<style>
html,body{margin:0}
body{width:1200px;height:630px;overflow:hidden;display:flex;align-items:center;gap:40px;padding:0 0 0 64px;box-sizing:border-box;
  background:radial-gradient(80% 120% at 0% 0%,#20244a,#0e0f13 60%);color:#f2f3f7;
  font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display",Helvetica,Arial,sans-serif}
.l{flex:0 0 360px}
.l img{width:84px;height:84px;display:block;margin-bottom:26px}
h1{font-size:58px;line-height:1.02;letter-spacing:-.035em;margin:0 0 18px}
h1 span{background:linear-gradient(100deg,#7d8bff,#a77bff);-webkit-background-clip:text;color:transparent}
p{font-size:25px;line-height:1.35;color:#a2a6b4;margin:0}
.r{flex:1;padding-right:36px}
.mock{width:100%}
</style>
<div class="l"><img src="file://$ROOT/docs/assets/icon-256.png"><h1>ShotMate<br><span>for Mac</span></h1><p>Hotkey → select → mark → ⌘V<br>Free &amp; open source.</p></div>
<div class="r">$MOCK</div>
HTML

render() { "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
  --default-background-color=00000000 --force-device-scale-factor="$3" --window-size="$2" \
  --screenshot="$4" "file://$TMP/$1" >/dev/null 2>&1; }

render hero.html 1600,1000 1 "$ROOT/docs/assets/hero.png"
render og.html 1200,630 1 "$ROOT/docs/assets/og.png"
echo "✓ docs/assets/hero.png, docs/assets/og.png"
