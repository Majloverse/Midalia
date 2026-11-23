"""Builds the game's map of central Milan from OpenStreetMap.

    uv run --python 3.11 --with bpy --with shapely world/milan/build_map.py

Writes, next to this file:
    milan.glb     the city: extruded buildings, roads, paths, squares, parks, water, ground
    places.json   where each of the game's doors sits on a real building, and the street lamps
The OpenStreetMap download is kept as osm.json (not committed); delete it to fetch fresh data.
Map data (c) OpenStreetMap contributors, ODbL.
"""
import json, math, pathlib, random, urllib.parse, urllib.request
import bpy, bmesh
from bmesh.types import BMFace
from shapely.geometry import Point, Polygon, LineString
from shapely.geometry.polygon import orient
from shapely.strtree import STRtree

HERE = pathlib.Path(__file__).parent
S, W, N, E = 45.4560, 9.1780, 45.4720, 9.2020   # the piece of Milan that is built: Duomo and around
HUB = (45.4603, 9.1938)                         # the university's front door (Statale, Via Festa del Perdono)
# The game's doors, nearest the university first. Signs must match PLACES in world.gd.
SIGNS = ["UNIVERSITÀ", "ALIMENTARI", "VIA VERDI 3", "BANCA", "SUPERMERCATO", "VIA DANTE 7",
         "MINIMARKET", "VIA ROMA 12", "VIA MILANO 21", "BENZINA", "STAZIONE CENTRALE"]
DOOR_SPACING = 45.0                             # metres between two of the game's doors
LAMP_REACH, LAMP_EVERY, LAMP_MAX = 280.0, 32.0, 80

LAT0, LON0 = (S + N) / 2, (W + E) / 2
KY = 111320.0; KX = KY * math.cos(math.radians(LAT0))
proj = lambda g: [((p["lon"] - LON0) * KX, (p["lat"] - LAT0) * KY) for p in g]
HX, HY = (E - W) * KX / 2, (N - S) * KY / 2
random.seed(1)

ROADW = {"motorway": 14, "trunk": 14, "primary": 12, "secondary": 10, "tertiary": 8, "residential": 6,
         "unclassified": 6, "living_street": 5, "pedestrian": 5, "service": 3.5}
SKIP = {"corridor", "elevator", "platform", "proposed", "construction", "steps", "bus_stop"}
WALLS = [(0.80, 0.66, 0.42), (0.86, 0.80, 0.66), (0.72, 0.50, 0.36), (0.62, 0.60, 0.56), (0.85, 0.72, 0.52)]


def download():
    cache = HERE / "osm.json"
    if not cache.exists():
        box = f"({S},{W},{N},{E})"
        query = "[out:json][timeout:120];(" + "".join(f"{k}{box};" for k in (
            'way["building"]', 'relation["building"]', 'way["highway"]',
            'way["leisure"="park"]', 'way["natural"="water"]')) + ");out geom;"
        request = urllib.request.Request("https://overpass-api.de/api/interpreter",
            urllib.parse.urlencode({"data": query}).encode(), {"User-Agent": "midalia-map-build/1"})
        cache.write_bytes(urllib.request.urlopen(request, timeout=180).read())
    return json.loads(cache.read_text())["elements"]


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
    """Sorts OSM into buildings [(outers, inners, height)], roads [(points, kind)] and flat areas."""
    buildings, roads, areas = [], [], {"plaza": [], "park": [], "water": []}
    for e in elements:
        t = e.get("tags", {})
        if e["type"] == "relation":
            pts = []
            outers = rings([proj(m["geometry"]) for m in e["members"] if m.get("geometry") and m["role"] != "inner"])
            inners = rings([proj(m["geometry"]) for m in e["members"] if m.get("geometry") and m["role"] == "inner"])
        else:
            pts = proj(e["geometry"]); outers, inners = rings([pts]), []
        if "building" in t:
            if outers and t.get("location") != "underground": buildings.append((outers, inners, height(t)))
        elif "highway" in t:
            k = t["highway"].replace("_link", "")
            if k in SKIP or t.get("tunnel") == "yes" or t.get("layer", "0").startswith("-"): continue
            if outers and (t.get("area") == "yes" or k == "pedestrian"): areas["plaza"] += outers
            else: roads.append((pts, k))
        elif outers:
            areas["water" if t.get("natural") == "water" else "park"] += outers
    return buildings, roads, areas


