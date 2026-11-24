"""Downloads an aerial photo of central Milan, so roofs and ground can be coloured from the real thing.

    python3 -I world/milan/get_ortho.py          (needs Pillow; or: uv run --with pillow world/milan/get_ortho.py)

The photo is AGEA's 2024 orthophoto (Agenzia per le Erogazioni in Agricoltura, CC BY 4.0), read from the
tile cache of AGEA's public image service. That service turns its export call into a checkerboard, so the
cached tiles are the only way in; level 18 is its finest, 0.597 m per pixel in Web Mercator, which is 0.42 m
on the ground in Milan. The 256-pixel cache tiles are stitched into pieces of at most 2048 x 2048 pixels:
    sources/ortho/tiles/r03_c05.jpg   one piece, row 3 from the north, column 5 from the west
    sources/ortho/tiles/index.json    where each piece lies (EPSG:3857 and EPSG:4326 bounds) and what is missing
    sources/ortho/preview.png         the whole mosaic, about 2000 pixels wide
One request at a time, with a pause between them and a growing wait after a failure. A piece is written only
when complete, so a run that is cut short carries on where it stopped; delete a piece to fetch it again.
Credit: "Aerial photo: Ortofoto AGEA 2024 - Agenzia per le Erogazioni in Agricoltura (AGEA), CC BY 4.0
(creativecommons.org/licenses/by/4.0), modified". Licence and sources: sources/ortho/README.txt.
"""
import io, json, math, os, pathlib, time, urllib.error, urllib.request
from PIL import Image

HERE = pathlib.Path(__file__).parent
SERVICE = "https://geoportale.agea.gov.it/image/rest/services/AgEA/Ortofoto_AgEA_2024/ImageServer"
SOUTH, NORTH, WEST, EAST = 45.4300, 45.4982, 9.1430, 9.2410   # the map's circle round the Duomo, and a little more
CENTRE = (45.4641, 9.1919)
LEVEL = 18                     # the finest level the cache has
PIECE = 8                      # cache tiles per side of one piece: 8 x 256 = 2048 pixels
PAUSE = 0.1                    # seconds between two requests
PREVIEW_WIDTH = 2000
OUT = HERE / "sources" / "ortho"
TILES = OUT / "tiles"
AGENT = {"User-Agent": "midalia-ortho-fetch/1"}
R = 6378137.0                  # the Web Mercator sphere

lat_of = lambda y: math.degrees(2 * math.atan(math.exp(y / R)) - math.pi / 2)
lon_of = lambda x: math.degrees(x / R)
y_of = lambda lat: R * math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
x_of = lambda lon: R * math.radians(lon)


def get(url, what):
    """The body of url, after up to 8 tries with a growing wait. None if the server says there is nothing there (404)."""
    for attempt in range(1, 9):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=60) as reply:
                body, kind = reply.read(), reply.headers.get("Content-Type", "")
            time.sleep(PAUSE)
            if what == "image" and not kind.startswith("image/"): raise ValueError(f"got {kind}, not an image")
            return body
        except urllib.error.HTTPError as error:
            if error.code == 404: time.sleep(PAUSE); return None
            problem = f"HTTP {error.code}"
        except Exception as error:
            problem = str(error)[:100]
        wait = min(2 ** attempt, 120)
        print(f"  {url} attempt {attempt} failed ({problem}), waiting {wait} s", flush=True)
        time.sleep(wait)
    raise SystemExit(f"FAILED: {url}")


def grid():
    """The service's tile grid at LEVEL: origin and the size of one cache tile in metres, from the service itself."""
    info = json.loads(get(SERVICE + "?f=json", "json"))
    tile = info["tileInfo"]
    assert "TileMap" in info["capabilities"] and tile["spatialReference"]["latestWkid"] == 3857, "the service changed"
    res = next(l["resolution"] for l in tile["lods"] if l["level"] == LEVEL)
    assert tile["rows"] == tile["cols"] == 256 and LEVEL <= info.get("maxLOD", LEVEL), "the service changed"
    return tile["origin"]["x"], tile["origin"]["y"], res * 256, res


