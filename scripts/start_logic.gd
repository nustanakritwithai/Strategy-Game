extends RefCounted
class_name StartLogic

## New-player start, as the server reports it.
## Register grants a home city and an army. GET /v1/auth/me and the register and
## claim-start bodies carry start_granted, home_city, and army_id. An account with
## start_granted false calls POST /v1/auth/claim-start once. The client never
## chooses the tile and never sends coordinates for the first city.

const CLAIM_PATH := "/v1/auth/claim-start"


## known is false when the server did not send start_granted (an older server).
static func parse(payload: Variant) -> Dictionary:
	var out := {"known": false, "start_granted": null, "home_city": null, "army_id": null}
	if not (payload is Dictionary):
		return out
	var row: Dictionary = payload
	if row.has("start_granted") and row["start_granted"] is bool:
		out["known"] = true
		out["start_granted"] = row["start_granted"]
	if row.get("home_city") is Dictionary:
		out["home_city"] = (row["home_city"] as Dictionary).duplicate(true)
	if row.has("army_id") and row["army_id"] != null:
		out["army_id"] = row["army_id"]
	return out


static func needs_claim(info: Dictionary) -> bool:
	return bool(info.get("known", false)) and info.get("start_granted") is bool and info["start_granted"] == false


static func granted(info: Dictionary) -> bool:
	return info.get("start_granted") is bool and info["start_granted"] == true


static func home_city_id(info: Dictionary) -> int:
	var city = info.get("home_city")
	if city is Dictionary:
		return Present.id_of((city as Dictionary).get("id"))
	return 0


static func army_id(info: Dictionary) -> int:
	return Present.id_of(info.get("army_id"))


## World point of the home city, or null when x or y is missing.
static func home_point(info: Dictionary) -> Variant:
	var city = info.get("home_city")
	if not (city is Dictionary):
		return null
	var row: Dictionary = city
	var x = row.get("x")
	var y = row.get("y")
	if not (x is float or x is int) or not (y is float or y is int):
		return null
	return Vector2(float(x), float(y))


## Claim-start takes no body. In particular it never carries x or y.
static func claim_body() -> Variant:
	return null


static func granted_text(info: Dictionary, yes: String, no: String) -> String:
	if not bool(info.get("known", false)):
		return Present.UNKNOWN
	return yes if granted(info) else no


static func home_text(info: Dictionary) -> String:
	var city = info.get("home_city")
	if not (city is Dictionary):
		return Present.UNKNOWN
	return "%s (%s, %s)" % [
		Present.field(city, "name"),
		Present.field(city, "x"),
		Present.field(city, "y"),
	]
