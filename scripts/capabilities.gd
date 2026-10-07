extends RefCounted
class_name Capabilities

## Which player routes the connected server actually exposes.
## Missing routes stay disabled. The client does not invent their results.


const ROUTES := {
	"register": "/v1/auth/register",
	"login": "/v1/auth/login",
	"refresh": "/v1/auth/refresh",
	"logout": "/v1/auth/logout",
	"logout_all": "/v1/auth/logout-all",
	"change_password": "/v1/auth/change-password",
	"auth_me": "/v1/auth/me",
	"claim_start": "/v1/auth/claim-start",
	"dev_login": "/v1/auth/dev-login",
	"move": "/v1/commands/move",
	"attack": "/v1/commands/attack",
	"recall": "/v1/commands/recall",
	"build": "/v1/commands/build",
	"research": "/v1/commands/research",
	"train": "/v1/commands/train",
	"found_city": "/v1/commands/found-city",
	"garrison": "/v1/commands/garrison",
	"transfer": "/v1/commands/transfer",
}

const PLAYER_AUTH_KEYS := ["register", "login", "refresh", "logout"]


static func empty() -> Dictionary:
	var caps := {"player_auth": false, "idempotency_spec": false, "idempotency": false}
	for key in ROUTES:
		caps[key] = false
	return caps


static func from_openapi(spec: Dictionary) -> Dictionary:
	var caps := empty()
	var paths: Dictionary = spec.get("paths", {})
	for key in ROUTES:
		caps[key] = paths.has(ROUTES[key])
	caps["player_auth"] = _all(caps, PLAYER_AUTH_KEYS)
	caps["idempotency_spec"] = spec_mentions_idempotency(spec)
	caps["idempotency"] = false
	return caps


static func from_status_codes(codes: Dictionary) -> Dictionary:
	var caps := empty()
	for key in ROUTES:
		var code := int(codes.get(ROUTES[key], codes.get(key, 0)))
		caps[key] = code != 0 and code != 404
	caps["player_auth"] = _all(caps, PLAYER_AUTH_KEYS)
	return caps


static func mark_missing(caps: Dictionary, key: String) -> Dictionary:
	var next := caps.duplicate(true)
	next[key] = false
	if key in PLAYER_AUTH_KEYS:
		next["player_auth"] = false
	return next


static func spec_mentions_idempotency(node: Variant) -> bool:
	if node is String:
		var lowered: String = (node as String).to_lower()
		return lowered == "idempotency-key" or lowered == "idempotency_key"
	if node is Dictionary:
		for key in node:
			if spec_mentions_idempotency(key) or spec_mentions_idempotency(node[key]):
				return true
	if node is Array:
		for item in node:
			if spec_mentions_idempotency(item):
				return true
	return false


static func cors_allows_header(allow_headers: String, header_name: String) -> bool:
	var want := header_name.strip_edges().to_lower()
	for part in allow_headers.split(","):
		var item := part.strip_edges().to_lower()
		if item == want or item == "*":
			return true
	return false


static func should_send_idempotency(openapi_mentions: bool, cors_checked: bool, cors_allows: bool) -> bool:
	# A browser blocks the whole request when the header is not allowed.
	# Trust a completed CORS check over the OpenAPI text.
	if cors_checked:
		return cors_allows
	return openapi_mentions


static func schema_properties(spec: Dictionary, path: String, method: String = "post") -> PackedStringArray:
	var paths: Dictionary = spec.get("paths", {})
	if not paths.has(path):
		return PackedStringArray()
	var op: Dictionary = paths[path].get(method, {})
	var schema: Dictionary = op.get("requestBody", {}).get("content", {}).get("application/json", {}).get("schema", {})
	schema = resolve_schema(spec, schema)
	var props: Dictionary = schema.get("properties", {})
	var out := PackedStringArray()
	for key in props:
		out.append(str(key))
	return out


static func resolve_schema(spec: Dictionary, schema: Dictionary) -> Dictionary:
	var ref := str(schema.get("$ref", ""))
	if ref == "":
		return schema
	if not ref.begins_with("#/"):
		return schema
	var node: Variant = spec
	for part in ref.substr(2).split("/"):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return schema
	if node is Dictionary:
		return node
	return schema


static func auth_body(
	properties: PackedStringArray,
	username: String,
	password: String,
	email: String = ""
) -> Dictionary:
	var body := {}
	var keys := properties
	if keys.is_empty() or keys.has("username"):
		body["username"] = username
	elif keys.has("name"):
		body["name"] = username
	if keys.is_empty() or keys.has("password"):
		body["password"] = password
	var mail := email.strip_edges()
	if mail != "" and (keys.is_empty() or keys.has("email")):
		body["email"] = mail
	return body


static func change_password_body(current_password: String, new_password: String) -> Dictionary:
	return {"current_password": current_password, "new_password": new_password}


static func refresh_body(properties: PackedStringArray, refresh_token: String) -> Dictionary:
	if properties.is_empty() or properties.has("refresh_token"):
		return {"refresh_token": refresh_token}
	var body := {}
	for key in properties:
		if key in ["refresh_token", "refresh", "token"]:
			body[key] = refresh_token
	if body.is_empty():
		body["refresh_token"] = refresh_token
	return body


static func _all(caps: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not bool(caps.get(key, false)):
			return false
	return true
