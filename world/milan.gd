class_name Milan
## The real streets and buildings of Milan in a circle round the Duomo, 3.8 km out:
## from Stazione Centrale to Corvetto, CityLife to the Politecnico. Made by world/milan/build_map.py
## from the Comune's topographic database, a laser survey, an aerial photo and OpenStreetMap: see CREDITS.md.
## The city comes in 300 m chunks; only those within the camera's reach are drawn.

const MODEL := "res://world/milan/milan.glb.zst"
const INFO := "res://world/milan/places.json"
const TREES := "res://world/milan/trees.bin"
const CHUNK := 300.0  # metres: trees are grouped like the city, so only those near the camera are drawn

const NOISE := "
float random(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(random(i), random(i + vec2(1, 0)), f.x), mix(random(i + vec2(0, 1)), random(i + vec2(1, 1)), f.x), f.y);
}
float box(vec2 p, vec2 lo, vec2 hi) { return step(lo.x, p.x) * step(p.x, hi.x) * step(lo.y, p.y) * step(p.y, hi.y); }
"

## A Milanese façade, drawn on a flat wall. From the street up: a ground floor of rusticated stone with an
## arch in every bay (a shop under an awning, a rolled-down shutter or a wooden portone), then plastered
## floors in ochre, yellow, pink or cream with tall windows in stone surrounds, louvred shutters, and
## iron balconies on corbels, an attic of small windows, and a stone cornice under an eave of clay tiles.
## Towers are glass; churches, the castle and the Duomo are bare brick or marble with tall windows.
## The model gives each wall UV = (window bays across, 1 - metres above the street) and
## UV2 = (the top of the building, 1 - tag), tag = a number 0..1 that picks the building's looks,
## + 2 if the wall stands against a neighbour and so has no windows, + 4 for a glass tower, + 8 for a monument.
const WALL_SHADER := "
shader_type spatial;
uniform vec3 wall : source_color;
uniform float night = 0.0;
varying vec3 at;
varying float ceiling;   // 1 on the underside of a building that bridges a passage
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ceiling = step((MODEL_NORMAL_MATRIX * NORMAL).y, -0.5);
}
%s
const float BAY = 3.6;   // metres: one window and the wall beside it, as in build_map.py
const vec3 PLASTER[8] = vec3[8](vec3(0.85, 0.64, 0.30), vec3(0.80, 0.54, 0.24), vec3(0.86, 0.76, 0.56), vec3(0.84, 0.54, 0.40),
	vec3(0.70, 0.36, 0.25), vec3(0.82, 0.58, 0.50), vec3(0.88, 0.78, 0.52), vec3(0.76, 0.46, 0.24));
