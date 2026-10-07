extends Control

## Player client. Renders server state and sends intent.
## Combat, resources, travel, and reports are never decided here.

const BUILDINGS := ["lumber_camp", "farm", "iron_mine", "warehouse", "barracks"]
const TECHS := ["forestry", "husbandry", "metallurgy", "logistics"]
const UNITS := ["militia", "infantry", "archer", "cavalry"]
const POLL_SECONDS := 8.0

var locale := Locale.new()
var settings := SettingsStore.new()
var token_store := TokenStore.new()
var clock := ServerClock.new()
var api := HttpApi.new()
var session := AuthLogic.blank_session()
var caps := Capabilities.empty()
var openapi := {}

var logged_in := false
var caps_ready := false
var health := "down"
var tab := "map"
var target_mode := ""
var selected_city_id := 0
var selected_army_id := 0
var command_inflight := false
var side_dirty := false
var fitted_once := false

var me := {}
var cities: Array = []
var map_cities: Array = []
var armies: Array = []
var reports: Array = []
var city_detail := {}
var report_detail: Variant = null
var open_report_id := 0

var train_unit := "militia"
var train_count := 1
var train_army_id := 0
var found_name := ""
var found_x := 0
var found_y := 0
var transfer_dest_id := 0
var transfer_amounts := {"wood": 0, "food": 0, "iron": 0, "gold": 0}
var pending_order := {}

var font: Font
var auth_layer: Control
var game_layer: Control
var auth_scroll: ScrollContainer
var auth_box: VBoxContainer
var game_top: HBoxContainer
var map_view: MapView
var side_scroll: ScrollContainer
var side: VBoxContainer
var tab_bar: HBoxContainer
var target_banner: Label
var status_banner: Label
var modal: ColorRect
var modal_title: Label
var modal_body: Label
var modal_ok: Button
var modal_cancel: Button
var url_edit: LineEdit
var name_edit: LineEdit
var pass_edit: LineEdit
var dev_name_edit: LineEdit
var stay_check: CheckBox
var dev_check: CheckBox
var dev_box: VBoxContainer
var phase_label: Label
var health_label: Label
var health_dot: ColorRect
var who_label: Label
var clock_label: Label
var poll_timer: Timer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	font = load("res://fonts/NotoSansThai-Regular.ttf")
	theme = _make_theme(font)
	settings.load()
	locale.set_lang(settings.locale)
	_build_ui()
	api.base_url = settings.server_url
	api.refresh_handler = _refresh_tokens
	add_child(api)
	poll_timer = Timer.new()
	poll_timer.wait_time = POLL_SECONDS
	poll_timer.timeout.connect(_on_poll)
	add_child(poll_timer)
	poll_timer.start()
	_apply_static_text()
	_layout()
	_show_auth()
	await _connect_server()


func _process(_delta: float) -> void:
	if clock.synced and clock_label != null:
		var now := clock.now_unix_ms(_local_ms())
		clock_label.text = _clock_text(now)
		if map_view != null:
			map_view.now_ms = now
			map_view.queue_redraw()
		_refresh_eta(now)
	if side_dirty and not _side_editing():
		_render_side()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _local_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _clock_text(now_ms: int) -> String:
	var full := IsoTime.format_utc(now_ms)
	if size.x < 720:
		return full.substr(11, 8)
	return full


func _connect_server() -> void:
	var typed := url_edit.text if url_edit != null else settings.server_url
	settings.server_url = SettingsStore.normalize_url(typed)
	if settings.server_url == "":
		settings.server_url = SettingsStore.DEFAULT_URL
	settings.save()
	api.base_url = settings.server_url
	url_edit.text = settings.server_url
	health = "down"
	caps_ready = false
	_set_health(locale.text("connecting"), Color("e09a32"))
	await _check_health()
	if health == "down":
		_apply_auth_state()
		return
	await _load_capabilities()
	caps_ready = true
	_apply_auth_state()
	await _try_saved_session()


func _check_health() -> void:
	var health_res := await api.request("GET", "/health")
	var time_res := await api.request("GET", "/v1/time")
	if time_res.get("ok", false) and time_res.get("json") is Dictionary:
		clock.apply_sample(time_res["json"], _local_ms())
		health = "ok"
		_set_health(locale.text("connected"), Color("3cbf6e"))
	elif health_res.get("ok", false):
		health = "degraded"
		_set_health(locale.text("connected"), Color("e09a32"))
	else:
		health = "down"
		clock.synced = false
		_set_health(locale.text("disconnected"), Color("e2584f"))


func _load_capabilities() -> void:
	openapi = {}
	var spec := await api.request("GET", "/openapi.json")
	if spec.get("ok", false) and spec.get("json") is Dictionary and (spec["json"] as Dictionary).has("paths"):
		openapi = spec["json"]
		caps = Capabilities.from_openapi(openapi)
	else:
		var codes := {}
		for key in Capabilities.ROUTES:
			var path: String = Capabilities.ROUTES[key]
			var probe := await api.request("POST", path, {})
			codes[path] = int(probe.get("status", 0))
		caps = Capabilities.from_status_codes(codes)
	# Browsers forbid setting Origin and Access-Control-Request-* from script.
	# On the web export, Idempotency-Key is sent only when OpenAPI names it.
	# The server must also list that header in CORS or the browser blocks the order.
	var allow := ""
	if not OS.has_feature("web"):
		var cors_headers := PackedStringArray([
			"Origin: https://nustanakritwithai.github.io",
			"Access-Control-Request-Method: POST",
			"Access-Control-Request-Headers: authorization,content-type,idempotency-key",
		])
		var cors := await api.request("OPTIONS", "/v1/commands/move", null, false, false, cors_headers)
		allow = ApiError.header_value(cors.get("headers", PackedStringArray()), "access-control-allow-headers")
	caps["idempotency"] = Capabilities.should_send_idempotency(
		bool(caps.get("idempotency_spec", false)),
		allow != "",
		Capabilities.cors_allows_header(allow, "Idempotency-Key")
	)


func _try_saved_session() -> void:
	if logged_in or not bool(caps.get("player_auth", false)):
		return
	var saved := token_store.load_refresh()
	if saved == "":
		return
	session = AuthLogic.blank_session()
	session["refresh_token"] = saved
	session["mode"] = "player"
	var ok: bool = await _refresh_tokens()
	if ok:
		await _enter_game()
	else:
		token_store.clear()
		session = AuthLogic.blank_session()
		phase_label.text = locale.text("session_expired")


