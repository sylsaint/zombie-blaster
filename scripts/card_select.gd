extends Control
## Layout shell for the three-card offer. Art can replace this scene if
## %Title, %Card0, %Card1 and %Card2 keep their unique names.


signal card_picked(index: int)

var _cards: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cards = [%Card0, %Card1, %Card2]
	var i := 0
	while i < _cards.size():
		_cards[i].pressed.connect(_emit.bind(i))
		i += 1
	visible = false


func present(titles: PackedStringArray, details: PackedStringArray) -> void:
	visible = true
	var i := 0
	while i < _cards.size():
		var show := i < titles.size()
		_cards[i].visible = show
		_cards[i].disabled = not show
		if show:
			var body := ""
			if i < details.size():
				body = details[i]
			_cards[i].text = titles[i] + "\n" + body
		i += 1


func dismiss() -> void:
	visible = false


func _emit(index: int) -> void:
	card_picked.emit(index)
