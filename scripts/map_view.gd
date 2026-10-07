extends Control
class_name MapView

## Pan and zoom map. Army markers move from server depart_at / arrive_at only.

signal city_picked(city_id: int)
signal army_picked(army_id: int)
signal point_picked(world: Vector2)

var font: Font
var cities: Array = []
var armies: Array = []
var now_ms: int = 0
var my_player_id: int = 0
var selected_city_id: int = 0
var selected_army_id: int = 0
var target_mode: String = ""
var legend_own := ""
var legend_other := ""
var legend_army := ""
var camera := Vector2(25, 30)
var zoom := 14.0
var fitted := false

var _dragging := false
var _moved := false
var _drag_origin := Vector2.ZERO
var _camera_origin := Vector2.ZERO
var _touches := {}
var _pinch_distance := 0.0

const HIT_RADIUS := 28.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func fit(list: Array) -> void:
	if list.is_empty() or size.x < 20.0 or size.y < 20.0:
		return
	var min_x := 1.0e9
	var min_y := 1.0e9
	var max_x := -1.0e9
	var max_y := -1.0e9
	for city in list:
		if not (city is Dictionary):
			continue
		var x := float(city.get("x", 0.0))
		var y := float(city.get("y", 0.0))
		min_x = min(min_x, x)
		min_y = min(min_y, y)
		max_x = max(max_x, x)
		max_y = max(max_y, y)
	camera = Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var span: float = max(max_x - min_x, max_y - min_y)
	span = max(span, 30.0)
	zoom = clampf(min(size.x, size.y) * 0.62 / span, 6.0, 28.0)
	fitted = true
	queue_redraw()


func _world_to_screen(world: Vector2) -> Vector2:
	return size * 0.5 + (world - camera) * zoom


func _screen_to_world(screen: Vector2) -> Vector2:
	return (screen - size * 0.5) / zoom + camera


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var world_before := _screen_to_world(screen_pos)
	zoom = clampf(zoom * factor, 4.0, 64.0)
	camera = world_before - (screen_pos - size * 0.5) / zoom
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _touches.size() >= 2:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 1.0 / 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_moved = false
				_drag_origin = button.position
				_camera_origin = camera
			else:
				if _dragging and not _moved:
					_pick(button.position)
				_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if _drag_origin.distance_to(motion.position) > 8.0:
			_moved = true
		camera = _camera_origin - (motion.position - _drag_origin) / zoom
		queue_redraw()
		accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not get_global_rect().has_point(touch.position):
				return
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		if _touches.size() >= 2:
			_pinch_distance = _touch_distance()
			_dragging = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			var distance := _touch_distance()
			if _pinch_distance > 1.0 and distance > 1.0:
				var midpoint := _touch_midpoint() - global_position
				_zoom_at(midpoint, distance / _pinch_distance)
			_pinch_distance = distance
			accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		if get_global_rect().has_point(magnify.position):
			_zoom_at(magnify.position - global_position, magnify.factor)
			accept_event()


func _touch_distance() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1])


func _touch_midpoint() -> Vector2:
	var points: Array = _touches.values()
	if points.size() < 2:
		return size * 0.5
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


func _pick(screen_pos: Vector2) -> void:
	if target_mode == "":
		var army_id := _closest_army(screen_pos)
		if army_id != 0:
			army_picked.emit(army_id)
			return
	var city_id := _closest_city(screen_pos)
	if city_id != 0:
		city_picked.emit(city_id)
		return
	point_picked.emit(_screen_to_world(screen_pos))


func _closest_city(screen_pos: Vector2) -> int:
	var best_id := 0
	var best := HIT_RADIUS
	for city in cities:
		if not (city is Dictionary) or not city.has("x") or not city.has("y"):
			continue
		var point := _world_to_screen(Vector2(float(city["x"]), float(city["y"])))
		var distance := point.distance_to(screen_pos)
		if distance < best:
			best = distance
			best_id = int(city.get("id", 0))
	return best_id


func _closest_army(screen_pos: Vector2) -> int:
	var best_id := 0
	var best := HIT_RADIUS
	for army in armies:
		if not (army is Dictionary):
			continue
		if not MovementInterp.known_position(army, now_ms):
			continue
		var point := _world_to_screen(MovementInterp.army_position(army, now_ms))
		var distance := point.distance_to(screen_pos)
		if distance < best:
			best = distance
			best_id = int(army.get("id", 0))
	return best_id


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("12171f"))
	var top_left := _screen_to_world(Vector2.ZERO)
	var bottom_right := _screen_to_world(size)
	var start_x := int(floor(min(top_left.x, bottom_right.x) / 10.0)) * 10 - 10
	var end_x := int(ceil(max(top_left.x, bottom_right.x) / 10.0)) * 10 + 10
	var start_y := int(floor(min(top_left.y, bottom_right.y) / 10.0)) * 10 - 10
	var end_y := int(ceil(max(top_left.y, bottom_right.y) / 10.0)) * 10 + 10
	var grid := Color(1, 1, 1, 0.06)
	for x in range(start_x, end_x + 1, 10):
		var from := _world_to_screen(Vector2(x, start_y))
		var to := _world_to_screen(Vector2(x, end_y))
		draw_line(from, to, grid, 1.0)
	for y in range(start_y, end_y + 1, 10):
		var from := _world_to_screen(Vector2(start_x, y))
		var to := _world_to_screen(Vector2(end_x, y))
		draw_line(from, to, grid, 1.0)
	for army in armies:
		if not (army is Dictionary):
			continue
		var movement = army.get("movement")
		if movement is Dictionary and MovementInterp.known_position(army, now_ms):
			var dest = movement.get("destination")
			if dest is Dictionary and dest.has("x") and dest.has("y"):
				var here := MovementInterp.army_position(army, now_ms)
				var there := Vector2(float(dest["x"]), float(dest["y"]))
				draw_line(_world_to_screen(here), _world_to_screen(there), Color("8ecae6a0"), 2.0)
	for city in cities:
		if not (city is Dictionary) or not city.has("x") or not city.has("y"):
			continue
		var point := _world_to_screen(Vector2(float(city["x"]), float(city["y"])))
		var mine := bool(city.get("is_mine", int(city.get("player_id", -1)) == my_player_id))
		var color := Color("f0c14a") if mine else Color("e07a5f")
		draw_circle(point, 11.0, color)
		if int(city.get("id", 0)) == selected_city_id:
			draw_arc(point, 16.0, 0, TAU, 24, Color("f7f7f2"), 2.0)
		if font != null:
			var label := Present.field(city, "name")
			draw_string(font, point + Vector2(14, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2f4f8"))
	for army in armies:
		if not (army is Dictionary):
			continue
		if not MovementInterp.known_position(army, now_ms):
			continue
		var point := _world_to_screen(MovementInterp.army_position(army, now_ms))
		var selected := int(army.get("id", 0)) == selected_army_id
		draw_colored_polygon(
			PackedVector2Array([
				point + Vector2(0, -12),
				point + Vector2(10, 8),
				point + Vector2(-10, 8),
			]),
			Color("f7f7f2") if selected else Color("8ecae6")
		)
		if font != null:
			draw_string(font, point + Vector2(12, -6), Present.field(army, "name"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d7eef7"))
	if font != null and legend_own != "":
		draw_circle(Vector2(18, 18), 6, Color("f0c14a"))
		draw_string(font, Vector2(30, 24), legend_own, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2f4f8"))
		draw_circle(Vector2(18, 40), 6, Color("e07a5f"))
		draw_string(font, Vector2(30, 46), legend_other, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2f4f8"))
		draw_colored_polygon(
			PackedVector2Array([Vector2(18, 54), Vector2(24, 66), Vector2(12, 66)]),
			Color("8ecae6")
		)
		draw_string(font, Vector2(30, 68), legend_army, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2f4f8"))
