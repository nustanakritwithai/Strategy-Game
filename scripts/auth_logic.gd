extends RefCounted
class_name AuthLogic

## Player-auth session rules.
## Access tokens stay in memory. Refresh tokens are stored only when the
## policy below says so. Dev-login tokens are never written to disk.
## Nothing in this script prints a token.


static func interpret_auth_http(status: int, payload: Variant) -> Dictionary:
	if status == 404:
		return {"ok": false, "phase7_missing": true}
	if status < 200 or status >= 300:
		return {
			"ok": false,
			"phase7_missing": false,
			"message": ApiError.verbatim(payload, status),
		}
	if not (payload is Dictionary):
		return {"ok": false, "phase7_missing": false, "message": ApiError.verbatim(payload, status)}
	var access := str(payload.get("access_token", payload.get("token", "")))
	if access == "":
		return {"ok": false, "phase7_missing": false, "message": ApiError.verbatim(payload, status)}
	return {"ok": true, "phase7_missing": false, "payload": payload}


static func should_persist_refresh(stay_signed_in: bool, mode: String, payload: Dictionary) -> bool:
	# Remember-me is the only reason a refresh token touches disk.
	# Access tokens are never persisted. Dev-login tokens are never persisted.
	if not stay_signed_in or mode != "player":
		return false
	return str(payload.get("refresh_token", "")) != ""


static func apply_token_payload(session: Dictionary, payload: Dictionary, mode: String) -> Dictionary:
	var next := session.duplicate(true)
	var access := str(payload.get("access_token", payload.get("token", "")))
	if access != "":
		next["access_token"] = access
	var refresh := str(payload.get("refresh_token", ""))
	if refresh != "":
		next["refresh_token"] = refresh
	next["mode"] = mode
	if payload.has("player_id"):
		next["player_id"] = int(payload["player_id"])
	if payload.has("player_name"):
		next["player_name"] = str(payload["player_name"])
	var player = payload.get("player")
	if player is Dictionary:
		if player.has("id"):
			next["player_id"] = int(player["id"])
		if player.has("name"):
			next["player_name"] = str(player["name"])
	if payload.has("username"):
		next["username"] = str(payload["username"])
	if payload.has("expires_in"):
		next["expires_in"] = int(payload["expires_in"])
	if payload.has("refresh_expires_in"):
		next["refresh_expires_in"] = int(payload["refresh_expires_in"])
	if payload.has("must_change_password"):
		next["must_change_password"] = bool(payload["must_change_password"])
	return next


static func blank_session() -> Dictionary:
	return {
		"access_token": "",
		"refresh_token": "",
		"mode": "",
		"player_id": 0,
		"player_name": "",
		"username": "",
		"expires_in": 0,
		"refresh_expires_in": 0,
		"must_change_password": false,
	}
