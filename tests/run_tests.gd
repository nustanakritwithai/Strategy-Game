extends SceneTree

## Headless unit tests. Exit 0 when every case passes.


func _init() -> void:
	var failed := _run()
	quit(1 if failed else 0)


func _run() -> bool:
	var suite: Script = load("res://tests/test_logic.gd")
	var inst: RefCounted = suite.new()
	var cases: Array = inst.call("cases")
	var failed := 0
	print("1..%s" % cases.size())
	for row in cases:
		var name: String = row[0]
		var fn: Callable = row[1]
		var err: String = str(fn.call())
		if err == "":
			print("ok %s" % name)
		else:
			failed += 1
			print("not ok %s" % name)
			print("# %s" % err)
	if failed == 0:
		print("# all passed")
		return false
	print("# %s failed" % failed)
	return true
