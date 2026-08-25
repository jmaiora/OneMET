"""Build the iOS app icon from the source artwork.

App Store requirements this enforces:
  * exactly 1024x1024, square
  * opaque RGB — no alpha channel (upload error 90717)
  * filename matches Contents.json ("icon-1024.png")

Source artwork can be any size/aspect; it is fitted (never cropped) and centred
on a background sampled from its own corners.

Run:  python make_icon.py
"""
import os
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
XC = os.path.join(BASE, "OneMET", "Assets.xcassets")
ICON = os.path.join(XC, "AppIcon.appiconset")
OUT = os.path.join(ICON, "icon-1024.png")

# First existing candidate wins; add your artwork filename here if it changes.
CANDIDATES = ["Icono_MET.png", "source.png", "logo.png"]
SIZE = 1024
MARGIN = 0.06          # 6% padding so the mark isn't flush against the edge


def find_source():
    for name in CANDIDATES:
        p = os.path.join(ICON, name)
        if os.path.exists(p):
            return p
    raise SystemExit("No source artwork found in %s (looked for %s)" % (ICON, CANDIDATES))


def background_of(img):
    """Median of the opaque corner pixels — seamless when the art has a solid backdrop."""
    w, h = img.size
    corners = [img.getpixel(p) for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    opaque = [c for c in corners if c[3] > 200]
    if not opaque:
        return (255, 255, 255)
    return tuple(sorted(c[i] for c in opaque)[len(opaque) // 2] for i in range(3))


def main():
    src_path = find_source()
    src = Image.open(src_path).convert("RGBA")

    canvas = Image.new("RGB", (SIZE, SIZE), background_of(src))
    box = int(SIZE * (1 - 2 * MARGIN))
    art = src.copy()
    art.thumbnail((box, box), Image.LANCZOS)
    canvas.paste(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2), art)
    canvas.save(OUT, "PNG")

    with open(os.path.join(ICON, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    {\n      "filename" : "icon-1024.png",\n'
                '      "idiom" : "universal",\n      "platform" : "ios",\n'
                '      "size" : "1024x1024"\n    }\n  ],\n'
                '  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
    with open(os.path.join(XC, "Contents.json"), "w") as f:
        f.write('{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n')

    check = Image.open(OUT)
    print("source :", os.path.basename(src_path), src.size)
    print("output :", OUT)
    print("verify : %s %s alpha=%s" % (check.size, check.mode, "A" in check.getbands()))


if __name__ == "__main__":
    main()
