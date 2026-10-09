extends SceneTree
## Write a throwaway project.binary that contains the presentation overrides.
## The exporter copies individual keys out of this file. It does not replace
## the exported project.binary wholesale.


func _init() -> void:
	var out := ""
	var specs: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--set="):
			specs.append(arg.trim_prefix("--set="))
	if out.is_empty() or specs.is_empty():
		push_error("usage: -- --out=PATH.binary --set=key=bool|int|string:value")
		quit(1)
		return
	for spec in specs:
		var eq := spec.find("=")
		if eq <= 0:
			push_error("bad --set %s" % spec)
			quit(1)
			return
		var key := spec.substr(0, eq)
		var rest := spec.substr(eq + 1)
		var colon := rest.find(":")
		if colon <= 0:
			push_error("bad --set %s" % spec)
			quit(1)
			return
		var typ := rest.substr(0, colon)
		var raw := rest.substr(colon + 1)
		var value: Variant
		match typ:
			"bool":
				value = raw == "true"
			"int":
				value = int(raw)
			"string":
				value = raw
			_:
				push_error("bad type %s" % typ)
				quit(1)
				return
		ProjectSettings.set_setting(key, value)
		print("ENCODE_SET %s=%s" % [key, ProjectSettings.get_setting(key)])
	var err := ProjectSettings.save_custom(out)
	print("ENCODE_SAVE err=%s path=%s" % [err, out])
	quit(0 if err == OK else 1)
