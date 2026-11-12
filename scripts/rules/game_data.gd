class_name GameData
extends RefCounted
## Valeurs chiffrées du jeu, lues dans data/*.json. Aucun chiffre de règle en dur dans le code.

var effraction: Dictionary
var combat: Dictionary
var butin: Dictionary
var equipement: Dictionary
var mobilier: Dictionary
var villa: Dictionary
## Réglages de l'adaptation vidéo (points d'action, allure des gardes, horloge).
var regles: Dictionary


static func load_default() -> GameData:
	var d := GameData.new()
	d.effraction = load_json("res://data/effraction.json")
	d.combat = load_json("res://data/combat.json")
	d.butin = load_json("res://data/butin.json")
	d.equipement = load_json("res://data/equipement.json")
	d.mobilier = load_json("res://data/mobilier.json")
	d.villa = load_json("res://data/villa.json")
	d.regles = load_json("res://data/regles_video.json")
	return d


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "JSON illisible : " + path)
	return parsed


## Portée du bruit d'une effraction (tableau 1) après `turns` tours passés sur place.
func break_in_noise(kind: String, turns: int) -> int:
	var row: Array = effraction["portee_bruit"][kind]
	return int(row[clampi(turns, 1, row.size()) - 1])


## Résultat d'un combat ou d'un saut (tableau 2) pour un dé déjà modifié : "ok", "ko" ou "tue".
func combat_result(kind: String, die: int) -> String:
	var column: Array = combat["resultats"][kind]
	return column[clampi(die, 1, column.size()) - 1]


## Ligne de la table de butin (tableau 3) pour un tirage dizaines-unités, de 11 à 66.
func loot_entry(roll: int) -> Dictionary:
	return butin["table"][str(roll)]


## Coût en points d'action d'un geste (regles_video.json).
func cost(action: String) -> int:
	return int(regles["cout"][action])


## Coût total d'un équipement en points (le livret en donne trois par voleur).
func equipment_cost(items: Array) -> int:
	var total := 0
	for item in items:
		total += int(equipement["objets"][item]["cout"])
	return total


## Un équipement est valable s'il ne cite que des objets connus, sans doublon, pour trois points au plus.
func valid_equipment(items: Array) -> bool:
	var seen := {}
	for item in items:
		if not equipement["objets"].has(item) or seen.has(item):
			return false
		seen[item] = true
	return equipment_cost(items) <= int(equipement["points"])


## Caractère du plan pour une case, ou " " hors plateau.
func villa_cell(cell: Vector2i) -> String:
	var rows: Array = villa["lignes"]
	if cell.y < 0 or cell.y >= rows.size():
		return " "
	var row: String = rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return " "
	return row[cell.x]