func _refresh_tokens() -> bool:
	if str(session.get("refresh_token", "")) == "" or str(session.get("mode", "")) != "player":
		return false
	if not bool(caps.get("refresh", false)):
		return false
	var props := Capabilities.schema_properties(openapi, "/v1/auth/refresh")
	var body := Capabilities.refresh_body(props, str(session.get("refresh_token", "")))
	var res := await api.request("POST", "/v1/auth/refresh", body, false, false)
	var interpreted := AuthLogic.interpret_auth_http(int(res.get("status", 0)), res.get("json"))
	if not bool(interpreted.get("ok", false)):
		return false
	var payload: Dictionary = interpreted["payload"]
	session = AuthLogic.apply_token_payload(session, payload, "player")
	api.access_token = str(session.get("access_token", ""))
	if AuthLogic.should_persist_refresh(settings.stay_signed_in, "player", payload):
		token_store.save_refresh(str(session.get("refresh_token", "")))
	elif not settings.stay_signed_in:
		token_store.clear()
	return true


func _on_poll() -> void:
	if not logged_in:
		await _check_health()
		return
	await _check_health()
	if health == "down":
		return
	await _refresh_world()


func _enter_game() -> void:
	api.access_token = str(session.get("access_token", ""))
	logged_in = true
	auth_layer.visible = false
	game_layer.visible = true
	_sync_who()
	await _refresh_world()
	_layout()


func _show_auth() -> void:
	logged_in = false
	auth_layer.visible = true
	game_layer.visible = false
	api.access_token = ""


func _refresh_world() -> void:
	var me_res := await _authed_get("/v1/me")
	if not logged_in:
		return
	if me_res.get("ok", false) and me_res.get("json") is Dictionary:
		me = me_res["json"]
		if me.has("name"):
			session["player_name"] = str(me.get("name", session.get("player_name", "")))
		if me.has("id"):
			session["player_id"] = int(me.get("id", session.get("player_id", 0)))
	if not logged_in:
		return
	var city_res := await _authed_get("/v1/me/cities")
	if not logged_in:
		return
	if city_res.get("ok", false) and city_res.get("json") is Dictionary:
		cities = city_res["json"].get("cities", [])
	var map_res := await _authed_get("/v1/map/cities")
	if not logged_in:
		return
	if map_res.get("ok", false) and map_res.get("json") is Dictionary:
		map_cities = map_res["json"].get("cities", [])
	var army_res := await _authed_get("/v1/me/armies")
	if not logged_in:
		return
	if army_res.get("ok", false) and army_res.get("json") is Dictionary:
		armies = army_res["json"].get("armies", [])
		if army_res["json"].has("server_time"):
			clock.apply_sample({"server_time": army_res["json"]["server_time"]}, _local_ms())
	var report_res := await _authed_get("/v1/me/reports")
	if not logged_in:
		return
	if report_res.get("ok", false) and report_res.get("json") is Dictionary:
		reports = report_res["json"].get("reports", [])
	if selected_city_id != 0:
		var detail := await _authed_get("/v1/me/cities/%s" % selected_city_id)
		if detail.get("ok", false) and detail.get("json") is Dictionary:
			city_detail = detail["json"]
	_ensure_selection()
	_sync_who()
	_sync_map()
	_render_side()


func _authed_get(path: String) -> Dictionary:
	api.access_token = str(session.get("access_token", ""))
	var res := await api.request("GET", path, null, true, true)
	if int(res.get("status", 0)) == 401:
		await _force_logout(true)
	return res


func _ensure_selection() -> void:
	if _find(cities, selected_city_id).is_empty() and not cities.is_empty():
		selected_city_id = int((cities[0] as Dictionary).get("id", 0))
	if _find(armies, selected_army_id).is_empty() and not armies.is_empty():
		selected_army_id = int((armies[0] as Dictionary).get("id", 0))


func _sync_who() -> void:
	var name := str(session.get("player_name", ""))
	if str(session.get("mode", "")) == "dev":
		who_label.text = "%s %s" % [locale.text("dev_banner"), name]
	else:
		who_label.text = name


func _sync_map() -> void:
	map_view.cities = map_cities
	map_view.armies = armies
	map_view.my_player_id = int(session.get("player_id", 0))
	map_view.selected_city_id = selected_city_id
	map_view.selected_army_id = selected_army_id
	map_view.target_mode = target_mode
	map_view.now_ms = clock.now_unix_ms(_local_ms()) if clock.synced else 0
	map_view.legend_own = locale.text("own_city")
	map_view.legend_other = locale.text("other_city")
	map_view.legend_army = locale.text("army_marker")
	if not fitted_once and not map_cities.is_empty() and map_view.size.x > 20:
		map_view.fit(map_cities)
		fitted_once = map_view.fitted
	map_view.queue_redraw()
	_sync_target_banner()


func _submit_player(kind: String) -> void:
	var player_name := name_edit.text.strip_edges()
	var password := pass_edit.text
	if player_name == "" or password == "":
		_alert(locale.text("alert_title"), locale.text("name_required"))
		return
	if caps_ready and not bool(caps.get("player_auth", false)):
		_alert(locale.text("alert_title"), locale.text("auth_phase7_missing"))
		return
	var path := "/v1/auth/register" if kind == "register" else "/v1/auth/login"
	var props := Capabilities.schema_properties(openapi, path)
	var body := Capabilities.auth_body(props, player_name, password)
	var res := await api.request("POST", path, body, false, false)
	pass_edit.text = ""
	await _finish_auth(res, "player")


func _submit_dev() -> void:
	if not settings.dev_mode:
		return
	var player_name := dev_name_edit.text.strip_edges()
	if player_name == "":
		_alert(locale.text("alert_title"), locale.text("dev_name_required"))
		return
	var res := await api.request("POST", "/v1/auth/dev-login", {"name": player_name}, false, false)
	await _finish_auth(res, "dev")