def main():
    TILES.mkdir(parents=True, exist_ok=True)
    ox, oy, size, res = grid()
    col_w, col_e = int((x_of(WEST) - ox) // size), int((x_of(EAST) - ox) // size)
    row_n, row_s = int((oy - y_of(NORTH)) // size), int((oy - y_of(SOUTH)) // size)
    pieces = [(r, c) for r in range(row_n, row_s + 1, PIECE) for c in range(col_w, col_e + 1, PIECE)]
    columns = len(range(col_w, col_e + 1, PIECE))
    index = {"service": SERVICE, "layer": "Ortofoto AgEA 2024", "cache_level": LEVEL, "crs": "EPSG:3857",
             "pixel_size_3857_m": res, "ground_pixel_m_at_centre": res * math.cos(math.radians(CENTRE[0])),
             "requested_box_4326": [WEST, SOUTH, EAST, NORTH],
             "note": "Pixels are square in EPSG:3857 (Web Mercator). Columns are linear in longitude; rows are "
                     "linear in Mercator y, not latitude: lat = degrees(2*atan(exp(y/6378137)) - pi/2). Treating "
                     "latitude as linear across one piece is off by under 2 cm, so a piece can be placed by its corners.",
             "credit": "Aerial photo: Ortofoto AGEA 2024 - Agenzia per le Erogazioni in Agricoltura (AGEA), "
                       "CC BY 4.0 (creativecommons.org/licenses/by/4.0), modified",
             "pieces": []}
    started = time.time()
    for n, (r0, c0) in enumerate(pieces, 1):
        r1, c1 = min(r0 + PIECE - 1, row_s), min(c0 + PIECE - 1, col_e)
        name = f"r{(r0 - row_n) // PIECE:02d}_c{(c0 - col_w) // PIECE:02d}.jpg"
        xmin, xmax, ymax, ymin = ox + c0 * size, ox + (c1 + 1) * size, oy - r0 * size, oy - (r1 + 1) * size
        entry = {"file": name, "width": (c1 - c0 + 1) * 256, "height": (r1 - r0 + 1) * 256,
                 "bbox_3857": [xmin, ymin, xmax, ymax], "bbox_4326": [lon_of(xmin), lat_of(ymin), lon_of(xmax), lat_of(ymax)],
                 "cache_rows": [r0, r1], "cache_cols": [c0, c1]}
        target, missing = TILES / name, []
        meta = TILES / (name + ".missing.json")
        if target.exists():
            if meta.exists(): missing = json.loads(meta.read_text())
            print(f"tile {n}/{len(pieces)} {name} already on disk", flush=True)
        else:
            image = Image.new("RGB", (entry["width"], entry["height"]))
            for r in range(r0, r1 + 1):
                for c in range(c0, c1 + 1):
                    body = get(f"{SERVICE}/tile/{LEVEL}/{r}/{c}", "image")
                    if body is None: missing.append([r, c]); continue
                    tile = Image.open(io.BytesIO(body)).convert("RGBA")
                    image.paste(tile, ((c - c0) * 256, (r - r0) * 256), tile)
            part = target.with_suffix(".part")
            image.save(part, "JPEG", quality=92)
            if missing: meta.write_text(json.dumps(missing))
            os.replace(part, target)
            rate = (time.time() - started) / n
            print(f"tile {n}/{len(pieces)} {name} {entry['width']}x{entry['height']} fetched"
                  f"{f', {len(missing)} cache tiles missing' if missing else ''}, about {rate * (len(pieces) - n) / 60:.0f} min left", flush=True)
        entry["missing_cache_tiles"] = missing
        index["pieces"].append(entry)
        (TILES / "index.part").write_text(json.dumps(index, indent=1))
        os.replace(TILES / "index.part", TILES / "index.json")

    # The preview: every piece shrunk and laid in place.
    width = (col_e - col_w + 1) * 256
    scale = PREVIEW_WIDTH / width
    preview = Image.new("RGB", (PREVIEW_WIDTH, round((row_s - row_n + 1) * 256 * scale)))
    for entry in index["pieces"]:
        x, y = (entry["cache_cols"][0] - col_w) * 256, (entry["cache_rows"][0] - row_n) * 256
        left, top = round(x * scale), round(y * scale)
        size_now = (round((x + entry["width"]) * scale) - left, round((y + entry["height"]) * scale) - top)
        with Image.open(TILES / entry["file"]) as piece:
            preview.paste(piece.resize(size_now, Image.LANCZOS), (left, top))
    preview.save(OUT / "preview.png")
    print(f"done: {len(pieces)} pieces ({columns} across), preview {preview.size[0]}x{preview.size[1]} in {OUT}", flush=True)


if __name__ == "__main__":
    main()
