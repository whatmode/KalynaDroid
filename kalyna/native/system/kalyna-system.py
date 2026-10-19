#!/usr/bin/env python3
"""kalyna-system: the system side of Kalyna OS (native edition).

The shell (kalyna-shell, C++/Qt) starts this service and talks to it over a Unix socket with one JSON
object per line:

    request   {"id": 7, "cmd": "wifi.connect", "args": {"ssid": "Home", "password": "..."}}
    reply     {"id": 7, "ok": true, "data": {...}}            or  {"id": 7, "ok": false, "error": "..."}
    event     {"event": "battery", "data": {"percent": 81, "charging": false, ...}}

It wraps the real system tools (NetworkManager, PipeWire, brightnessctl, systemd, Waydroid, .desktop
files) and, where a tool is missing (a test machine), answers with believable demo data, so the shell can
always be run and tested. KALYNA_DEMO=1 forces demo mode.
"""
import asyncio, configparser, glob, json, os, re, shlex, shutil, signal, socket, subprocess, sys, time

VERSION = "2.0.0"
DEMO = os.environ.get("KALYNA_DEMO") == "1"
HOME = os.path.expanduser("~")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/kalyna-{os.getuid()}"
SOCK = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RUNTIME, "kalyna-system.sock")
ASSETS = os.environ.get("KALYNA_ASSETS", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"))


def have(tool):
    return not DEMO and shutil.which(tool) is not None


def run(args, timeout=20, env=None):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        return 1, str(e)


def spawn(args, env=None):
    return subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            start_new_session=True, env=env)


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


# ---------------------------------------------------------------- battery
def battery():
    for bat in sorted(glob.glob("/sys/class/power_supply/*")):
        if read(bat + "/type") != "Battery" or DEMO:
            continue
        cap = read(bat + "/capacity")
        if not cap:
            continue
        status = read(bat + "/status")
        ac = any(read(p + "/online") == "1" for p in glob.glob("/sys/class/power_supply/*")
                 if read(p + "/type") in ("Mains", "USB", "USB_C"))
        return {"present": True, "percent": int(cap), "charging": status == "Charging",
                "full": status == "Full", "plugged": ac or status in ("Charging", "Full")}
    if DEMO or not glob.glob("/sys/class/power_supply/*"):
        return {"present": True, "percent": 76, "charging": False, "full": False, "plugged": False, "demo": True}
    return {"present": False, "percent": 100, "charging": False, "full": False, "plugged": True}


# ---------------------------------------------------------------- volume (PipeWire / WirePlumber)
_demo = {"volume": 60, "muted": False, "brightness": 70, "wifi": True, "bt": False, "ssid": "Kalyna Home",
         "known": {"Kalyna Home"}}


def volume():
    if have("wpctl"):
        code, out = run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], 5)
        m = re.search(r"Volume:\s*([\d.]+)", out)
        if code == 0 and m:
            return {"available": True, "percent": round(float(m.group(1)) * 100), "muted": "MUTED" in out}
        return {"available": False, "percent": 0, "muted": True}
    return {"available": True, "percent": _demo["volume"], "muted": _demo["muted"], "demo": True}


def set_volume(percent=None, muted=None):
    if have("wpctl"):
        if percent is not None:
            run(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", f"{max(0, min(100, int(percent)))}%"], 5)
            if muted is None:
                run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"], 5)
        if muted is not None:
            run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if muted else "0"], 5)
    else:
        if percent is not None:
            _demo["volume"] = max(0, min(100, int(percent)))
            _demo["muted"] = False
        if muted is not None:
            _demo["muted"] = bool(muted)
    return volume()


# ---------------------------------------------------------------- brightness
def backlight():
    devs = sorted(glob.glob("/sys/class/backlight/*"))
    return None if DEMO or not devs else devs[0]


def brightness():
    d = backlight()
    if d:
        mx = int(read(d + "/max_brightness", "100") or 100)
        cur = int(read(d + "/brightness", "0") or 0)
        return {"available": True, "percent": round(cur * 100 / max(1, mx))}
    return {"available": DEMO, "percent": _demo["brightness"], "demo": True}


def set_brightness(percent):
    p = max(3, min(100, int(percent)))
    d = backlight()
    if d:
        if shutil.which("brightnessctl"):     # works for the logged-in user through logind, no root needed
            run(["brightnessctl", "-q", "set", f"{p}%"], 5)
        else:
            try:
                mx = int(read(d + "/max_brightness", "100"))
                with open(d + "/brightness", "w") as f:
                    f.write(str(round(mx * p / 100)))
            except OSError:
                pass
    else:
        _demo["brightness"] = p
    return brightness()