func _finish_auth(res: Dictionary, mode: String) -> void:
	var status := int(res.get("status", 0))
	if status == 0:
		_alert(locale.text("alert_title"), locale.text("error_network"))
		return
	if mode == "dev" and status == 404:
		_alert(locale.text("server_rejected"), ApiError.verbatim(res.get("json"), status))
		return
	var interpreted := AuthLogic.interpret_auth_http(status, res.get("json"))
	if bool(interpreted.get("phase7_missing", false)):
		caps["player_auth"] = false
		caps_ready = true
		_apply_auth_state()
		_alert(locale.text("alert_title"), locale.text("auth_phase7_missing"))
		return
	if not bool(interpreted.get("ok", false)):
		_alert(locale.text("server_rejected"), str(interpreted.get("message", "")))
		return
	var payload: Dictionary = interpreted["payload"]
	var previous_refresh := str(session.get("refresh_token", ""))
	session = AuthLogic.apply_token_payload(AuthLogic.blank_session(), payload, mode)
	if str(session.get("refresh_token", "")) == "" and mode == "player":
		session["refresh_token"] = previous_refresh
	api.access_token = str(session.get("access_token", ""))
	if AuthLogic.should_persist_refresh(settings.stay_signed_in, mode, payload):
		token_store.save_refresh(str(session.get("refresh_token", "")))
	else:
		token_store.clear()
	await _enter_game()


func _force_logout(expired: bool) -> void:
	session = AuthLogic.blank_session()
	api.access_token = ""
	token_store.clear()
	logged_in = false
	_show_auth()
	if expired:
		phase_label.text = locale.text("session_expired")


func _logout() -> void:
	if str(session.get("mode", "")) == "player" and bool(caps.get("logout", false)):
		api.access_token = str(session.get("access_token", ""))
		var refresh := str(session.get("refresh_token", ""))
		var body: Variant = null
		if refresh != "":
			var props := Capabilities.schema_properties(openapi, "/v1/auth/logout")
			body = Capabilities.refresh_body(props, refresh)
		await api.request("POST", "/v1/auth/logout", body, true, false)
	await _force_logout(false)


func _dispatch(order: Dictionary) -> void:
	if command_inflight or order.is_empty():
		return
	command_inflight = true
	status_banner.text = locale.text("working")
	var headers := PackedStringArray()
	if bool(caps.get("idempotency", false)):
		headers.append("Idempotency-Key: %s" % JsonText.uuid4())
	api.access_token = str(session.get("access_token", ""))
	var res := await api.request("POST", str(order["path"]), order["body"], true, true, headers)
	command_inflight = false
	status_banner.text = ""
	var status := int(res.get("status", 0))
	if status == 404:
		_note_missing_path(str(order["path"]))
		_alert(locale.text("server_rejected"), ApiError.verbatim(res.get("json"), status))
		_render_side()
		return
	if status == 401:
		await _force_logout(true)
		return
	if not bool(res.get("ok", false)):
		var message := locale.text("error_network") if status == 0 else ApiError.verbatim(
			JsonText.redact(res.get("json")) if res.get("json") != null else res.get("text"),
			status
		)
		_alert(locale.text("server_rejected"), message)
		return
	target_mode = ""
	_sync_target_banner()
	_alert(locale.text("server_accepted"), JsonText.pretty(JsonText.redact(res.get("json"))))
	await _refresh_world()


func _note_missing_path(path: String) -> void:
	for key in Capabilities.ROUTES:
		if Capabilities.ROUTES[key] == path:
			caps = Capabilities.mark_missing(caps, key)


func _open_confirm(summary: String, order: Dictionary) -> void:
	pending_order = order
	modal_title.text = locale.text("confirm_title")
	modal_body.text = summary
	modal_ok.text = locale.text("confirm")
	modal_ok.set_meta("i18n", "confirm")
	modal_cancel.visible = true
	modal.visible = true


func _alert(title: String, body: String) -> void:
	pending_order = {}
	modal_title.text = title
	modal_body.text = body
	modal_ok.text = locale.text("dismiss")
	modal_ok.set_meta("i18n", "dismiss")
	modal_cancel.visible = false
	modal.visible = true


func _on_modal_ok() -> void:
	var order: Dictionary = pending_order
	pending_order = {}
	modal.visible = false
	modal_cancel.visible = true
	if not order.is_empty():
		await _dispatch(order)


func _on_modal_cancel() -> void:
	pending_order = {}
	modal.visible = false
	modal_cancel.visible = true


func _order_summary(path: String, body: Dictionary) -> String:
	return "%s\nPOST %s\n%s\n\n%s" % [
		locale.text("confirm_title"),
		path,
		JsonText.pretty(body),
		locale.text("command_blurb"),
	]


func _require_army() -> bool:
	if selected_army_id == 0:
		_alert(locale.text("alert_title"), locale.text("select_army"))
		return false
	return true


func _require_city() -> bool:
	if _active_city().is_empty():
		_alert(locale.text("alert_title"), locale.text("select_city"))
		return false
	return true


func _begin_target(mode: String) -> void:
	if mode in ["attack", "reinforce", "move", "garrison"] and not _require_army():
		return
	if mode == "transfer" and not _require_city():
		return
	if mode == "found" and not _require_city():
		return
	target_mode = mode
	tab = "map"
	_sync_map()
	_layout()
	_render_side()


func _on_city_picked(city_id: int) -> void:
	if target_mode == "":
		selected_city_id = city_id
		tab = "city"
		_layout()
		_refresh_selected_city()
		return
	if target_mode == "attack":
		_queue(CommandBodies.attack_body(selected_army_id, city_id), "/v1/commands/attack")
	elif target_mode == "reinforce":
		_queue(CommandBodies.move_body(selected_army_id, city_id, false), "/v1/commands/move")
	elif target_mode == "move":
		_queue(CommandBodies.move_body(selected_army_id, city_id, true), "/v1/commands/move")
	elif target_mode == "garrison":
		_queue(CommandBodies.garrison_body(selected_army_id, city_id), "/v1/commands/garrison")
	elif target_mode == "transfer":
		transfer_dest_id = city_id
		target_mode = ""
		tab = "city"
		_sync_target_banner()
		_layout()
		_render_side()
	elif target_mode == "found":
		var city := _find(map_cities, city_id)
		if not city.is_empty():
			found_x = int(city.get("x", 0))
			found_y = int(city.get("y", 0))
		target_mode = ""
		tab = "city"
		_sync_target_banner()
		_layout()
		_render_side()


func _on_army_picked(army_id: int) -> void:
	selected_army_id = army_id
	if target_mode == "":
		tab = "army"
		_layout()
		_render_side()


func _on_point_picked(world: Vector2) -> void:
	if target_mode != "found":
		return
	found_x = int(round(world.x))
	found_y = int(round(world.y))
	target_mode = ""
	tab = "city"
	_sync_target_banner()
	_layout()
	_render_side()


