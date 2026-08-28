"""Generates every launcher icon from the mark. Rerun with `python tool/gen_icons.py`.

The mark is the signature component reduced to one element: a brass redaction
bar with the ascender of a hidden letter escaping above it. Never rotated,
never crimson, never over a photograph, and no gloss, gradient or inner shadow.

Geometry is defined once, on a 32-unit grid, matching lib/design/icons.dart so
the in-app mark and the launcher icon cannot drift apart.
"""
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..')

INK = (5, 7, 10, 255)        # #05070A - the darkest thing on the phone
BRASS = (223, 168, 60, 255)  # brass-400
WHITE = (255, 255, 255, 255)

# On the 32 grid: bar x6..26, y13..19; ascender a 6-wide arch from y9.5 to y13.
BAR = (6.0, 13.0, 26.0, 19.0)
ASC_X0, ASC_X1, ASC_TOP, ASC_BOTTOM = 13.0, 19.0, 9.5, 13.0
ASC_STROKE = 2.0


def draw_mark(size, fg, bg, clear_space=0.22, supersample=8):
    """The mark centred in a square, with `clear_space` of the box left empty."""
    s = size * supersample
    img = Image.new('RGBA', (s, s), bg if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    art = s * (1 - 2 * clear_space)
    unit = art / 32.0
    ox = oy = s * clear_space

    def px(x, y):
        return (ox + x * unit, oy + y * unit)

    # The bar. Radius 1 on the 32 grid - small and hard, like every other
    # corner in the system.
    x0, y0 = px(BAR[0], BAR[1])
    x1, y1 = px(BAR[2], BAR[3])
    d.rounded_rectangle([x0, y0, x1, y1], radius=unit * 1.0, fill=fg)

    # The ascender: two uprights joined by a half-round cap, stroked not filled,
    # so it reads as a letter escaping rather than a second bar.
    w = unit * ASC_STROKE
    ax0, atop = px(ASC_X0, ASC_TOP)
    ax1, abottom = px(ASC_X1, ASC_BOTTOM)
    radius = (ax1 - ax0) / 2.0
    cy = atop + radius
    d.arc([ax0, atop, ax1, atop + 2 * radius], start=180, end=360, fill=fg, width=int(round(w)))
    d.line([ax0 + w / 2, cy, ax0 + w / 2, abottom], fill=fg, width=int(round(w)))
    d.line([ax1 - w / 2, cy, ax1 - w / 2, abottom], fill=fg, width=int(round(w)))

    return img.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    # Absolute first part means the caller already resolved the directory.
    path = os.path.join(*parts) if os.path.isabs(parts[0]) else os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    return path


def main():
    written = 0

    # ---- Android legacy mipmaps (full-bleed ink ground) -------------------
    for folder, size in [('mipmap-mdpi', 48), ('mipmap-hdpi', 72), ('mipmap-xhdpi', 96),
                         ('mipmap-xxhdpi', 144), ('mipmap-xxxhdpi', 192)]:
        icon = draw_mark(size, BRASS, INK)
        save(icon, 'android', 'app', 'src', 'main', 'res', folder, 'ic_launcher.png')
        written += 1

        # Adaptive foreground: the mark alone, on 108dp with the 66dp safe zone,
        # so it survives circle, squircle and square masks alike.
        fg_size = int(size * 108 / 48)
        save(draw_mark(fg_size, BRASS, None, clear_space=0.30),
             'android', 'app', 'src', 'main', 'res', folder, 'ic_launcher_foreground.png')
        written += 1

        # Monochrome (Android 13+): bar solid, drawn at full weight. Never a
        # thinner bar - at tile size a thin one simply disappears.
        save(draw_mark(fg_size, WHITE, None, clear_space=0.30),
             'android', 'app', 'src', 'main', 'res', folder, 'ic_launcher_monochrome.png')
        written += 1

    # Notification small icon: bar only. At 24dp the ascender is a smudge.
    for folder, size in [('drawable-mdpi', 24), ('drawable-hdpi', 36), ('drawable-xhdpi', 48),
                         ('drawable-xxhdpi', 72), ('drawable-xxxhdpi', 96)]:
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        unit = size / 32.0
        d.rounded_rectangle(
            [6 * unit, 13 * unit, 26 * unit, 19 * unit],
            radius=unit, fill=WHITE,
        )
        save(img, 'android', 'app', 'src', 'main', 'res', folder, 'ic_stat_spy.png')
        written += 1

    # ---- iOS AppIcon -------------------------------------------------------
    # Filenames come from the asset catalogue itself, so the set stays exactly
    # the one Xcode already references - no orphans, no missing entries.
    appicon = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    with open(os.path.join(appicon, 'Contents.json'), encoding='utf-8') as f:
        catalogue = json.load(f)

    done = set()
    for entry in catalogue['images']:
        filename = entry['filename']
        if filename in done:
            continue
        done.add(filename)
        base = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].rstrip('x'))
        px_size = int(round(base * scale))
        # iOS masks to a squircle itself, so the ground is full-bleed and flat.
        save(draw_mark(px_size, BRASS, INK), appicon, filename)
        written += 1

    print(f'{written} icon files written')


if __name__ == '__main__':
    main()
