#!/usr/bin/env python3
"""Pixel diff of the screenshot deck against a baseline.

Usage: scripts/screenshots-diff.py [baseline-dir]
  With no argument the baseline is the last committed Screenshots/ (git show HEAD:...).
Writes Screenshots/diff/index.html (baseline | current | heat overlay) for every screen whose
differing-pixel ratio exceeds 0.5%, plus screens added or removed. Exits 1 when any screen differs.

Uses Pillow (pip3 install --user Pillow): there is no JPEG decoder in the standard library.
"""
import html
import io
import pathlib
import shutil
import subprocess
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit("screenshots-diff needs Pillow: pip3 install --user Pillow")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "Screenshots"
OUT = SHOTS / "diff"
RATIO_LIMIT = 0.005
# The deck is JPEG quality 70, so identical frames differ by a few levels per channel.
# ponytail: fixed noise floor, tune here if re-encoding noise ever crosses it.
CHANNEL_TOLERANCE = 24


def baseline_images():
    """{name: bytes} from the argument folder, or from HEAD's committed Screenshots/."""
    if len(sys.argv) > 1:
        base = pathlib.Path(sys.argv[1])
        return {p.name: p.read_bytes() for p in base.glob("STARTSCREEN_*.jpg")}
    git = ["git", "-C", str(ROOT)]
    names = subprocess.run(git + ["ls-tree", "--name-only", "HEAD", "Screenshots/"],
                           check=True, capture_output=True, text=True).stdout.split()
    return {pathlib.Path(n).name: subprocess.run(git + ["show", f"HEAD:{n}"], check=True,
                                                 capture_output=True).stdout
            for n in names if pathlib.PurePath(n).name.startswith("STARTSCREEN_") and n.endswith(".jpg")}


def compare(old, new):
    """(differing-pixel ratio, heat overlay image)."""
    if old.size != new.size:
        return 1.0, new.convert("L").convert("RGB")
    mask = ImageChops.difference(old, new).convert("L").point(lambda v: 255 if v > CHANNEL_TOLERANCE else 0)
    ratio = mask.histogram()[255] / (new.width * new.height)
    dim = Image.blend(Image.new("RGB", new.size, "black"), new.convert("L").convert("RGB"), 0.35)
    heat = Image.composite(Image.new("RGB", new.size, (255, 40, 40)), dim, mask)
    return ratio, heat


def main():
    base = baseline_images()
    current = {p.name: p for p in SHOTS.glob("STARTSCREEN_*.jpg")}
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    rows, same = [], 0
    for name in sorted(base.keys() | current.keys()):
        if name not in current:
            rows.append((name, "removed", None))
            (OUT / f"base-{name}").write_bytes(base[name])
            continue
        if name not in base:
            rows.append((name, "added", None))
            continue
        old = Image.open(io.BytesIO(base[name])).convert("RGB")
        ratio, heat = compare(old, Image.open(current[name]).convert("RGB"))
        if ratio <= RATIO_LIMIT:
            same += 1
            continue
        (OUT / f"base-{name}").write_bytes(base[name])
        heat.save(OUT / f"heat-{name}", quality=70)
        rows.append((name, f"{ratio:.1%}", ratio))

    rows.sort(key=lambda r: -(r[2] if r[2] is not None else 2))
    for name, status, _ in rows:
        print(f"  {status:>8}  {name}")
    print(f"{len(rows)} differ, {same} unchanged (limit {RATIO_LIMIT:.1%}) -> {OUT / 'index.html'}")

    def img(src, label):
        return (f'<figure><img loading="lazy" src="{html.escape(src)}" alt="{label}">'
                f"<figcaption>{label}</figcaption></figure>")
    cards = []
    for name, status, _ in rows:
        figs = [img(f"base-{name}", "baseline") if status != "added" else "<figure></figure>",
                img(f"../{name}", "current") if status != "removed" else "<figure></figure>",
                img(f"heat-{name}", "diff") if status not in ("added", "removed") else "<figure></figure>"]
        title = html.escape(name.removeprefix("STARTSCREEN_").removesuffix(".jpg"))
        cards.append(f'<section><h2>{title} <span>{status}</span></h2><div class="row">{"".join(figs)}</div></section>')
    (OUT / "index.html").write_text(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Screenshot Diff</title>
<style>
:root {{ color-scheme: light dark; --bg: #f4f4f5; --fg: #18181b; --card: #fff; --accent: #d92626; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg: #111113; --fg: #e4e4e7; --card: #1c1c1f; --accent: #ff6b6b; }} }}
body {{ margin: 0; padding: 16px; background: var(--bg); color: var(--fg); font: 14px -apple-system, system-ui, sans-serif; }}
main {{ display: grid; gap: 16px; grid-template-columns: repeat(auto-fill, minmax(420px, 1fr)); }}
section {{ background: var(--card); border-radius: 12px; padding: 12px; }}
h1 {{ font-size: 20px; }} h2 {{ font-size: 13px; margin: 0 0 8px; font-family: ui-monospace, monospace; }}
h2 span {{ color: var(--accent); float: right; }}
.row {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }}
figure {{ margin: 0; }} img {{ width: 100%; border-radius: 8px; display: block; }}
figcaption {{ text-align: center; opacity: .6; font-size: 12px; margin-top: 4px; }}
@media (max-width: 480px) {{ main {{ grid-template-columns: 1fr; }} }}
</style></head><body>
<h1>{len(rows)} screens differ, {same} unchanged</h1>
<main>{"".join(cards)}</main>
</body></html>
""")
    return 1 if rows else 0


if __name__ == "__main__":
    sys.exit(main())