func _queue(body: Dictionary, path: String) -> void:
	target_mode = ""
	_sync_target_banner()
	_open_confirm(_order_summary(path, body), {"path": path, "body": body})


func _refresh_selected_city() -> void:
	if not logged_in or selected_city_id == 0:
		_render_side()
		return
	var detail := await _authed_get("/v1/me/cities/%s" % selected_city_id)
	if detail.get("ok", false) and detail.get("json") is Dictionary:
		city_detail = detail["json"]
	_sync_map()
	_render_side()


func _active_city() -> Dictionary:
	if not city_detail.is_empty() and int(city_detail.get("id", 0)) == selected_city_id:
		return city_detail
	return _find(cities, selected_city_id)


func _find(rows: Array, id: int) -> Dictionary:
	for row in rows:
		if row is Dictionary and int(row.get("id", 0)) == id:
			return row
	return {}


func _send_build(building: String) -> void:
	if not _require_city():
		return
	var body := CommandBodies.build_body(selected_city_id, building)
	_queue(body, "/v1/commands/build")


func _send_research(tech: String) -> void:
	var body := CommandBodies.research_body(tech)
	_queue(body, "/v1/commands/research")


func _send_recall() -> void:
	if not _require_army():
		return
	_queue(CommandBodies.recall_body(selected_army_id), "/v1/commands/recall")


func _send_train() -> void:
	if not _require_city():
		return
	var body := CommandBodies.train_body(selected_city_id, train_unit, train_count, train_army_id)
	_queue(body, "/v1/commands/train")


func _send_found() -> void:
	if not _require_city():
		return
	var body := CommandBodies.found_city_body(selected_city_id, found_x, found_y, found_name.strip_edges())
	_queue(body, "/v1/commands/found-city")


func _on_transfer_amount(value: float, resource: String) -> void:
	transfer_amounts[resource] = int(value)


func _send_transfer() -> void:
	if not _require_city() or transfer_dest_id == 0:
		if transfer_dest_id == 0:
			_alert(locale.text("alert_title"), locale.text("tap_city"))
		return
	var body := CommandBodies.transfer_body(
		selected_city_id,
		transfer_dest_id,
		int(transfer_amounts["wood"]),
		int(transfer_amounts["food"]),
		int(transfer_amounts["iron"]),
		int(transfer_amounts["gold"])
	)
	_queue(body, "/v1/commands/transfer")


func _open_report(report_id: int) -> void:
	open_report_id = report_id
	tab = "reports"
	var res := await _authed_get("/v1/me/reports/%s" % report_id)
	if res.get("ok", false):
		report_detail = res.get("json")
	else:
		report_detail = null
		var status := int(res.get("status", 0))
		if status != 401:
			_alert(
				locale.text("server_rejected"),
				locale.text("error_network") if status == 0 else ApiError.verbatim(res.get("json"), status)
			)
	_render_side()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("12171f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	auth_layer = Control.new()
	auth_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	auth_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(auth_layer)
	auth_scroll = ScrollContainer.new()
	auth_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	auth_layer.add_child(auth_scroll)
	var auth_panel := PanelContainer.new()
	auth_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auth_scroll.add_child(auth_panel)
	auth_box = VBoxContainer.new()
	auth_box.add_theme_constant_override("separation", 8)
	auth_panel.add_child(auth_box)
	_build_auth_form()

	game_layer = Control.new()
	game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_layer)
	game_top = HBoxContainer.new()
	game_top.add_theme_constant_override("separation", 8)
	game_layer.add_child(game_top)
	who_label = Label.new()
	who_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_label.clip_text = true
	game_top.add_child(who_label)
	clock_label = Label.new()
	game_top.add_child(clock_label)
	health_dot = ColorRect.new()
	health_dot.custom_minimum_size = Vector2(14, 14)
	game_top.add_child(health_dot)
	var lang_btn := Button.new()
	lang_btn.set_meta("i18n", "language")
	lang_btn.custom_minimum_size = Vector2(64, 44)
	lang_btn.pressed.connect(_toggle_lang)
	game_top.add_child(lang_btn)
	var settings_btn := Button.new()
	settings_btn.set_meta("i18n", "settings")
	settings_btn.custom_minimum_size = Vector2(44, 44)
	settings_btn.pressed.connect(_set_tab.bind("settings"))
	game_top.add_child(settings_btn)
	var logout_btn := Button.new()
	logout_btn.set_meta("i18n", "logout")
	logout_btn.custom_minimum_size = Vector2(44, 44)
	logout_btn.pressed.connect(_logout)
	game_top.add_child(logout_btn)

	map_view = MapView.new()
	map_view.font = font
	map_view.city_picked.connect(_on_city_picked)
	map_view.army_picked.connect(_on_army_picked)
	map_view.point_picked.connect(_on_point_picked)
	game_layer.add_child(map_view)
	target_banner = Label.new()
	target_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_banner.visible = false
	game_layer.add_child(target_banner)
	side_scroll = ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game_layer.add_child(side_scroll)
	var side_panel := PanelContainer.new()
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_panel)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side_panel.add_child(side)
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	game_layer.add_child(tab_bar)
	for key in ["map", "city", "army", "reports"]:
		var button := Button.new()
		button.set_meta("i18n", key)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(_set_tab.bind(key))
		tab_bar.add_child(button)

	status_banner = Label.new()
	status_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_layer.add_child(status_banner)

	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, 0.62)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.offset_left = -280
	dialog.offset_right = 280
	dialog.offset_top = -230
	dialog.offset_bottom = 230
	modal.add_child(dialog)
	var dialog_box := VBoxContainer.new()
	dialog_box.add_theme_constant_override("separation", 8)
	dialog.add_child(dialog_box)
	modal_title = Label.new()
	modal_title.add_theme_font_size_override("font_size", 22)
	dialog_box.add_child(modal_title)
	var body_scroll := ScrollContainer.new()
	body_scroll.custom_minimum_size = Vector2(0, 220)
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog_box.add_child(body_scroll)
	modal_body = Label.new()
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.custom_minimum_size = Vector2(480, 0)
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(modal_body)
	var dialog_buttons := HBoxContainer.new()
	dialog_buttons.alignment = BoxContainer.ALIGNMENT_END
	dialog_box.add_child(dialog_buttons)
	modal_cancel = Button.new()
	modal_cancel.set_meta("i18n", "cancel")
	modal_cancel.custom_minimum_size = Vector2(120, 48)
	modal_cancel.pressed.connect(_on_modal_cancel)
	dialog_buttons.add_child(modal_cancel)
	modal_ok = Button.new()
	modal_ok.set_meta("i18n", "confirm")
	modal_ok.custom_minimum_size = Vector2(160, 48)
	modal_ok.pressed.connect(_on_modal_ok)
	dialog_buttons.add_child(modal_ok)


