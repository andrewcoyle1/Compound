"""Builds Compound's app icon art from Barlow Condensed's italic "C".

    python3 build.py BarlowCondensed-ExtraBoldItalic.ttf

The font is from Google Fonts (github.com/google/fonts, ofl/barlowcondensed),
under the SIL Open Font License 1.1 in OFL.txt beside this script. The glyph is
converted to outlines in compound-c.svg, which is the source of truth; every
PNG below is rendered from the same outline.

Writes, relative to app/:
- ios/Runner/AppIcons/AppIcon{,-dev,-stg}.icon/Assets/CompoundDefault.png and
  CompoundDark.png: the mark alone on transparent, black and volt (the bundle's
  `fill` paints the background);
- packages/app_ui/assets/app_icon.png: the light icon, square, 144 px;
- android/app/src/main/res/mipmap-*/ic_launcher_{foreground,monochrome}.png.
"""

import os
import sys

from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
VOLT = (0xC8, 0xF3, 0x1D, 255)
BLACK = (0, 0, 0, 255)
CANVAS = 1024
HEIGHT = 620  # cap height plus overshoot, in canvas px: ~60%, inside the grid's outer circle
CENTROID_PULL = 0.5  # 0 centres the bounding box, 1 the ink's centre of mass (optical centring)


class Flatten(BasePen):
    """Collects each contour as a polygon, curves sampled finely."""

    def __init__(self, glyphset):
        super().__init__(glyphset)
        self.contours, self.cur = [], []

    def _moveTo(self, p):
        self.cur = [p]

    def _lineTo(self, p):
        self.cur.append(p)

    def _curveToOne(self, a, b, c):
        p0 = self.cur[-1]
        for i in range(1, 33):
            t = i / 32
            u = 1 - t
            self.cur.append(tuple(u**3 * p0[k] + 3 * u * u * t * a[k] + 3 * u * t * t * b[k] + t**3 * c[k] for k in (0, 1)))

    def _qCurveToOne(self, a, b):
        p0 = self.cur[-1]
        for i in range(1, 33):
            t = i / 32
            u = 1 - t
            self.cur.append(tuple(u * u * p0[k] + 2 * u * t * a[k] + t * t * b[k] for k in (0, 1)))

    def _closePath(self):
        self.contours.append(self.cur)

    _endPath = _closePath


def outline(font_path):
    f = TTFont(font_path)
    gs = f.getGlyphSet()
    g = gs[f.getBestCmap()[ord('C')]]
    flat, bounds, svg = Flatten(gs), BoundsPen(gs), SVGPathPen(gs)
    g.draw(flat)
    g.draw(bounds)
    g.draw(svg)
    return flat.contours, bounds.bounds, svg.getCommands()


def area_centroid(poly):
    a = cx = 0.0
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        c = x0 * y1 - x1 * y0
        a += c
        cx += (x0 + x1) * c
    return cx / (3 * a)


def transform(contours, bounds):
    """Font units (y up) to canvas px (y down): HEIGHT tall, optically centred."""
    x0, y0, x1, y1 = bounds
    k = HEIGHT / (y1 - y0)
    cx = (1 - CENTROID_PULL) * (x0 + x1) / 2 + CENTROID_PULL * area_centroid(contours[0])
    return k, CANVAS / 2 - k * cx, CANVAS / 2 + k * (y0 + y1) / 2


def mark(contours, k, tx, ty, size, color, bg=None, scale=1.0):
    """The mark on a `size` px square, `scale` of the canvas, rendered 4x and downsampled."""
    ss = 4
    n = size * ss
    s = n / CANVAS * scale
    off = n * (1 - scale) / 2
    m = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(m)
    for poly in contours:  # Barlow's C is one contour
        d.polygon([(off + s * (tx + k * x), off + s * (ty - k * y)) for x, y in poly], fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), bg or (0, 0, 0, 0))
    out.paste(Image.new('RGBA', (size, size), color), (0, 0), m)
    return out


def main(font_path):
    contours, bounds, path = outline(font_path)
    k, tx, ty = transform(contours, bounds)
    with open(os.path.join(HERE, 'compound-c.svg'), 'w') as f:
        f.write(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">\n'
            f'  <!-- Barlow Condensed {os.path.basename(font_path)[16:-4]} "C" (OFL 1.1, see OFL.txt), as outlines. -->\n'
            f'  <path transform="matrix({k:.6f} 0 0 {-k:.6f} {tx:.3f} {ty:.3f})" d="{path}"/>\n</svg>\n')

    for name in ('AppIcon', 'AppIcon-dev', 'AppIcon-stg'):
        assets = os.path.join(APP, 'ios/Runner/AppIcons', name + '.icon', 'Assets')
        mark(contours, k, tx, ty, CANVAS, BLACK).save(os.path.join(assets, 'CompoundDefault.png'), optimize=True)
        mark(contours, k, tx, ty, CANVAS, VOLT).save(os.path.join(assets, 'CompoundDark.png'), optimize=True)

    icon = mark(contours, k, tx, ty, CANVAS, BLACK, bg=VOLT).convert('RGB')
    icon.resize((144, 144), Image.LANCZOS).save(os.path.join(APP, 'packages/app_ui/assets/app_icon.png'), optimize=True)

    # Adaptive icon: 108 dp, of which the launcher shows the middle 72, so the iOS canvas maps to 2/3.
    res = os.path.join(APP, 'android/app/src/main/res')
    for dpi, px in (('mdpi', 108), ('hdpi', 162), ('xhdpi', 216), ('xxhdpi', 324), ('xxxhdpi', 432)):
        fg = mark(contours, k, tx, ty, px, BLACK, scale=2 / 3)
        fg.save(os.path.join(res, f'mipmap-{dpi}', 'ic_launcher_foreground.png'), optimize=True)
        fg.save(os.path.join(res, f'mipmap-{dpi}', 'ic_launcher_monochrome.png'), optimize=True)


if __name__ == '__main__':
    main(sys.argv[1])
