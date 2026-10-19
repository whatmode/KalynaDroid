#!/usr/bin/env python3
"""Builds Kalyna's native assets from the web edition, so both look and sound the same.

  fonts       Inter (Kalyna Text / Display) and JetBrains Mono, unpacked from WOFF to OpenType
  glyphs      the stroke icon set (24x24 SVG) used for apps and quick settings
  logo        the kalyna berries
  wallpapers  the five painted wallpapers, rendered at 1280x800 and 800x1280 (needs Playwright)
  sounds      the scroll-edge sounds: a double hand clap (top) and a bouncing ball (bottom)

usage: make-assets.py <path to kalyna-os/src> <output assets dir>
"""
import base64, json, math, random, re, struct, subprocess, sys, wave, zlib
from pathlib import Path

SRC, OUT = Path(sys.argv[1]), Path(sys.argv[2])
html = (SRC / "kalyna.html").read_text(encoding="utf-8")
fonts_css = (SRC / "fonts.css").read_text(encoding="utf-8")
for d in ("fonts", "glyphs", "wallpapers", "sounds"):
    (OUT / d).mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------- fonts (WOFF 1.0 -> sfnt)
def woff_to_sfnt(data: bytes) -> bytes:
    sig, flavor, length, num, _, total_sfnt = struct.unpack(">4sIIHHI", data[:20])
    assert sig == b"wOFF"
    tables = []
    for i in range(num):
        tag, off, clen, olen, csum = struct.unpack(">4sIIII", data[44 + i * 20:64 + i * 20])
        raw = data[off:off + clen]
        tables.append((tag, csum, zlib.decompress(raw) if clen < olen else raw))
    es = int(math.log2(num)); sr = (2 ** es) * 16
    out = struct.pack(">IHHHH", flavor, num, sr, es, num * 16 - sr)
    offset = 12 + 16 * num
    body = b""
    for tag, csum, t in tables:
        out += struct.pack(">4sIII", tag, csum, offset + len(body), len(t))
        body += t + b"\0" * ((4 - len(t) % 4) % 4)
    return out + body


faces = re.findall(r"@font-face\{font-family:'([^']+)';font-style:(\w+);font-weight:(\d+);[^}]*?base64,([A-Za-z0-9+/=]+)\)", fonts_css)
for fam, style, weight, b64 in faces:
    sf = woff_to_sfnt(base64.b64decode(b64))
    ext = "otf" if sf[:4] == b"OTTO" else "ttf"
    name = f"{fam.replace(' ', '')}-{weight}{'-italic' if style == 'italic' else ''}.{ext}"
    (OUT / "fonts" / name).write_bytes(sf)
print("fonts:", len(faces))

# ---------------------------------------------------------------- glyphs
gblock = html[html.index("const G={"):]
gblock = gblock[:gblock.index("\n};")]
glyphs = dict(re.findall(r"^\s*(\w+):'([^']*)'", gblock, re.M))
# extra glyphs the native shell needs, drawn in the same 24px stroke style
glyphs.update({
    "search": '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5l5 5"/>',
    "bt": '<path d="M7 7.5l10 9-5 4.5V3l5 4.5-10 9"/>',
    "rotate": '<path d="M4.5 12a7.5 7.5 0 0 1 12.8-5.3L19.5 9"/><path d="M19.5 4.5V9H15"/><path d="M19.5 12a7.5 7.5 0 0 1-12.8 5.3L4.5 15"/><path d="M4.5 19.5V15H9"/>',
    "keyboard": '<rect x="2.5" y="6" width="19" height="12" rx="2"/><path d="M6 9.5h.01M9.3 9.5h.01M12.6 9.5h.01M15.9 9.5h.01M18 9.5h.01M6 12.5h.01M18 12.5h.01M9 12.5h6M8 15.2h8"/>',
    "kbhide": '<rect x="2.5" y="3.5" width="19" height="11" rx="2"/><path d="M6 7h.01M9.3 7h.01M12.6 7h.01M15.9 7h.01M18 7h.01M8 10.8h8M9 18l3 3 3-3"/>',
    "shift": '<path d="M12 4l7.5 8H15v7H9v-7H4.5z"/>',
    "backspace": '<path d="M8.5 5.5H20a1.5 1.5 0 0 1 1.5 1.5v10a1.5 1.5 0 0 1-1.5 1.5H8.5L2.5 12z"/><path d="M11.5 9.5l5 5M16.5 9.5l-5 5"/>',
    "enter": '<path d="M19.5 5.5v6.5a2 2 0 0 1-2 2H5"/><path d="M8.5 10.5L5 14l3.5 3.5"/>',
    "charge": '<path d="M13 2.5L5.5 13.5H11L10 21.5l8-11h-5.5z"/>',
    "recent": '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9 4v16"/>',
    "plane": '<path d="M10.5 21l1.5-1.5V14l8 2.5v-2l-8-5V4.5a1.5 1.5 0 0 0-3 0v5l-8 5v2l8-2.5v5.5L10.5 21z"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "chev": '<path d="M9 5.5l6.5 6.5L9 18.5"/>',
    "secure": '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>',
    "display": '<rect x="3" y="4.5" width="18" height="12" rx="2"/><path d="M8.5 20h7M12 16.5V20"/>',
    "palette": '<path d="M12 3.5a8.5 8.5 0 0 0 0 17c1.2 0 1.8-.8 1.8-1.7 0-1.3-1.2-1.6-1.2-2.8 0-1 .8-1.8 1.8-1.8h2.3a3.8 3.8 0 0 0 3.8-3.8C20.5 6.6 16.6 3.5 12 3.5z"/><circle cx="7.8" cy="11" r="1"/><circle cx="10.5" cy="7.5" r="1"/><circle cx="15" cy="7.8" r="1"/>',
    "hand": '<path d="M8 13V6.5a1.5 1.5 0 0 1 3 0V12M11 11.5V5a1.5 1.5 0 0 1 3 0v6.5M14 11.5V6.5a1.5 1.5 0 0 1 3 0V14c0 4-2.5 7-6.5 7-2.6 0-4.2-1.4-5.3-3.4L3.5 14.5a1.4 1.4 0 0 1 2.3-1.5L8 15"/>',
})
for k, body in glyphs.items():
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="96" height="96" fill="none" '
           'stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + body + "</svg>")
    (OUT / "glyphs" / f"{k}.svg").write_text(svg)
