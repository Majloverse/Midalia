"""Builds the game's map of central Milan.

    uv run --python 3.11 --with bpy --with shapely --with pyshp --with pyproj --with pillow --with zstandard world/milan/build_map.py

Writes, next to this file:
    milan.glb.zst the city: buildings, roofs, streets, pavements, paths, squares, parks, water, ground (zstd-packed glTF)
    places.json   where each of the game's doors sits on a real building, the street lamps, and the model's unpacked size
    trees.bin     where the trees stand and how tall they are: x, z, metres, x, z, metres, ... as 32-bit floats
The buildings come from the Comune di Milano's topographic database (DBT 2020), every part of every building
with its real height, porticos and archways included; OpenStreetMap adds the ones built since and everything else.
Downloads are kept, not committed: osm.json.gz (delete it to fetch fresh data) and sources/ (see get_dbt.sh).
Roof shapes and tree heights come from the MASE laser survey (get_lidar.py), roof colours from AGEA's 2024 aerial photo
(get_ortho.py). Sources and licences: CREDITS.md.
"""
import gzip, json, math, pathlib, random, struct, time, urllib.parse, urllib.request, zlib
from collections import namedtuple
import bpy, bmesh, numpy, shapely
from bmesh.types import BMFace
from shapely.geometry import Point, Polygon, LineString, shape
from shapely.geometry.polygon import orient
from shapely.ops import unary_union
from shapely.strtree import STRtree

HERE = pathlib.Path(__file__).parent
DBT = HERE / "sources" / "dbt" / "shp"           # the layers of DBT 2020 that are used, unzipped by get_dbt.sh
LIDAR = HERE / "sources" / "lidar" / "dsm.tif"   # the height of every roof, laser-measured in 2009-10: get_lidar.py
PHOTO = HERE / "sources" / "ortho" / "tiles"     # the city seen from above in 2024: get_ortho.py
# One part of a building: its outline, how high its underside and its top are above the street (metres),
# the building it belongs to, the building's kind (DBT code: 11 church, 22 cathedral, ...), the street's height above the sea.
Part = namedtuple("Part", "outline base top building kind street")
MONUMENTS = {"06", "07", "10", "11", "12", "15", "16", "20", "22"}   # baptistery, bell tower, castle, church, temple, cathedral...
ROOF_COLOURS = 12                               # the roofs' colours, from the photo, are rounded to this many
CENTRE, RADIUS = (45.4641, 9.1919), 3800.0     # the piece of Milan that is built: a circle round the Duomo,
                                                # out past Corvetto, so it holds Stazione Centrale and CityLife too
HUB = (45.4846, 9.2040)                         # Piazza Duca d'Aosta, in front of Stazione Centrale, where the game begins
STATION = "Milano Centrale"                     # the real building that gets the station's door
# The game's doors, nearest the station first. Signs must match PLACES in world.gd.
SIGNS = ["STAZIONE CENTRALE", "ALIMENTARI", "VIA ROMA 12", "BANCA", "VIA VERDI 3", "SUPERMERCATO",
         "VIA DANTE 7", "MINIMARKET", "UNIVERSITÀ", "VIA MILANO 21", "BENZINA"]
DOOR_SPACING = 45.0                             # metres between two of the game's doors
LAMP_REACH, LAMP_EVERY, LAMP_MAX = 280.0, 32.0, 80
SERVERS = ("https://overpass-api.de/api/interpreter", "https://overpass.openstreetmap.fr/api/interpreter")  # tried in turn
TILES = 4                                       # the download is cut into TILES x TILES pieces
CHUNK = 300.0                                   # metres: the size of the pieces the city is cut into
BAY = 3.6                                       # metres: how wide one window and the wall beside it are

LAT0, LON0 = CENTRE
KY = 111320.0; KX = KY * math.cos(math.radians(LAT0))
proj = lambda g: [((p["lon"] - LON0) * KX, (p["lat"] - LAT0) * KY) for p in g]
inside = lambda p: math.hypot(p[0], p[1]) < RADIUS
random.seed(1)

ROADW = {"motorway": 14, "trunk": 14, "primary": 12, "secondary": 10, "tertiary": 8, "residential": 6,
         "unclassified": 6, "living_street": 5, "pedestrian": 5, "service": 3.5}
SKIP = {"corridor", "elevator", "platform", "proposed", "construction", "steps", "bus_stop"}
# Milan's plaster: giallo Milano, cream, salmon, pale grey, brick, off-white, warm grey, beige.
WALLS = [(0.86, 0.70, 0.45), (0.88, 0.80, 0.66), (0.84, 0.62, 0.50), (0.74, 0.72, 0.68), (0.70, 0.45, 0.33),
         (0.90, 0.86, 0.78), (0.60, 0.56, 0.50), (0.80, 0.68, 0.55)]


def download():
    """Everything OpenStreetMap has in the circle's bounding box: every way, every node with tags, and the
    relations that are shapes. (Not bus and tram routes: they are lines across the whole city, not things on the map.)
    Fetched in small tiles, one at a time, because the server turns away big or parallel requests.
    Each tile is kept in osm_tiles/ as it arrives, so a download that is cut short carries on where it stopped."""
    cache, tiles = HERE / "osm.json.gz", HERE / "osm_tiles"
    if cache.exists(): return json.loads(gzip.decompress(cache.read_bytes()))
    tiles.mkdir(exist_ok=True)
    dy, dx = 2 * RADIUS / KY / TILES, 2 * RADIUS / KX / TILES
    found = {}
    for n in range(TILES * TILES):
        s, w = LAT0 - RADIUS / KY + (n // TILES) * dy, LON0 - RADIUS / KX + (n % TILES) * dx
        kept = tiles / f"{n}.json"
        if kept.exists():
            for e in json.loads(kept.read_text()): found[(e["type"], e["id"])] = e
            continue
        box = f"({s},{w},{s + dy},{w + dx})"
        query = (f"[out:json][timeout:170][maxsize:1073741824];(way{box};node{box}(if:count_tags()>0);"
                 f'relation["type"="multipolygon"]{box};relation["building"]{box};);out geom;')
        for attempt in range(1, 13):
            try:
                request = urllib.request.Request(SERVERS[attempt % len(SERVERS)],
                    urllib.parse.urlencode({"data": query}).encode(), {"User-Agent": "midalia-map-build/1"})
                data = json.loads(urllib.request.urlopen(request, timeout=240).read())
                assert "remark" not in data, data["remark"]
                break
            except Exception as error:
                print(f"tile {n + 1}/{TILES * TILES} attempt {attempt} failed: {str(error)[:80]}", flush=True)
                time.sleep(min(5 * attempt, 60))
        else: raise SystemExit("FAILED: OpenStreetMap download")
        kept.write_text(json.dumps(data["elements"]))
        for e in data["elements"]: found[(e["type"], e["id"])] = e
        print(f"tile {n + 1}/{TILES * TILES} downloaded, {len(found)} things so far", flush=True)
    elements = [found[key] for key in sorted(found)]      # always in the same order, so a rebuild gives the same city
    cache.write_bytes(gzip.compress(json.dumps(elements).encode(), 6))
    for kept in tiles.iterdir(): kept.unlink()
    tiles.rmdir()
    return elements


def rings(parts):
    """Stitches way fragments into closed rings (multipolygon members come split)."""
    parts = [p[:] for p in parts if len(p) > 1]; res = []
    while parts:
        r = parts.pop()
        while r[0] != r[-1]:
            for i, p in enumerate(parts):
                if p[0] == r[-1]: r += p[1:]; break
                if p[-1] == r[-1]: r += p[-2::-1]; break
            else: break
            parts.pop(i)
        if r[0] == r[-1] and len(r) > 3: res.append(r[:-1])
    return res


def height(t):
    for k, m in (("height", 1), ("building:levels", 3.2)):
        try: return max(3.0, float(t[k].split()[0].replace("m", "").replace(",", ".")) * m)
        except (KeyError, ValueError, IndexError): pass
    return 15 + random.random() * 6   # ponytail: an untagged building gets ~5 floors; only the few DBT lacks come from here


def read(elements):
    """Sorts OSM into buildings [(outline, height)], roads [(points, kind)], flat areas {kind: [(outers, inners)]}
    and the station's outline."""
    buildings, roads, areas, station = [], [], {"plaza": [], "park": [], "water": []}, []
    for e in elements:
        t = e.get("tags", {})
        if e["type"] == "node": continue
        if e["type"] == "relation":
            pts = []
            outers = rings([proj(m["geometry"]) for m in e["members"] if m.get("geometry") and m["role"] != "inner"])
            inners = rings([proj(m["geometry"]) for m in e["members"] if m.get("geometry") and m["role"] == "inner"])
        else:
            pts = proj(e["geometry"]); outers, inners = rings([pts]), []
        here = bool(outers) and inside(outers[0][0])
        if "building" in t:
            if here and t.get("location") != "underground":
                outline = unary_union([Polygon(o).buffer(0) for o in outers if len(o) > 2])
                if inners: outline = outline.difference(unary_union([Polygon(i).buffer(0) for i in inners if len(i) > 2]))
                if outline.area > 1: buildings.append((outline, height(t)))
            if t.get("name") == STATION: station += outers
        elif "highway" in t:
            k = t["highway"].replace("_link", "")
            if k in SKIP or t.get("tunnel") == "yes" or t.get("layer", "0").startswith("-"): continue
            if outers and (t.get("area") == "yes" or k == "pedestrian"):
                if here: areas["plaza"].append((outers, inners))
            else:
                run = []                                  # a road is cut where it leaves the circle
                for p in pts + [None]:
                    if p is not None and inside(p): run.append(p)
                    else:
                        if len(run) > 1: roads.append((run, k))
                        run = []
        elif here and t.get("natural") == "water":
            areas["water"].append((outers, inners))
        elif here and (t.get("leisure") in ("park", "garden") or t.get("landuse") in ("grass", "village_green", "meadow")
                       or t.get("natural") in ("wood", "scrub", "grassland")):
            areas["park"].append((outers, inners))
    return buildings, roads, areas, station


def dbt(layer):
    """The features of one DBT 2020 layer in the circle: [(record, shape in the map's metres, its lowest height above the sea)].
    DBT is drawn in RDN2008 / UTM 32N (EPSG:7791)."""
    import shapefile
    from pyproj import Transformer
    to_utm, to_wgs = Transformer.from_crs(4326, 7791, always_xy=True), Transformer.from_crs(7791, 4326, always_xy=True)
    cx, cy = to_utm.transform(LON0, LAT0)
    def local(xy):
        lon, lat = to_wgs.transform(xy[:, 0], xy[:, 1])
        return numpy.column_stack(((numpy.asarray(lon) - LON0) * KX, (numpy.asarray(lat) - LAT0) * KY))
    found = []
    for item in shapefile.Reader(str(DBT / layer), encoding="latin-1").iterShapeRecords():
        s = item.shape
        x0, y0, x1, y1 = s.bbox if hasattr(s, "bbox") else (*s.points[0], *s.points[0])
        if math.hypot((x0 + x1) / 2 - cx, (y0 + y1) / 2 - cy) < RADIUS:
            found.append((item.record, shapely.transform(shapely.force_2d(shape(s)), local), min(s.z)))
    return found


def read_dbt():
    """Every part of every building in the circle from DBT 2020: [Part]."""
    import shapefile
    kinds = {r["CLASSID"]: "22" if r["NOME"].strip() == "DUOMO" else r["EDIFC_TY"]     # DBT files the Duomo as a church (11)
             for r in shapefile.Reader(str(DBT / "EDIFC"), encoding="latin-1").iterRecords()}
    rows = [[s, z, r["UN_VOL_QE"], r["CEDIUV"], r["UN_VOL_POR"] == "01"] for r, s, z in dbt("UN_VOL") if r["UN_VOL_POR"] != "08"]  # 08: underground
    # The parts standing on the street tile the ground without overlapping; they are simplified together,
    # so two neighbours still share the very same wall afterwards.
    standing = [row for row in rows if row[4]]
    for row, simple in zip(standing, shapely.coverage_simplify(numpy.array([row[0] for row in standing]), 0.3)): row[0] = simple
    # Heights are above sea level; the street under a building is where its standing parts start.
    street = {}
    for _, z, _, b, on_ground in standing: street[b] = min(street.get(b, z), z)
    lookup = STRtree([row[0] for row in standing])
    parts = []
    for outline, z, top, b, on_ground in rows:
        g = z if on_ground else street.get(b) or standing[lookup.nearest(outline)][1]
        base = 0.0 if on_ground else max(0.0, z - g)
        if not on_ground: outline = outline.simplify(0.3)
        if top - g - base > 0.5 and outline.area > 1 and inside(outline.representative_point().coords[0]):
            parts.append(Part(outline, base, top - g, b, kinds.get(b, "01"), g))
    return parts


def flat_shapes(found):
    """DBT shapes as the (outers, inners) the map's flat layers are made of."""
    out = []
    for _, s, _ in found:
        for p in getattr(s.buffer(0), "geoms", [s.buffer(0)]):
            if p.area > 1 and inside(p.representative_point().coords[0]):
                out.append(([list(p.exterior.coords)[:-1]], [list(i.coords)[:-1] for i in p.interiors]))
    return out


def read_trees():
    """Every tree the Comune mapped (DBT 2020), with its height from the laser survey: [(x, y, metres tall)].
    One the survey missed (planted after 2010) is taken as 7 m."""
    (dsm, west, north, step), (dtm, *_) = laser(LIDAR), laser(LIDAR.with_name("dtm.tif"))
    trees = []
    for _, s, _ in dbt("ALBERO"):
        x, y = s.x, s.y
        row, col = int((north - (y / KY + LAT0)) / step), int(((x / KX + LON0) - west) / step)
        on = 1 <= row < dsm.shape[0] - 1 and 1 <= col < dsm.shape[1] - 1
        tall = float(dsm[row - 1:row + 2, col - 1:col + 2].max() - dtm[row, col]) if on else 0.0   # the crown's top, near the trunk
        trees.append((x, y, tall if 3 <= tall <= 35 else 7.0))
    return trees


def add_newer(parts, osm):
    """The buildings OpenStreetMap has where DBT 2020 has none: the ones built since."""
    shapes = numpy.array([p[0] for p in parts])
    outlines = numpy.array([o for o, _ in osm])
    mine, theirs = STRtree(shapes).query(outlines, predicate="intersects")
    covered = numpy.zeros(len(osm))
    numpy.add.at(covered, mine, shapely.area(shapely.intersection(outlines[mine], shapes[theirs])))
    newer = [Part(o, 0.0, h, f"osm{i}", "01", None) for i, (o, h) in enumerate(osm) if covered[i] < 0.25 * o.area and o.area > 15]
    return parts + newer, len(newer)


def roof_over(parts):
    """Neighbouring parts whose tops are within a metre of each other share one roof, as a block of Milanese houses does.
    Returns the roofs [(outline, eave, street)], and the parts with each top moved to its roof's eave."""
    shapes = numpy.array([p.outline for p in parts])
    up = list(range(len(parts)))
    def root(i):
        while up[i] != i: up[i] = up[up[i]]; i = up[i]
        return i
    for i, j in zip(*STRtree(shapes).query(shapes, predicate="dwithin", distance=0.35)):
        if i < j and abs(parts[i].top - parts[j].top) <= 1.0: up[root(i)] = root(j)
    groups = {}
    for i in range(len(parts)): groups.setdefault(root(i), []).append(i)
    roofs, parts = [], list(parts)
    for members in groups.values():
        eave = float(numpy.median([parts[i].top for i in members]))
        alone = [i for i in members if abs(parts[i].top - eave) > 1.5]    # a chain of small steps can drift; those keep their own
        members = [i for i in members if i not in alone]
        roofs += [(parts[i].outline, parts[i].top, parts[i].street) for i in alone]
        outline = unary_union(shapes[members]).buffer(0.2, join_style="mitre").buffer(-0.2, join_style="mitre").simplify(0.2)
        streets = [parts[i].street for i in members if parts[i].street is not None]
        roofs.append((outline, eave, float(numpy.median(streets)) if streets else None))
        for i in members: parts[i] = parts[i]._replace(top=eave)
    return roofs, parts


def laser(path=LIDAR):
    """The laser survey's heights, read in place: (heights[row, column], west, north, degrees per pixel).
    The file is an uncompressed float32 GeoTIFF in longitude and latitude, as get_lidar.py writes it."""
    with path.open("rb") as f: data = f.read(4096)
    assert data[:4] == b"II*\0", "expected a little-endian TIFF"
    at = struct.unpack_from("<I", data, 4)[0]
    tags = {}
    for i in range(struct.unpack_from("<H", data, at)[0]):
        tag, _, count, value = struct.unpack_from("<HHII", data, at + 2 + 12 * i)
        tags[tag] = (count, value)
    assert tags[259][1] == 1 and tags[258][1] == 32, "expected uncompressed 32-bit samples"
    width, height = tags[256][1], tags[257][1]
    first = struct.unpack_from("<I", data, tags[273][1])[0]       # the rows follow one another from the first strip on
    step = struct.unpack_from("<3d", data, tags[33550][1])[0]
    west, north = struct.unpack_from("<6d", data, tags[33922][1])[3:5]
    return numpy.memmap(path, "<f4", "r", first, (height, width)), west, north, step


def photo():
    """A function giving the colour (r, g, b 0..1) the 2024 aerial photo shows at each longitude and latitude."""
    from PIL import Image
    tiles = json.loads((PHOTO / "index.json").read_text())["pieces"]
    seen = {}
    def colour(lon, lat):
        x = numpy.radians(lon) * 6378137.0                                   # Web Mercator, as the photo's tiles are cut
        y = numpy.log(numpy.tan(math.pi / 4 + numpy.radians(lat) / 2)) * 6378137.0
        out = numpy.full((len(x), 3), numpy.nan)
        for i, t in enumerate(tiles):
            x0, y0, x1, y1 = t["bbox_3857"]
            here = (x >= x0) & (x < x1) & (y > y0) & (y <= y1)
            if not here.any() or not (PHOTO / t["file"]).exists(): continue
            if i not in seen: seen[i] = numpy.asarray(Image.open(PHOTO / t["file"]).convert("RGB").reduce(2))   # 0.84 m is plenty
            image = seen[i]
            h, w = image.shape[:2]
            out[here] = image[((y1 - y[here]) / (y1 - y0) * h).astype(int).clip(0, h - 1),
                              ((x[here] - x0) / (x1 - x0) * w).astype(int).clip(0, w - 1)] / 255.0
        return out
    return colour


def survey(roofs):
    """Reads every roof off the laser survey and the aerial photo. Returns [(outline, eave, slope, colour)]:
    slope is how many metres the roof rises per metre in from the walls, 0 if it is flat
    (or if the building has changed since 2010, when the survey was flown); colour is the roof's colour in the photo."""
    heights, west, north, step = laser()
    seen = photo()
    out = []
    pitched = 0
    for n, (outline, eave, street) in enumerate(roofs):
        if n % 10000 == 0: print(f"roof {n}/{len(roofs)}", flush=True)
        x0, y0, x1, y1 = outline.bounds
        gap = max(0.8, math.sqrt(outline.area / 2500))                        # at most some 2500 spots on one roof
        xs, ys = (a.ravel() for a in numpy.meshgrid(numpy.arange(x0 + gap / 2, x1, gap), numpy.arange(y0 + gap / 2, y1, gap)))
        keep = shapely.contains_xy(outline, xs, ys)
        xs, ys = xs[keep], ys[keep]
        slope, colour = 0.0, None
        if len(xs) >= 12:
            d = shapely.distance(shapely.points(xs, ys), outline.boundary)
            lon, lat = xs / KX + LON0, ys / KY + LAT0
            rgb = seen(lon, lat)
            inner = (d > 1.0) & ~numpy.isnan(rgb[:, 0])
            if inner.sum() >= 4: colour = numpy.median(rgb[inner], axis=0)
            reach = d.max()
            if street is not None and reach >= 2.0:
                row, col = ((north - lat) / step).astype(int), ((lon - west) / step).astype(int)
                on = (row >= 0) & (row < heights.shape[0]) & (col >= 0) & (col < heights.shape[1])
                rise = numpy.full(len(xs), -99.0)
                rise[on] = heights[row[on], col[on]] - (street + eave)
                ok = (rise > -50) & (d < 0.85 * reach)
                # A sloping roof rises steadily with the distance from the walls. One median per metre in,
                # so chimneys, trees and aerials don't count.
                bins = d[ok].astype(int)
                found = [(b + 0.5, numpy.median(rise[ok][bins == b]), (bins == b).sum()) for b in numpy.unique(bins) if (bins == b).sum() >= 3]
                if len(found) >= 3:
                    at, mid, weight = numpy.array(found).T
                    a, c = numpy.polyfit(at, mid, 1, w=numpy.sqrt(weight))
                    off = numpy.average(numpy.abs(mid - (a * at + c)), weights=weight)
                    if 0.15 <= a <= 1.2 and off < 0.6 and abs(c) < 2.0:
                        slope = float(min(a, 0.9)); pitched += 1
        out.append((outline, eave, slope, colour))
    print(f"{pitched} of {len(roofs)} roofs slope", flush=True)
    return out


def hip(bm, outline, eave, slope):
    """A roof rising from every wall at the same pitch, with ridges and hips where the slopes meet:
    the outline shrunk step by step, each ring higher than the last, and the bands between them filled in."""
    faces, corner = [], {}
    def vert(x, y, z):
        key = (round(x, 3), round(y, 3), round(z, 3))
        if key not in corner: corner[key] = bm.verts.new(key)
        return corner[key]
    for piece in getattr(outline, "geoms", [outline]):
        reach = shapely.maximum_inscribed_circle(piece, 0.1).length            # how far in the ridge is
        steps = [reach * f for f in (0.0, 0.35, 0.7, 0.94)]
        rings = [piece] + [piece.buffer(-d, join_style="mitre", mitre_limit=4).simplify(0.1) for d in steps[1:]] + [Polygon()]
        for k, d in enumerate(steps):
            inner = rings[k + 1]
            band = rings[k].difference(inner) if not inner.is_empty else rings[k]
            for tri in shapely.constrained_delaunay_triangles(band).geoms:
                corners = list(tri.exterior.coords)[:3]
                on_inner = shapely.distance(shapely.points(corners), inner.boundary) < 0.02 if not inner.is_empty else [False] * 3
                vs = [vert(x, y, eave + slope * (steps[k + 1] if hi else d)) for (x, y), hi in zip(corners, on_inner)]
                if len(set(vs)) < 3 or bm.faces.get(vs): continue
                f = bm.faces.new(vs)
                f.normal_update()
                if f.normal.z < 0: f.normal_flip()
                faces.append(f)
    return faces


def plant(trees, solid):
    """The trees not standing in a house or in the traffic."""
    spots = shapely.points([(x, y) for x, y, _ in trees])
    blocked = numpy.zeros(len(trees), bool)
    blocked[STRtree(solid).query(spots, predicate="intersects")[0]] = True
    return [t for t, no in zip(trees, blocked) if not no]


def place_doors(shapes, roads, station):
    """Picks a real street-facing wall for each of the game's doors, clustered round the station.
    shapes: the outlines of everything standing on the street; station: the station's outline."""
    hub = Point((HUB[1] - LON0) * KX, (HUB[0] - LAT0) * KY)
    solid = STRtree(shapes)
    streets = [LineString(p) for p, k in roads if k in ROADW and k != "service" and len(p) > 1]
    street_tree = STRtree(streets)

    def walls(shape):
        """Each wall of a building long enough for a door, with clear ground in front: (distance from the hub, middle, outward)."""
        for part in getattr(shape, "geoms", [shape]):
            ring = list(orient(part).exterior.coords)    # anticlockwise, so outside is on the right
            for (ax, ay), (bx, by) in zip(ring, ring[1:]):
                L = math.hypot(bx - ax, by - ay)
                if L < 9: continue
                nx, ny = (by - ay) / L, -(bx - ax) / L
                mx, my = (ax + bx) / 2, (ay + by) / 2
                step = Point(mx + nx * 2.5, my + ny * 2.5)
                if any(shapes[i].intersects(step.buffer(1.5)) for i in solid.query(step.buffer(1.5))): continue
                yield Point(mx, my).distance(hub), mx, my, nx, ny

    # The station's door goes on the real station, on the wall nearest the square in front of it.
    found = [min(walls(station))]
    rest = []
    for shape in shapes:
        if shape.distance(hub) > 450: continue
        for d, mx, my, nx, ny in walls(shape):
            here, step = Point(mx, my), Point(mx + nx * 2.5, my + ny * 2.5)
            to_street = streets[street_tree.nearest(here)].distance(here)
            # A street runs past this wall, on this side of it.
            if 3 <= to_street <= 16 and streets[street_tree.nearest(step)].distance(step) < to_street: rest.append((d, mx, my, nx, ny))
    found += sorted(rest)
    doors = []
    for _, mx, my, nx, ny in found:
        if all(math.hypot(mx - d["x"], -my - d["z"]) >= DOOR_SPACING for d in doors):
            # Godot: x east, z south. The door's own -Z points into the building.
            doors.append({"x": round(mx, 2), "z": round(-my, 2), "yaw": round(math.atan2(nx, -ny), 4)})
        if len(doors) == len(SIGNS): break
    assert len(doors) == len(SIGNS), f"only {len(doors)} doors found"

    lamps = []
    for line, (_, k) in ((LineString(p), (p, k)) for p, k in roads if k in ROADW and k != "service" and len(p) > 1):
        if line.distance(hub) > LAMP_REACH: continue
        side = line.parallel_offset(ROADW[k] / 2 + 1.0, "left")
        if side.is_empty or side.geom_type != "LineString": continue
        for i in range(int(side.length // LAMP_EVERY) + 1):
            p = side.interpolate(i * LAMP_EVERY + LAMP_EVERY / 2)
            if p.distance(hub) > LAMP_REACH or any(shapes[j].distance(p) < 0.6 for j in solid.query(p.buffer(0.6))): continue
            if all(math.hypot(p.x - q[1], -p.y - q[2]) > 20 for q in lamps): lamps.append((p.distance(hub), round(p.x, 2), round(-p.y, 2)))
    lamps = [[x, z] for _, x, z in sorted(lamps)[:LAMP_MAX]]
    return dict(zip(SIGNS, doors)), lamps


def fill(bm, outers, inners=(), z=0.0):
    edges = []
    for ring in [*outers, *inners]:
        vs = [bm.verts.new((x, y, z)) for x, y in ring]
        edges += [bm.edges.new((vs[i], vs[(i + 1) % len(vs)])) for i in range(len(vs))]
    return [f for f in bmesh.ops.triangle_fill(bm, edges=edges, use_beauty=True)["geom"] if isinstance(f, BMFace)]


def cap(bm, outline, z, up=True):
    """The outline filled in at height z, facing up or down."""
    faces = []
    for p in getattr(outline, "geoms", [outline]):
        faces += fill(bm, [list(p.exterior.coords)[:-1]], [list(i.coords)[:-1] for i in p.interiors], z)
    for f in faces:
        f.normal_update()
        if (f.normal.z < 0) == up: f.normal_flip()
    return faces


def palette(colours, k=ROOF_COLOURS):
    """Rounds the roofs' colours to k: [index per roof], [k colours]. A roof the photo missed gets terracotta."""
    terracotta = numpy.array([0.62, 0.36, 0.27])
    known = numpy.array([c if c is not None else terracotta for c in colours])
    centres = known[numpy.linspace(0, len(known) - 1, k).astype(int)]
    for _ in range(12):                                                      # k-means
        nearest = ((known[:, None, :] - centres[None]) ** 2).sum(2).argmin(1)
        centres = numpy.array([known[nearest == i].mean(0) if (nearest == i).any() else centres[i] for i in range(k)])
    vivid = lambda c: tuple(float(min(1.0, max(0.0, c.mean() + (v - c.mean()) * 1.5)) ** 1.25) for v in c)
    return nearest.tolist(), [vivid(c) for c in centres]          # the photo is hazy: more colour, a little darker


def build_model(buildings, roofs, roads, areas):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    def mat(name, rgb, rough=0.85):
        m = bpy.data.materials.new(name); m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        # Colours are written as they should look on screen; Blender wants them linear.
        b.inputs["Base Color"].default_value = (*(c ** 2.2 for c in rgb), 1); b.inputs["Roughness"].default_value = rough
        return m

    def emit(name, bm, *mats):
        if not name.startswith(("buildings", "roofs")): bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])   # these face the right way already
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        for m in mats: me.materials.append(m)
        scene.collection.objects.link(bpy.data.objects.new(name, me))

    # Everything is cut into square chunks, so the game only draws the ones near the player.
    chunks = {}
    def chunk(layer, x, y):
        key = (layer, int(x // CHUNK), int(y // CHUNK))
        if key not in chunks: chunks[key] = bmesh.new()
        return chunks[key]

    # Where two parts share a wall, only the piece of it above the lower one can be seen; the rest is left out.
    at = lambda p: (round(p[0], 2), round(p[1], 2))
    rings, sides = [], {}
    for i, part in enumerate(buildings):
        mine = [list(r.coords) for p in getattr(part.outline, "geoms", [part.outline]) for r in (orient(p).exterior, *orient(p).interiors)]
        rings.append(mine)
        for ring in mine:
            for a, b in zip(ring, ring[1:]): sides.setdefault((at(a), at(b)), []).append(i)
    walls_kept = walls_all = 0
    brick, marble = len(WALLS), len(WALLS) + 1
    for i, (outline, base, top, building, kind, _) in enumerate(buildings):
        bm = chunk("buildings", *outline.representative_point().coords[0])
        uv, facade = bm.loops.layers.uv.verify(), bm.loops.layers.uv.get("facade") or bm.loops.layers.uv.new("facade")
        seed = zlib.crc32(building.encode()) / 2 ** 32      # every part of one building looks alike
        if kind in MONUMENTS:   # brick, but the cathedral is marble
            colour, style = (marble if kind == "22" else brick), 8
        else:
            colour, style = int(seed * len(WALLS)), (4 if top > 50 else 0)
        if base > 0.05:
            for f in cap(bm, outline, base, up=False): f.material_index = colour       # the ceiling of a portico or an archway
        for ring in rings[i]:
            for (ax, ay), (bx, by) in zip(ring, ring[1:]):
                L = math.hypot(bx - ax, by - ay)
                if L < 0.05: continue
                walls_all += 1
                low = base
                for j in sorted(sides.get((at((bx, by)), at((ax, ay))), []), key=lambda j: buildings[j].base):
                    if buildings[j].base <= low + 0.3: low = max(low, buildings[j].top)
                if low >= top - 0.05: continue
                walls_kept += 1
                # Outlines run anticlockwise, so this quad faces out. uv: window bays across, height up.
                # facade: the top, and the look (see WALL_SHADER in milan.gd); a wall above a lower neighbour is a bare party wall.
                f = bm.faces.new([bm.verts.new(p) for p in ((ax, ay, low), (bx, by, low), (bx, by, top), (ax, ay, top))])
                f.material_index = colour
                bays = max(1, round(L / BAY))
                tag = seed + style + (2 if low > base + 0.05 else 0)
                for loop, u, v in zip(f.loops, (0, bays, bays, 0), (low, low, top, top)):
                    loop[uv].uv = (u, v)
                    loop[facade].uv = (top, tag)
    print(f"walls: {walls_kept} of {walls_all} can be seen", flush=True)
    shades, colours = palette([colour for _, _, _, colour in roofs])
    for (outline, eave, slope, _), shade in zip(roofs, shades):
        bm = chunk("roofs", *outline.representative_point().coords[0])
        for f in (hip(bm, outline, eave, slope) if slope else cap(bm, outline, eave)):
            f.material_index = shade
            f.smooth = True        # so neighbouring triangles share their corners in the file; ROOF_SHADER shades them flat

    # Flat things sit a hair above the ground and each other, so the player's feet stay on top.
    for pts, k in roads:
        layer, w, z = ("roads", ROADW[k], 0.04) if k in ROADW else ("paths", 2.5, 0.03)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            L = math.hypot(bx - ax, by - ay)
            if L < 0.01: continue
            nx, ny = -(by - ay) / L * w / 2, (bx - ax) / L * w / 2
            bm = chunk(layer, ax, ay)
            bm.faces.new([bm.verts.new(p) for p in ((ax - nx, ay - ny, z), (bx - nx, by - ny, z), (bx + nx, by + ny, z), (ax + nx, ay + ny, z))])
    for layer, z in (("plaza", 0.02), ("park", 0.01), ("water", 0.015), ("roads", 0.04), ("pavements", 0.05)):
        for outers, inners in areas[layer]: fill(chunk(layer, *outers[0][0]), outers, inners, z=z)

    house = [mat(f"wall_{i}", c) for i, c in enumerate(WALLS)] + [mat("wall_brick", (0.62, 0.36, 0.26)), mat("wall_marble", (0.8, 0.77, 0.73))]
    tops = [mat(f"roof_{i}", c) for i, c in enumerate(colours)]
    flat = {"roads": mat("asphalt", (0.16, 0.16, 0.17), 0.95), "paths": mat("path", (0.30, 0.29, 0.27)), "pavements": mat("paving", (0.4, 0.39, 0.37)),
            "plaza": mat("plaza", (0.62, 0.60, 0.55)), "park": mat("park", (0.13, 0.33, 0.10)), "water": mat("water", (0.05, 0.20, 0.35), 0.1)}
    for (layer, cx, cy), bm in chunks.items():
        emit(f"{layer}_{cx}_{cy}", bm, *(house if layer == "buildings" else tops if layer == "roofs" else [flat[layer]]))
    g = bmesh.new()
    g.faces.new([g.verts.new((RADIUS * math.cos(i * math.tau / 96), RADIUS * math.sin(i * math.tau / 96), 0)) for i in range(96)])
    emit("ground", g, mat("pavement", (0.42, 0.41, 0.39)))
    print("writing the model", flush=True)
    import zstandard
    glb = HERE / "milan.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb))
    model = glb.read_bytes()
    glb.unlink()
    (HERE / "milan.glb.zst").write_bytes(zstandard.ZstdCompressor(level=19, threads=-1).compress(model))   # the game unpacks it as it loads
    return len(model)


osm, roads, areas, station = read(download())
buildings = read_dbt()
print(f"{len(buildings)} building parts from DBT 2020", flush=True)
buildings, newer = add_newer(buildings, osm)
# The streets' and pavements' real surfaces come from DBT; OpenStreetMap's road lines still place the doors and lamps,
# and its footpaths are drawn through the parks.
pieces = lambda layer: [p for _, s, _ in dbt(layer) for p in getattr(s.buffer(0).simplify(0.2), "geoms", [s.buffer(0).simplify(0.2)]) if p.area > 1]
carriageways, pavements = pieces("AC_VEI"), pieces("AC_PED")
paths = [(p, k) for p, k in roads if k not in ROADW]
middles = numpy.array([LineString(p).interpolate(0.5, normalized=True) for p, _ in paths])
paved = set(STRtree(carriageways + pavements).query(middles, predicate="intersects")[0])
paths = [path for i, path in enumerate(paths) if i not in paved]
as_rings = lambda ps: [([list(p.exterior.coords)[:-1]], [list(i.coords)[:-1] for i in p.interiors]) for p in ps if inside(p.representative_point().coords[0])]
areas["roads"], areas["pavements"] = as_rings(carriageways), as_rings(pavements)
print(f"{newer} newer buildings from OpenStreetMap, {len(carriageways)} streets, {len(pavements)} pavements, "
      f"{len(areas['park'])} green areas; planting trees", flush=True)
standing = [p.outline for p in buildings if p.base == 0]
trees = plant(read_trees(), standing + carriageways)
(HERE / "trees.bin").write_bytes(numpy.array([(x, -y, tall) for x, y, tall in trees], "<f4").tobytes())   # Godot: z runs south
print(f"{len(trees)} trees; placing doors", flush=True)
station = unary_union([Polygon(ring).buffer(0) for ring in station])
station = unary_union([o for o in standing if station.contains(o.representative_point())]).simplify(1.0)
places, lamps = place_doors(standing, roads, station)
print("doors placed; building the model", flush=True)
roofs, buildings = roof_over(buildings)
print(f"{len(roofs)} roofs; reading them off the laser survey and the aerial photo", flush=True)
roofs = survey(roofs)
size = build_model(buildings, roofs, paths, areas)
(HERE / "places.json").write_text(json.dumps({
    "credit": "Comune di Milano DBT 2020, MASE LiDAR, AGEA 2024 orthophoto (all CC BY 4.0); (c) OpenStreetMap contributors, ODbL. See CREDITS.md",
    "radius": RADIUS, "model_bytes": size, "places": places, "lamps": lamps}, ensure_ascii=False, indent=1))
print(f"{len(buildings)} buildings, {len(roads)} roads, {len(lamps)} lamps, doors:", *places.items(), sep="\n")
