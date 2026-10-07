extends Node
class_name HttpApi

## HTTP transport. Logs the method, path, and status only — never tokens or bodies.


var base_url := ""
var access_token := ""
var refresh_handler: Callable = Callable()
var _busy := false


func request(
	method: String,
	path: String,
	body: Variant = null,
	with_auth: bool = false,
	retry_auth: bool = false,
	extra_headers: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var response := await _raw(method, path, body, with_auth, extra_headers)
	if (
		retry_auth
		and with_auth
		and int(response.get("status", 0)) == 401
		and refresh_handler.is_valid()
	):
		var refreshed: Variant = refresh_handler.call()
		if not (refreshed is bool):
			refreshed = await refreshed
		if refreshed == true:
			response = await _raw(method, path, body, with_auth, extra_headers)
	return response


func _raw(
	method: String,
	path: String,
	body: Variant,
	with_auth: bool,
	extra_headers: PackedStringArray
) -> Dictionary:
	while _busy:
		await get_tree().process_frame
	_busy = true
	var out := await _send(method, path, body, with_auth, extra_headers)
	_busy = false
	return out


func _send(
	method: String,
	path: String,
	body: Variant,
	with_auth: bool,
	extra_headers: PackedStringArray
) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	var payload := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload = body if body is String else JSON.stringify(body)
	if with_auth and access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	for header in extra_headers:
		headers.append(header)
	var url := SettingsStore.normalize_url(base_url) + path
	var err := http.request(url, headers, _method_enum(method), payload)
	if err != OK:
		http.queue_free()
		push_warning("HTTP %s %s failed to start (%s)" % [method, path, err])
		return _empty(path, err)
	var args: Array = await http.request_completed
	var result := int(args[0])
	var status := int(args[1])
	var resp_headers: PackedStringArray = args[2]
	var resp_body: PackedByteArray = args[3]
	http.queue_free()
	var text := resp_body.get_string_from_utf8()
	var parsed: Variant = JsonText.parse_preserving_integers(text)
	if status >= 400 or result != HTTPRequest.RESULT_SUCCESS:
		push_warning("HTTP %s %s -> status %s result %s" % [method, path, status, result])
	return {
		"status": status,
		"json": parsed,
		"text": "" if parsed != null else text,
		"headers": resp_headers,
		"result": result,
		"path": path,
		"ok": status >= 200 and status < 300 and result == HTTPRequest.RESULT_SUCCESS,
	}


func _empty(path: String, result: int) -> Dictionary:
	return {
		"status": 0,
		"json": null,
		"text": "",
		"headers": PackedStringArray(),
		"result": result,
		"path": path,
		"ok": false,
	}


func _method_enum(method: String) -> int:
	match method.to_upper():
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		"OPTIONS":
			return HTTPClient.METHOD_OPTIONS
		"PUT":
			return HTTPClient.METHOD_PUT
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET
