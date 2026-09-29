#!/usr/bin/env python3
"""Writes <dir>/index.html: one row per screen, light and dark side by side.

Plain HTML because Pillow and ImageMagick are not guaranteed on this machine.
"""
import html
import pathlib
import sys

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Screenshots")
screens = sorted({p.stem.rsplit("-", 1)[0] for p in out.glob("STARTSCREEN_*.jpg")})
cards = []
for screen in screens:
    shots = "".join(
        f'<figure><img loading="lazy" src="{html.escape(screen)}-{mode}.jpg" alt="{html.escape(screen)} {mode}">'
        f"<figcaption>{mode}</figcaption></figure>"
        for mode in ("light", "dark")
        if (out / f"{screen}-{mode}.jpg").exists()
    )
    name = html.escape(screen.removeprefix("STARTSCREEN_"))
    cards.append(f'<section><h2>{name}</h2><div class="pair">{shots}</div></section>')

(out / "index.html").write_text(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DialedIn Screenshots</title>
<style>
:root {{ color-scheme: light dark; --bg: #f4f4f5; --fg: #18181b; --card: #fff; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg: #111113; --fg: #e4e4e7; --card: #1c1c1f; }} }}
body {{ margin: 0; padding: 16px; background: var(--bg); color: var(--fg); font: 14px -apple-system, system-ui, sans-serif; }}
main {{ display: grid; gap: 16px; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); }}
section {{ background: var(--card); border-radius: 12px; padding: 12px; }}
h1 {{ font-size: 20px; }} h2 {{ font-size: 13px; margin: 0 0 8px; font-family: ui-monospace, monospace; }}
.pair {{ display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }}
figure {{ margin: 0; }} img {{ width: 100%; border-radius: 8px; display: block; }}
figcaption {{ text-align: center; opacity: .6; font-size: 12px; margin-top: 4px; }}
</style></head><body>
<h1>DialedIn screenshots ({len(screens)} screens)</h1>
<main>{"".join(cards)}</main>
</body></html>
""")
print(f"Contact sheet: {out / 'index.html'} ({len(screens)} screens)")
