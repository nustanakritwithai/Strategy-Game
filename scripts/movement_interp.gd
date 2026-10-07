extends RefCounted
class_name MovementInterp

## Display-only march positions.
## Same formula as the server's travel_progress and interpolate.
## depart_at and arrive_at come from the server. This does not choose travel time.


static func progress(depart_ms: int, arrive_ms: int, now_ms: int) -> float:
	var total := arrive_ms - depart_ms
	if total <= 0:
		return 1.0
	return clampf(float(now_ms - depart_ms) / float(total), 0.0, 1.0)


static func position(origin: Vector2, dest: Vector2, amount: float) -> Vector2:
	var clamped := clampf(amount, 0.0, 1.0)
	return Vector2(
		origin.x + (dest.x - origin.x) * clamped,
		origin.y + (dest.y - origin.y) * clamped
	)


static func known_position(army: Dictionary, now_ms: int) -> bool:
	return _known(army, now_ms)


static func _point(node: Variant) -> Variant:
	if node is Dictionary and (node as Dictionary).has("x") and (node as Dictionary).has("y"):
		return Vector2(float((node as Dictionary)["x"]), float((node as Dictionary)["y"]))
	return null


static func _known(army: Dictionary, now_ms: int) -> bool:
	var movement = army.get("movement")
	if movement is Dictionary:
		var depart := IsoTime.parse_unix_ms(str(movement.get("depart_at", "")))
		var arrive := IsoTime.parse_unix_ms(str(movement.get("arrive_at", "")))
		if (depart != 0 or arrive != 0) and _point(movement.get("origin")) != null and _point(movement.get("destination")) != null:
			return true
	return _point(army.get("position")) != null


static func army_position(army: Dictionary, now_ms: int) -> Vector2:
	var movement = army.get("movement")
	if movement is Dictionary:
		var depart := IsoTime.parse_unix_ms(str(movement.get("depart_at", "")))
		var arrive := IsoTime.parse_unix_ms(str(movement.get("arrive_at", "")))
		var origin = _point(movement.get("origin"))
		var dest = _point(movement.get("destination"))
		if (depart != 0 or arrive != 0) and origin is Vector2 and dest is Vector2:
			return position(origin, dest, progress(depart, arrive, now_ms))
	var pos = _point(army.get("position"))
	if pos is Vector2:
		return pos
	return Vector2.ZERO
