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


static func _xy(node: Variant) -> Vector2:
	if node is Dictionary:
		return Vector2(float(node.get("x", 0.0)), float(node.get("y", 0.0)))
	return Vector2.ZERO


static func army_position(army: Dictionary, now_ms: int) -> Vector2:
	var movement = army.get("movement")
	if movement is Dictionary:
		var depart := IsoTime.parse_unix_ms(str(movement.get("depart_at", "")))
		var arrive := IsoTime.parse_unix_ms(str(movement.get("arrive_at", "")))
		if depart != 0 or arrive != 0:
			var origin := _xy(movement.get("origin", {}))
			var dest := _xy(movement.get("destination", {}))
			return position(origin, dest, progress(depart, arrive, now_ms))
	var pos = army.get("position")
	if pos is Dictionary and (pos.has("x") or pos.has("y")):
		return _xy(pos)
	return Vector2.ZERO