const vec3 SHUTTER[4] = vec3[4](vec3(0.13, 0.27, 0.17), vec3(0.20, 0.34, 0.25), vec3(0.34, 0.21, 0.12), vec3(0.40, 0.42, 0.40));
const vec3 AWNING[4] = vec3[4](vec3(0.10, 0.34, 0.20), vec3(0.62, 0.13, 0.10), vec3(0.14, 0.24, 0.45), vec3(0.80, 0.58, 0.15));
const vec3 CLAY = vec3(0.74, 0.40, 0.26);
// A steady random number from whole numbers. (The building's tag wobbles a hair from pixel to pixel,
// so it is rounded before it gets here; otherwise the walls come out speckled.)
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
// How well a fine pattern, `period` metres across, can be made out: 1 close up, 0 once it is smaller than a pixel.
float seen(float period, float px) {
	return 1.0 - smoothstep(0.25, 0.6, px / period);
}
// Whether this window opens onto a balcony. Each building keeps to one habit.
float balcony(float column, float level, float sd, float habit) {
	if (habit < 0.25) return 0.0;                                                   // none
	if (habit < 0.55) return step(0.5, mod(column, 2.0));                           // every other window, all the way up
	if (habit < 0.82) return step(0.62, hash(vec2(column, level) + sd * 1.7));      // here and there
	return step(level, 0.5);                                                        // one long one on the first floor
}
void fragment() {
	float h = 1.0 - UV.y;
	float top = UV2.x;
	float tag = floor((1.0 - UV2.y) * 4096.0 + 0.5) / 4096.0;
	float sd = floor(fract(tag) * 4096.0 + 0.5);
	float open = 1.0 - mod(floor(tag * 0.5), 2.0);
	float style = floor(tag * 0.25);
	float storey = 3.1 + 0.5 * hash(vec2(sd, 3.0));
	float shop = 4.0 + 0.8 * hash(vec2(sd, 4.0));
	float bay = fract(UV.x);
	float column = floor(UV.x);
	float xm = UV.x * BAY;            // metres along the wall
	float x = (bay - 0.5) * BAY;      // metres from the middle of this bay
	float px = max(fwidth(UV.x) * BAY, fwidth(h));
	float grime = 0.5 * noise(at.xz * 0.7 + at.y * 0.3) + 0.5 * noise(vec2(UV.x * 3.0, h * 0.15));
	vec3 colour = wall * (0.86 + 0.18 * grime);
	vec3 far = colour * 0.8;   // what the wall looks like from too far away to make out its windows
	float rough = 0.92;
	float glass = 0.0;
	float lit = 0.0;
	if (style > 1.5) {
		// Brick or marble in courses, a tall window in every other bay.
		colour *= 1.0 - 0.18 * step(fract(h / 0.45), 0.08) - 0.08 * step(fract(UV.x * 9.0 + floor(h / 0.45) * 0.5), 0.06);
		float window = box(vec2(bay, mod(h, 9.0)), vec2(0.4, 3.0), vec2(0.6, 7.5)) * step(0.5, mod(column, 2.0)) * step(h, top - 2.0) * open;
		colour = mix(colour, vec3(0.1, 0.1, 0.12), window);
		lit = window * 0.4;
		far = colour;
	} else if (style > 0.5) {
		// Glass and thin mullions, floor after floor.
		vec2 g = vec2(fract(UV.x * 2.0), fract(h / 3.4));
		glass = box(g, vec2(0.05, 0.1), vec2(0.95, 0.95));
		colour = mix(wall * 0.5, vec3(0.13, 0.18, 0.23) + 0.05 * grime, glass);
		rough = mix(0.5, 0.35, glass);
		lit = glass * step(0.72, hash(vec2(floor(UV.x * 2.0), floor(h / 3.4)) + sd));
		far = vec3(0.16, 0.2, 0.25);
	} else {
		// The colours below are picked by eye, as they look on screen; they are turned into light at the end.
		vec3 plaster = PLASTER[int(hash(vec2(sd, 11.0)) * 7.99)] * (0.86 + 0.18 * grime);
		plaster *= 1.0 - 0.10 * smoothstep(0.55, 0.9, noise(vec2(xm * 0.5, h * 0.06) + sd));   // where the rain runs down
		vec3 stone = mix(vec3(0.74, 0.68, 0.58), vec3(0.62, 0.60, 0.56), step(0.5, hash(vec2(sd, 12.0)))) * (0.9 + 0.12 * grime);
		vec3 trim = mix(stone, vec3(0.90, 0.86, 0.78), 0.5);   // surrounds, sills and cornices: paler than the wall
		vec3 shut = SHUTTER[int(hash(vec2(sd, 13.0)) * 3.99)];
		vec3 iron = vec3(0.07, 0.08, 0.08);
		float habit = hash(vec2(sd, 14.0));
		float persiane = step(0.22, hash(vec2(sd, 15.0)));      // most houses have louvred shutters; the rest roll-down blinds
		vec3 woodwork = mix(vec3(0.88, 0.86, 0.80), vec3(0.27, 0.17, 0.10), step(0.6, hash(vec2(sd, 16.0))));
		float crown = mix(0.26, 0.9, open);                     // the height of the cornice and eave
		float levels = max(0.0, floor((top - crown - shop) / storey));
		colour = plaster;
		far = mix(plaster, vec3(0.2), 0.13);
		if (open < 0.5) {
			// A bare party wall: patched plaster, nothing else.
			colour *= 0.94 + 0.08 * noise(vec2(xm * 0.25, h * 0.25) + sd);
			far = colour;
		} else if (top < 5.6) {
			// A low shed or lodge: a plinth and one shuttered window to a bay.
			colour = mix(colour, stone * 0.85, step(h, 0.6));
			if (top > 3.5) {
				vec2 p = vec2(x, h);
				float win = box(p, vec2(-0.5, 1.05), vec2(0.5, 2.25));
				colour = mix(colour, trim, box(p, vec2(-0.62, 0.95), vec2(0.62, 2.37)));
				colour = mix(colour, shut * mix(0.87, 0.72 + 0.3 * step(0.45, fract(h * 15.0)), seen(0.066, px)) * (1.0 - 0.3 * step(abs(x), 0.02)), win);
			}
		} else if (h < shop) {
			// The ground floor: stone in courses, an arch in every bay.
			float joints = step(fract(h / 0.5), 0.06) + step(fract(xm / 1.2 + floor(h / 0.5) * 0.5), 0.03);
			colour = stone * (1.0 - 0.2 * min(joints, 1.0) * seen(0.5, px)) * (1.0 - 0.18 * step(h, 0.55));
			far = stone * 0.78;
			float radius = 1.15;
			float spring = shop - 1.05 - radius;                 // where the arch starts to curve
			float reach = h < spring ? abs(x) : length(vec2(x, h - spring));
			float opening = step(reach, radius);
			float ring = step(reach, radius + 0.26) * (1.0 - opening);
			float turn = atan(h - spring, x);
			vec3 arch = trim * (1.0 - 0.16 * step(fract(turn / 0.349), 0.1) * step(spring, h) * seen(0.3, px));
			arch = mix(arch, trim * 1.06, step(abs(x), 0.17) * step(spring, h));   // the keystone
			colour = mix(colour, arch, ring);
			colour = mix(colour, trim * 1.06, step(abs(x), 0.17) * step(spring + radius, h) * step(h, spring + radius + 0.42));
			float kind = hash(vec2(column, sd + 7.0));
			vec3 within;
			if (kind < 0.16) {
				// A portone: two leaves of panelled wood, an iron fanlight in the arch.
				vec3 wood = mix(vec3(0.33, 0.20, 0.11), vec3(0.11, 0.22, 0.15), step(0.55, hash(vec2(sd, 17.0))));
				float panel = box(vec2(abs(x), h), vec2(0.18, 0.35), vec2(0.98, 1.15)) + box(vec2(abs(x), h), vec2(0.18, 1.35), vec2(0.98, spring - 0.2));
				float moulding = panel - (box(vec2(abs(x), h), vec2(0.25, 0.42), vec2(0.91, 1.08)) + box(vec2(abs(x), h), vec2(0.25, 1.42), vec2(0.91, spring - 0.27)));
				within = wood * (0.85 + 0.25 * panel - 0.3 * moulding) * (0.9 + 0.2 * noise(vec2(xm * 14.0, h * 1.5)));
				within *= 1.0 - 0.6 * step(abs(x), 0.02);
				within = mix(within, vec3(0.75, 0.6, 0.25), step(length(vec2(abs(x) - 0.13, h - 1.22)), 0.05));   // brass knobs
				float bars = max(step(fract(turn / 0.262 + 0.5), 0.14), step(abs(fract((reach) / 0.38) - 0.5), 0.06));
				vec3 fan = mix(vec3(0.05, 0.06, 0.08), iron * 2.2, bars * seen(0.2, px));
				within = mix(within, fan, step(spring + 0.06, h));
				within = mix(within, wood * 0.6, step(abs(h - spring - 0.03), 0.05));
				glass = 0.0;
			} else if (kind < 0.74) {
				// A shop: a dark frame, a window full of things, and for most an awning.
				vec3 goods = vec3(0.10, 0.09, 0.08) + vec3(0.14, 0.11, 0.07) * noise(vec2(xm * 2.5, h * 2.0) + sd) * smoothstep(0.3, 0.6, h) * (1.0 - smoothstep(1.6, 2.2, h));
				goods += vec3(0.06, 0.08, 0.10) * smoothstep(1.0, 3.0, h);
				float frame = max(step(radius - 0.07, reach), max(step(h, 0.3), step(abs(abs(x) - 0.42), 0.025) * step(h, 2.3)));
				frame = max(frame, step(abs(h - 2.3), 0.03));
				within = mix(goods, vec3(0.09, 0.09, 0.09), frame);
				glass = 1.0 - frame;
				lit = glass * 0.45;
				float pick = hash(vec2(column, sd + 9.0));
				if (pick < 0.62) {
					float drop = spring - 0.42 - 0.07 * abs(sin(xm * PI / 0.3));      // a scalloped edge
					float cloth = step(abs(x), 1.45) * step(drop, h) * step(h, spring + 0.38);
					vec3 dye = AWNING[int(pick / 0.62 * 3.99)];
					vec3 stripes = mix(dye, vec3(0.90, 0.87, 0.78), step(0.5, fract(xm / 0.6)) * step(0.3, hash(vec2(sd, 18.0))));
					stripes *= 0.72 + 0.4 * smoothstep(spring - 0.45, spring + 0.38, h);  // it slopes out over the pavement
					within = mix(within, stripes, cloth);
					colour = mix(colour, stripes, cloth);
					opening = max(opening, cloth);
					glass *= 1.0 - cloth;
					lit *= 1.0 - cloth;
				}
			} else if (kind < 0.9) {
				// Shut for the day behind a roller shutter.
				within = vec3(0.50, 0.51, 0.52) * mix(0.9, 0.8 + 0.2 * step(0.5, fract(h * 9.0)), seen(0.11, px)) * (0.9 + 0.15 * grime);
			} else {
				// A blind arch, with one barred window.
				within = plaster * 0.86;
				float small = box(vec2(x, h), vec2(-0.45, 1.5), vec2(0.45, 2.4));
				float grate = max(step(fract(x / 0.18), 0.16), step(abs(h - 1.95), 0.03));
				within = mix(within, mix(vec3(0.06, 0.07, 0.09), iron * 2.0, grate * seen(0.18, px)), small);
			}
			within *= 1.0 - 0.3 * smoothstep(radius - 0.18, radius, reach) * step(spring, h);   // shade under the arch
			colour = mix(colour, within, opening);
			// The stone band that divides the shops from the floors above, and its shadow.
			colour = mix(colour, trim, step(shop - 0.3, h));
			colour *= 1.0 - 0.3 * step(shop - 0.4, h) * step(h, shop - 0.3) * (1.0 - opening);
			rough = mix(rough, 0.35, glass);
		} else if (h < shop + levels * storey) {
			float level = floor((h - shop) / storey);
			float y = h - shop - level * storey;
			vec2 p = vec2(x, y);
			float nobile = step(level, 0.5);                       // the first floor, the grand one
			float out_ = balcony(column, level, sd, habit);
			float above = level + 1.5 < levels ? balcony(column, level + 1.0, sd, habit) : 0.0;
			float reach = mix(1.3, 2.0, step(0.82, habit));        // half a balcony's width; 2.0 runs on into the next bay
			float bottom = mix(0.95, 0.15, out_);                  // a window, or a door down to the balcony floor
			float wtop = 2.7;
			float win = box(p, vec2(-0.6, bottom), vec2(0.6, wtop));
			float surround = box(p, vec2(-0.77, bottom), vec2(0.77, wtop + 0.16));
			float sill = (1.0 - out_) * box(p, vec2(-0.9, 0.8), vec2(0.9, 0.95));
			float pediment = nobile * box(p, vec2(-1.0, wtop + 0.2), vec2(1.0, wtop + 0.33));
			colour *= 1.0 - 0.28 * (1.0 - out_) * box(p, vec2(-0.9, 0.7), vec2(0.9, 0.8));                 // shadow under the sill
			colour *= 1.0 - 0.28 * nobile * box(p, vec2(-1.0, wtop + 0.12), vec2(1.0, wtop + 0.2));
			colour = mix(colour, trim, max(max(surround, sill), pediment));
			// Shutters folded back against the wall, or closed over the window.
			float row = hash(vec2(column, level) + sd * 3.1);
			float closed = step(0.78, row);
			float slats = mix(0.87, 0.72 + 0.3 * step(0.45, fract(y * 15.0)), seen(0.066, px));
			float leaves = persiane * (1.0 - closed) * box(vec2(abs(x), y), vec2(0.79, bottom), vec2(1.36, wtop));
			float edge = min(1.0, step(abs(x), 0.83) + step(1.32, abs(x)) + step(y, bottom + 0.05) + step(wtop - 0.05, y));
			colour = mix(colour, shut * mix(slats, 0.75, edge), leaves);
			colour *= 1.0 - 0.2 * persiane * (1.0 - closed) * box(vec2(abs(x), y), vec2(1.36, bottom - 0.05), vec2(1.42, wtop - 0.05));   // their shadow
			// The window itself: two casements, sometimes a curtain, the wall's shadow across the top.
			vec3 pane = vec3(0.07, 0.09, 0.12) + vec3(0.08, 0.10, 0.12) * (y - bottom) / (wtop - bottom);
			float curtain = step(0.45, hash(vec2(column, level) + sd * 5.3)) * step(0.2, abs(x));
			pane = mix(pane, vec3(0.66, 0.64, 0.58), 0.6 * curtain);
			float frame = max(step(abs(x), 0.035), max(step(abs(y - (wtop - 0.62)), 0.03), 1.0 - box(p, vec2(-0.54, bottom + 0.06), vec2(0.54, wtop - 0.06))));
			pane = mix(pane, woodwork, frame * seen(0.12, px));
			pane *= 1.0 - 0.45 * max(step(wtop - 0.16, y), step(x, -0.5));
			vec3 blind = persiane > 0.5 ? shut * slats * (1.0 - 0.35 * step(abs(x), 0.02))
				: vec3(0.62, 0.62, 0.59) * mix(0.9, 0.8 + 0.2 * step(0.5, fract(y * 11.0)), seen(0.09, px));
			colour = mix(colour, mix(pane, blind, closed), win);
			glass = win * (1.0 - closed) * (1.0 - frame);
			lit = 0.6 * glass * step(0.66, hash(vec2(column, level) + sd * 7.7));
			// Under the balcony of the floor above: its shadow on the wall, and the stone corbels that carry it.
			float under = storey - y;
			colour *= 1.0 - 0.32 * above * step(abs(x), 1.3) * (1.0 - smoothstep(0.0, 0.7, under));
			colour = mix(colour, trim * 0.82, above * step(abs(abs(x) - 0.95), 0.05 + 0.06 * (1.0 - under / 0.34)) * step(under, 0.34));
			// The balcony: a stone slab and an iron railing.
			float on = out_ * step(abs(x), reach);
			float bars = mix(0.2, step(fract(xm / 0.14), 0.2), seen(0.14, px));
			float curl = step(abs(fract(xm / 0.28) - 0.5), 0.3) * step(abs(y - 0.62), 0.05) * seen(0.28, px);   // a band of ironwork halfway up
			float rails = max(step(1.03, y), step(y, 0.21));
			float posts = step(reach - 0.05, abs(x)) * step(reach, 1.9);
			colour = mix(colour, iron, on * step(0.15, y) * step(y, 1.1) * max(max(bars, curl), max(rails, posts)));
			colour = mix(colour, trim * (0.72 + 0.28 * step(0.05, y)), on * step(y, 0.15));
			glass *= 1.0 - on * step(y, 1.1);
			rough = mix(rough, 0.35, glass);
		} else {
			// The attic under the eaves: a small square window to each bay, if there is room.
			float room = top - crown - shop - levels * storey;
			float y = h - shop - levels * storey;
			if (room > 1.4) {
				vec2 p = vec2(x, y - room * 0.5);
				float small = box(p, vec2(-0.42, -0.3), vec2(0.42, 0.3));
				colour = mix(colour, trim, box(p, vec2(-0.54, -0.42), vec2(0.54, 0.42)));
				colour = mix(colour, vec3(0.07, 0.09, 0.12) * (1.0 - 0.4 * step(0.18, p.y)), small);
				colour = mix(colour, woodwork, small * step(abs(x), 0.03) * seen(0.1, px));
				glass = small;
				lit = small * step(0.8, hash(vec2(column, sd + 21.0)));
			}
		}
		// The crown: a stone cornice with dentils, the dark underside of the eave, and the ends of the roof tiles.
		float e = top - h;
		float tile = abs(sin(xm * PI / 0.22));
		if (e < 0.2 + 0.05 * tile) {
			colour = CLAY * mix(0.85, (0.68 + 0.34 * tile) * (0.88 + 0.24 * hash(vec2(floor(xm / 0.22), sd))), seen(0.22, px));
			far = CLAY * 0.85;
			glass = 0.0; lit = 0.0;
		} else if (e < mix(0.26, 0.46, open)) {
			colour = vec3(0.15, 0.11, 0.08) + vec3(0.14, 0.10, 0.07) * step(fract(xm / 0.55), 0.22) * seen(0.55, px);
			glass = 0.0; lit = 0.0;
		} else if (e < crown) {
			float m = (e - 0.46) / (crown - 0.46);
			colour = trim * (1.04 - 0.22 * m);
			colour *= 1.0 - 0.3 * step(0.25, m) * step(m, 0.6) * step(0.5, fract(xm / 0.3)) * seen(0.3, px);   // dentils
			colour *= 1.0 - 0.22 * (step(abs(m - 0.22), 0.035) + step(abs(m - 0.63), 0.035));
			glass = 0.0; lit = 0.0;
		}
		if (ceiling > 0.5) {
			// The ceiling of an archway: plaster in shade, in square coffers.
			vec2 coffer = abs(fract(at.xz / 2.4) - 0.5);
			float rib = step(0.42, max(coffer.x, coffer.y));
			colour = vec3(0.60, 0.55, 0.47) * (0.9 + 0.12 * grime) * (1.0 - 0.22 * rib * seen(2.4, px * 4.0));
			far = vec3(0.56, 0.51, 0.44);
			glass = 0.0; lit = 0.0;
		}
		colour = pow(colour, vec3(2.2));
		far = pow(far, vec3(2.2));
	}
	// Far off, a window is smaller than a pixel: show the wall's average instead of flickering dots.
	float blur = smoothstep(0.12, 0.35, max(fwidth(UV.x), fwidth(h) / storey));
	ALBEDO = mix(colour, far, blur);
	ROUGHNESS = mix(rough, 0.9, blur);
	EMISSION = vec3(1.0, 0.8, 0.45) * lit * night * 0.9;
}
" % NOISE