def place_doors(buildings, roads):
    """Picks a real street-facing wall for each of the game's doors, clustered round the university."""
    hub = Point((HUB[1] - LON0) * KX, (HUB[0] - LAT0) * KY)
    shapes = [Polygon(o).buffer(0) for outers, _, _ in buildings for o in outers if len(o) > 2]
    solid = STRtree(shapes)
    streets = [LineString(p) for p, k in roads if k in ROADW and k != "service" and len(p) > 1]
    street_tree = STRtree(streets)
    found = []
    for shape in shapes:
        if shape.geom_type != "Polygon" or shape.distance(hub) > 450: continue
        ring = list(orient(shape).exterior.coords)       # anticlockwise, so outside is on the right
        for (ax, ay), (bx, by) in zip(ring, ring[1:]):
            L = math.hypot(bx - ax, by - ay)
            if L < 9: continue
            nx, ny = (by - ay) / L, -(bx - ax) / L
            mx, my = (ax + bx) / 2, (ay + by) / 2
            step = Point(mx + nx * 2.5, my + ny * 2.5)
            d = streets[street_tree.nearest(Point(mx, my))].distance(Point(mx, my))
            if not 3 <= d <= 16 or streets[street_tree.nearest(step)].distance(step) >= d: continue
            if any(shapes[i].intersects(step.buffer(1.5)) for i in solid.query(step.buffer(1.5))): continue
            found.append((Point(mx, my).distance(hub), mx, my, nx, ny))
    found.sort()
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

    walls = [bmesh.new() for _ in WALLS]
    for outers, inners, h in buildings:
        bm = random.choice(walls)
        faces = fill(bm, outers, inners)
        if not faces: continue
        top = [f for f in bmesh.ops.extrude_face_region(bm, geom=faces)["geom"] if isinstance(f, BMFace)]
        bmesh.ops.translate(bm, vec=(0, 0, h), verts=list({v for f in top for v in f.verts}))
        for f in top: f.material_index = 1
    roof = mat("roof", (0.45, 0.20, 0.13))
    for i, bm in enumerate(walls): emit(f"buildings_{i}", bm, mat(f"wall_{i}", WALLS[i]), roof)

    # Flat things sit a hair above the ground and each other, so the player's feet stay on top.
    road, path = bmesh.new(), bmesh.new()
    for pts, k in roads:
        bm, w, z = (road, ROADW[k], 0.04) if k in ROADW else (path, 2.5, 0.03)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            L = math.hypot(bx - ax, by - ay)
            if L < 0.01: continue
            nx, ny = -(by - ay) / L * w / 2, (bx - ax) / L * w / 2
            bm.faces.new([bm.verts.new(p) for p in ((ax - nx, ay - ny, z), (bx - nx, by - ny, z), (bx + nx, by + ny, z), (ax + nx, ay + ny, z))])
    emit("roads", road, mat("asphalt", (0.035, 0.035, 0.04), 0.6)); emit("paths", path, mat("path", (0.30, 0.29, 0.27)))
    for name, z, rgb in (("plaza", 0.02, (0.62, 0.60, 0.55)), ("park", 0.01, (0.13, 0.33, 0.10)), ("water", 0.01, (0.05, 0.20, 0.35))):
        bm = bmesh.new()
        for ring in areas[name]: fill(bm, [ring], z=z)
        emit(name, bm, mat(name, rgb, 0.1 if name == "water" else 0.85))
    g = bmesh.new()
    g.faces.new([g.verts.new(p) for p in ((-HX, -HY, 0), (HX, -HY, 0), (HX, HY, 0), (-HX, HY, 0))])
    emit("ground", g, mat("pavement", (0.42, 0.41, 0.39)))
    bpy.ops.export_scene.gltf(filepath=str(HERE / "milan.glb"))


buildings, roads, areas = read(download())
places, lamps = place_doors(buildings, roads)
(HERE / "places.json").write_text(json.dumps({
    "credit": "Map data (c) OpenStreetMap contributors, ODbL", "half": [round(HX, 1), round(HY, 1)],
    "places": places, "lamps": lamps}, ensure_ascii=False, indent=1))
build_model(buildings, roads, areas)
print(f"{len(buildings)} buildings, {len(roads)} roads, {len(lamps)} lamps, doors:", *places.items(), sep="\n")