func _build_auth_form() -> void:
	var title := Label.new()
	title.set_meta("i18n", "title")
	title.add_theme_font_size_override("font_size", 32)
	auth_box.add_child(title)
	var subtitle := Label.new()
	subtitle.set_meta("i18n", "subtitle")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auth_box.add_child(subtitle)
	var lang_row := HBoxContainer.new()
	auth_box.add_child(lang_row)
	var th := Button.new()
	th.text = "ไทย"
	th.custom_minimum_size = Vector2(88, 44)
	th.pressed.connect(_set_lang.bind("th"))
	lang_row.add_child(th)
	var en := Button.new()
	en.text = "English"
	en.custom_minimum_size = Vector2(110, 44)
	en.pressed.connect(_set_lang.bind("en"))
	lang_row.add_child(en)
	_add_caption(auth_box, "server_url")
	url_edit = LineEdit.new()
	url_edit.text = settings.server_url
	url_edit.custom_minimum_size = Vector2(0, 44)
	auth_box.add_child(url_edit)
	var use_btn := Button.new()
	use_btn.set_meta("i18n", "use_server")
	use_btn.custom_minimum_size = Vector2(0, 48)
	use_btn.pressed.connect(_connect_server)
	auth_box.add_child(use_btn)
	var health_row := HBoxContainer.new()
	auth_box.add_child(health_row)
	var auth_dot := ColorRect.new()
	auth_dot.custom_minimum_size = Vector2(14, 14)
	auth_dot.color = Color("e2584f")
	auth_dot.set_meta("health_dot", true)
	health_row.add_child(auth_dot)
	health_label = Label.new()
	health_label.set_meta("i18n", "connecting")
	health_row.add_child(health_label)
	phase_label = Label.new()
	phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auth_box.add_child(phase_label)
	_add_caption(auth_box, "player_name")
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(0, 44)
	auth_box.add_child(name_edit)
	_add_caption(auth_box, "password")
	pass_edit = LineEdit.new()
	pass_edit.secret = true
	pass_edit.custom_minimum_size = Vector2(0, 44)
	auth_box.add_child(pass_edit)
	stay_check = CheckBox.new()
	stay_check.set_meta("i18n", "stay_signed_in")
	stay_check.button_pressed = settings.stay_signed_in
	stay_check.toggled.connect(_on_stay_toggled)
	auth_box.add_child(stay_check)
	var stay_hint := Label.new()
	stay_hint.set_meta("i18n", "stay_hint")
	stay_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auth_box.add_child(stay_hint)
	var auth_buttons := HBoxContainer.new()
	auth_box.add_child(auth_buttons)
	var register_btn := Button.new()
	register_btn.set_meta("i18n", "register")
	register_btn.custom_minimum_size = Vector2(0, 48)
	register_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register_btn.pressed.connect(_submit_player.bind("register"))
	auth_buttons.add_child(register_btn)
	var login_btn := Button.new()
	login_btn.set_meta("i18n", "login")
	login_btn.custom_minimum_size = Vector2(0, 48)
	login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_btn.pressed.connect(_submit_player.bind("login"))
	auth_buttons.add_child(login_btn)
	dev_check = CheckBox.new()
	dev_check.set_meta("i18n", "dev_mode")
	dev_check.button_pressed = settings.dev_mode
	dev_check.toggled.connect(_on_dev_toggled)
	auth_box.add_child(dev_check)
	dev_box = VBoxContainer.new()
	dev_box.add_theme_constant_override("separation", 8)
	dev_box.visible = settings.dev_mode
	auth_box.add_child(dev_box)
	var dev_help := Label.new()
	dev_help.set_meta("i18n", "dev_mode_help")
	dev_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev_box.add_child(dev_help)
	dev_name_edit = LineEdit.new()
	dev_name_edit.text = "Alice"
	dev_name_edit.custom_minimum_size = Vector2(0, 44)
	dev_name_edit.placeholder_text = "Alice"
	dev_box.add_child(dev_name_edit)
	var dev_btn := Button.new()
	dev_btn.set_meta("i18n", "dev_login")
	dev_btn.custom_minimum_size = Vector2(0, 48)
	dev_btn.pressed.connect(_submit_dev)
	dev_box.add_child(dev_btn)


func _render_side() -> void:
	if side == null:
		return
	if _side_editing():
		side_dirty = true
		return
	side_dirty = false
	var old := side.get_children()
	for child in old:
		side.remove_child(child)
		child.free()
	match tab:
		"city":
			_render_city()
		"army":
			_render_army()
		"reports":
			_render_reports()
		"settings":
			_render_settings()
		_:
			_render_navigator()
	_apply_static_text()


func _render_navigator() -> void:
	_add_section(side, "your_cities")
	if cities.is_empty():
		_add_plain(side, locale.text("no_city"))
	for city in cities:
		if city is Dictionary:
			_add_picker(side, "%s (%s, %s)" % [city.get("name", ""), city.get("x", ""), city.get("y", "")], _pick_city.bind(int(city.get("id", 0))))
	_add_section(side, "your_armies")
	if armies.is_empty():
		_add_plain(side, locale.text("no_army"))
	for army in armies:
		if army is Dictionary:
			_add_army_row(army)
	_add_plain(side, locale.text("map_hint"))
	_add_idempotency_note(side)