## Roofs: rows of terracotta coppi where they slope, weathered clay where they are flat. The aerial photo
## still tints each roof, so no two are quite alike. The mesh shares corners between triangles, so each
## face's slope is worked out here.
const ROOF_SHADER := "
shader_type spatial;
uniform vec3 roof : source_color;
varying vec3 at;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
%s
void fragment() {
	vec3 n = normalize(cross(dFdy(at), dFdx(at)));
	n *= sign(n.y + 0.0001);
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec2 down = normalize(n.xz + vec2(0.0001));
	vec2 across = vec2(-down.y, down.x);
	vec2 tile = vec2(dot(at.xz, across) / 0.22, dot(at.xz, down) / 0.36);
	float coppi = (0.72 + 0.28 * sin(fract(tile.x) * 6.2832)) * (1.0 - 0.3 * step(0.86, fract(tile.y)));
	float blur = smoothstep(0.2, 0.6, max(fwidth(tile.x), fwidth(tile.y)));   // tiles smaller than a pixel: their average
	vec3 clay = vec3(0.50, 0.17, 0.08);   // terracotta
	float shade = dot(roof, vec3(0.333));
	vec3 sloped = mix(clay * (0.75 + 0.5 * shade), roof, 0.15) * mix(coppi * (0.85 + 0.3 * random(floor(tile))), 0.86, blur);
	vec3 level = mix(clay * (0.8 + 0.3 * shade), roof, 0.12) * (0.78 + 0.3 * noise(at.xz * 0.8)) * (0.92 + 0.08 * noise(at.xz * 9.0));
	ALBEDO = mix(level, sloped, step(0.08, length(n.xz)));
	ROUGHNESS = 0.9;
}
" % NOISE


