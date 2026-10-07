extends RefCounted
class_name JsonText

const SECRET_KEYS := {
	"access_token": true,
	"refresh_token": true,
	"token": true,
	"password": true,
	"authorization": true,
}


static func redact(value: Variant) -> Variant:
	if value is Dictionary:
		var copy := {}
		for key in value:
			if SECRET_KEYS.has(str(key).to_lower()):
				copy[key] = "[redacted]"
			else:
				copy[key] = redact(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		for item in value:
			copy.append(redact(item))
		return copy
	return value


static func pretty(value: Variant, indent: int = 0) -> String:
	var pad := "  ".repeat(indent)
	if value == null:
		return "null"
	if value is Dictionary:
		if value.is_empty():
			return "{}"
		var lines := PackedStringArray()
		lines.append("{")
		for key in value.keys():
			lines.append("%s  %s: %s" % [pad, str(key), pretty(value[key], indent + 1)])
		lines.append("%s}" % pad)
		return "\n".join(lines)
	if value is Array:
		if value.is_empty():
			return "[]"
		var lines := PackedStringArray()
		lines.append("[")
		for item in value:
			lines.append("%s  %s" % [pad, pretty(item, indent + 1)])
		lines.append("%s]" % pad)
		return "\n".join(lines)
	if value is bool:
		return "true" if value else "false"
	if value is String:
		return value
	return str(value)


static func uuid4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = rng.randi() % 256
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex_chars := "0123456789abcdef"
	var hex := ""
	for b in bytes:
		hex += hex_chars[int(b) >> 4]
		hex += hex_chars[int(b) & 15]
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]