# ---------------------------------------------------------------- Wi-Fi (NetworkManager)
def nm_fields(line):
    out, cur, esc = [], "", False
    for ch in line:
        if esc:
            cur += ch; esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def nm_run(args, timeout=5):
    """Run nmcli with stable, parseable output regardless of the user's locale."""
    return run(["nmcli", *args], timeout, env=dict(os.environ, LC_ALL="C", LANG="C"))


def nm_ok():
    if not have("nmcli"):
        return False
    code, out = nm_run(["-t", "-f", "RUNNING", "general"], 5)
    return code == 0 and out.strip().startswith("running")


def kernel_wifi_iface():
    """Find a kernel wireless netdev even if NetworkManager is not ready yet."""
    for path in sorted(glob.glob("/sys/class/net/*/wireless")):
        if os.path.isdir(path):
            return os.path.basename(os.path.dirname(path))
    if shutil.which("iw"):
        code, out = run(["iw", "dev"], 3)
        m = re.search(r"^\s*Interface\s+(\S+)", out, re.M)
        if m:
            return m.group(1)
    return None


DEMO_NETS = [("Kalyna Home", 86, True), ("Kyiv Cafe", 61, False), ("Neighbour 5G", 44, True), ("Library", 30, True)]


def wifi_state(scan=False):
    if not nm_ok():
        if not DEMO:
            iface = kernel_wifi_iface()
            return {"available": bool(iface), "iface": iface or "", "enabled": False, "networks": [],
                    "error": "NetworkManager is not responding. Check that NetworkManager.service is running."}
        nets = [{"ssid": s, "signal": g, "secure": sec, "known": s in _demo["known"]} for s, g, sec in DEMO_NETS]
        return {"available": True, "enabled": _demo["wifi"], "ssid": _demo["ssid"] if _demo["wifi"] else "",
                "ip": "192.168.1.42" if _demo["ssid"] and _demo["wifi"] else "", "networks": nets if _demo["wifi"] else [],
                "demo": True}
    code, out = nm_run(["-t", "-f", "WIFI", "radio"], 5)
    enabled = out.strip().startswith("enabled")
    dev = None
    for l in nm_run(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], 5)[1].splitlines():
        f = nm_fields(l)
        if len(f) >= 4 and f[1] == "wifi":
            dev = f
            break
    if not dev:
        iface = kernel_wifi_iface()
        if iface:
            return {"available": True, "enabled": enabled, "iface": iface, "networks": [],
                    "error": "Wi-Fi hardware is detected, but NetworkManager is not managing it. Restart NetworkManager and check rfkill."}
        return {"available": False,
                "error": "No wireless interface is visible to Linux. Check that the Steam Deck Wi-Fi driver and firmware loaded; on OLED models, check QCA2066/ath11k firmware."}
    known = {f[0] for f in map(nm_fields, nm_run(["-t", "-f", "NAME,TYPE", "connection", "show"], 5)[1].splitlines())
             if len(f) >= 2 and f[1] in ("802-11-wireless", "wifi")}
    nets, cur = {}, ""
    if enabled:
        code, out = nm_run(["-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list",
                           "--rescan", "yes" if scan else "auto"], 20)
        for l in out.splitlines():
            f = nm_fields(l)
            if len(f) < 4 or not f[1]:
                continue
            if f[0] == "*":
                cur = f[1]
            sig = int(f[2] or 0)
            if f[1] not in nets or nets[f[1]]["signal"] < sig:
                nets[f[1]] = {"ssid": f[1], "signal": sig, "secure": bool(f[3] and f[3] != "--"), "known": f[1] in known}
    connected = dev[2] == "connected"
    ip = nm_run(["-g", "IP4.ADDRESS", "device", "show", dev[0]], 5)[1].strip().split("/")[0] if connected else ""
    return {"available": True, "enabled": enabled, "iface": dev[0], "ssid": (cur or dev[3]) if connected else "",
            "ip": ip, "networks": sorted(nets.values(), key=lambda n: -n["signal"])}


def wifi_connect(ssid, password=""):
    if not nm_ok():
        if not DEMO:
            return {"ok": False, "error": "NetworkManager is not running."}
        _demo["ssid"] = ssid
        _demo["known"].add(ssid)
        return {"ok": True}
    known = ssid in {f[0] for f in map(nm_fields, nm_run(["-t", "-f", "NAME", "connection", "show"], 5)[1].splitlines())}
    if known and not password:
        code, out = nm_run(["connection", "up", "id", ssid], 60)
    else:
        if known:
            nm_run(["connection", "delete", "id", ssid], 15)
        args = ["device", "wifi", "connect", ssid] + (["password", password] if password else [])
        code, out = nm_run(args, 60)
    return {"ok": code == 0, "error": "" if code == 0 else out.strip().splitlines()[-1][:200] if out.strip() else "failed"}


