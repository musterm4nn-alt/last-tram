class_name CreatorBackgroundTab
extends VBoxContainer
## The character creator's Background tab (T-0075): one button per background with a line about
## it; the chosen one is pressed. Emits `changed` after a choice.

## The model changed; the creator refreshes the preview and Start.
signal changed

var _model: CreatorModel
## Background id -> its button.
var _buttons: Dictionary[String, Button] = {}


## Builds one row per background for `model` (call once).
func build(model: CreatorModel) -> void:
	_model = model
	add_theme_constant_override("separation", 8)
	for def: BackgroundDef in Session.content.backgrounds.values():
		var button := Button.new()
		button.text = def.name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(140, 0)
		button.pressed.connect(func() -> void:
			_model.spec.background = def.id
			changed.emit())
		var about := Label.new()
		about.text = line(Session.content, def)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(360, 0)
		var row := HBoxContainer.new()
		row.add_child(button)
		row.add_child(about)
		add_child(row)
		_buttons[def.id] = button


## Presses the chosen background's button (the default when none is chosen).
func sync(model: CreatorModel) -> void:
	_model = model
	var chosen := Backgrounds.of(Session.content, model.spec.background).id
	for id: String in _buttons:
		_buttons[id].set_pressed_no_signal(id == chosen)


## "Just released. … · €15.00 · no job" for a background.
static func line(content: ContentDB, def: BackgroundDef) -> String:
	var job := content.job(def.job_id) if not def.job_id.is_empty() else null
	return "%s · %s · %s" % [def.description, Money.format(def.cash + def.bank), job.name if job != null else "no job"]