func _render_city() -> void:
	var city := _active_city()
	_add_section(side, "city")
	if city.is_empty():
		_add_plain(side, locale.text("no_city"))
		return
	_add_plain(side, "%s  (%s, %s)  %s" % [
		city.get("name", ""),
		city.get("x", ""),
		city.get("y", ""),
		city.get("player_name", ""),
	])
	_add_plain(side, locale.text("city_hint"))
	_add_section(side, "resources")
	for key in ["wood", "food", "iron", "gold"]:
		_add_plain(side, "%s  %s    %s %s" % [
			locale.text(key),
			city.get(key, ""),
			city.get("%s_rate" % key, ""),
			locale.text("per_hour"),
		])
	if city.has("last_updated"):
		_add_plain(side, "%s  %s" % [locale.text("last_updated"), city.get("last_updated", "")])
	_add_section(side, "buildings")
	var buildings: Dictionary = city.get("buildings", {}) if city.get("buildings") is Dictionary else {}
	var shown := {}
	for building in BUILDINGS:
		shown[building] = true
		var level = buildings.get(building, "—")
		var row := HBoxContainer.new()
		side.add_child(row)
		var label := Label.new()
		label.text = "%s  %s %s" % [building, locale.text("level"), level]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_add_small_button(row, "build", _send_build.bind(building))
	for building in buildings:
		if shown.has(building):
			continue
		_add_plain(side, "%s  %s %s" % [building, locale.text("level"), buildings[building]])
	_add_section(side, "research")
	var research: Dictionary = me.get("research", {}) if me.get("research") is Dictionary else {}
	for tech in TECHS:
		var row := HBoxContainer.new()
		side.add_child(row)
		var label := Label.new()
		label.text = "%s  %s %s" % [tech, locale.text("level"), research.get(tech, "—")]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_add_small_button(row, "research_action", _send_research.bind(tech))
	_add_section(side, "garrison")
	var garrison = city.get("garrison_army_ids", [])
	_add_plain(side, "%s  %s" % [locale.text("garrison_ids"), garrison])
	_add_section(side, "train")
	_add_disabled_or_form(side, "train", "/v1/commands/train", _train_form)
	_add_section(side, "found_city")
	_add_plain(side, locale.text("found_help"))
	_add_disabled_or_form(side, "found_city", "/v1/commands/found-city", _found_form)
	_add_section(side, "transfer")
	_add_plain(side, locale.text("transfer_help"))
	_add_disabled_or_form(side, "transfer", "/v1/commands/transfer", _transfer_form)


func _train_form(parent: Node) -> void:
	var units := OptionButton.new()
	units.custom_minimum_size = Vector2(0, 44)
	for unit in UNITS:
		units.add_item(unit)
		if unit == train_unit:
			units.select(units.item_count - 1)
	units.item_selected.connect(func(index: int) -> void: train_unit = units.get_item_text(index))
	parent.add_child(units)
	var count := _spin(1, 100, train_count)
	count.value_changed.connect(func(value: float) -> void: train_count = int(value))
	parent.add_child(count)
	_add_plain(parent, locale.text("optional_army"))
	var army := _spin(0, 1000000, train_army_id)
	army.value_changed.connect(func(value: float) -> void: train_army_id = int(value))
	parent.add_child(army)
	_add_action_button(parent, "train", _send_train)


func _found_form(parent: Node) -> void:
	var name_field := LineEdit.new()
	name_field.text = found_name
	name_field.placeholder_text = locale.text("city_name")
	name_field.custom_minimum_size = Vector2(0, 44)
	name_field.text_changed.connect(func(value: String) -> void: found_name = value)
	parent.add_child(name_field)
	var x_spin := _spin(-500, 500, found_x)
	x_spin.value_changed.connect(func(value: float) -> void: found_x = int(value))
	parent.add_child(x_spin)
	var y_spin := _spin(-500, 500, found_y)
	y_spin.value_changed.connect(func(value: float) -> void: found_y = int(value))
	parent.add_child(y_spin)
	_add_action_button(parent, "tap_empty_for_found", _begin_target.bind("found"))
	_add_action_button(parent, "found_city", _send_found)


func _transfer_form(parent: Node) -> void:
	for key in ["wood", "food", "iron", "gold"]:
		_add_plain(parent, locale.text(key))
		var spin := _spin(0, 1000000000, int(transfer_amounts[key]))
		spin.value_changed.connect(_on_transfer_amount.bind(key))
		parent.add_child(spin)
	var dest := _find(map_cities, transfer_dest_id)
	var dest_name := str(dest.get("name", transfer_dest_id)) if transfer_dest_id != 0 else locale.text("none")
	_add_plain(parent, "%s  %s" % [locale.text("dest_city"), dest_name])
	_add_action_button(parent, "tap_city", _begin_target.bind("transfer"))
	_add_action_button(parent, "transfer", _send_transfer)


func _render_army() -> void:
	_add_section(side, "army")
	if armies.is_empty():
		_add_plain(side, locale.text("no_army"))
		return
	for army in armies:
		if army is Dictionary:
			_add_army_row(army)
	var army := _find(armies, selected_army_id)
	if army.is_empty():
		return
	_add_plain(side, "%s  %s" % [locale.text("status"), army.get("status", "")])
	_add_plain(side, "%s  %s    %s  %s" % [
		locale.text("home"),
		army.get("home_city_id", ""),
		locale.text("location"),
		army.get("location_city_id", ""),
	])
	_add_plain(side, "%s  %s" % [locale.text("units"), army.get("units", "")])
	var movement = army.get("movement")
	if movement is Dictionary:
		_add_plain(side, "%s  %s" % [locale.text("mission"), movement.get("mission", "")])
		var eta := Label.new()
		eta.set_meta("arrive", str(movement.get("arrive_at", "")))
		eta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(eta)
		_add_plain(side, "depart_at  %s" % movement.get("depart_at", ""))
		_add_plain(side, "arrive_at  %s" % movement.get("arrive_at", ""))
	_add_plain(side, locale.text("reinforce_help"))
	_add_action_button(side, "reinforce", _begin_target.bind("reinforce"))
	_add_plain(side, locale.text("move_help"))
	_add_action_button(side, "move", _begin_target.bind("move"))
	_add_action_button(side, "attack", _begin_target.bind("attack"))
	_add_action_button(side, "recall", _send_recall)
	_add_plain(side, locale.text("garrison_help"))
	if bool(caps.get("garrison", false)):
		_add_action_button(side, "garrison", _begin_target.bind("garrison"))
	else:
		_add_waiting(side, "/v1/commands/garrison")
	_add_idempotency_note(side)


