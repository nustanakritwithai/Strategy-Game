extends RefCounted
class_name SettingsStore

const DEFAULT_URL := "https://157-85-96-139.sslip.io"
const DEFAULT_PATH := "user://settings.cfg"

var server_url := DEFAULT_URL
var locale := "th"
var dev_mode := false
var stay_signed_in := false


func load(path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	server_url = normalize_url(str(cfg.get_value("net", "server_url", DEFAULT_URL)))
	locale = str(cfg.get_value("ui", "locale", "th"))
	if locale != "en":
		locale = "th"
	dev_mode = bool(cfg.get_value("ui", "dev_mode", false))
	stay_signed_in = bool(cfg.get_value("ui", "stay_signed_in", false))


func save(path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("net", "server_url", normalize_url(server_url))
	cfg.set_value("ui", "locale", locale)
	cfg.set_value("ui", "dev_mode", dev_mode)
	cfg.set_value("ui", "stay_signed_in", stay_signed_in)
	cfg.save(path)


static func normalize_url(url: String) -> String:
	var s := url.strip_edges()
	while s.ends_with("/"):
		s = s.substr(0, s.length() - 1)
	return s
