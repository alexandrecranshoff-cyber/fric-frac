extends TestCase
## Cohérence du plan de la villa relevé sur le plateau (data/villa.json).

const OUTSIDE := ".,~_/"
const OPENINGS := {"D": "porte_interieure", "E": "porte_exterieure", "F": "fenetre"}


func _zone(ch: String) -> String:
	if OUTSIDE.contains(ch):
		return "dehors"
	if ch >= "a" and ch <= "m":
		return ch
	return ""


func _cells(d: GameData, wanted: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rows: Array = d.villa["lignes"]
	for y in rows.size():
		for x in (rows[y] as String).length():
			if wanted.contains(rows[y][x]):
				result.append(Vector2i(x, y))
	return result


func test_dimensions_et_legende() -> void:
	var d := GameData.load_default()
	var rows: Array = d.villa["lignes"]
	assert_eq(rows.size(), int(d.villa["grille"]["lignes"]))
	for row in rows:
		assert_eq((row as String).length(), int(d.villa["grille"]["colonnes"]))
		for ch in row:
			assert_true(" #=.,~_/DEF".contains(ch) or d.villa["pieces"].has(ch), "caractère inconnu : " + ch)


func test_treize_pieces() -> void:
	var d := GameData.load_default()
	assert_eq(d.villa["pieces"].size(), 13)
	for room in d.villa["pieces"]:
		assert_true(_cells(d, room).size() >= 5, "pièce trop petite : " + room)


func test_enceinte_fermee_avec_une_grille() -> void:
	var d := GameData.load_default()
	assert_eq(_cells(d, "=").size(), 2)
	# Aucune case du terrain ne touche le bord du plateau sans passer par le mur ou la grille.
	for cell in _cells(d, OUTSIDE):
		for n in Hex.neighbors(cell):
			assert_true(d.villa_cell(n) != " ", "trou dans l'enceinte près de " + str(cell))


func test_gardes_dans_le_hall() -> void:
	var d := GameData.load_default()
	for name in ["A", "B"]:
		var g: Dictionary = d.villa["gardes"][name]
		var cell := Vector2i(int(g["case"][0]), int(g["case"][1]))
		assert_eq(d.villa_cell(cell), "h", name)
		var seen := {}
		for face in ["1", "2", "3", "4", "5", "6"]:
			var dir: String = g["directions"][face]
			seen[dir] = true
			# Les chiffres imprimés autour de A et B sont tous sur des cases du hall.
			assert_eq(d.villa_cell(Hex.step(cell, dir)), "h", name + face)
		assert_eq(seen.size(), 6, name)
	# Sur le plateau, le 3 de A est à droite et le 3 de B à gauche : B est A retourné.
	assert_eq(d.villa["gardes"]["A"]["directions"]["3"], "est")
	assert_eq(d.villa["gardes"]["B"]["directions"]["3"], "ouest")


func test_ouvertures() -> void:
	var d := GameData.load_default()
	var listed := {}
	var count := {"porte_interieure": 0, "porte_exterieure": 0, "fenetre": 0}
	for o in d.villa["ouvertures"]:
		var cell := Vector2i(int(o["case"][0]), int(o["case"][1]))
		var kind: String = o["type"]
		listed[cell] = true
		count[kind] += 1
		assert_eq(OPENINGS.get(d.villa_cell(cell), ""), kind, str(cell))
		var zones: Array = o["relie"]
		assert_eq(zones.size(), 2, str(cell))
		assert_eq(zones.has("dehors"), kind != "porte_interieure", str(cell))
		# Chaque côté de l'ouverture a au moins une case où poser le pied.
		for z in zones:
			var found := false
			for n in Hex.neighbors(cell):
				if _zone(d.villa_cell(n)) == z:
					found = true
			assert_true(found, "%s ne touche pas %s" % [cell, z])
	assert_eq(listed.size(), _cells(d, "DEF").size())
	assert_eq(count["porte_interieure"], 40)
	assert_eq(count["porte_exterieure"], 8)
	assert_eq(count["fenetre"], 20)


func test_toutes_les_pieces_communiquent() -> void:
	var d := GameData.load_default()
	var links := {}
	var enterable := {}
	for o in d.villa["ouvertures"]:
		var a: String = o["relie"][0]
		var b: String = o["relie"][1]
		if o["type"] == "porte_interieure":
			links[a] = (links.get(a, []) as Array) + [b]
			links[b] = (links.get(b, []) as Array) + [a]
		else:
			enterable[a if b == "dehors" else b] = true
	var reached := {"h": true}
	var queue := ["h"]
	while not queue.is_empty():
		var room: String = queue.pop_front()
		for other in links.get(room, []):
			if not reached.has(other):
				reached[other] = true
				queue.append(other)
	assert_eq(reached.size(), 13)
	# On entre dans la villa par le hall (perron) ou par une fenêtre ou une porte de façade.
	assert_true(enterable.has("h"))
	assert_true(enterable.size() >= 9)


func test_arbres_dehors() -> void:
	var d := GameData.load_default()
	assert_eq(d.villa["arbres"].size(), 21)
	for t in d.villa["arbres"]:
		assert_true(".,".contains(d.villa_cell(Vector2i(int(t[0]), int(t[1])))), str(t))