func _render_reports() -> void:
	_add_section(side, "reports")
	_add_plain(side, locale.text("reports_hint"))
	if open_report_id != 0 and report_detail is Dictionary:
		_add_action_button(side, "back", func() -> void:
			open_report_id = 0
			report_detail = null
			_render_side()
		)
		var detail: Dictionary = report_detail
		_add_plain(side, "#%s" % detail.get("id", ""))
		_add_plain(side, "%s  %s" % [locale.text("winner"), detail.get("winner", "")])
		_add_plain(side, "%s  %s    %s  %s" % [
			locale.text("attacker"),
			detail.get("attacker_player_id", ""),
			locale.text("defender"),
			detail.get("defender_player_id", ""),
		])
		_add_plain(side, "%s  %s" % [locale.text("seed"), detail.get("seed", "")])
		_add_plain(side, "%s  %s" % [locale.text("rounds"), detail.get("rounds", "")])
		_add_plain(side, "%s  %s" % [locale.text("created_at"), detail.get("created_at", "")])
		_add_section(side, "casualties")
		_add_plain(side, "attacker  %s" % JsonText.pretty(detail.get("attacker_casualties")))
		_add_plain(side, "defender  %s" % JsonText.pretty(detail.get("defender_casualties")))
		_add_section(side, "loot")
		_add_plain(side, JsonText.pretty(detail.get("loot")))
		_add_section(side, "server_record")
		_add_plain(side, JsonText.pretty(detail))
		return
	if reports.is_empty():
		_add_plain(side, locale.text("no_reports"))
		return
	for report in reports:
		if report is Dictionary:
			var label := "#%s  %s %s" % [report.get("id", ""), locale.text("winner"), report.get("winner", "")]
			_add_picker(side, label, _open_report.bind(int(report.get("id", 0))))


func _apply_settings_url(editor: LineEdit) -> void:
	url_edit.text = editor.text
	await _connect_server()
	if logged_in:
		await _refresh_world()


func _render_settings() -> void:
	_add_section(side, "settings")
	_add_caption(side, "server_url")
	var editor := LineEdit.new()
	editor.text = settings.server_url
	editor.custom_minimum_size = Vector2(0, 44)
	side.add_child(editor)
	var use := Button.new()
	use.text = locale.text("use_server")
	use.custom_minimum_size = Vector2(0, 48)
	use.pressed.connect(_apply_settings_url.bind(editor))
	side.add_child(use)
	_add_idempotency_note(side)
	_add_section(side, "unavailable_actions")
	var any := false
	for key in ["train", "found_city", "garrison", "transfer"]:
		if not bool(caps.get(key, false)):
			any = true
			_add_waiting(side, Capabilities.ROUTES[key])
	if not any:
		_add_plain(side, locale.text("none"))
	if not bool(caps.get("player_auth", false)):
		_add_plain(side, locale.text("auth_phase7_missing"))


func _add_army_row(army: Dictionary) -> void:
	var selected := int(army.get("id", 0)) == selected_army_id
	var label := "%s  %s" % [army.get("name", army.get("id", "")), army.get("status", "")]
	if selected:
		label = "• " + label
	_add_picker(side, label, _pick_army.bind(int(army.get("id", 0))))


func _add_disabled_or_form(parent: Node, cap_key: String, endpoint: String, builder: Callable) -> void:
	if bool(caps.get(cap_key, false)):
		builder.call(parent)
	else:
		_add_waiting(parent, endpoint)


func _add_waiting(parent: Node, endpoint: String) -> void:
	var label := Label.new()
	label.text = locale.text("waiting_endpoint", {"endpoint": endpoint})
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("e09a32"))
	parent.add_child(label)


func _add_idempotency_note(parent: Node) -> void:
	_add_plain(parent, locale.text("idempotency_on") if bool(caps.get("idempotency", false)) else locale.text("idempotency_off"))


func _add_section(parent: Node, key: String) -> void:
	var label := Label.new()
	label.set_meta("i18n", key)
	label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)


func _add_caption(parent: Node, key: String) -> void:
	var label := Label.new()
	label.set_meta("i18n", key)
	parent.add_child(label)


