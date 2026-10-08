extends RefCounted

func cases() -> Array:
	return [
		["iso_epoch", _iso_epoch],
		["iso_live_vector", _iso_live_vector],
		["iso_offset", _iso_offset],
		["iso_format_roundtrip", _iso_format_roundtrip],
		["clock_offset_and_countdown", _clock_offset_and_countdown],
		["movement_progress", _movement_progress],
		["movement_display_position", _movement_display_position],
		["api_error_game", _api_error_game],
		["api_error_validation", _api_error_validation],
		["header_value", _header_value],
		["capabilities_openapi", _capabilities_openapi],
		["capabilities_status", _capabilities_status],
		["idempotency_policy", _idempotency_policy],
		["auth_body_schema", _auth_body_schema],
		["auth_interpret", _auth_interpret],
		["auth_persist_policy", _auth_persist_policy],
		["auth_refresh_rotation", _auth_refresh_rotation],
		["command_bodies", _command_bodies],
		["redact_tokens", _redact_tokens],
		["uuid4_shape", _uuid4_shape],
		["token_store_refresh_only", _token_store_refresh_only],
		["settings_store_roundtrip", _settings_store_roundtrip],
		["exact_server_integers", _exact_server_integers],
		["maintenance_banner", _maintenance_banner],
		["whole_numbers_as_integers", _whole_numbers_as_integers],
		["battle_round_rows", _battle_round_rows],
		["start_parse_and_claim", _start_parse_and_claim],
		["start_unknown_on_old_server", _start_unknown_on_old_server],
		["claim_start_route", _claim_start_route],
		["label_layout_no_overlap", _label_layout_no_overlap],
		["army_marker_offset", _army_marker_offset],
		["thai_is_default", _thai_is_default],
	]


func _iso_epoch() -> String:
	var got := IsoTime.parse_unix_ms("1970-01-01T00:00:00Z")
	if got != 0:
		return "epoch parsed as %s" % got
	return ""


func _iso_live_vector() -> String:
	var got := IsoTime.parse_unix_ms("2026-10-07T12:35:14.788656Z")
	if got != 1791376514788:
		return "live vector parsed as %s" % got
	var from_payload := IsoTime.unix_ms_from_time_payload({
		"server_time": "2026-10-07T12:35:14.788656Z",
		"unix_ms": 1791376514788,
	})
	if from_payload != 1791376514788:
		return "payload unix_ms ignored"
	return ""


func _iso_offset() -> String:
	var got := IsoTime.parse_unix_ms("1970-01-01T05:30:00+05:30")
	if got != 0:
		return "offset parsed as %s" % got
	return ""


func _iso_format_roundtrip() -> String:
	var text := IsoTime.format_utc(1791376514788)
	if text != "2026-10-07 12:35:14 UTC":
		return "formatted as %s" % text
	return ""


func _clock_offset_and_countdown() -> String:
	var clock := ServerClock.new()
	var server_ms := 1791376514788
	var local_ms := server_ms - 2500
	clock.apply_sample({"unix_ms": server_ms, "server_time": "ignored"}, local_ms)
	if clock.offset_ms != 2500:
		return "offset %s" % clock.offset_ms
	if clock.now_unix_ms(local_ms + 1000) != server_ms + 1000:
		return "now drifted"
	var arrive := "2026-10-07T12:35:19.788656Z"
	var remain := clock.countdown_seconds(arrive, local_ms)
	if abs(remain - 5.0) > 0.001:
		return "countdown %s" % remain
	return ""


func _movement_progress() -> String:
	if abs(MovementInterp.progress(0, 10000, 2500) - 0.25) > 0.0001:
		return "quarter"
	if MovementInterp.progress(5, 5, 9) != 1.0:
		return "zero duration"
	if MovementInterp.progress(0, 1000, -50) != 0.0:
		return "before depart"
	if MovementInterp.progress(0, 1000, 5000) != 1.0:
		return "after arrive"
	var point := MovementInterp.position(Vector2(0, 0), Vector2(10, 40), 0.25)
	if abs(point.x - 2.5) > 0.0001 or abs(point.y - 10.0) > 0.0001:
		return "position %s" % point
	return ""


