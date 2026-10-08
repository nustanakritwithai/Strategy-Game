extends Control
class_name ResourceBar

## Wood, food, iron, and gold of one city, from the latest server payload only.
## A value the server did not send shows UNKNOWN.

const KEYS := ["wood", "food", "iron", "gold"]

var font: Font
var city: Dictionary = {}
var title := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_city(row: Dictionary, city_title: String) -> void:
	city = row
	title = city_title
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1a2230"))
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color(1, 1, 1, 0.08), 1.0)
	if font == null:
		return
	var fs := 15
	var left := 8.0
	var mid_y := size.y * 0.5
	if title != "" and size.x >= 640.0:
		var title_w: float = min(220.0, font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		draw_string(font, Vector2(left, mid_y + fs * 0.35), title, HORIZONTAL_ALIGNMENT_LEFT, 220, fs, Color("f0c14a"))
		left += title_w + 16.0
	var cell_w: float = min(170.0, (size.x - left - 4.0) / KEYS.size())
	for i in KEYS.size():
		var key: String = KEYS[i]
		var x := left + cell_w * i
		Icons.resource(self, key, Vector2(x + 10, mid_y), 0.9)
		var value := Present.field(city, key) if not city.is_empty() else Present.UNKNOWN
		var color := Color("f2f4f8") if value != Present.UNKNOWN else Color("e09a32")
		var room := cell_w - 24.0
		var size_px := fs
		while size_px > 10 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > room:
			size_px -= 1
		draw_string(font, Vector2(x + 21, mid_y + size_px * 0.35), value, HORIZONTAL_ALIGNMENT_LEFT, room, size_px, color)
