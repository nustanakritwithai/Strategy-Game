extends RefCounted
class_name LabelLayout

## Screen-space placement so map markers and their names do not sit on top of
## each other. Display only: world positions from the server are not changed.


## Moves each point in `moving` by `step` until it is at least `min_dist` from every
## point in `fixed` and from the moving points already placed.
static func offset_markers(fixed: Array, moving: Array, min_dist: float, step: Vector2, max_steps: int = 12) -> Array:
	var placed: Array = []
	for item in moving:
		var p: Vector2 = item
		var tries := 0
		while tries < max_steps and (_near(p, fixed, min_dist) or _near(p, placed, min_dist)):
			p += step
			tries += 1
		placed.append(p)
	return placed


static func _near(p: Vector2, points: Array, min_dist: float) -> bool:
	for other in points:
		if p.distance_to(other as Vector2) < min_dist:
			return true
	return false


## items: [{"anchor": Vector2, "radius": float, "size": Vector2, "prefer": "below"|"right"}]
## Returns one Rect2 per item. Tries the preferred side first, then the others,
## then stacks further out until the label clears every marker and placed label.
## When `bounds` has an area, a spot fully inside it wins over one that is clipped.
static func place(items: Array, bounds: Rect2 = Rect2(), max_stack: int = 8) -> Array:
	var blocked: Array = []
	for item in items:
		var a: Vector2 = item["anchor"]
		var r: float = float(item["radius"])
		blocked.append(Rect2(a - Vector2(r, r), Vector2(r, r) * 2.0))
	var out: Array = []
	for item in items:
		var candidates := _candidates(item, max_stack, bounds)
		var chosen: Rect2 = candidates[candidates.size() - 1]
		var found := false
		if bounds.has_area():
			for rect in candidates:
				if bounds.encloses(rect) and not _hits(rect, blocked):
					chosen = rect
					found = true
					break
		if not found:
			for rect in candidates:
				if not _hits(rect, blocked):
					chosen = rect
					break
		blocked.append(chosen)
		out.append(chosen)
	return out


static func _candidates(item: Dictionary, max_stack: int, bounds: Rect2 = Rect2()) -> Array:
	var a: Vector2 = item["anchor"]
	var r: float = float(item["radius"])
	var sz: Vector2 = item["size"]
	var right := Rect2(a + Vector2(r + 4.0, -sz.y * 0.5), sz)
	var left := Rect2(a + Vector2(-r - 4.0 - sz.x, -sz.y * 0.5), sz)
	var centered_x := a.x - sz.x * 0.5
	if bounds.has_area() and sz.x <= bounds.size.x:
		# A label under or over its marker may slide sideways to stay on screen.
		centered_x = clampf(centered_x, bounds.position.x, bounds.end.x - sz.x)
	var below := Rect2(Vector2(centered_x, a.y + r + 2.0), sz)
	var above := Rect2(Vector2(centered_x, a.y - r - 2.0 - sz.y), sz)
	var out: Array = []
	if str(item.get("prefer", "right")) == "below":
		out = [below, above, right, left]
		for k in range(1, max_stack + 1):
			out.append(Rect2(below.position + Vector2(0, k * (sz.y + 2.0)), sz))
	else:
		out = [right, above, left, below]
		for k in range(1, max_stack + 1):
			out.append(Rect2(right.position + Vector2(0, k * (sz.y + 2.0)), sz))
	return out


static func _hits(rect: Rect2, blocked: Array) -> bool:
	for other in blocked:
		if rect.intersects(other as Rect2):
			return true
	return false
