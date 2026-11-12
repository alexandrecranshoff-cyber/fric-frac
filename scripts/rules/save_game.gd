class_name SaveGame
extends RefCounted
## Sauvegarde d'une partie : sa graine, sa mise en place et la liste de ses gestes. Rejouer cette
## liste redonne la même partie, mêmes dés compris. C'est aussi le « film du casse ».

const VERSION := 1


static func to_dict(state: GameState) -> Dictionary:
	return {"version": VERSION, "graine": state.dice.rng_seed(), "config": state.config.duplicate(true),
		"gestes": state.commands.duplicate(true)}


## Rejoue une partie sauvegardée, jusqu'au geste `upto` (tous par défaut). Null si elle est illisible.
static func from_dict(data: GameData, saved: Dictionary, upto: int = -1) -> GameState:
	if int(saved.get("version", 0)) != VERSION:
		return null
	var state := GameSetup.new_game(data, int(saved["graine"]), saved["config"])
	if state == null:
		return null
	TurnFlow.start_game(state)
	var commands: Array = saved["gestes"]
	var count := commands.size() if upto < 0 else mini(upto, commands.size())
	for i in count:
		GameActions.apply(state, commands[i])
	return state


static func to_json(state: GameState) -> String:
	return JSON.stringify(to_dict(state))


static func from_json(data: GameData, text: String) -> GameState:
	var parsed = JSON.parse_string(text)
	return from_dict(data, parsed) if parsed is Dictionary else null
