"""Builds the game's map of central Milan from OpenStreetMap.

    uv run --python 3.11 --with bpy --with shapely world/milan/build_map.py

Writes, next to this file:
    milan.glb.gz  the city: extruded buildings, roads, paths, squares, parks, water, ground
    places.json   where each of the game's doors sits on a real building, and the street lamps
    trees.bin     where the trees stand: x, z, x, z, ... as 32-bit floats
The OpenStreetMap download is kept as osm.json (not committed); delete it to fetch fresh data.
Map data (c) OpenStreetMap contributors, ODbL.
"""
import gzip, json, math, pathlib, random, struct, time, urllib.parse, urllib.request
import bpy, bmesh
from bmesh.types import BMFace
from shapely.geometry import Point, Polygon, LineString
from shapely.geometry.polygon import orient
from shapely.strtree import STRtree

HERE = pathlib.Path(__file__).parent
CENTRE, RADIUS = (45.4641, 9.1919), 3800.0     # the piece of Milan that is built: a circle round the Duomo,
                                                # out past Corvetto, so it holds Stazione Centrale and CityLife too
HUB = (45.4846, 9.2040)                         # Piazza Duca d'Aosta, in front of Stazione Centrale, where the game begins
STATION = "Milano Centrale"                     # the real building that gets the station's door
# The game's doors, nearest the station first. Signs must match PLACES in world.gd.
SIGNS = ["STAZIONE CENTRALE", "ALIMENTARI", "VIA ROMA 12", "BANCA", "VIA VERDI 3", "SUPERMERCATO",
         "VIA DANTE 7", "MINIMARKET", "UNIVERSITÀ", "VIA MILANO 21", "BENZINA"]
DOOR_SPACING = 45.0                             # metres between two of the game's doors
LAMP_REACH, LAMP_EVERY, LAMP_MAX = 280.0, 32.0, 80
TREE_ROW_EVERY, PARK_TREE_EVERY = 8.0, 220.0     # metres along a row of trees; square metres of park per tree
CHUNK = 300.0                                   # metres: the size of the pieces the city is cut into

LAT0, LON0 = CENTRE
KY = 111320.0; KX = KY * math.cos(math.radians(LAT0))
proj = lambda g: [((p["lon"] - LON0) * KX, (p["lat"] - LAT0) * KY) for p in g]
inside = lambda p: math.hypot(p[0], p[1]) < RADIUS
random.seed(1)

ROADW = {"motorway": 14, "trunk": 14, "primary": 12, "secondary": 10, "tertiary": 8, "residential": 6,
         "unclassified": 6, "living_street": 5, "pedestrian": 5, "service": 3.5}
SKIP = {"corridor", "elevator", "platform", "proposed", "construction", "steps", "bus_stop"}
WALLS = [(0.80, 0.66, 0.42), (0.86, 0.80, 0.66), (0.72, 0.50, 0.36), (0.62, 0.60, 0.56), (0.85, 0.72, 0.52)]


def download():
    """Fetches the circle's bounding box in four quarters: one big request is often turned away."""
    cache = HERE / "osm.json"
    if cache.exists(): return json.loads(cache.read_text())["elements"]
    dy, dx = RADIUS / KY, RADIUS / KX
    found = {}
    for n, (s, w) in enumerate(((LAT0 - dy, LON0 - dx), (LAT0 - dy, LON0), (LAT0, LON0 - dx), (LAT0, LON0))):
        box = f"({s},{w},{s + dy},{w + dx})"
        query = "[out:json][timeout:170];(" + "".join(f"{k}{box};" for k in (
            'way["building"]', 'relation["building"]', 'way["highway"]', 'node["natural"="tree"]', 'way["natural"="tree_row"]',
            *(f'{kind}[{what}]' for kind in ("way", "relation") for what in (
                '"leisure"~"^(park|garden)$"', '"landuse"~"^(grass|village_green|meadow)$"', '"natural"~"^(water|wood|scrub|grassland)$"')))) + ");out geom;"
        for attempt in range(1, 9):
            try:
                request = urllib.request.Request("https://overpass-api.de/api/interpreter",
                    urllib.parse.urlencode({"data": query}).encode(), {"User-Agent": "midalia-map-build/1"})
                data = json.loads(urllib.request.urlopen(request, timeout=240).read())
                assert "remark" not in data, data["remark"]
                break
            except Exception as error:
                print(f"quarter {n + 1}/4 attempt {attempt} failed: {str(error)[:80]}", flush=True)
                time.sleep(30)
        else: raise SystemExit("FAILED: OpenStreetMap download")
        for e in data["elements"]: found[(e["type"], e["id"])] = e
        print(f"quarter {n + 1}/4 downloaded, {len(found)} things so far", flush=True)
    cache.write_text(json.dumps({"elements": list(found.values())}))
    return list(found.values())


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
    return 15 + random.random() * 6   # ponytail: untagged buildings get ~5 floors; use Lombardia DBT heights for accuracy


def read(elements):
    """Sorts OSM into buildings [(outers, inners, height)], roads [(points, kind)], flat areas {kind: [(outers, inners)]},
    the station's outline, trees [(x, y)] and the parks and woods that should be full of trees."""
    buildings, roads, areas, station, trees, wooded = [], [], {"plaza": [], "park": [], "water": []}, [], [], []
    for e in elements:
        t = e.get("tags", {})
        if e["type"] == "node":
            trees += [p for p in proj([e]) if inside(p)]
            continue
        if e["type"] == "relation":
            pts = []
            outers = rings([proj(m["geometry"]) for m in e["members"] if m.get("geometry") and m["role"] != "inner"])
            inners = rings([proj(m["geometry"]) for m in e["members"] if m.get("geometry") and m["role"] == "inner"])
        else:
            pts = proj(e["geometry"]); outers, inners = rings([pts]), []
        here = bool(outers) and inside(outers[0][0])
        if "building" in t:
            if here and t.get("location") != "underground": buildings.append((outers, inners, height(t)))
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
        elif t.get("natural") == "tree_row":
            row = LineString(pts)
            trees += [(q.x, q.y) for q in (row.interpolate(d * TREE_ROW_EVERY) for d in range(int(row.length // TREE_ROW_EVERY) + 1)) if inside((q.x, q.y))]
        elif here:
            areas["water" if t.get("natural") == "water" else "park"].append((outers, inners))
            if t.get("leisure") == "park" or t.get("natural") == "wood": wooded += outers
    return buildings, roads, areas, station, trees, wooded


def plant(trees, wooded, buildings, roads):
    """Fills parks and woods with trees (OSM maps few of them one by one), then drops every tree standing in a road or a house."""
    for ring in wooded:
        park = Polygon(ring).buffer(0)
        x0, y0, x1, y1 = park.bounds
        for _ in range(int(park.area / PARK_TREE_EVERY)):
            spot = Point(random.uniform(x0, x1), random.uniform(y0, y1))
            if park.contains(spot): trees.append((spot.x, spot.y))
    ways = [(LineString(p), ROADW.get(k, 2.5) / 2 + 1.0) for p, k in roads if len(p) > 1]
    way_tree = STRtree([w for w, _ in ways])
    houses = [Polygon(o).buffer(0) for outers, _, _ in buildings for o in outers if len(o) > 2]
    house_tree = STRtree(houses)
    kept = []
    for x, y in trees:
        spot = Point(x, y)
        if any(ways[i][0].distance(spot) < ways[i][1] for i in way_tree.query(spot.buffer(8))): continue
        if any(houses[i].distance(spot) < 1.5 for i in house_tree.query(spot.buffer(1.5))): continue
        kept.append((x, y))
    return kept


def place_doors(buildings, roads, station):
    """Picks a real street-facing wall for each of the game's doors, clustered round the station."""
    hub = Point((HUB[1] - LON0) * KX, (HUB[0] - LAT0) * KY)
    shapes = [Polygon(o).buffer(0) for outers, _, _ in buildings for o in outers if len(o) > 2]
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
    found = [min(w for ring in station for w in walls(Polygon(ring).buffer(0)))]
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


def build_model(buildings, roads, areas):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    def mat(name, rgb, rough=0.85):
        m = bpy.data.materials.new(name); m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        # Colours are written as they should look on screen; Blender wants them linear.
        b.inputs["Base Color"].default_value = (*(c ** 2.2 for c in rgb), 1); b.inputs["Roughness"].default_value = rough
        return m

    def emit(name, bm, *mats):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        for m in mats: me.materials.append(m)
        scene.collection.objects.link(bpy.data.objects.new(name, me))

    # Everything is cut into square chunks, so the game only draws the ones near the player.
    chunks = {}
    def chunk(layer, x, y):
        key = (layer, int(x // CHUNK), int(y // CHUNK))
        if key not in chunks: chunks[key] = bmesh.new()
        return chunks[key]

    for outers, inners, h in buildings:
        bm = chunk("buildings", *outers[0][0])
        faces = fill(bm, outers, inners)
        if not faces: continue
        colour = random.randrange(len(WALLS))
        for f in faces: f.material_index = colour          # the walls take this over when extruded
        top = [f for f in bmesh.ops.extrude_face_region(bm, geom=faces)["geom"] if isinstance(f, BMFace)]
        bmesh.ops.translate(bm, vec=(0, 0, h), verts=list({v for f in top for v in f.verts}))
        for f in top: f.material_index = len(WALLS)        # roof

    # Flat things sit a hair above the ground and each other, so the player's feet stay on top.
    for pts, k in roads:
        layer, w, z = ("roads", ROADW[k], 0.04) if k in ROADW else ("paths", 2.5, 0.03)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            L = math.hypot(bx - ax, by - ay)
            if L < 0.01: continue
            nx, ny = -(by - ay) / L * w / 2, (bx - ax) / L * w / 2
            bm = chunk(layer, ax, ay)
            bm.faces.new([bm.verts.new(p) for p in ((ax - nx, ay - ny, z), (bx - nx, by - ny, z), (bx + nx, by + ny, z), (ax + nx, ay + ny, z))])
    for layer, z in (("plaza", 0.02), ("park", 0.01), ("water", 0.015)):
        for outers, inners in areas[layer]: fill(chunk(layer, *outers[0][0]), outers, inners, z=z)

    house = [mat(f"wall_{i}", c) for i, c in enumerate(WALLS)] + [mat("roof", (0.45, 0.20, 0.13))]
    flat = {"roads": mat("asphalt", (0.035, 0.035, 0.04), 0.6), "paths": mat("path", (0.30, 0.29, 0.27)),
            "plaza": mat("plaza", (0.62, 0.60, 0.55)), "park": mat("park", (0.13, 0.33, 0.10)), "water": mat("water", (0.05, 0.20, 0.35), 0.1)}
    for (layer, cx, cy), bm in chunks.items():
        emit(f"{layer}_{cx}_{cy}", bm, *(house if layer == "buildings" else [flat[layer]]))
    g = bmesh.new()
    g.faces.new([g.verts.new((RADIUS * math.cos(i * math.tau / 96), RADIUS * math.sin(i * math.tau / 96), 0)) for i in range(96)])
    emit("ground", g, mat("pavement", (0.42, 0.41, 0.39)))
    print("writing the model", flush=True)
    glb = HERE / "milan.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb))
    (HERE / "milan.glb.gz").write_bytes(gzip.compress(glb.read_bytes()))   # the game unpacks it as it loads
    glb.unlink()


buildings, roads, areas, station, trees, wooded = read(download())
print(f"{len(buildings)} buildings, {len(roads)} roads, {len(areas['park'])} green areas; planting trees", flush=True)
trees = plant(trees, wooded, buildings, roads)
(HERE / "trees.bin").write_bytes(struct.pack(f"<{len(trees) * 2}f", *(v for x, y in trees for v in (x, -y))))   # Godot: z runs south
print(f"{len(trees)} trees; placing doors", flush=True)
places, lamps = place_doors(buildings, roads, station)
print("doors placed; building the model", flush=True)
(HERE / "places.json").write_text(json.dumps({
    "credit": "Map data (c) OpenStreetMap contributors, ODbL", "radius": RADIUS,
    "places": places, "lamps": lamps}, ensure_ascii=False, indent=1))
build_model(buildings, roads, areas)
print(f"{len(buildings)} buildings, {len(roads)} roads, {len(lamps)} lamps, doors:", *places.items(), sep="\n")