## Adds the city to the world. Returns:
##   places: sign -> {x, z, yaw} of that door on a real wall (its own -Z points into the building)
##   lamps: street lamp spots near the station
##   walls: the wall materials, for set_night()
static func build(parent: Node3D) -> Dictionary:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	# Unpacked and read straight from the file, so the game runs without opening the editor first.
	# ponytail: an exported build doesn't carry the file; add *.zst to the export filter then.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_buffer(FileAccess.get_file_as_bytes(MODEL).decompress(info.model_bytes, FileAccess.COMPRESSION_ZSTD), "", state)
	var city := document.generate_scene(state)
	parent.add_child(city)

	var shaders := {"wall": Shader.new(), "roof": Shader.new()}
	shaders.wall.code = WALL_SHADER
	shaders.roof.code = ROOF_SHADER
	var made := {}  # material name -> its shader material, shared by every chunk of the city
	for node in city.find_children("buildings*", "MeshInstance3D", true, false) + city.find_children("roofs*", "MeshInstance3D", true, false):
		var houses: MeshInstance3D = node
		houses.create_trimesh_collision()
		for surface in houses.mesh.get_surface_count():
			var original: BaseMaterial3D = houses.mesh.surface_get_material(surface)
			var kind := original.resource_name.get_slice("_", 0)
			if not shaders.has(kind):
				continue
			if not made.has(original.resource_name):
				var material := ShaderMaterial.new()
				material.shader = shaders[kind]
				material.set_shader_parameter(kind, original.albedo_color)
				made[original.resource_name] = material
			houses.set_surface_override_material(surface, made[original.resource_name])
	var walls := made.keys().filter(func(name): return name.begins_with("wall")).map(func(name): return made[name])
	# Streets, paving and grass are matt: without this they shine like wet glass when looked along.
	for node in city.find_children("*", "MeshInstance3D", true, false):
		if not node.name.begins_with("buildings") and not node.name.begins_with("roofs") and not node.name.begins_with("water"):
			for surface in node.mesh.get_surface_count():
				var ground: BaseMaterial3D = node.mesh.surface_get_material(surface)
				ground.roughness = 1.0
				ground.metallic_specular = 0.15

	_plant(parent)

	# The ground to stand on, and invisible walls where the map ends.
	var radius: float = info.radius
	Build.blocker(parent, Vector3(0, -0.5, 0), Vector3(radius * 2, 1, radius * 2))
	var walls_round := 90
	for i in walls_round:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * radius / walls_round + 4, 40, 2)
		shape.shape = box
		body.add_child(shape)
		body.rotation.y = -i * TAU / walls_round + PI / 2
		body.position = Vector3(cos(i * TAU / walls_round), 0, sin(i * TAU / walls_round)) * (radius - 2) + Vector3(0, 20, 0)
		parent.add_child(body)
	return {"places": info.places, "lamps": info.lamps, "walls": walls}


