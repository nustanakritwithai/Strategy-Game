extends RefCounted
class_name TokenStore

## Writes the refresh token only. Access tokens and passwords are not accepted.


const DEFAULT_PATH := "user://player_refresh.cfg"


func save_refresh(refresh_token: String, path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "refresh_token", refresh_token)
	cfg.save(path)


func load_refresh(path: String = DEFAULT_PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return ""
	return str(cfg.get_value("auth", "refresh_token", ""))


func clear(path: String = DEFAULT_PATH) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute) or FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)
