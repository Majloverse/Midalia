#!/usr/bin/env python3
"""Fetch 1 m LiDAR elevation tiles (DSM first return and DTM) for central Milan, then mosaic them.

Source: MASE (Italian Ministry of Environment), Piano Straordinario di Telerilevamento Ambientale,
LiDAR flown 2009-2010, product LIDAR_2014, CC BY 4.0. Download app: https://sim.mase.gov.it/pst/

Request flow (the same one the app's cart widget uses, no login needed):
  1. List the 1x1 tiles (0.01 x 0.01 degrees) in the box from the public grid FeatureServer.
  2. POST {canale, prodotto, layer, tileList} to /core/api/esri/api/v1/downloads -> idSessione.
  3. Poll GET /downloads/{idSessione} until status is "ready"; it lists one zip URL per file.
  4. Download each zip (the URL host is internal, so it is re-hosted under sim.mase.gov.it),
     keep only the GeoTIFFs, then POST /downloads/{idSessione}/ack.

Tiles go to sources/lidar/tiles/{dsm_first,dtm}/<tavola>.tif; tiles already there are skipped,
so the script resumes after an interruption. Then sources/lidar/dsm.tif and dtm.tif are written:
float32 GeoTIFF, EPSG:4326, 0.00001 degree pixels, nodata -9999.

Needs only the standard library, plus numpy for the mosaics.
Run:  python3 -I world/milan/get_lidar.py            (download what is missing, then mosaic)
      python3 -I world/milan/get_lidar.py --dry-run  (list the tiles only)
      python3 -I world/milan/get_lidar.py --mosaic-only
"""
import argparse
import http.cookiejar
import json
import os
import re
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

# Box around the game map (a 3800 m circle around the Duomo, 45.4641 N 9.1919 E).
LAT_MIN, LAT_MAX = 45.4300, 45.4982
LON_MIN, LON_MAX = 9.1430, 9.2410

GRID_URL = ("https://gis.platform.sim.mase.gov.it/portalgis/rest/services/Hosted/"
            "Grigliato_lidar/FeatureServer/2/query")  # layer 2 = 1x1 grid
API = "https://sim.mase.gov.it/core/api/esri/api/v1/downloads"
CANALE, PRODOTTO = "PST2", "LIDAR_2014"
# Our folder name -> (API layer, suffix of the TIFF name inside the zip, mosaic file name).
LAYERS = {
    "dsm_first": ("dsm_first_1x1", "DSMFirst", "dsm.tif"),
    "dtm": ("dtm_1x1", "DTM", "dtm.tif"),
}
NODATA = -9999.0
USER_AGENT = "lidar-tile-fetch/1.0 (python-urllib; sequential, polite)"
PAUSE = 2.0             # seconds between requests to the API
POLL_TIMEOUT = 20 * 60  # give up on one session after this long
MAX_TILE_BYTES = 64 << 20

HERE = Path(__file__).resolve().parent
OUT = HERE / "sources" / "lidar"
TILES = OUT / "tiles"
SESSIONS = TILES / "_sessions.json"  # sessions requested but not yet downloaded
MISSING = TILES / "_missing.json"    # tiles the server returned empty (not surveyed)

TAVOLA_RE = re.compile(r"^D(\d{4})(\d{4})_0101$")
FILE_PATH_RE = re.compile(r"^/api/v1/downloads/[0-9a-f]{16,64}/file/\d{1,12}$")

_opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))


def log(msg):
    print(msg, flush=True)


# ---------------------------------------------------------------- HTTP with polite retries