func _movement_display_position() -> String:
	var army := {
		"position": {"x": 1, "y": 1},
		"movement": {
			"depart_at": "1970-01-01T00:00:00Z",
			"arrive_at": "1970-01-01T00:00:10Z",
			"origin": {"x": 0, "y": 0},
			"destination": {"x": 100, "y": 0},
		},
	}
	var point := MovementInterp.army_position(army, 5000)
	if abs(point.x - 50.0) > 0.001 or abs(point.y) > 0.001:
		return "march point %s" % point
	var idle := {"position": {"x": 3, "y": 4}}
	var idle_point := MovementInterp.army_position(idle, 0)
	if idle_point != Vector2(3, 4):
		return "idle point %s" % idle_point
	var incomplete := {
		"movement": {
			"depart_at": "1970-01-01T00:00:00Z",
			"arrive_at": "1970-01-01T00:00:10Z",
			"origin": {},
			"destination": {"x": 1},
		},
		"position": {"x": 8, "y": 9},
	}
	if MovementInterp.army_position(incomplete, 5000) != Vector2(8, 9):
		return "incomplete march invented a point"
	var nowhere := {
		"movement": {
			"depart_at": "1970-01-01T00:00:00Z",
			"arrive_at": "1970-01-01T00:00:10Z",
			"origin": {},
			"destination": {"x": 1},
		},
	}
	if MovementInterp.known_position(nowhere, 5000):
		return "unknown position treated as known"
	if Present.field({}, "wood") != "UNKNOWN":
		return "missing field"
	if Present.field({"wood": 0}, "wood") != "0":
		return "zero hidden"
	if Present.text(null) != "UNKNOWN":
		return "null"
	if Present.text(5.0) != "5":
		return "whole float shown with a fraction"
	return ""


func _api_error_game() -> String:
	var text := ApiError.verbatim({"error": {"code": "not_found", "message": "no such player"}}, 404)
	if text != "no such player\ncode: not_found":
		return text
	return ""


func _api_error_validation() -> String:
	var payload := {
		"detail": [
			{"type": "missing", "loc": ["body", "army_id"], "msg": "Field required", "input": {}},
			{"type": "missing", "loc": ["body", "destination_city_id"], "msg": "Field required", "input": {}},
		]
	}
	var text := ApiError.verbatim(payload, 422)
	if not text.contains("Field required"):
		return text
	if not text.contains("location: body.army_id"):
		return text
	if not text.contains("location: body.destination_city_id"):
		return text
	return ""


func _header_value() -> String:
	var headers := PackedStringArray([
		"content-type: application/json",
		"Access-Control-Allow-Headers: Accept, Authorization, Content-Type",
	])
	var got := ApiError.header_value(headers, "access-control-allow-headers")
	if got != "Accept, Authorization, Content-Type":
		return got
	return ""


func _capabilities_openapi() -> String:
	var spec := {
		"paths": {
			"/v1/auth/register": {
				"post": {
					"requestBody": {
						"content": {
							"application/json": {
								"schema": {"properties": {"username": {}, "password": {}}}
							}
						}
					}
				}
			},
			"/v1/auth/login": {},
			"/v1/auth/refresh": {},
			"/v1/auth/logout": {},
			"/v1/auth/dev-login": {},
			"/v1/commands/move": {},
			"/v1/commands/attack": {},
			"/v1/commands/recall": {},
			"/v1/commands/build": {},
			"/v1/commands/research": {},
		}
	}
	var caps := Capabilities.from_openapi(spec)
	if not caps["player_auth"] or not caps["move"] or caps["train"] or caps["found_city"]:
		return "flags %s" % caps
	var props := Capabilities.schema_properties(spec, "/v1/auth/register")
	if not props.has("username") or not props.has("password"):
		return "props %s" % props
	return ""


