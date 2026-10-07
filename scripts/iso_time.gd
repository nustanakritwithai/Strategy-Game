extends RefCounted
class_name IsoTime

## UTC timestamps shared by the clock and march display.
## Division matches the C++ civil calendar algorithm (truncation toward zero).


static func div_trunc(a: int, b: int) -> int:
	return int(float(a) / float(b))


static func days_from_civil(year: int, month: int, day: int) -> int:
	var y := year
	var m := month
	if m <= 2:
		y -= 1
	var era := div_trunc(y - 399, 400) if y < 0 else div_trunc(y, 400)
	var yoe := y - era * 400
	var month_shift := -3 if m > 2 else 9
	var doy := div_trunc(153 * (m + month_shift) + 2, 5) + day - 1
	var doe := yoe * 365 + div_trunc(yoe, 4) - div_trunc(yoe, 100) + doy
	return era * 146097 + doe - 719468


static func civil_from_days(z: int) -> Dictionary:
	z += 719468
	var era := div_trunc(z - 146096, 146097) if z < 0 else div_trunc(z, 146097)
	var doe := z - era * 146097
	var yoe := div_trunc(doe - div_trunc(doe, 1460) + div_trunc(doe, 36524) - div_trunc(doe, 146096), 365)
	var y := yoe + era * 400
	var doy := doe - (365 * yoe + div_trunc(yoe, 4) - div_trunc(yoe, 100))
	var mp := div_trunc(5 * doy + 2, 153)
	var d := doy - div_trunc(153 * mp + 2, 5) + 1
	var m := mp + 3 if mp < 10 else mp - 9
	if m <= 2:
		y += 1
	return {"year": y, "month": m, "day": d}


static func parse_unix_ms(text: String) -> int:
	var s := text.strip_edges()
	if s.is_empty():
		return 0
	var offset_min := 0
	if s.ends_with("Z") or s.ends_with("z"):
		s = s.substr(0, s.length() - 1)
	else:
		var plus := s.rfind("+")
		var minus := s.rfind("-")
		var sign_at := -1
		var sign := 1
		if plus > 10:
			sign_at = plus
			sign = 1
		if minus > 10 and minus > sign_at:
			sign_at = minus
			sign = -1
		if sign_at > 10:
			var off := s.substr(sign_at + 1)
			s = s.substr(0, sign_at)
			var parts := off.split(":")
			var hh := int(parts[0]) if parts.size() > 0 else 0
			var mm := int(parts[1]) if parts.size() > 1 else 0
			offset_min = sign * (hh * 60 + mm)
	var date_time := s.split("T")
	if date_time.size() != 2:
		date_time = s.split(" ")
	if date_time.size() != 2:
		return 0
	var ymd := date_time[0].split("-")
	if ymd.size() != 3:
		return 0
	var time_part := date_time[1]
	var frac := 0
	var dot := time_part.find(".")
	if dot >= 0:
		var frac_txt := time_part.substr(dot + 1)
		time_part = time_part.substr(0, dot)
		var digits := ""
		for i in frac_txt.length():
			var ch := frac_txt.substr(i, 1)
			if ch < "0" or ch > "9":
				break
			digits += ch
		while digits.length() < 6:
			digits += "0"
		frac = int(digits.substr(0, 6))
	var hms := time_part.split(":")
	if hms.size() < 2:
		return 0
	var year := int(ymd[0])
	var month := int(ymd[1])
	var day := int(ymd[2])
	var hour := int(hms[0])
	var minute := int(hms[1])
	var second := int(hms[2]) if hms.size() > 2 else 0
	var days := days_from_civil(year, month, day)
	var ms := days * 86400000 + hour * 3600000 + minute * 60000 + second * 1000 + div_trunc(frac, 1000)
	ms -= offset_min * 60000
	return ms


static func unix_ms_from_time_payload(payload: Dictionary) -> int:
	if payload.has("unix_ms"):
		return int(payload["unix_ms"])
	return parse_unix_ms(str(payload.get("server_time", "")))


static func format_utc(unix_ms: int) -> String:
	var sec := div_trunc(unix_ms, 1000)
	var days := div_trunc(sec, 86400)
	var rem := sec - days * 86400
	if rem < 0:
		rem += 86400
		days -= 1
	var civil := civil_from_days(days)
	var hour := div_trunc(rem, 3600)
	var minute := div_trunc(rem % 3600, 60)
	var second := rem % 60
	return "%04d-%02d-%02d %02d:%02d:%02d UTC" % [civil.year, civil.month, civil.day, hour, minute, second]