def request(url, data=None, method=None, timeout=120, attempts=6, dest=None, max_bytes=None):
    """GET/POST with retries and exponential backoff. Returns bytes, or writes to dest."""
    body = None
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json, */*"}
    if data is not None:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    for attempt in range(attempts):
        try:
            req = urllib.request.Request(url, data=body, headers=headers, method=method)
            with _opener.open(req, timeout=timeout) as resp:
                if dest is None:
                    return resp.read(max_bytes + 1 if max_bytes else -1)
                part = dest.with_name(dest.name + ".part")
                n = 0
                with open(part, "wb") as f:
                    while chunk := resp.read(1 << 20):
                        n += len(chunk)
                        if max_bytes and n > max_bytes:
                            raise ValueError(f"download larger than {max_bytes} bytes")
                        f.write(chunk)
                os.replace(part, dest)
                return n
        except urllib.error.HTTPError as e:
            retryable = e.code in (408, 425, 429) or e.code >= 500
            if not retryable or attempt == attempts - 1:
                raise
            wait = e.headers.get("Retry-After")
            wait = float(wait) if wait and wait.isdigit() else 5 * 2 ** attempt
            log(f"  HTTP {e.code} on {url}; retry in {min(wait, 300):.0f} s")
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as e:
            if attempt == attempts - 1:
                raise
            wait = 5 * 2 ** attempt
            log(f"  {type(e).__name__}: {e}; retry in {wait} s")
        time.sleep(min(wait, 300))


def get_json(url, data=None, method=None):
    return json.loads(request(url, data=data, method=method, max_bytes=8 << 20))


# ---------------------------------------------------------------- tile list

def tile_bounds(tavola):
    m = TAVOLA_RE.match(tavola)
    lat0, lon0 = int(m.group(1)) / 100, int(m.group(2)) / 100
    return lon0, lat0, lon0 + 0.01, lat0 + 0.01


def list_tiles():
    """1x1 grid cells whose interior overlaps the box, as dicts with fid/tavola/regione/contratto."""
    cache = TILES / "_grid_1x1.json"
    if cache.exists():
        feats = json.loads(cache.read_text())
    else:
        q = urllib.parse.urlencode({
            "geometry": f"{LON_MIN},{LAT_MIN},{LON_MAX},{LAT_MAX}",
            "geometryType": "esriGeometryEnvelope", "inSR": 4326,
            "spatialRel": "esriSpatialRelIntersects",
            "outFields": "fid,tavola,regione,contratto,data",
            "returnGeometry": "false", "f": "json",
        })
        d = get_json(f"{GRID_URL}?{q}")
        if "features" not in d or d.get("exceededTransferLimit"):
            raise SystemExit(f"unexpected grid response: {str(d)[:300]}")
        feats = [f["attributes"] for f in d["features"]]
        cache.write_text(json.dumps(feats, indent=1))
    tiles = []
    for a in feats:
        tav = str(a.get("tavola", ""))
        if not TAVOLA_RE.match(tav):
            continue
        x0, y0, x1, y1 = tile_bounds(tav)
        if x0 < LON_MAX and x1 > LON_MIN and y0 < LAT_MAX and y1 > LAT_MIN:  # strict: drop edge-touching
            tiles.append({"fid": str(a["fid"]), "tavola": tav, "regione": str(a.get("regione") or ""),
                          "contratto": str(a.get("contratto") or ""), "data": str(a.get("data") or "")})
    return sorted(tiles, key=lambda t: t["tavola"])


# ---------------------------------------------------------------- minimal GeoTIFF reader/writer

_TSIZE = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8}
_TFMT = {1: "B", 3: "H", 4: "I", 6: "b", 8: "h", 9: "i", 11: "f", 12: "d"}


def read_tiff(path):
    """Read a single-band, uncompressed, stripped float32 GeoTIFF. Returns (array, info)."""
    import numpy as np
    with open(path, "rb") as f:
        buf = f.read()
    bo = {b"II": "<", b"MM": ">"}.get(buf[:2])
    if bo is None or struct.unpack(bo + "H", buf[2:4])[0] != 42:
        raise ValueError("not a classic TIFF")
    off = struct.unpack(bo + "I", buf[4:8])[0]
    n = struct.unpack(bo + "H", buf[off:off + 2])[0]
    tags = {}
    for i in range(n):
        e = off + 2 + 12 * i
        tag, typ, cnt = struct.unpack(bo + "HHI", buf[e:e + 8])
        size = _TSIZE.get(typ, 1) * cnt
        voff = e + 8 if size <= 4 else struct.unpack(bo + "I", buf[e + 8:e + 12])[0]
        raw = buf[voff:voff + size]
        if typ == 2:
            tags[tag] = raw.rstrip(b"\0").decode("latin-1")
        elif typ in _TFMT:
            tags[tag] = struct.unpack(f"{bo}{cnt}{_TFMT[typ]}", raw)
    w, h = tags[256][0], tags[257][0]
    if tags.get(259, (1,))[0] != 1 or tags.get(277, (1,))[0] != 1 or 322 in tags:
        raise ValueError("only uncompressed, single-band, stripped TIFFs are supported")
    if tags.get(258, (0,))[0] != 32 or tags.get(339, (1,))[0] != 3:
        raise ValueError("expected float32 samples")
    data = b"".join(buf[o:o + c] for o, c in zip(tags[273], tags[279]))
    if len(data) < w * h * 4:
        raise ValueError("truncated pixel data")
    arr = np.frombuffer(data[:w * h * 4], dtype=bo + "f4").reshape(h, w).astype("<f4")
    sx, sy = tags[33550][:2]
    i, j, _, x, y, _ = tags[33922][:6]
    keys = tags.get(34735, ())
    geo = {keys[k]: keys[k + 3] for k in range(4, len(keys), 4) if keys[k + 1] == 0}
    if geo.get(2048) != 4326 and geo.get(1024) != 2:
        raise ValueError(f"unexpected CRS keys {geo}")
    half = 0.5 if geo.get(1025) == 2 else 0.0  # RasterPixelIsPoint: tiepoint is a pixel centre
    x0 = x - (i + half) * sx
    y1 = y + (j + half) * sy
    nod = tags.get(42113)
    return arr, {"x0": x0, "y1": y1, "sx": sx, "sy": sy, "w": w, "h": h,
                 "nodata": float(nod) if nod not in (None, "") else None}


def write_tiff(path, arr, x0, y1, sx, sy, nodata):
    """Write a little-endian, uncompressed, stripped float32 GeoTIFF (EPSG:4326, PixelIsArea)."""
    import numpy as np
    arr = np.ascontiguousarray(arr, dtype="<f4")
    h, w = arr.shape
    rps = max(1, (1 << 21) // (w * 4))  # about 2 MB per strip
    nstrips = (h + rps - 1) // rps
    counts = [min(rps, h - k * rps) * w * 4 for k in range(nstrips)]
    nod = f"{nodata:g}".encode() + b"\0"
    geokeys = (1, 1, 0, 4, 1024, 0, 1, 2, 1025, 0, 1, 1, 2048, 0, 1, 4326, 2054, 0, 1, 9102)
    entries = [  # (tag, type, values)
        (256, 4, (w,)), (257, 4, (h,)), (258, 3, (32,)), (259, 3, (1,)), (262, 3, (1,)),
        (273, 4, None), (277, 3, (1,)), (278, 4, (rps,)), (279, 4, tuple(counts)),
        (284, 3, (1,)), (339, 3, (3,)),
        (33550, 12, (sx, sy, 0.0)), (33922, 12, (0.0, 0.0, 0.0, x0, y1, 0.0)),
        (34735, 3, geokeys), (42113, 2, nod),
    ]
    ifd_off = 8
    extra_off = ifd_off + 2 + 12 * len(entries) + 4
    # Lay out out-of-line values, then pixel data.
    extra, placed = bytearray(), {}
    for tag, typ, vals in entries:
        cnt = len(vals) if vals is not None else nstrips
        if _TSIZE[typ] * cnt > 4:
            placed[tag] = extra_off + len(extra)
            extra += b"\0" * (_TSIZE[typ] * cnt)
            if len(extra) % 2:
                extra += b"\0"
    data_off = extra_off + len(extra)
    offsets = tuple(data_off + sum(counts[:k]) for k in range(nstrips))
    ifd = bytearray(struct.pack("<H", len(entries)))
    for tag, typ, vals in entries:
        if tag == 273:
            vals = offsets
        raw = vals if typ == 2 else struct.pack(f"<{len(vals)}{_TFMT[typ]}", *vals)
        cnt = len(vals)
        if tag in placed:
            p = placed[tag] - extra_off
            extra[p:p + len(raw)] = raw
            ifd += struct.pack("<HHII", tag, typ, cnt, placed[tag])
        else:
            ifd += struct.pack("<HHI", tag, typ, cnt) + raw.ljust(4, b"\0")
    ifd += struct.pack("<I", 0)
    tmp = path.with_name(path.name + ".part")
    with open(tmp, "wb") as f:
        f.write(b"II*\0" + struct.pack("<I", ifd_off))
        f.write(ifd)
        f.write(extra)
        f.write(arr.tobytes())
    os.replace(tmp, path)


# ---------------------------------------------------------------- download

def load_json(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def save_json(path, obj):
    tmp = path.with_name(path.name + ".part")
    tmp.write_text(json.dumps(obj, indent=1))
    os.replace(tmp, path)


def public_url(raw):
    """The status lists the internal gateway URL; re-host it under the public API prefix."""
    path = urllib.parse.urlparse(raw).path
    if path.startswith("/core/api/esri/"):
        path = path[len("/core/api/esri"):]
    if not FILE_PATH_RE.match(path):
        raise ValueError(f"unexpected file URL {raw!r}")
    return "https://sim.mase.gov.it/core/api/esri" + path


def extract_tiles(zpath, folder, suffix, wanted):
    """Copy the wanted tile TIFFs out of a downloaded zip. Returns ({tavola: bytes}, [empty tavole])."""
    got, empty = {}, []
    name_re = re.compile(r"^[A-Za-z_]+_[0-9 ]*_(D\d{8}_0101)_" + suffix + r"\.tiff?$")
    with zipfile.ZipFile(zpath) as z:
        for info in z.infolist():
            m = name_re.match(info.filename)
            if not m or m.group(1) not in wanted:
                continue
            tav = m.group(1)
            if info.file_size == 0:
                empty.append(tav)
                continue
            if info.file_size > MAX_TILE_BYTES:
                raise ValueError(f"{info.filename} is {info.file_size} bytes, too large")
            dest = TILES / folder / f"{tav}.tif"
            tmp = dest.with_name(dest.name + ".part")
            tmp.write_bytes(z.read(info))
            arr, g = read_tiff(tmp)  # validate before keeping it
            x0, y0, _, y1 = tile_bounds(tav)
            if abs(g["x0"] - x0) > 1e-6 or abs(g["y1"] - y1) > 1e-6:
                raise ValueError(f"{tav}: georeference {g['x0']},{g['y1']} does not match the name")
            os.replace(tmp, dest)
            got[tav] = info.file_size
    return got, empty


def run_session(folder, sid, batch, done, total, missing):
    """Wait for a session, download and unpack its files, ack it. Returns tiles finished."""
    api_layer, suffix, _ = LAYERS[folder]
    wanted = {t["tavola"] for t in batch}
    start = time.time()
    delay = 5
    while True:
        st = get_json(f"{API}/{sid}")
        status = st.get("status")
        urls = st.get("urls") or []
        expected = int(st.get("expected") or 0)
        if status == "error":
            log(f"  session {sid}: error ({st.get('reason')}); tiles left for the next run")
            return 0
        if st.get("consumed") and not urls:
            return 0
        if status == "ready" and urls and len(urls) >= expected:
            break
        if time.time() - start > POLL_TIMEOUT:
            log(f"  session {sid}: still {status} after {POLL_TIMEOUT // 60} min; tiles left for the next run")
            return 0
        time.sleep(delay)
        delay = min(delay * 1.5, 30)
    incoming = TILES / "_incoming"
    incoming.mkdir(exist_ok=True)
    finished = 0
    for k, raw in enumerate(urls):
        zpath = incoming / f"{sid}_{k}.zip"
        size = request(public_url(raw), dest=zpath, timeout=600,
                       max_bytes=MAX_TILE_BYTES * (len(batch) + 1))
        got, empty = extract_tiles(zpath, folder, suffix, wanted)
        zpath.unlink()
        for tav in sorted(got):
            finished += 1
            log(f"{folder} tile {done + finished}/{total} {tav} ok ({got[tav] / 1e6:.1f} MB)")
        for tav in sorted(empty):
            finished += 1
            missing.setdefault(folder, [])
            if tav not in missing[folder]:
                missing[folder].append(tav)
            log(f"{folder} tile {done + finished}/{total} {tav} empty on the server (not surveyed)")
        wanted -= set(got) | set(empty)
        time.sleep(PAUSE)
    save_json(MISSING, missing)
    for tav in sorted(wanted):
        log(f"  {tav} was not in the {sid} files; left for the next run")
    try:
        request(f"{API}/{sid}/ack", data={}, method="POST", attempts=2)
    except Exception as e:  # ack is best effort
        log(f"  ack failed for {sid}: {e}")
    return finished


def download(tiles, folders, batch_size):
    missing = load_json(MISSING, {})
    sessions = load_json(SESSIONS, {})
    for folder in folders:
        (TILES / folder).mkdir(parents=True, exist_ok=True)
    # Finish sessions a previous run requested but did not download.
    for sid, s in list(sessions.items()):
        if s["folder"] not in folders:
            continue
        log(f"resuming session {sid} ({len(s['tiles'])} {s['folder']} tiles)")
        try:
            run_session(s["folder"], sid, s["tiles"], 0, len(s["tiles"]), missing)
        except Exception as e:  # expired or broken: its tiles are simply requested again
            log(f"  session {sid} could not be resumed ({type(e).__name__}: {e}); will request again")
        del sessions[sid]
        save_json(SESSIONS, sessions)
    for folder in folders:
        api_layer = LAYERS[folder][0]
        total = len(tiles)
        todo, done = [], 0
        for t in tiles:
            if (TILES / folder / f"{t['tavola']}.tif").exists():
                done += 1
            elif t["tavola"] in missing.get(folder, []) or not t["contratto"].strip():
                done += 1
                log(f"{folder} tile {done}/{total} {t['tavola']} skipped (not surveyed)")
            else:
                todo.append(t)
        log(f"{folder}: {done}/{total} tiles already handled, {len(todo)} to download")
        for b in range(0, len(todo), batch_size):
            batch = todo[b:b + batch_size]
            payload = {"canale": CANALE, "prodotto": PRODOTTO, "layer": api_layer,
                       "tileList": [{k: t[k] for k in ("fid", "tavola", "regione", "contratto")}
                                    for t in batch],
                       "metadataList": []}
            resp = get_json(API, data=payload, method="POST")
            sid = resp.get("idSessione")
            reason = resp.get("reason") or (resp.get("upstream") or {}).get("reason")
            if reason != "OK" or not sid or not re.fullmatch(r"[0-9a-f]{16,64}", sid):
                log(f"  request refused for {len(batch)} tiles: {str(resp)[:300]}")
                time.sleep(PAUSE)
                continue
            sessions[sid] = {"folder": folder, "tiles": batch}
            save_json(SESSIONS, sessions)
            log(f"  session {sid}: {len(batch)} {api_layer} tiles requested")
            done += run_session(folder, sid, batch, done, total, missing)
            del sessions[sid]
            save_json(SESSIONS, sessions)
            time.sleep(PAUSE)
    try:
        (TILES / "_incoming").rmdir()  # only if empty
    except OSError:
        pass


# ---------------------------------------------------------------- mosaic

def mosaic(folder):
    import numpy as np
    files = sorted((TILES / folder).glob("D*_0101.tif"))
    if not files:
        log(f"{folder}: no tiles, no mosaic")
        return
    _, g0 = read_tiff(files[0])
    sx, sy = g0["sx"], g0["sy"]
    x0 = round(LON_MIN / sx) * sx
    y1 = round(LAT_MAX / sy) * sy
    w = round((LON_MAX - LON_MIN) / sx)
    h = round((LAT_MAX - LAT_MIN) / sy)
    out = np.full((h, w), NODATA, dtype="<f4")
    used = 0
    for p in files:
        arr, g = read_tiff(p)
        if abs(g["sx"] - sx) > 1e-12 or abs(g["sy"] - sy) > 1e-12:
            raise ValueError(f"{p.name}: pixel size differs")
        c0 = round((g["x0"] - x0) / sx)
        r0 = round((y1 - g["y1"]) / sy)
        rs, re_ = max(r0, 0), min(r0 + g["h"], h)
        cs, ce = max(c0, 0), min(c0 + g["w"], w)
        if rs >= re_ or cs >= ce:
            continue
        tile = arr[rs - r0:re_ - r0, cs - c0:ce - c0].copy()
        bad = ~np.isfinite(tile) | (tile < -1000)
        if g["nodata"] is not None:
            bad |= tile == g["nodata"]
        tile[bad] = NODATA
        dst = out[rs:re_, cs:ce]
        keep = tile != NODATA
        dst[keep] = tile[keep]
        used += 1
    dest = OUT / LAYERS[folder][2]
    write_tiff(dest, out, x0, y1, sx, sy, NODATA)
    valid = float((out != NODATA).mean()) * 100
    log(f"{folder}: {dest.name} {w}x{h} px from {used} tiles, {valid:.2f}% valid, "
        f"{dest.stat().st_size / 1e6:.0f} MB")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--batch", type=int, default=10, help="tiles per request (the app allows 20)")
    ap.add_argument("--layers", default="dsm_first,dtm", help="comma list of: " + ",".join(LAYERS))
    ap.add_argument("--dry-run", action="store_true", help="list the tiles and stop")
    ap.add_argument("--mosaic-only", action="store_true", help="skip downloading")
    ap.add_argument("--no-mosaic", action="store_true")
    args = ap.parse_args()
    folders = [f for f in args.layers.split(",") if f]
    if any(f not in LAYERS for f in folders) or not 1 <= args.batch <= 20:
        ap.error("bad --layers or --batch")
    TILES.mkdir(parents=True, exist_ok=True)
    if not args.mosaic_only:
        tiles = list_tiles()
        log(f"{len(tiles)} tiles of 0.01 deg intersect the box "
            f"({sum(1 for t in tiles if not t['contratto'].strip())} not surveyed)")
        if args.dry_run:
            for t in tiles:
                log(f"  {t['tavola']} fid {t['fid']} contract {t['contratto'] or '-'} flown {t['data']}")
            return
        download(tiles, folders, args.batch)
    if not args.no_mosaic:
        for f in folders:
            mosaic(f)
    log("done")


if __name__ == "__main__":
    main()