print("glyphs:", len(glyphs))

# ---------------------------------------------------------------- logo
m = re.search(r"const LOGO=\(s=18\)=>`(<svg[^`]*</svg>)`", html)
logo = m.group(1).replace('width="${s}" height="${s}"', 'width="128" height="128" xmlns="http://www.w3.org/2000/svg"')
(OUT / "logo.svg").write_text(logo.replace("currentColor", "#d6453d"))
(OUT / "logo-white.svg").write_text(logo.replace("currentColor", "#ffffff"))

# ---------------------------------------------------------------- app colours (for matching native icons)
apps = {}
ablock = html[html.index("const APPS={"):]
ablock = ablock[:ablock.index("\n};")]
for k, name, g, c1, c2 in re.findall(r"^\s*(\w+):\{desc:'[^']*',name:'([^']*)',g:G\.(\w+),c:\['(#\w+)','(#\w+)'\]", ablock, re.M):
    apps[k] = {"name": name, "glyph": g, "colors": [c1, c2]}
(OUT / "apps.json").write_text(json.dumps(apps, indent=1))

# ---------------------------------------------------------------- wallpapers
wb = html[html.index("const WALLS={"):]
wb = wb[:wb.index("\n};") + 3]
rng = re.search(r"(const rng=[^\n]*|function rng\([^\n]*)", html).group(1)
names = re.findall(r"^  (\w+):\{name:'([^']+)'", wb, re.M)
(OUT / "wallpapers" / "index.json").write_text(json.dumps([{"id": k, "name": n} for k, n in names], indent=1))
try:
    from playwright.sync_api import sync_playwright
    page_html = "<canvas id=c></canvas><script>" + rng + "\n" + wb + "</script>"
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page()
        pg.set_content(page_html)
        for key, _ in names:
            for w, h in ((1280, 800), (800, 1280)):
                url = pg.evaluate("""([k,w,h])=>{const c=document.getElementById('c');c.width=w;c.height=h;
                    const x=c.getContext('2d');WALLS[k].draw(x,w,h);return c.toDataURL('image/jpeg',.92)}""", [key, w, h])
                (OUT / "wallpapers" / f"{key}-{w}x{h}.jpg").write_bytes(base64.b64decode(url.split(",", 1)[1]))
        b.close()
    print("wallpapers:", len(names))
except Exception as e:  # keep going without Playwright; the shell falls back to a gradient
    print("wallpapers skipped:", e)

# ---------------------------------------------------------------- sounds (same synthesis as the web edition)
SR = 48000
TAU = math.pi * 2


def finish(d, fi, fo):
    pk = max(abs(x) for x in d) or 1
    I, O, L = round(fi * SR), round(fo * SR), len(d)
    for i in range(L):
        g = .9 / pk
        if i < I: g *= i / I
        if i > L - O: g *= (L - i) / O
        d[i] *= g
    return d


def clap(seed=7):
    R = random.Random(seed).random
    L = round(SR * .75); d = [0.0] * L

    def one(t0, amp):
        s0 = round(t0 * SR); fc = 1100 + R() * 500; r = .9; w = TAU * fc / SR
        a1, a2 = 2 * r * math.cos(w), -r * r; y1 = y2 = 0.0
        spikes = [0, .006 + R() * .004, .013 + R() * .005, .021 + R() * .006]
        for i in range(round(SR * .2)):
            if s0 + i >= L: break
            t = i / SR; e = 0.0
            for k, sp in enumerate(spikes):
                if t >= sp: e += (1 if k == 3 else .65) * math.exp(-(t - sp) / .0035)
            e += .18 * math.exp(-max(0, t - .021) / .045)
            z = R() * 2 - 1; y = a1 * y1 + a2 * y2 + .32 * z; y2, y1 = y1, y
            d[s0 + i] += amp * e * (y * .85 + z * .25)
    one(.01, 1); one(.2 + R() * .03, .92)
    return finish(d, .001, .1)


def ball(seed=11):
    R = random.Random(seed).random
    L = round(SR * 1.25); d = [0.0] * L
    t, gap, amp = .01, .36 + R() * .04, 1.0; f0 = 210 + R() * 30
    while gap > .02 and t < 1.1:
        s0 = round(t * SR); ph = ph2 = 0.0
        for i in range(round(SR * .12)):
            if s0 + i >= L: break
            x = i / SR; f = f0 * (.62 + .38 * math.exp(-x / .012)); ph += TAU * f / SR; ph2 += TAU * f * 2.6 / SR
            d[s0 + i] += amp * (math.exp(-x / .03) * math.sin(ph) + .28 * math.exp(-x / .012) * math.sin(ph2)
                                + .1 * math.exp(-x / .0018) * (R() * 2 - 1))
        t += gap; gap *= .68; amp *= .66
    return finish(d, .001, .15)


def write_wav(path, d):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(x * 32767)))) for x in d))


write_wav(OUT / "sounds" / "edge-top.wav", clap())
write_wav(OUT / "sounds" / "edge-bottom.wav", ball())
print("sounds: 2")