func _capabilities_status() -> String:
	var caps := Capabilities.from_status_codes({
		"/v1/auth/register": 404,
		"/v1/auth/login": 404,
		"/v1/auth/refresh": 404,
		"/v1/auth/logout": 404,
		"/v1/commands/move": 401,
		"/v1/commands/train": 404,
		"/v1/commands/attack": 422,
	})
	if caps["player_auth"] or not caps["move"] or caps["train"] or not caps["attack"]:
		return "status flags %s" % caps
	return ""


func _idempotency_policy() -> String:
	var allow := "Accept, Accept-Language, Authorization, Content-Language, Content-Type, X-Admin-Token"
	if Capabilities.cors_allows_header(allow, "Idempotency-Key"):
		return "false allow treated as true"
	if not Capabilities.cors_allows_header("Authorization, Idempotency-Key", "idempotency-key"):
		return "present header missed"
	if Capabilities.should_send_idempotency(true, true, false):
		return "cors block ignored"
	if not Capabilities.should_send_idempotency(true, false, false):
		return "spec ignored when cors was not checked"
	if not Capabilities.spec_mentions_idempotency({"name": "Idempotency-Key"}):
		return "spec scan"
	return ""


func _auth_body_schema() -> String:
	var body := Capabilities.auth_body(PackedStringArray(["username", "password", "email"]), "Ada", "secret", "")
	if body.get("username") != "Ada" or body.get("password") != "secret" or body.has("email") or body.has("name"):
		return str(body.keys())
	var with_email := Capabilities.auth_body(PackedStringArray(["username", "password", "email"]), "Ada", "secret", "ada@example.com")
	if with_email.get("email") != "ada@example.com":
		return "email"
	var fallback := Capabilities.auth_body(PackedStringArray(), "Ada", "secret")
	if fallback.get("username") != "Ada" or fallback.get("password") != "secret":
		return "fallback"
	var refresh := Capabilities.refresh_body(PackedStringArray(), "r1")
	if refresh.get("refresh_token") != "r1":
		return "refresh body"
	var changed := Capabilities.change_password_body("old-secret", "new-secret")
	if changed.get("current_password") != "old-secret" or changed.get("new_password") != "new-secret":
		return "change password"
	return ""


func _auth_interpret() -> String:
	var missing := AuthLogic.interpret_auth_http(404, {"detail": "Not Found"})
	if not missing.get("phase7_missing", false) or missing.get("ok", true):
		return "404"
	var bad := AuthLogic.interpret_auth_http(401, {"error": {"code": "unauthorized", "message": "missing bearer token"}})
	if bad.get("ok", true) or str(bad.get("message", "")) != "missing bearer token\ncode: unauthorized":
		return str(bad.get("message", ""))
	var ok := AuthLogic.interpret_auth_http(200, {"token": "dev:1", "player_id": 1, "player_name": "Alice"})
	if not ok.get("ok", false):
		return "dev token rejected"
	return ""


func _auth_persist_policy() -> String:
	var dev := {"token": "dev:1", "refresh_token": "nope"}
	if AuthLogic.should_persist_refresh(true, "dev", dev):
		return "dev token would be stored"
	var player := {"access_token": "a", "refresh_token": "r"}
	if not AuthLogic.should_persist_refresh(true, "player", player):
		return "remember me ignored"
	if AuthLogic.should_persist_refresh(false, "player", player):
		return "unchecked remember me still stored"
	if AuthLogic.should_persist_refresh(true, "player", {"access_token": "a"}):
		return "missing refresh stored"
	return ""