def wifi_forget(ssid):
    if not nm_ok():
        if not DEMO:
            return {"ok": False, "error": "NetworkManager is not running."}
        _demo["known"].discard(ssid)
        if _demo["ssid"] == ssid:
            _demo["ssid"] = ""
        return {"ok": True}
    nm_run(["connection", "delete", "id", ssid], 15)
    return {"ok": True}


def wifi_enable(on):
    if not nm_ok():
        if not DEMO:
            return wifi_state()
        _demo["wifi"] = bool(on)
        return wifi_state()
    nm_run(["radio", "wifi", "on" if on else "off"], 10)
    return wifi_state()


# ---------------------------------------------------------------- Bluetooth
def bt_state():
    if have("bluetoothctl"):
        code, out = run(["bluetoothctl", "show"], 5)
        if code != 0 or "Controller" not in out:
            return {"available": False, "enabled": False}
        return {"available": True, "enabled": "Powered: yes" in out}
    return {"available": True, "enabled": _demo["bt"], "demo": True}


def bt_enable(on):
    if have("bluetoothctl"):
        if shutil.which("rfkill"):
            run(["rfkill", "unblock", "bluetooth"], 5)
        run(["bluetoothctl", "power", "on" if on else "off"], 10)
    else:
        _demo["bt"] = bool(on)
    return bt_state()


# ---------------------------------------------------------------- power
def power(action):
    cmd = {"off": "poweroff", "restart": "reboot", "suspend": "suspend"}.get(action)
    if not cmd:
        return {"ok": False}
    if DEMO or not shutil.which("systemctl"):
        return {"ok": True, "demo": True}
    spawn(["systemctl", cmd])
    return {"ok": True}


# ---------------------------------------------------------------- apps (.desktop files and Waydroid)
APP_DIRS = ["/usr/share/applications", "/usr/local/share/applications", os.path.join(HOME, ".local/share/applications")]
SKIP = re.compile(r"^(kalyna|org\.freedesktop\.|xdg-|nm-|lxc|cage|avahi|bssh|bvnc|qv4l2|qvidcap|electron|"
                  r"org\.kde\.(kded|plasma|kwin)|cmake|htop|vim|nvim|uxterm|xterm|org\.gnome\.Shell)", re.I)
ICON_THEMES = ["hicolor", "breeze", "Adwaita", "Papirus"]


def find_icon(name):
    if not name:
        return ""
    if os.path.isabs(name):
        return name if os.path.isfile(name) else ""
    for size in ("scalable", "256x256", "128x128", "512x512", "96x96", "64x64", "48x48"):
        for theme in ICON_THEMES:
            for ext in ("svg", "png"):
                for kind in ("apps", "applications"):
                    p = f"/usr/share/icons/{theme}/{size}/{kind}/{name}.{ext}"
                    if os.path.isfile(p):
                        return p
    for ext in ("svg", "png"):
        p = f"/usr/share/pixmaps/{name}.{ext}"
        if os.path.isfile(p):
            return p
    return ""


def desktop_entry(path):
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        return cp["Desktop Entry"]
    except Exception:
        return None


def linux_apps():
    out, seen = [], set()
    for d in APP_DIRS:
        for f in sorted(glob.glob(os.path.join(d, "*.desktop"))):
            aid = os.path.basename(f)[:-8]
            if aid in seen or SKIP.match(aid):
                continue
            e = desktop_entry(f)
            if not e or e.get("Type") != "Application" or e.get("NoDisplay", "").lower() == "true" or \
                    e.get("Hidden", "").lower() == "true" or not e.get("Exec") or e.get("Terminal", "").lower() == "true":
                continue
            seen.add(aid)
            kind = "android" if aid.startswith("waydroid.") else "linux"
            out.append({"id": aid, "name": e.get("Name", aid), "comment": e.get("Comment", ""), "kind": kind,
                        "icon": find_icon(e.get("Icon", "")), "exec": e.get("Exec", ""),
                        "categories": e.get("Categories", ""), "wmclass": e.get("StartupWMClass", "")})
    if DEMO and not out:
        out = [{"id": a, "name": n, "comment": c, "kind": "linux", "icon": "", "exec": "true", "categories": "", "wmclass": ""}
               for a, n, c in (("org.mozilla.firefox", "Firefox", "Web browser"), ("foot", "Foot", "Terminal"),
                               ("org.gnome.Calculator", "Calculator", "Arithmetic"))]
    return sorted(out, key=lambda a: a["name"].lower())


