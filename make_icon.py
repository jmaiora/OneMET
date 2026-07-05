import os, zlib, struct
BASE = os.path.dirname(os.path.abspath(__file__))
XC   = os.path.join(BASE, "OneMET", "Assets.xcassets")
ICON = os.path.join(XC, "AppIcon.appiconset")
os.makedirs(ICON, exist_ok=True)
W = H = 1024
cx = cy = W / 2.0
R = W * 0.30
def pixel(x, y):
    t = (x + y) / (W + H)
    r = int(26 + t * 20); g = int(120 + t * 80); b = int(220 - t * 70)
    dx, dy = x - cx, y - cy
    if dx * dx + dy * dy < R * R:
        return (255, 255, 255)
    return (r, g, b)
raw = bytearray()
for y in range(H):
    raw.append(0)
    for x in range(W):
        raw += bytes(pixel(x, y))
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
       + chunk(b"IEND", b""))
open(os.path.join(ICON, "icon-1024.png"), "wb").write(png)
open(os.path.join(ICON, "Contents.json"), "w").write('{\n  "images" : [\n    {\n      "filename" : "icon-1024.png",\n      "idiom" : "universal",\n      "platform" : "ios",\n      "size" : "1024x1024"\n    }\n  ],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
open(os.path.join(XC, "Contents.json"), "w").write('{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
print("OK", len(png))