func _auth_refresh_rotation() -> String:
	var session := AuthLogic.blank_session()
	session = AuthLogic.apply_token_payload(session, {
		"access_token": "a1",
		"refresh_token": "r1",
		"player_id": 3,
		"player_name": "Ada",
	}, "player")
	session = AuthLogic.apply_token_payload(session, {"access_token": "a2", "refresh_token": "r2"}, "player")
	if session["access_token"] != "a2" or session["refresh_token"] != "r2" or session["player_name"] != "Ada":
		return "rotation dropped state"
	session = AuthLogic.apply_token_payload(session, {"access_token": "a3"}, "player")
	if session["refresh_token"] != "r2" or session["access_token"] != "a3":
		return "refresh not kept"
	return ""


func _command_bodies() -> String:
	var move := CommandBodies.move_body(1, 2, true)
	if move != {"army_id": 1, "destination_city_id": 2, "relocate": true}:
		return "move"
	if CommandBodies.attack_body(1, 2) != {"army_id": 1, "target_city_id": 2}:
		return "attack"
	if CommandBodies.recall_body(4) != {"army_id": 4}:
		return "recall"
	if CommandBodies.build_body(3, "farm") != {"city_id": 3, "building": "farm"}:
		return "build"
	if CommandBodies.research_body("forestry") != {"tech": "forestry"}:
		return "research"
	var train := CommandBodies.train_body(1, "militia", 2, 0)
	if train.has("army_id") or train.get("count") != 2:
		return "train optional army"
	var found := CommandBodies.found_city_body(1, 4, 5, "Newhold")
	if found.get("name") != "Newhold" or found.get("x") != 4:
		return "found"
	if CommandBodies.garrison_body(1, 8) != {"army_id": 1, "city_id": 8}:
		return "garrison"
	var transfer := CommandBodies.transfer_body(1, 2, 3, 0, 0, 1)
	if transfer.get("wood") != 3 or transfer.get("gold") != 1 or transfer.get("destination_city_id") != 2:
		return "transfer"
	var first := CommandBodies.idempotency_key("", false)
	var reused := CommandBodies.idempotency_key(first, true)
	if reused != first:
		return "retry minted a new key"
	var fresh := CommandBodies.idempotency_key(first, false)
	if fresh == first or fresh == "":
		return "new action reused the key"
	return ""


func _redact_tokens() -> String:
	var pretty := JsonText.pretty(JsonText.redact({
		"access_token": "super-secret-token",
		"refresh_token": "other-secret",
		"player_name": "Ada",
		"nested": {"password": "hunter2", "ok": true},
	}))
	if pretty.contains("super-secret-token") or pretty.contains("other-secret") or pretty.contains("hunter2"):
		return "secret leaked"
	if not pretty.contains("[redacted]") or not pretty.contains("Ada"):
		return "redaction dropped public fields"
	return ""


func _uuid4_shape() -> String:
	var id := JsonText.uuid4()
	var parts := id.split("-")
	if parts.size() != 5:
		return "parts"
	if parts[0].length() != 8 or parts[1].length() != 4 or parts[2].length() != 4:
		return "lengths"
	if parts[2].substr(0, 1) != "4":
		return "version"
	return ""


func _token_store_refresh_only() -> String:
	var path := "user://test_player_refresh.cfg"
	var store := TokenStore.new()
	store.clear(path)
	store.save_refresh("refresh-sample", path)
	if store.load_refresh(path) != "refresh-sample":
		store.clear(path)
		return "roundtrip failed"
	var absolute := ProjectSettings.globalize_path(path)
	var text := FileAccess.get_file_as_string(absolute)
	if text.contains("password") or text.contains("access_token"):
		store.clear(path)
		return "unexpected fields in refresh file"
	store.clear(path)
	if store.load_refresh(path) != "":
		return "clear failed"
	return ""


func _settings_store_roundtrip() -> String:
	var path := "user://test_settings.cfg"
	var store := SettingsStore.new()
	store.server_url = "https://example.test///"
	store.locale = "en"
	store.dev_mode = true
	store.stay_signed_in = false
	store.save(path)
	var loaded := SettingsStore.new()
	loaded.load(path)
	if loaded.server_url != "https://example.test":
		return "url %s" % loaded.server_url
	if loaded.locale != "en" or not loaded.dev_mode or loaded.stay_signed_in:
		return "flags"
	var fresh := SettingsStore.new()
	if fresh.stay_signed_in:
		return "remember me defaults on"
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
	if text.contains("password") or text.contains("token"):
		return "settings file holds a secret"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ""


