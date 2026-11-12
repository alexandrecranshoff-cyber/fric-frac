class_name GameActions
extends RefCounted
## Les gestes d'un joueur, sous forme de commandes. Chaque commande acceptée est notée dans
## `state.commands` : la graine des dés et cette liste suffisent à rejouer la partie à l'identique.
##
## Commandes (les cases sont des paires [colonne, ligne]) :
## - {"type": "climb", "cell"}   monter sur le mur d'enceinte ;
## - {"type": "jump", "cell"}    sauter du mur dans le jardin ;
## - {"type": "gate", "cell"}    se présenter devant la grille ;
## - {"type": "move", "path"}    marcher le long d'un chemin de cases ;
## - {"type": "work", "target", "points"}   passer des points sur une serrure ;
## - {"type": "open", "target"}  forcer la serrure ;
## - {"type": "attack", "target": numéro du pion, "mode"} ;
## - {"type": "leave"}           quitter le plateau ;
## - {"type": "end_turn"}.
## Une cible de serrure est {"cell": [colonne, ligne]} ou {"furniture": numéro}.


## Applique une commande du voleur dont c'est le tour. Renvoie les événements à afficher, liste
## vide si la commande est refusée.
static func apply(state: GameState, command: Dictionary) -> Array:
	var thief := state.current_thief()
	if thief == null:
		return []
	var events: Array = []
	var type: String = command.get("type", "")
	if type == "end_turn":
		events = TurnFlow.end_turn(state)
	elif thief.skips_turn:
		return []
	else:
		match type:
			"climb":
				events = Movement.climb(state, thief, GameSetup.cell_of(command["cell"]))
			"jump":
				events = Movement.jump(state, thief, GameSetup.cell_of(command["cell"]))
			"gate":
				events = Movement.approach_gate(state, thief, GameSetup.cell_of(command["cell"]))
			"move":
				var path := []
				for c in command["path"]:
					path.append(GameSetup.cell_of(c))
				events = Movement.move(state, thief, path)
			"work":
				events = BreakIn.work(state, thief, _target(command["target"]), int(command["points"]))
			"open":
				events = BreakIn.open(state, thief, _target(command["target"]))
			"attack":
				var target := state.get_pawn(int(command["target"]))
				if target != null:
					events = Combat.attack(state, thief, target, command["mode"])
			"leave":
				events = Movement.leave(state, thief)
	if not events.is_empty() or type == "end_turn":
		state.commands.append(command.duplicate(true))
	return events


static func _target(target: Dictionary) -> Dictionary:
	if target.has("furniture"):
		return {"furniture": int(target["furniture"])}
	return {"cell": GameSetup.cell_of(target["cell"])}
