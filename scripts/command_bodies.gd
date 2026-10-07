extends RefCounted
class_name CommandBodies

## JSON bodies for player commands. Field names match the server models.
## The server validates them and decides the outcome.


static func idempotency_key(existing: String, retrying: bool) -> String:
	var key := existing.strip_edges()
	if retrying and key != "":
		return key
	return JsonText.uuid4()


static func move_body(army_id: int, destination_city_id: int, relocate: bool) -> Dictionary:
	return {
		"army_id": army_id,
		"destination_city_id": destination_city_id,
		"relocate": relocate,
	}


static func attack_body(army_id: int, target_city_id: int) -> Dictionary:
	return {"army_id": army_id, "target_city_id": target_city_id}


static func recall_body(army_id: int) -> Dictionary:
	return {"army_id": army_id}


static func build_body(city_id: int, building: String) -> Dictionary:
	return {"city_id": city_id, "building": building}


static func research_body(tech: String) -> Dictionary:
	return {"tech": tech}


static func train_body(city_id: int, unit_type: String, count: int, army_id: int) -> Dictionary:
	var body := {"city_id": city_id, "unit_type": unit_type, "count": count}
	if army_id > 0:
		body["army_id"] = army_id
	return body


static func found_city_body(source_city_id: int, x: int, y: int, city_name: String) -> Dictionary:
	return {
		"source_city_id": source_city_id,
		"x": x,
		"y": y,
		"name": city_name,
	}


static func garrison_body(army_id: int, city_id: int) -> Dictionary:
	return {"army_id": army_id, "city_id": city_id}


static func transfer_body(
	source_city_id: int,
	destination_city_id: int,
	wood: int,
	food: int,
	iron: int,
	gold: int
) -> Dictionary:
	return {
		"source_city_id": source_city_id,
		"destination_city_id": destination_city_id,
		"wood": wood,
		"food": food,
		"iron": iron,
		"gold": gold,
	}