func _exact_server_integers() -> String:
	var parsed: Variant = JsonText.parse_preserving_integers(
		'{"seed":8752478362702228813,"id":5,"name":"seed 8752478362702228813","ratio":1.5}'
	)
	if not (parsed is Dictionary):
		return "parse failed"
	var row: Dictionary = parsed
	if str(row["seed"]) != "8752478362702228813":
		return "seed rounded to %s" % str(row["seed"])
	if Present.field(row, "seed") != "8752478362702228813":
		return "seed label"
	if int(row["id"]) != 5:
		return "small id"
	if str(row["name"]) != "seed 8752478362702228813":
		return "string mutated"
	if abs(float(row["ratio"]) - 1.5) > 0.001:
		return "float mutated"
	return ""


func _maintenance_banner() -> String:
	if not ApiError.is_maintenance(503, {"error": {"code": "maintenance", "message": "world is in maintenance; player commands are not accepted"}}):
		return "503 missed"
	if not ApiError.is_maintenance(409, {"error": {"code": "maintenance", "message": "worker is paused for snapshot restore"}}):
		return "409 maintenance missed"
	if ApiError.is_maintenance(404, {"error": {"code": "not_found", "message": "missing"}}):
		return "404 treated as maintenance"
	var text := ApiError.verbatim({"error": {"code": "maintenance", "message": "world is in maintenance; player commands are not accepted"}}, 503)
	if not text.contains("world is in maintenance") or not text.contains("code: maintenance"):
		return text
	return ""


func _whole_numbers_as_integers() -> String:
	var parsed: Variant = JsonText.parse_preserving_integers(
		'{"id":1,"attacker_player_id":1,"defender_player_id":2,"rounds":[{"round":1,"damage_to_defender":61}],"ratio":1.5,"seed":8752478362702228813}'
	)
	var row: Dictionary = parsed
	if Present.id_text(row["id"]) != "#1":
		return "id %s" % Present.id_text(row["id"])
	if Present.field(row, "attacker_player_id") != "1" or Present.field(row, "defender_player_id") != "2":
		return "player ids"
	var compact := Present.text(row["rounds"])
	if compact.contains(".0") or not compact.contains("round: 1") or not compact.contains("61"):
		return "compact %s" % compact
	var pretty := JsonText.pretty(row)
	if pretty.contains("1.0") or pretty.contains("61.0"):
		return "pretty %s" % pretty
	if not pretty.contains("8752478362702228813") or not pretty.contains("1.5"):
		return "pretty lost exact values"
	if Present.text(1.5) != "1.5":
		return "fraction dropped"
	if Present.id_of(3.0) != 3 or Present.id_of(null) != 0 or Present.id_of("7") != 7:
		return "id_of"
	if Present.id_text(null) != "UNKNOWN":
		return "missing id"
	return ""


func _battle_round_rows() -> String:
	var parsed: Variant = JsonText.parse_preserving_integers(
		'[{"round":1,"attacker_variance_bp":9500,"defender_variance_bp":10400,"damage_to_attacker":12,"damage_to_defender":61},{"round":2}]'
	)
	var rows := Present.round_rows(parsed)
	if rows.size() != 2:
		return "rows %s" % rows.size()
	if rows[0] != ["1", "12", "61", "9500 / 10400"]:
		return "row %s" % str(rows[0])
	if rows[1] != ["2", "UNKNOWN", "UNKNOWN", "UNKNOWN / UNKNOWN"]:
		return "missing keys %s" % str(rows[1])
	if not Present.round_rows(null).is_empty():
		return "null rounds"
	return ""


