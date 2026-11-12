extends TestCase
## Meubles découverts, forcés et fouillés (tableau 3).


func _salon(type: String) -> GameState:
	# Un meuble au milieu du salon au tapis rond, le voleur deux cases plus à l'ouest.
	var s := RulesFixture.without_guards(RulesFixture.game([[]], [{"type": type, "cases": [[17, 7]]}]))
	RulesFixture.put(RulesFixture.thief(s), Vector2i(15, 7))
	return s


func test_un_meuble_se_devoile_quand_on_passe_a_cote() -> void:
	var s := _salon("secretaire")
	var t := RulesFixture.thief(s)
	var f := s.furniture[0]
	assert_false(f.revealed)
	var events := Movement.move(s, t, [Vector2i(16, 7), Vector2i(16, 8)])
	assert_true(f.revealed)
	assert_eq(t.pos, Vector2i(16, 7), "le voleur s'arrête pour choisir")
	assert_eq(RulesFixture.events_of(events, "reveal")[0]["kind"], "secretaire")


func test_s_eloigner_d_un_meuble_le_vide() -> void:
	# Livret : dès que le pion qui a découvert un meuble s'en éloigne, il est considéré comme vide.
	var s := _salon("coffre_fort")
	var t := RulesFixture.thief(s)
	var f := s.furniture[0]
	Movement.move(s, t, [Vector2i(16, 7)])
	assert_false(f.emptied)
	Movement.move(s, t, [Vector2i(15, 7)])
	assert_true(f.emptied)
	assert_true(BreakIn.work(s, t, {"furniture": f.id}, 1).is_empty())


func test_coffre_fort_trois_tirages() -> void:
	var s := _salon("coffre_fort")
	var t := RulesFixture.thief(s)
	var f := s.furniture[0]
	Movement.move(s, t, [Vector2i(16, 7)])
	BreakIn.work(s, t, {"furniture": f.id}, 5)
	# Tirages : 66 rivière de diamants, 34 portefeuille, 12 rien.
	s.dice.force([6, 6, 3, 4, 1, 2])
	var events := BreakIn.open(s, t, {"furniture": f.id})
	# Coffre-fort, 5 tours : bruit à 3 cases.
	assert_eq(events[0]["noise"], 3)
	assert_eq(RulesFixture.events_of(events, "loot").size(), 3)
	assert_eq(t.loot, ["riviere_de_diamants", "portefeuille"])
	assert_true(f.emptied, "un meuble se fouille une fois")


func test_un_tirage_par_secretaire_deux_par_armoire() -> void:
	for pair in [["secretaire", 1], ["armoire", 2]]:
		var s := _salon(pair[0])
		var t := RulesFixture.thief(s)
		Movement.move(s, t, [Vector2i(16, 7)])
		BreakIn.work(s, t, {"furniture": 1}, 5)
		s.dice.force([4, 1, 4, 2])
		var events := BreakIn.open(s, t, {"furniture": 1})
		assert_eq(RulesFixture.events_of(events, "loot").size(), pair[1], pair[0])


func test_rien_a_forcer_dans_un_fauteuil() -> void:
	var s := _salon("fauteuil")
	var t := RulesFixture.thief(s)
	Movement.move(s, t, [Vector2i(16, 7)])
	assert_true(s.furniture[0].revealed)
	assert_true(BreakIn.work(s, t, {"furniture": 1}, 1).is_empty())


func test_gaz_etourdissant() -> void:
	var s := _salon("secretaire")
	var t := RulesFixture.thief(s)
	Movement.move(s, t, [Vector2i(16, 7)])
	BreakIn.work(s, t, {"furniture": 1}, 3)
	s.dice.force([1, 3])
	BreakIn.open(s, t, {"furniture": 1})
	assert_eq(t.ap, 0)
	TurnFlow.end_turn(s)
	assert_true(t.skips_turn)
	TurnFlow.end_turn(s)
	assert_true(t.skips_turn)
	TurnFlow.end_turn(s)
	assert_false(t.skips_turn)


func test_signal_d_alarme_et_bruits_du_meuble() -> void:
	var s := RulesFixture.game([[]], [{"type": "secretaire", "cases": [[17, 7]]}])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(15, 7))
	Movement.move(s, t, [Vector2i(16, 7)])
	BreakIn.work(s, t, {"furniture": 1}, 4)
	# 33 : signal d'alarme, trois dés (5 + 5 + 6 = 16 cases) : le garde A l'entend.
	s.dice.force([3, 3, 5, 5, 6])
	var events := BreakIn.open(s, t, {"furniture": 1})
	assert_eq(RulesFixture.events_of(events, "alarm_bell")[0]["roll"]["total"], 16)
	assert_true(s.alarm)
	assert_eq(RulesFixture.guard(s, "A").target, Vector2i(17, 7))


func test_passage_secret() -> void:
	var s := _salon("secretaire")
	var t := RulesFixture.thief(s)
	Movement.move(s, t, [Vector2i(16, 7)])
	BreakIn.work(s, t, {"furniture": 1}, 3)
	s.dice.force([3, 2])
	BreakIn.open(s, t, {"furniture": 1})
	assert_eq(t.secret_passages, [1])
	TurnFlow.end_turn(s)
	assert_eq(Movement.exit_way(s, t), "passage")
	Movement.leave(s, t)
	assert_eq(t.status, Pawn.Status.ESCAPED)
