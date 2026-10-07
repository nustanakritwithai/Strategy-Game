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


## Godot parses every JSON number as a float, so a 64-bit seed would be rounded.
## Integers with 16 or more digits are quoted before parsing and stay exact text.
static func parse_preserving_integers(text: String) -> Variant:
	if text == "":
		return null
	return JSON.parse_string(_quote_wide_integers(text))


static func _quote_wide_integers(text: String) -> String:
	var out := ""
	var i := 0
	var in_string := false
	var escape := false
	while i < text.length():
		var ch := text.substr(i, 1)
		if in_string:
			out += ch
			if escape:
				escape = false
			elif ch == "\\":
				escape = true
			elif ch == "\"":
				in_string = false
			i += 1
			continue
		if ch == "\"":
			in_string = true
			out += ch
			i += 1
			continue
		if ch == "-" or (ch >= "0" and ch <= "9"):
			var start := i
			if ch == "-":
				i += 1
			var digits := 0
			while i < text.length():
				var digit := text.substr(i, 1)
				if digit < "0" or digit > "9":
					break
				digits += 1
				i += 1
			if i < text.length():
				var mark := text.substr(i, 1)
				if mark == "." or mark == "e" or mark == "E":
					i += 1
					while i < text.length():
						var more := text.substr(i, 1)
						if (more >= "0" and more <= "9") or more == "+" or more == "-" or more == "e" or more == "E" or more == ".":
							i += 1
							continue
						break
					out += text.substr(start, i - start)
					continue
			var raw := text.substr(start, i - start)
			if digits >= 16:
				out += "\"%s\"" % raw
			else:
				out += raw
			continue
		out += ch
		i += 1
	return out


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