func _add_plain(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _add_picker(parent: Node, text: String, cb: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(cb)
	parent.add_child(button)


func _add_action_button(parent: Node, key: String, cb: Callable) -> void:
	var button := Button.new()
	button.set_meta("i18n", key)
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(cb)
	parent.add_child(button)


func _add_small_button(parent: Node, key: String, cb: Callable) -> void:
	var button := Button.new()
	button.set_meta("i18n", key)
	button.custom_minimum_size = Vector2(96, 44)
	button.pressed.connect(cb)
	parent.add_child(button)


func _spin(min_value: int, max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.value = value
	spin.custom_minimum_size = Vector2(0, 44)
	spin.rounded = true
	return spin


func _pick_city(city_id: int) -> void:
	selected_city_id = city_id
	tab = "city"
	_layout()
	_refresh_selected_city()


func _pick_army(army_id: int) -> void:
	selected_army_id = army_id
	tab = "army"
	_layout()
	_render_side()
	_sync_map()


func _set_tab(next: String) -> void:
	tab = next
	if next != "reports":
		open_report_id = 0
	_layout()
	_render_side()
	_sync_map()


func _sync_target_banner() -> void:
	target_banner.visible = target_mode != ""
	match target_mode:
		"attack":
			target_banner.text = locale.text("tap_enemy_city")
		"reinforce", "move", "garrison", "transfer":
			target_banner.text = locale.text("tap_city")
		"found":
			target_banner.text = locale.text("tap_empty_for_found")
		_:
			target_banner.text = ""


func _layout() -> void:
	if auth_scroll == null:
		return
	var panel_w: float = min(480.0, max(280.0, size.x - 24.0))
	auth_scroll.position = Vector2((size.x - panel_w) * 0.5, 8)
	auth_scroll.size = Vector2(panel_w, max(0.0, size.y - 16))
	var narrow := size.x < 900.0
	var top_h := 56.0
	var tab_h := 56.0 if narrow else 0.0
	game_top.position = Vector2(8, 6)
	game_top.size = Vector2(max(0.0, size.x - 16), top_h - 8)
	tab_bar.visible = narrow
	tab_bar.position = Vector2(4, size.y - tab_h)
	tab_bar.size = Vector2(max(0.0, size.x - 8), tab_h)
	var body_top := top_h
	var body_h: float = max(0.0, size.y - top_h - tab_h)
	var show_panel := not narrow or tab != "map"
	if target_mode != "":
		show_panel = false
	if narrow and show_panel:
		map_view.position = Vector2(0, body_top)
		map_view.size = Vector2(size.x, body_h * 0.38)
		side_scroll.visible = true
		side_scroll.position = Vector2(0, body_top + body_h * 0.38)
		side_scroll.size = Vector2(size.x, body_h * 0.62)
	elif show_panel:
		var side_w: float = min(420.0, size.x * 0.38)
		map_view.position = Vector2(0, body_top)
		map_view.size = Vector2(max(0.0, size.x - side_w), body_h)
		side_scroll.visible = true
		side_scroll.position = Vector2(size.x - side_w, body_top)
		side_scroll.size = Vector2(side_w, body_h)
	else:
		map_view.position = Vector2(0, body_top)
		map_view.size = Vector2(size.x, body_h)
		side_scroll.visible = false
	target_banner.position = Vector2(12, body_top + 78)
	target_banner.size = Vector2(max(0.0, map_view.size.x - 24), 64)
	status_banner.position = Vector2(12, size.y - tab_h - 36)
	status_banner.size = Vector2(max(0.0, size.x - 24), 32)
	if modal != null and modal.get_child_count() > 0:
		var dialog := modal.get_child(0) as Control
		var dialog_w: float = min(560.0, max(280.0, size.x - 24.0))
		var dialog_h: float = min(480.0, max(240.0, size.y - 24.0))
		dialog.offset_left = -dialog_w * 0.5
		dialog.offset_right = dialog_w * 0.5
		dialog.offset_top = -dialog_h * 0.5
		dialog.offset_bottom = dialog_h * 0.5
		if modal_body != null:
			modal_body.custom_minimum_size = Vector2(dialog_w - 48.0, 0)
	if logged_in and not fitted_once:
		_sync_map()


func _side_editing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or side == null:
		return false
	return side.is_ancestor_of(focus) and (focus is LineEdit or focus is SpinBox)


func _refresh_eta(now_ms: int) -> void:
	if side == null:
		return
	_walk_eta(side, now_ms)


func _walk_eta(node: Node, now_ms: int) -> void:
	if node.has_meta("arrive"):
		var remain := IsoTime.parse_unix_ms(str(node.get_meta("arrive"))) - now_ms
		var label := node as Label
		if label != null:
			label.text = "%s  %s" % [locale.text("eta"), _format_remain(remain)]
	for child in node.get_children():
		_walk_eta(child, now_ms)


func _format_remain(remain_ms: int) -> String:
	if remain_ms < 0:
		remain_ms = 0
	var total := int(remain_ms / 1000)
	var hours := int(total / 3600)
	var minutes := int((total % 3600) / 60)
	var seconds := total % 60
	return "%d:%02d:%02d" % [hours, minutes, seconds]


func _apply_static_text() -> void:
	_walk_i18n(self)
	if dev_name_edit != null:
		dev_name_edit.placeholder_text = locale.text("dev_player_name")
	_apply_auth_state()
	_sync_target_banner()
	if health_label != null and not health_label.has_meta("i18n"):
		_set_health(_health_copy(), health_dot.color if health_dot != null else Color("e09a32"))
	if logged_in:
		_sync_who()


func _walk_i18n(node: Node) -> void:
	if node.has_meta("i18n"):
		var translated := locale.text(str(node.get_meta("i18n")))
		if node is Button:
			(node as Button).text = translated
		elif node is Label:
			(node as Label).text = translated
	for child in node.get_children():
		_walk_i18n(child)


func _apply_auth_state() -> void:
	if phase_label == null:
		return
	if not caps_ready:
		if phase_label.text == locale.text("session_expired"):
			return
		phase_label.text = ""
		return
	if bool(caps.get("player_auth", false)):
		phase_label.text = locale.text("auth_phase7_ready")
		phase_label.add_theme_color_override("font_color", Color("8ecae6"))
	else:
		phase_label.text = locale.text("auth_phase7_missing")
		phase_label.add_theme_color_override("font_color", Color("e09a32"))


func _health_copy() -> String:
	match health:
		"ok", "degraded":
			return locale.text("connected")
		"down":
			return locale.text("disconnected")
		_:
			return locale.text("connecting")


func _set_health(text: String, color: Color) -> void:
	if health_label != null:
		health_label.text = text
		if health_label.has_meta("i18n"):
			health_label.remove_meta("i18n")
	if health_dot != null:
		health_dot.color = color
	_paint_health_dots(color)


func _paint_health_dots(color: Color) -> void:
	if auth_box == null:
		return
	_paint_dots(auth_box, color)


func _paint_dots(node: Node, color: Color) -> void:
	if node.has_meta("health_dot") and node is ColorRect:
		(node as ColorRect).color = color
	for child in node.get_children():
		_paint_dots(child, color)


func _set_lang(next: String) -> void:
	settings.locale = next
	settings.save()
	locale.set_lang(next)
	_apply_static_text()
	_render_side()
	_sync_map()


func _toggle_lang() -> void:
	_set_lang("en" if locale.lang == "th" else "th")


func _on_stay_toggled(on: bool) -> void:
	settings.stay_signed_in = on
	settings.save()


func _on_dev_toggled(on: bool) -> void:
	settings.dev_mode = on
	settings.save()
	dev_box.visible = on


func _make_theme(text_font: Font) -> Theme:
	var next := Theme.new()
	if text_font != null:
		next.default_font = text_font
	next.default_font_size = 18
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("243041")
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("31405a")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("1c2430")
	next.set_stylebox("normal", "Button", normal)
	next.set_stylebox("hover", "Button", hover)
	next.set_stylebox("pressed", "Button", hover)
	next.set_stylebox("disabled", "Button", disabled)
	next.set_stylebox("focus", "Button", hover)
	next.set_color("font_color", "Button", Color("f2f4f8"))
	next.set_color("font_hover_color", "Button", Color("f2f4f8"))
	next.set_color("font_pressed_color", "Button", Color("f2f4f8"))
	next.set_color("font_disabled_color", "Button", Color("8b93a1"))
	next.set_color("font_color", "Label", Color("f2f4f8"))
	next.set_color("font_color", "CheckBox", Color("f2f4f8"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("1c2433")
	panel.set_corner_radius_all(12)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	next.set_stylebox("panel", "PanelContainer", panel)
	var line := StyleBoxFlat.new()
	line.bg_color = Color("121820")
	line.set_corner_radius_all(6)
	line.content_margin_left = 8
	line.content_margin_right = 8
	line.content_margin_top = 6
	line.content_margin_bottom = 6
	next.set_stylebox("normal", "LineEdit", line)
	next.set_color("font_color", "LineEdit", Color("f2f4f8"))
	next.set_color("font_placeholder_color", "LineEdit", Color("9aa3b2"))
	next.set_color("font_color", "SpinBox", Color("f2f4f8"))
	return next