func _start_parse_and_claim() -> String:
	var parsed: Variant = JsonText.parse_preserving_integers(
		'{"start_granted":true,"home_city":{"id":3,"name":"ada Home","x":-500,"y":-500},"army_id":3}'
	)
	var info := StartLogic.parse(parsed)
	if StartLogic.needs_claim(info) or not StartLogic.granted(info):
		return "granted start would claim"
	if StartLogic.home_city_id(info) != 3 or StartLogic.army_id(info) != 3:
		return "ids"
	if StartLogic.home_point(info) != Vector2(-500, -500):
		return "point %s" % str(StartLogic.home_point(info))
	if StartLogic.home_text(info) != "ada Home (-500, -500)":
		return "home text %s" % StartLogic.home_text(info)
	var none := StartLogic.parse({"start_granted": false, "home_city": null, "army_id": null})
	if not StartLogic.needs_claim(none):
		return "no start did not ask to claim"
	if StartLogic.home_point(none) != null or StartLogic.home_city_id(none) != 0:
		return "invented home"
	if StartLogic.granted_text(none, "yes", "no") != "no":
		return "granted text"
	if StartLogic.claim_body() != null:
		return "claim body must not carry coordinates"
	var no_xy := StartLogic.parse({"start_granted": true, "home_city": {"id": 4, "name": "x"}})
	if StartLogic.home_point(no_xy) != null:
		return "missing coordinates invented"
	return ""


func _start_unknown_on_old_server() -> String:
	var info := StartLogic.parse({"player_id": 1, "player_name": "Ada"})
	if bool(info["known"]) or StartLogic.needs_claim(info):
		return "old server treated as no-start"
	if StartLogic.granted_text(info, "yes", "no") != "UNKNOWN":
		return "granted not UNKNOWN"
	if StartLogic.home_text(info) != "UNKNOWN":
		return "home not UNKNOWN"
	if StartLogic.home_point(StartLogic.parse(null)) != null:
		return "null payload"
	return ""


func _claim_start_route() -> String:
	var caps := Capabilities.from_openapi({"paths": {"/v1/auth/claim-start": {}}})
	if not caps.get("claim_start", false):
		return "claim route missed"
	if Capabilities.from_openapi({"paths": {}}).get("claim_start", true):
		return "missing claim route treated as present"
	return ""


func _label_layout_no_overlap() -> String:
	var items := [
		{"anchor": Vector2(100, 100), "radius": 14.0, "size": Vector2(80, 20)},
		{"anchor": Vector2(118, 86), "radius": 11.0, "size": Vector2(80, 20)},
		{"anchor": Vector2(104, 102), "radius": 11.0, "size": Vector2(60, 20)},
	]
	var rects := LabelLayout.place(items)
	if rects.size() != 3:
		return "count"
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				return "labels %s and %s overlap" % [i, j]
	return ""


func _army_marker_offset() -> String:
	var city := Vector2(50, 50)
	var moved := LabelLayout.offset_markers([city], [city, city], 20.0, Vector2(18, -14))
	if (moved[0] as Vector2).distance_to(city) < 20.0:
		return "army still on the city marker"
	if (moved[1] as Vector2).distance_to(moved[0]) < 20.0:
		return "two armies stacked"
	var far := LabelLayout.offset_markers([city], [Vector2(200, 200)], 20.0, Vector2(18, -14))
	if far[0] != Vector2(200, 200):
		return "free army moved"
	return ""


func _thai_is_default() -> String:
	if SettingsStore.new().locale != "th":
		return "settings default"
	var loc := Locale.new()
	if loc.lang != "th":
		return "locale default"
	for key in ["start_title", "home_city", "round_col", "dmg_to_attacker", "winner_draw", "language_switch"]:
		loc.set_lang("th")
		var th := loc.text(key)
		loc.set_lang("en")
		var en := loc.text(key)
		if th == key or en == key or th == "" or en == "":
			return "missing text %s" % key
	return ""
