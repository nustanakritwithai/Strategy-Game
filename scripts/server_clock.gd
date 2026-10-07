extends RefCounted
class_name ServerClock

## offset = server_time - local_now, as docs/GAME_RULES.md describes.
## Countdowns use this offset. The client does not advance the simulation.


var offset_ms: int = 0
var synced: bool = false
var last_server_unix_ms: int = 0


func apply_sample(payload: Dictionary, local_unix_ms: int) -> void:
	var server_ms := IsoTime.unix_ms_from_time_payload(payload)
	offset_ms = server_ms - local_unix_ms
	last_server_unix_ms = server_ms
	synced = true


func now_unix_ms(local_unix_ms: int) -> int:
	return local_unix_ms + offset_ms


func countdown_ms(arrive_at: String, local_unix_ms: int) -> int:
	return IsoTime.parse_unix_ms(arrive_at) - now_unix_ms(local_unix_ms)


func countdown_seconds(arrive_at: String, local_unix_ms: int) -> float:
	return float(countdown_ms(arrive_at, local_unix_ms)) / 1000.0
