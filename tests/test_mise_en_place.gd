extends TestCase
## Mise en place : mobilier au hasard, gardes à leur poste, équipement à trois points.


func _game(seed_value: int) -> GameState:
	var data := GameData.load_default()
	return GameSetup.new_game(data, seed_value, GameSetup.solo_config(data))


func test_trente_six_meubles_dans_les_pieces() -> void:
	var s := _game(3)
	assert_eq(s.furniture.size(), 36)
	var count := {}
	for f in s.furniture:
		count[f.type] = count.get(f.type, 0) + 1
		var size := int(s.data.mobilier["types"][f.type]["cases"])
		assert_eq(f.cells.size(), size, f.type)
		for c in f.cells:
			assert_true(s.plan.rooms.has(s.plan.cell(c)), "%s hors des pièces en %s" % [f.type, c])
			assert_false(s.plan.is_opening(c), "un meuble sur une porte")
		if size == 2:
			assert_eq(Hex.distance(f.cells[0], f.cells[1]), 1, "les deux cases se touchent")
			assert_eq(s.plan.cell(f.cells[0]), s.plan.cell(f.cells[1]), "dans la même pièce")
	for type in s.data.mobilier["types"]:
		assert_eq(count.get(type, 0), 6, type)


func test_deux_meubles_ne_se_touchent_jamais() -> void:
	# Livret : « on ne pose pas deux meubles sur des cases adjacentes ».
	for seed_value in [1, 2, 3, 4]:
		var s := _game(seed_value)
		for f in s.furniture:
			for g in s.furniture:
				if f == g:
					continue
				for a in f.cells:
					for b in g.cells:
						assert_true(Hex.distance(a, b) > 1, "graine %d : %s et %s" % [seed_value, f.type, g.type])


func test_aucune_porte_obstruee() -> void:
	# Livret : « on n'obstrue pas une porte ». Chaque ouverture garde une case libre de chaque côté.
	var s := _game(7)
	for c in s.plan.openings:
		var free := [false, false]
		for d in Hex.DIRECTIONS:
			var n := Hex.step(c, d)
			if s.plan.passable(c, n) and not s.furniture_at.has(n):
				free[s.plan.opening_side(c, d)] = true
		assert_true(free[0] and free[1], "ouverture %s" % c)


func test_meme_graine_meme_villa() -> void:
	var a := _game(11)
	var b := _game(11)
	var c := _game(12)
	var same := true
	var differs := false
	for i in a.furniture.size():
		same = same and a.furniture[i].type == b.furniture[i].type and a.furniture[i].cells == b.furniture[i].cells
		differs = differs or a.furniture[i].cells != c.furniture[i].cells
	assert_true(same, "même graine, même mobilier")
	assert_true(differs, "autre graine, autre mobilier")


func test_un_dormeur_par_lit_et_gardes_a_leur_poste() -> void:
	var s := _game(5)
	assert_eq(s.sleepers().size(), 6)
	for sleeper in s.sleepers():
		var bed := s.get_furniture(sleeper.furniture_id)
		assert_eq(bed.type, "lit")
		assert_eq(sleeper.pos, bed.head(), "la tête du dormeur est sur la première case du lit")
	assert_eq(RulesFixture.guard(s, "A").pos, Vector2i(13, 12))
	assert_eq(RulesFixture.guard(s, "B").pos, Vector2i(13, 18))
	for t in s.thieves():
		assert_eq(t.status, Pawn.Status.OUTSIDE, "les voleurs partent de la rue")


func test_trois_points_d_equipement() -> void:
	var data := GameData.load_default()
	# Revolver (3) et matraque (1) : quatre points, refusé.
	assert_eq(GameSetup.new_game(data, 1, {"voleurs": [{"equipement": ["revolver", "matraque"]}]}), null)
	assert_false(data.valid_equipment(["pare_balles_1", "pare_balles_1"]), "pas deux fois le même objet")
	assert_true(data.valid_equipment(["chaussures_silencieuses", "pare_balles_1", "matraque"]))
	for key in data.regles["tenues"]:
		assert_true(data.valid_equipment(data.regles["tenues"][key]["equipement"]), key)


func test_bande_du_solo_et_tour_de_role() -> void:
	var data := GameData.load_default()
	var solo := GameSetup.solo_config(data)
	assert_eq(solo["voleurs"].size(), int(data.regles["solo"]["voleurs"]))
	assert_eq(solo["tours"], int(data.regles["solo"]["tours"]))
	for t in solo["voleurs"]:
		assert_true(data.valid_equipment(t["equipement"]), "tenue " + t["tenue"])
		assert_true(data.regles["tenues"][t["tenue"]]["modele"] != "", "la bande du solo est en 3D")
	var hot := GameSetup.hot_seat_config(data, ["apache", "chatte", "apache"])
	assert_eq(hot["tours"], 0, "pas d'horloge en tour de rôle")
	assert_eq(hot["voleurs"][2]["joueur"], 3)
	assert_eq(hot["voleurs"][2]["nom"], "l'Apache 2", "deux joueurs dans la même tenue")