_launched = {}


def launch(aid):
    for a in linux_apps():
        if a["id"] == aid:
            args = [x for x in shlex.split(a["exec"]) if not re.fullmatch(r"%[a-zA-Z]", x)]
            env = dict(os.environ)
            # Kalyna is a Wayland compositor without X11: ask toolkits for Wayland
            env.update({"QT_QPA_PLATFORM": "wayland", "GDK_BACKEND": "wayland", "SDL_VIDEODRIVER": "wayland",
                        "MOZ_ENABLE_WAYLAND": "1", "ELECTRON_OZONE_PLATFORM_HINT": "wayland",
                        "XDG_SESSION_TYPE": "wayland"})
            env.pop("DISPLAY", None)
            if os.path.basename(args[0]) in ("chromium", "google-chrome-stable", "chrome", "brave", "code", "electron"):
                args.insert(1, "--ozone-platform=wayland")
            if DEMO and a["exec"] == "true":          # a made-up demo entry
                return {"ok": True, "demo": True}
            try:
                p = spawn(args, env)
                _launched[p.pid] = p
                return {"ok": True, "pid": p.pid}
            except OSError as e:
                return {"ok": False, "error": str(e)}
    return {"ok": False, "error": "no such app"}


def run_command(cmd):
    """start a program by command line (e.g. from Kalyna search: '> foot')"""
    env = dict(os.environ, QT_QPA_PLATFORM="wayland", GDK_BACKEND="wayland", MOZ_ENABLE_WAYLAND="1")
    env.pop("DISPLAY", None)
    try:
        spawn(["sh", "-c", cmd], env)
        return {"ok": True}
    except OSError as e:
        return {"ok": False, "error": str(e)}


# ---------------------------------------------------------------- Android (Waydroid)
def android_state():
    if not have("waydroid"):
        return {"installed": False}
    code, out = run(["waydroid", "status"], 15)
    st = {"installed": True, "initialized": os.path.exists("/var/lib/waydroid/waydroid.cfg")}
    for line in out.splitlines():
        m = re.match(r"\s*([A-Za-z ]+):\s*(.*)", line)
        if m:
            st[m.group(1).strip().lower().replace(" ", "_")] = m.group(2).strip()
    st["running"] = st.get("session", "").upper() == "RUNNING"
    return st


def android_start():
    if not have("waydroid"):
        return {"ok": False, "error": "Android (Waydroid) is not installed"}
    env = dict(os.environ)
    spawn(["waydroid", "session", "start"], env)
    return {"ok": True}


def android_stop():
    if have("waydroid"):
        run(["waydroid", "session", "stop"], 60)
    return {"ok": True}


# ---------------------------------------------------------------- sound effects
_last_sound = [0.0]


def play(name, volume=0.6):
    if time.time() - _last_sound[0] < 0.25:
        return {"ok": True, "skipped": True}
    _last_sound[0] = time.time()
    path = os.path.join(ASSETS, "sounds", os.path.basename(name) + ".wav")
    if not os.path.isfile(path) or DEMO:
        return {"ok": os.path.isfile(path), "demo": DEMO}
    v = max(0.0, min(1.0, float(volume)))
    if shutil.which("pw-play"):
        spawn(["pw-play", "--volume", f"{v:.2f}", path])
    elif shutil.which("paplay"):
        spawn(["paplay", f"--volume={int(v * 65536)}", path])
    elif shutil.which("aplay"):
        spawn(["aplay", "-q", path])
    return {"ok": True}


# ---------------------------------------------------------------- system info
def info():
    mem = read("/proc/meminfo")
    total = int(re.search(r"MemTotal:\s+(\d+)", mem).group(1)) // 1024 if "MemTotal" in mem else 0
    avail = int(re.search(r"MemAvailable:\s+(\d+)", mem).group(1)) // 1024 if "MemAvailable" in mem else 0
    cpu = re.search(r"model name\s*:\s*(.*)", read("/proc/cpuinfo"))
    product = read("/sys/class/dmi/id/product_name")
    model = {"Jupiter": "Steam Deck (LCD)", "Galileo": "Steam Deck (OLED)"}.get(product, product or "PC")
    osr = dict(re.findall(r'^(\w+)="?([^"\n]*)"?', read("/etc/os-release"), re.M))
    return {"version": VERSION, "host": socket.gethostname(), "kernel": os.uname().release, "arch": os.uname().machine,
            "model": model, "product": product, "cpu": cpu.group(1).strip() if cpu else "", "cores": os.cpu_count(),
            "memTotalMB": total, "memAvailMB": avail, "base": osr.get("PRETTY_NAME", ""), "user": os.environ.get("USER", ""),
            "demo": DEMO, "uptime": int(float(read("/proc/uptime", "0 0").split()[0]))}


