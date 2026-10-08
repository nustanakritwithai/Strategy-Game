extends RefCounted
class_name Present

## Text for a value the server sent.
## A missing field is UNKNOWN. The client does not invent a number or a name.
## Godot parses every JSON number as a float, so a whole number such as 1 arrives
## as 1.0. Whole numbers are printed without the fraction. Integers too wide for a
## float are kept as their raw text by JsonText.parse_preserving_integers.


const UNKNOWN := "UNKNOWN"
const EXACT_FLOAT_LIMIT := 9007199254740992.0


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
	if value is float:
		return number(value)
	if value is Array or value is Dictionary:
		return compact(value)
	return str(value)


## A whole float prints as an integer. Anything else keeps Godot's text.
static func number(value: float) -> String:
	if is_finite(value) and value == floor(value) and abs(value) <= EXACT_FLOAT_LIMIT:
		return str(int(value))
	return str(value)


## One-line text for a list or a map, with whole numbers shown as integers.
static func compact(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Dictionary:
		var parts := PackedStringArray()
		for key in (value as Dictionary).keys():
			parts.append("%s: %s" % [str(key), compact(value[key])])
		return "{%s}" % ", ".join(parts)
	if value is Array:
		var items := PackedStringArray()
		for item in value:
			items.append(compact(item))
		return "[%s]" % ", ".join(items)
	if value is float:
		return number(value)
	if value is bool:
		return "true" if value else "false"
	return str(value)


## "#12" for an id the server sent, UNKNOWN when it did not.
static func id_text(value: Variant) -> String:
	var shown := text(value)
	if shown == UNKNOWN:
		return UNKNOWN
	return "#%s" % shown


## Integer value of an id field, or 0 when the server did not send a usable one.
static func id_of(value: Variant) -> int:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is String and (value as String).is_valid_int():
		return (value as String).to_int()
	return 0


## Rows for the battle-round table: round, damage to attacker, damage to defender,
## and the two variance values in basis points exactly as the server stored them.
## A round that is not an object, or a missing key, shows UNKNOWN.
static func round_rows(rounds: Variant) -> Array:
	var rows: Array = []
	if not (rounds is Array):
		return rows
	for entry in rounds:
		if not (entry is Dictionary):
			rows.append([UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN])
			continue
		var row: Dictionary = entry
		var round_key := "round" if row.has("round") else "round_index"
		rows.append([
			field(row, round_key),
			field(row, "damage_to_attacker"),
			field(row, "damage_to_defender"),
			"%s / %s" % [field(row, "attacker_variance_bp"), field(row, "defender_variance_bp")],
		])
	return rows
