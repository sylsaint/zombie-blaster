extends SceneTree
## Runs against an exported pack (--main-pack), not the project folder.
## Asserts the main menu is on screen with a non-zero rect.


var _frames: int = 0
var _main: Node = null


func _initialize() -> void:
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _main == null:
		DisplayServer.window_set_size(Vector2i(1080, 1920))
		root.size = Vector2i(1080, 1920)
		_main = root.get_node_or_null("Main")
		if _main == null:
			var packed := load("res://scenes/main.tscn") as PackedScene
			if packed == null:
				_fail("main scene did not load from the pack")
				return
			_main = packed.instantiate()
			root.add_child(_main)
		return
	_frames += 1
	if _frames < 20:
		return
	_assert_menu()


func _assert_menu() -> void:
	var menu := _main.get_node_or_null("UI/MainMenu") as Control
	if menu == null:
		_fail("UI/MainMenu is missing")
		return
	var title := menu.get_node_or_null("Margin/Sheet/Column/Title") as Label
	var play := menu.get_node_or_null("Margin/Sheet/Column/Play") as Button
	var rect := menu.get_viewport().get_visible_rect()
	print("EXPORTED_MENU menu_visible=%s menu_size=%s title=%s play_size=%s viewport=%s" % [
		menu.visible,
		menu.size,
		title.text if title != null else "",
		play.size if play != null else Vector2.ZERO,
		rect.size,
	])
	if not menu.visible:
		_fail("MainMenu is not visible")
		return
	if menu.size.x <= 100.0 or menu.size.y <= 100.0:
		_fail("MainMenu size is %s" % menu.size)
		return
	if title == null or title.text != "高速打僵尸" or not title.visible:
		_fail("title is missing or not 高速打僵尸")
		return
	if title.size.y <= 0.0:
		_fail("title rect is empty")
		return
	if play == null or not play.visible or play.size.y < 50.0:
		_fail("play button is not visible")
		return
	print("EXPORTED_MENU_OK")
	quit(0)


func _fail(reason: String) -> void:
	print("EXPORTED_MENU_FAIL %s" % reason)
	quit(1)