# ---------------------------------------------------------------- dispatch
COMMANDS = {
    "info": lambda a: info(),
    "battery": lambda a: battery(),
    "volume.get": lambda a: volume(),
    "volume.set": lambda a: set_volume(a.get("percent"), a.get("muted")),
    "brightness.get": lambda a: brightness(),
    "brightness.set": lambda a: set_brightness(a.get("percent", 50)),
    "wifi.state": lambda a: wifi_state(bool(a.get("scan"))),
    "wifi.connect": lambda a: wifi_connect(str(a.get("ssid", "")), str(a.get("password", ""))),
    "wifi.forget": lambda a: wifi_forget(str(a.get("ssid", ""))),
    "wifi.enable": lambda a: wifi_enable(bool(a.get("on"))),
    "bt.state": lambda a: bt_state(),
    "bt.enable": lambda a: bt_enable(bool(a.get("on"))),
    "power": lambda a: power(str(a.get("action", ""))),
    "apps.list": lambda a: linux_apps(),
    "apps.launch": lambda a: launch(str(a.get("id", ""))),
    "apps.run": lambda a: run_command(str(a.get("cmd", ""))),
    "android.state": lambda a: android_state(),
    "android.start": lambda a: android_start(),
    "android.stop": lambda a: android_stop(),
    "sound.play": lambda a: play(str(a.get("name", "")), a.get("volume", 0.6)),
    "ping": lambda a: {"pong": True, "version": VERSION},
}

clients = set()


async def broadcast(event, data):
    msg = (json.dumps({"event": event, "data": data}) + "\n").encode()
    for w in list(clients):
        try:
            w.write(msg)
            await w.drain()
        except Exception:
            clients.discard(w)


async def handle(reader, writer):
    clients.add(writer)
    loop = asyncio.get_running_loop()
    try:
        while True:
            line = await reader.readline()
            if not line:
                break
            try:
                req = json.loads(line)
            except ValueError:
                continue
            rid, cmd, args = req.get("id"), req.get("cmd", ""), req.get("args") or {}
            fn = COMMANDS.get(cmd)
            if not fn:
                resp = {"id": rid, "ok": False, "error": f"unknown command {cmd}"}
            else:
                try:
                    data = await loop.run_in_executor(None, fn, args)   # slow tools never block other requests
                    resp = {"id": rid, "ok": True, "data": data}
                except Exception as e:  # report, never crash the service
                    resp = {"id": rid, "ok": False, "error": f"{type(e).__name__}: {e}"}
            writer.write((json.dumps(resp) + "\n").encode())
            await writer.drain()
            if cmd in ("volume.set", "brightness.set", "wifi.enable", "wifi.connect", "wifi.forget", "bt.enable"):
                ev = {"volume.set": "volume", "brightness.set": "brightness", "bt.enable": "bt"}.get(cmd, "wifi")
                await broadcast(ev, resp.get("data") if ev != "wifi" else await loop.run_in_executor(None, wifi_state))
    finally:
        clients.discard(writer)
        writer.close()


async def watcher():
    """push changes the shell shows all the time: battery, volume, brightness, Wi-Fi connection"""
    loop = asyncio.get_running_loop()
    last = {}
    tick = 0
    while True:
        await asyncio.sleep(2)
        tick += 1
        for pid, p in list(_launched.items()):          # reap apps that have quit
            if p.poll() is not None:
                del _launched[pid]
        if not clients:
            continue
        checks = [("battery", battery), ("volume", volume), ("brightness", brightness)]
        if tick % 5 == 0:
            checks.append(("wifi", wifi_state))
            checks.append(("bt", bt_state))
        for name, fn in checks:
            try:
                v = await loop.run_in_executor(None, fn)
            except Exception:
                continue
            key = json.dumps(v, sort_keys=True)
            if last.get(name) != key:
                last[name] = key
                await broadcast(name, v)


async def main():
    os.makedirs(os.path.dirname(SOCK), exist_ok=True)
    try:
        os.unlink(SOCK)
    except OSError:
        pass
    server = await asyncio.start_unix_server(handle, path=SOCK)
    os.chmod(SOCK, 0o600)
    print(f"kalyna-system {VERSION} listening on {SOCK}{' (demo mode)' if DEMO else ''}", flush=True)
    asyncio.create_task(watcher())
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
