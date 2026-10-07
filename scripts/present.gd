extends RefCounted
class_name Present

## Text for a value the server sent.
## A missing field is UNKNOWN. The client does not invent a number or a name.


const UNKNOWN := "UNKNOWN"


static func field(row: Variant, key: String) -> String:
	if not (row is Dictionary):
		return UNKNOWN
	if not (row as Dictionary).has(key):
		return UNKNOWN
	return text((row as Dictionary)[key])


static func text(value: Variant) -> String:
	if value == null:
		return UNKNOWN
	if value is String and (value as String) == "":
		return UNKNOWN
	return str(value)
