extends RefCounted
class_name Icons

## Small vector icons drawn with CanvasItem calls. No texture assets.

const OWN_CITY := Color("f0c14a")
const OTHER_CITY := Color("e07a5f")
const ARMY := Color("8ecae6")
const OUTLINE := Color("0d1117")
const SELECT := Color("f7f7f2")


static func _poly(ci: CanvasItem, center: Vector2, s: float, points: Array, color: Color) -> void:
	var out := PackedVector2Array()
	for p in points:
		out.append(center + (p as Vector2) * s)
	ci.draw_colored_polygon(out, color)
	out.append(out[0])
	ci.draw_polyline(out, OUTLINE, 1.5)


## Castle with three towers and a gate.
static func own_city(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	_poly(ci, c, s, [
		Vector2(-12, 9), Vector2(-12, -6), Vector2(-12, -10), Vector2(-8, -10), Vector2(-8, -6),
		Vector2(-3, -6), Vector2(-3, -13), Vector2(3, -13), Vector2(3, -6), Vector2(8, -6),
		Vector2(8, -10), Vector2(12, -10), Vector2(12, 9),
	], OWN_CITY)
	_poly(ci, c, s, [Vector2(-3, 9), Vector2(-3, 2), Vector2(0, -1), Vector2(3, 2), Vector2(3, 9)], Color("6b4f1d"))


## House with a pitched roof.
static func other_city(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	_poly(ci, c, s, [Vector2(-10, 9), Vector2(-10, -1), Vector2(10, -1), Vector2(10, 9)], Color("c9b89a"))
	_poly(ci, c, s, [Vector2(-13, 0), Vector2(0, -12), Vector2(13, 0)], OTHER_CITY)
	_poly(ci, c, s, [Vector2(-2, 9), Vector2(-2, 3), Vector2(3, 3), Vector2(3, 9)], Color("5b3a29"))


## Shield with a crossed-sword stroke.
static func army(ci: CanvasItem, c: Vector2, s: float = 1.0, selected: bool = false) -> void:
	_poly(ci, c, s, [
		Vector2(-8, -9), Vector2(8, -9), Vector2(8, 0), Vector2(0, 10), Vector2(-8, 0),
	], SELECT if selected else ARMY)
	var ink := Color("1d3557")
	ci.draw_line(c + Vector2(-4, -5) * s, c + Vector2(4, 4) * s, ink, 2.0)
	ci.draw_line(c + Vector2(4, -5) * s, c + Vector2(-4, 4) * s, ink, 2.0)


static func wood(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	_poly(ci, c, s, [Vector2(-8, -3), Vector2(6, -3), Vector2(6, 3), Vector2(-8, 3)], Color("a06a3c"))
	ci.draw_circle(c + Vector2(6, 0) * s, 3.2 * s, Color("e3c08d"))
	ci.draw_arc(c + Vector2(6, 0) * s, 1.4 * s, 0, TAU, 10, Color("a06a3c"), 1.0)


static func food(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	var stalk := Color("e9c46a")
	ci.draw_line(c + Vector2(0, 8) * s, c + Vector2(0, -8) * s, Color("b08d2f"), 1.5)
	for i in 3:
		var y := -6.0 + 4.0 * i
		ci.draw_circle(c + Vector2(-2.5, y) * s, 2.0 * s, stalk)
		ci.draw_circle(c + Vector2(2.5, y) * s, 2.0 * s, stalk)


static func iron(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	_poly(ci, c, s, [Vector2(-8, 5), Vector2(-5, -4), Vector2(5, -4), Vector2(8, 5)], Color("9aa5b1"))
	ci.draw_line(c + Vector2(-4, -2) * s, c + Vector2(4, -2) * s, Color("dfe6ee"), 1.0)


static func gold(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_circle(c, 7.0 * s, Color("f4c430"))
	ci.draw_arc(c, 7.0 * s, 0, TAU, 20, OUTLINE, 1.2)
	ci.draw_arc(c, 4.2 * s, 0, TAU, 16, Color("b8860b"), 1.2)


static func resource(ci: CanvasItem, key: String, c: Vector2, s: float = 1.0) -> void:
	match key:
		"wood":
			wood(ci, c, s)
		"food":
			food(ci, c, s)
		"iron":
			iron(ci, c, s)
		"gold":
			gold(ci, c, s)
