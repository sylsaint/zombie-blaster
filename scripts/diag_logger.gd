class_name DiagLogger
extends Logger
## Keeps the last few push_error / script / shader lines for the diagnostic overlay.
## Called from engine threads: lock, and never print or push_error from here.


const CAP := 15

var _mutex := Mutex.new()
var _lines: PackedStringArray = PackedStringArray()


func _log_error(function, file, line, code, rationale, _editor_notify, error_type, _script_backtraces) -> void:
	var kind := int(error_type)
	if kind == Logger.ERROR_TYPE_WARNING:
		return
	var tag := "ERROR"
	if kind == Logger.ERROR_TYPE_SCRIPT:
		tag = "SCRIPT"
	elif kind == Logger.ERROR_TYPE_SHADER:
		tag = "SHADER"
	var text := "%s %s:%s %s %s %s" % [tag, file, line, function, code, rationale]
	_mutex.lock()
	_lines.append(text)
	while _lines.size() > CAP:
		_lines.remove_at(0)
	_mutex.unlock()


func snapshot() -> PackedStringArray:
	_mutex.lock()
	var copy := _lines.duplicate()
	_mutex.unlock()
	return copy