## Stands a tree on every spot in trees.bin (x, z, metres tall, ...): the trees the Comune mapped, as tall as
## the laser survey saw them. Each chunk's trees are one MultiMesh.
## ponytail: trees have no collision, you walk through the trunks; add a capsule per tree near the player if that matters.
static func _plant(parent: Node3D) -> void:
	var spots := FileAccess.get_file_as_bytes(TREES).to_float32_array()
	var chunks := {}
	for i in range(0, spots.size(), 3):
		chunks.get_or_add(Vector2i(floori(spots[i] / CHUNK), floori(spots[i + 1] / CHUNK)), []).append(Vector3(spots[i], spots[i + 2], spots[i + 1]))
	var tree := _tree()
	for key in chunks:
		var grove := MultiMesh.new()
		grove.transform_format = MultiMesh.TRANSFORM_3D
		grove.mesh = tree
		grove.instance_count = chunks[key].size()
		for i in grove.instance_count:
			var spot: Vector3 = chunks[key][i]
			var size := spot.y / 7.0   # the model is 7 m tall
			grove.set_instance_transform(i, Transform3D(Basis(Vector3.UP, spot.x + spot.z).scaled(Vector3.ONE * size), Vector3(spot.x, 0, spot.z)))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = grove
		parent.add_child(instance)


## One simple tree, about 7 m tall: a trunk and a round crown.
static func _tree() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.22
	trunk.height = 2.8
	trunk.radial_segments = 5
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = 2.3
	crown.height = 4.8
	crown.radial_segments = 7
	crown.rings = 4
	var mesh := ArrayMesh.new()
	for part in [[trunk, 1.4, Color(0.33, 0.24, 0.16)], [crown, 4.6, Color(0.17, 0.38, 0.15)]]:
		var tool := SurfaceTool.new()
		tool.append_from(part[0], 0, Transform3D(Basis(), Vector3(0, part[1], 0)))
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		tool.set_material(material)
		tool.commit(mesh)
	return mesh


## 0 by day, 1 at night: how brightly the lit windows shine.
static func set_night(walls: Array, amount: float) -> void:
	for material in walls:
		material.set_shader_parameter("night", amount)
