class_name DiceRoller
extends RefCounted
## Générateur de dés à graine : tout tirage aléatoire du jeu passe par ici,
## pour pouvoir rejouer une partie et écrire des tests déterministes.

var history: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _forced: Array[int] = []


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func rng_seed() -> int:
	return _rng.seed


func rng_state() -> int:
	return _rng.state


## Reprend une partie sauvegardée : même graine, même position dans la suite des tirages.
func restore(seed_value: int, state_value: int) -> void:
	_rng.seed = seed_value
	_rng.state = state_value
	_forced.clear()


## Impose les prochaines faces (tests, rejeu). Elles sont consommées dans l'ordre.
func force(values: Array) -> void:
	for v in values:
		_forced.append(int(v))


func d6() -> int:
	if not _forced.is_empty():
		return _forced.pop_front()
	return _rng.randi_range(1, 6)


## Lance `count` D6 et ajoute `bonus`. Le résultat est gardé dans l'historique
## pour que l'interface puisse afficher les dés.
func roll(count: int, bonus: int = 0, label: String = "") -> Dictionary:
	var faces: Array[int] = []
	var total := bonus
	for i in count:
		var f := d6()
		faces.append(f)
		total += f
	var result := {"label": label, "faces": faces, "bonus": bonus, "total": total}
	history.append(result)
	return result


## Deux dés lancés successivement : le premier donne les dizaines, le second
## les unités (11 à 66). Sert à la table de butin.
func d66(label: String = "") -> Dictionary:
	var tens := d6()
	var units := d6()
	var result := {"label": label, "faces": [tens, units] as Array[int], "bonus": 0, "total": tens * 10 + units}
	history.append(result)
	return result
