#!/usr/bin/env python3
"""Upload a large file to FEX.net using its anonymous chunked-upload API.

Run from a machine/network where FEX.net permits API access:
  python3 tools/upload-fex.py KalynaOS-CachyOS-Handheld-SteamDeck.img.xz
"""
import json
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.fex.net/api/v1"
CHUNK_SIZE = 4 * 1024 * 1024


def request(url, method="GET", data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=300) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc


def main():
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} FILE")
    path = pathlib.Path(sys.argv[1]).expanduser().resolve()
    if not path.is_file():
        raise SystemExit(f"File not found: {path}")
    size = path.stat().st_size
    print(f"File: {path.name} ({size:,} bytes)", flush=True)

    _, raw = request(API + "/anonymous/upload-token")
    token = json.loads(raw)["token"]
    auth = {"authorization": "Bearer " + token}
    metadata = json.dumps({
        "directory_id": None,
        "size": size,
        "name": path.name,
    }).encode()
    _, raw = request(
        API + "/anonymous/file",
        "POST",
        metadata,
        {**auth, "content-type": "application/json"},
    )
    init = json.loads(raw)
    upload_url = init.get("location")
    file_key = init.get("anon_upload_link")
    if not upload_url or not file_key:
        raise RuntimeError("FEX did not return upload location and public link key")

    status, _ = request(
        upload_url,
        "POST",
        b"",
        {
            **auth,
            "fsp-filename": urllib.parse.quote(path.name),
            "fsp-size": str(size),
            "fsp-version": "1.0.0",
        },
    )
    if status not in (200, 201, 204):
        raise RuntimeError(f"FEX resource creation returned HTTP {status}")

    offset = 0
    with path.open("rb") as source:
        while True:
            chunk = source.read(CHUNK_SIZE)
            if not chunk:
                break
            status, _ = request(
                upload_url,
                "PATCH",
                chunk,
                {
                    **auth,
                    "content-type": "application/offset+octet-stream",
                    "fsp-offset": str(offset),
                    "fsp-version": "1.0.0",
                },
            )
            offset += len(chunk)
            print(f"Uploaded {offset:,}/{size:,} bytes ({offset * 100 / size:.1f}%)", flush=True)
            if offset < size and status != 204:
                raise RuntimeError(f"FEX intermediate chunk returned HTTP {status}")
            if offset == size and status not in (200, 204):
                raise RuntimeError(f"FEX final chunk returned HTTP {status}")

    print("\nUpload complete. Share this link:")
    print("https://fex.net/s/" + file_key)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Upload failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
