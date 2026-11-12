extends TestCase
## Enchaînement des tours, receleur, horloge, brouillard et rejeu.


func test_receleur_argent_entier_le_reste_divise() -> void:
	var s := RulesFixture.game([[], [], []])
	var loot := ["riviere_de_diamants", "lingot_d_or", "portefeuille"]
	for t in s.thieves():
		t.loot = loot.duplicate()
		t.status = Pawn.Status.ESCAPED
	s.thieves()[1].has_knocked_out = true
	s.thieves()[2].has_knocked_out = true
	s.thieves()[2].has_killed = true
	# Argent : 5 000 + 1 000. Rivière : 500 000, divisée par 5 ou par 10.
	assert_eq(Fence.payout(s, s.thieves()[0])["total"], 506000)
	assert_eq(Fence.payout(s, s.thieves()[1])["total"], 106000)
	assert_eq(Fence.payout(s, s.thieves()[2])["total"], 56000)
	assert_eq(Fence.ranking(s)[0]["id"], s.thieves()[0].id)


func test_un_voleur_arrete_ne_touche_rien() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.thief(s)
	t.loot = ["bague"]
	t.status = Pawn.Status.ARRESTED
	assert_eq(Fence.payout(s, t)["total"], 0)


func test_les_gardes_font_six_cases_par_tour_de_table() -> void:
	# Trois voleurs : deux cases de garde après chacun. En alerte : quatre.
	var s := RulesFixture.game([[], [], []])
	s.dice.force([3])
	Guards.start_ronde(s, [])
	var a := RulesFixture.guard(s, "A")
	TurnFlow.end_turn(s)
	assert_eq(a.pos, Vector2i(15, 12))
	s.dice.force([6])
	TurnFlow.end_turn(s)
	assert_eq(a.pos, Vector2i(15, 12), "un pas vers l'est, puis demi-tour vers l'ouest")
	var s2 := RulesFixture.game([[], [], []])
	NoiseRules.alarm(s2, Vector2i(16, 14), [])
	TurnFlow.end_turn(s2)
	assert_eq(RulesFixture.guard(s2, "A").pos, Vector2i(16, 14), "quatre cases en alerte")


func test_tour_de_role() -> void:
	var s := RulesFixture.game([[], []])
	var first := s.current_thief()
	TurnFlow.end_turn(s)
	assert_true(s.current_thief() != first)
	TurnFlow.end_turn(s)
	assert_eq(s.current_thief(), first)
	assert_eq(s.table_round, 2)


func test_lever_du_jour() -> void:
	var s := RulesFixture.game([[], []], [], 2)
	var inside := RulesFixture.put(RulesFixture.thief(s, 0), Vector2i(2, 2))
	var street := RulesFixture.thief(s, 1)
	for i in 4:
		TurnFlow.end_turn(s)
	assert_true(s.over)
	assert_eq(inside.status, Pawn.Status.ARRESTED)
	assert_eq(street.status, Pawn.Status.ESCAPED, "resté dans la rue, il rentre bredouille")


func test_brouillard_on_ne_voit_que_sa_piece() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(17, 12))
	var seen := Visibility.pawns_seen(s, [t])
	assert_false(seen.has(RulesFixture.guard(s, "A")), "le garde A est derrière le mur, dans le hall")
	# Sur une porte, on voit les deux pièces.
	RulesFixture.put(t, Vector2i(14, 17), 0)
	seen = Visibility.pawns_seen(s, [t])
	assert_true(seen.has(RulesFixture.guard(s, "B")))


func test_on_entend_un_garde_qui_marche_hors_de_vue() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(17, 12))
	var a := RulesFixture.guard(s, "A")
	a.moved_last_phase = true
	var heard := Visibility.guards_heard(s, [t])
	assert_eq(heard.size(), 1)
	assert_eq(heard[0]["id"], a.id)
	RulesFixture.put(t, Vector2i(22, 2))
	assert_true(Visibility.guards_heard(s, [t]).is_empty(), "trop loin")


func _play(state: GameState) -> void:
	for command in [
		{"type": "gate", "cell": [13, 24]},
		{"type": "work", "target": {"cell": [13, 24]}, "points": 5},
		{"type": "end_turn"},
		{"type": "climb", "cell": [0, 5]},
		{"type": "end_turn"},
		{"type": "work", "target": {"cell": [13, 24]}, "points": 3},
		{"type": "open", "target": {"cell": [13, 24]}},
		{"type": "move", "path": [[13, 23], [13, 22]]},
		{"type": "end_turn"},
		{"type": "jump", "cell": [1, 5]},
		{"type": "move", "path": [[2, 5], [2, 6]]},
		{"type": "end_turn"},
	]:
		GameActions.apply(state, command)


func test_rejouer_une_partie_a_l_identique() -> void:
	var data := GameData.load_default()
	var config := GameSetup.solo_config(data)
	config["voleurs"] = config["voleurs"].slice(0, 2)
	var state := GameSetup.new_game(data, 2026, config)
	TurnFlow.start_game(state)
	_play(state)
	assert_true(state.commands.size() >= 10, "%d gestes acceptés" % state.commands.size())
	assert_eq(state.thieves()[0].pos, Vector2i(13, 22))
	var saved := SaveGame.to_json(state)
	var again := SaveGame.from_json(data, saved)
	assert_eq(again.snapshot(), state.snapshot())
	# Arrêté au cinquième geste : le film du casse peut se rembobiner.
	var halfway := SaveGame.from_dict(data, JSON.parse_string(saved), 5)
	assert_eq(halfway.commands.size(), 5)


func test_casse_en_solo() -> void:
	var data := GameData.load_default()
	var state := GameSetup.new_game(data, 9, GameSetup.solo_config(data))
	assert_eq(state.thieves().size(), 3)
	assert_eq(state.max_rounds, 24)
	TurnFlow.start_game(state)
	for i in 3 * 24:
		GameActions.apply(state, {"type": "end_turn"})
	assert_true(state.over)
	assert_eq(Fence.band_score(state)["total"], 0)
