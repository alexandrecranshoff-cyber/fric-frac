extends TestCase
## Ce que l'interface propose au voleur dont c'est le tour (TurnOptions).


func test_cases_atteignables_a_six_points() -> void:
	var s := RulesFixture.without_guards(RulesFixture.game())
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(5, 2))
	var reach := TurnOptions.reachable(s, t)
	assert_eq(reach[Vector2i(6, 2)]["cost"], 1)
	assert_eq(reach[Vector2i(11, 2)]["cost"], 6)
	assert_false(reach.has(Vector2i(12, 2)), "sept cases : trop loin")
	assert_false(reach.has(t.pos), "la case de départ n'est pas proposée")
	for cell in reach:
		assert_eq(reach[cell]["path"].size() <= reach[cell]["cost"], true)
		assert_eq(reach[cell]["path"].back(), cell)


func test_le_chemin_propose_est_celui_que_joue_le_moteur() -> void:
	var s := RulesFixture.without_guards(RulesFixture.game())
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(5, 2))
	var goal := Vector2i(8, 4)
	var option: Dictionary = TurnOptions.reachable(s, t)[goal]
	var path := []
	for c in option["path"]:
		path.append([c.x, c.y])
	GameActions.apply(s, {"type": "move", "path": path})
	assert_eq(t.pos, goal)
	assert_eq(t.ap, 6 - int(option["cost"]))


func test_une_porte_fermee_arrete_le_chemin() -> void:
	# Le voleur sur la porte entre le salon rouge et le salon au tapis rond, côté salon rouge :
	# il ne passe de l'autre côté qu'en forçant la porte.
	var s := RulesFixture.without_guards(RulesFixture.game())
	var door := Vector2i(13, 6)
	var t := RulesFixture.thief(s)
	RulesFixture.put(t, door, s.plan.opening_side(door, "ouest"))
	var reach := TurnOptions.reachable(s, t)
	assert_true(reach.has(Vector2i(12, 6)))
	assert_false(reach.has(Vector2i(14, 6)), "de l'autre côté de la porte")
	var locks := TurnOptions.locks(s, t)
	assert_eq(locks.size(), 1)
	assert_eq(locks[0]["kind"], "porte_interieure")
	assert_eq(locks[0]["target"], {"cell": door})


func test_depuis_la_rue_la_grille_et_le_mur() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.thief(s)
	assert_eq(t.status, Pawn.Status.OUTSIDE)
	assert_eq(TurnOptions.gate_cells(s, t), [Vector2i(13, 24), Vector2i(14, 24)] as Array[Vector2i])
	var walls := TurnOptions.climb_cells(s, t)
	assert_true(walls.size() > 40)
	for c in walls:
		assert_true(s.plan.is_wall(c))
	assert_true(TurnOptions.reachable(s, t).is_empty(), "pas de marche depuis la rue")
	GameActions.apply(s, {"type": "climb", "cell": [5, 0]})
	assert_eq(TurnOptions.jump_cells(s, t).size(), 0, "plus de points : il sautera au tour suivant")


func test_adversaires_dans_la_piece() -> void:
	var s := RulesFixture.game([["matraque"]])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(12, 12))
	var attacks := TurnOptions.attacks(s, t)
	var guard := RulesFixture.guard(s, "A")
	assert_eq(attacks.size(), 1)
	assert_eq(attacks[0]["id"], guard.id)
	assert_true(attacks[0]["modes"].has("main_nue"))
	assert_true(attacks[0]["modes"].has("matraque"))
	t.has_attacked = true
	assert_true(TurnOptions.attacks(s, t).is_empty(), "une attaque par tour")


func test_sortie_par_le_mur() -> void:
	var s := RulesFixture.without_guards(RulesFixture.game())
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(5, 0))
	assert_true(TurnOptions.can_leave(s, t))
	RulesFixture.put(t, Vector2i(5, 2))
	assert_false(TurnOptions.can_leave(s, t))
	assert_true(TurnOptions.climb_cells(s, t).is_empty(), "le mur n'est pas voisin")
	RulesFixture.put(t, Vector2i(5, 1))
	assert_true(TurnOptions.climb_cells(s, t).has(Vector2i(5, 0)))
