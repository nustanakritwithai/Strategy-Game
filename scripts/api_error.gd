extends RefCounted
class_name ApiError

## Turns a server error body into text the player can read.
## GameError messages and FastAPI validation msgs are kept as the server sent them.


static func is_maintenance(status: int, payload: Variant) -> bool:
	if status == 503:
		return true
	if payload is Dictionary:
		var err = (payload as Dictionary).get("error")
		if err is Dictionary and str((err as Dictionary).get("code", "")) == "maintenance":
			return true
	return false


static func verbatim(payload: Variant, status: int = 0) -> String:
	if payload is Dictionary:
		var err = payload.get("error")
		if err is Dictionary:
			var msg := str(err.get("message", ""))
			var code := str(err.get("code", ""))
			if msg != "" and code != "":
				return "%s\ncode: %s" % [msg, code]
			if msg != "":
				return msg
		if payload.has("detail"):
			return format_detail(payload["detail"])
		if payload.has("message"):
			return str(payload["message"])
	if payload is String and str(payload) != "":
		return str(payload)
	if status > 0:
		return "HTTP %s" % status
	return ""


static func format_detail(detail: Variant) -> String:
	if detail is String:
		return detail
	if detail is Array:
		var lines := PackedStringArray()
		for item in detail:
			if item is Dictionary:
				var msg := str(item.get("msg", ""))
				var loc_txt := _loc(item.get("loc", []))
				if msg != "" and loc_txt != "":
					lines.append("%s\nlocation: %s" % [msg, loc_txt])
				elif msg != "":
					lines.append(msg)
				else:
					lines.append(str(item))
			else:
				lines.append(str(item))
		return "\n".join(lines)
	return str(detail)


static func _loc(loc: Variant) -> String:
	if loc is Array:
		var parts := PackedStringArray()
		for part in loc:
			parts.append(str(part))
		return ".".join(parts)
	if loc == null:
		return ""
	return str(loc)


static func header_value(headers: PackedStringArray, name: String) -> String:
	var prefix := name.to_lower() + ":"
	for header in headers:
		if header.to_lower().begins_with(prefix):
			return header.substr(name.length() + 1).strip_edges()
	return ""
