class_name GameTheme
extends RefCounted
## Shared portrait theme at res://assets/ui/game_theme.tres.
## Display font slot: ZCOOL KuaiLe (站酷快乐体), subset. Left empty.
## Body font slot: Noto Sans SC fallback, subset. Left empty.
## Button and panel StyleBoxes are the Kenney UI skin drop-in.
## This change does not ship font files.


const PATH := "res://assets/ui/game_theme.tres"
const DISPLAY := &"Display"
const BODY := &"Body"


static func load_theme() -> Theme:
	return load(PATH) as Theme
