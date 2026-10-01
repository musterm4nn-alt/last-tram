class_name SystemicDialogue
extends DialogueProvider
## Template lines from ContentDB.dialogue (T-0040). The line and topic are picked from the
## exchange itself (tick, people, interaction), so the same exchange always shows the same
## words, without touching the sim's random streams.

var _content: ContentDB


func _init(content: ContentDB) -> void:
	_content = content


func line_for(exchange: Dictionary, _sim: Sim) -> String:
	var interaction_id := String(exchange.get("interaction_id", ""))
	var outcome := String(exchange.get("outcome", ""))
	var by_outcome: Dictionary = _content.dialogue.lines.get(interaction_id, {})
	var texts: PackedStringArray = by_outcome.get(outcome, PackedStringArray())
	if texts.is_empty():
		return ""
	var key := hash([exchange.get("actor_id", 0), exchange.get("target_id", 0), interaction_id, exchange.get("tick", 0)])
	var text := texts[absi(key) % texts.size()]
	var topics := _content.dialogue.topics
	if not topics.is_empty():
		text = text.replace("{topic}", topics[absi(key / 7) % topics.size()])
	return text


func thought_for(need_id: String) -> String:
	return _content.dialogue.needs.get(need_id, "")
