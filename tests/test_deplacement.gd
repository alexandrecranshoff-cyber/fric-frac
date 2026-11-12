extends TestCase
## Déplacement des voleurs, bruit des pas, entrée par le mur et la grille.


func test_six_points_d_action_un_par_case() -> void:
	var s := RulesFixture.without_guards(RulesFixture.game())
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(5, 2))
	assert_eq(t.ap, 6)
	var events := Movement.move(s, t, [Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2)])
	assert_eq(t.pos, Vector2i(8, 2))
	assert_eq(t.ap, 3)
	assert_eq(events[0]["path"].size(), 3)
	# Plus de points : le voleur s'arrête.
	Movement.move(s, t, [Vector2i(9, 2), Vector2i(10, 2), Vector2i(11, 2), Vector2i(12, 2)])
	assert_eq(t.pos, Vector2i(11, 2))
	assert_eq(t.ap, 0)


func test_le_bruit_des_pas_porte_aussi_loin_que_la_marche() -> void:
	# Livret : un déplacement d'une case s'entend à une case du point d'arrivée, de deux cases à deux.
	var s := RulesFixture.game()
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(5, 2))
	var events := Movement.move(s, t, [Vector2i(6, 2), Vector2i(7, 2)])
	var noise: Array = RulesFixture.events_of(events, "noise")
	assert_eq(noise.size(), 1)
	assert_eq(noise[0]["radius"], 2)
	assert_eq(noise[0]["cell"], Vector2i(7, 2))
	events = Movement.move(s, t, [Vector2i(8, 2)])
	assert_eq(RulesFixture.events_of(events, "noise")[0]["radius"], 3, "le compte court sur tout le tour")


func test_chaussures_silencieuses() -> void:
	var s := RulesFixture.game([["chaussures_silencieuses"]])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(5, 2))
	var events := Movement.move(s, t, [Vector2i(6, 2), Vector2i(7, 2)])
	assert_true(RulesFixture.events_of(events, "noise").is_empty())


func test_on_ne_traverse_ni_mur_ni_meuble() -> void:
	var s := RulesFixture.game([[]], [{"type": "fauteuil", "cases": [[16, 7]]}])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(15, 7))
	assert_eq(Movement.step_cost(s, t.pos, t.side, Vector2i(16, 7)), -1, "meuble")
	# Pièce bleue (a) contre salon au tapis rouge (b) : un mur.
	assert_eq(Movement.step_cost(s, Vector2i(7, 6), -1, Vector2i(8, 6)), -1, "mur")
	assert_eq(Movement.step_cost(s, Vector2i(5, 2), -1, Vector2i(7, 2)), -1, "cases non voisines")


func test_fenetre_avec_ou_sans_arbre() -> void:
	# Livret : les cases-fenêtres adjacentes à un arbre se franchissent comme des cases normales,
	# les autres coûtent deux points pour entrer dans la villa.
	var s := RulesFixture.game()
	assert_true(s.plan.near_tree(Vector2i(3, 6)))
	assert_eq(Movement.step_cost(s, Vector2i(2, 6), -1, Vector2i(3, 6)), 1)
	assert_false(s.plan.near_tree(Vector2i(14, 5)))
	assert_eq(Movement.step_cost(s, Vector2i(14, 4), -1, Vector2i(14, 5)), 2)


func test_balustrade_et_escalier_du_perron() -> void:
	var s := RulesFixture.game()
	# De la cour au perron : la balustrade coûte deux points, l'escalier un seul.
	assert_eq(Movement.step_cost(s, Vector2i(12, 22), -1, Vector2i(12, 21)), 2)
	assert_eq(Movement.step_cost(s, Vector2i(12, 22), -1, Vector2i(11, 21)), 1)
	assert_eq(Movement.step_cost(s, Vector2i(11, 21), -1, Vector2i(12, 21)), 1)


func test_monter_sur_le_mur_puis_sauter() -> void:
	# Livret : on pose son pion sur une case-mur ; au tour suivant, on saute dans le jardin en
	# consultant la colonne « saut » de la table de combat.
	var s := RulesFixture.game()
	var t := RulesFixture.thief(s)
	var events := Movement.climb(s, t, Vector2i(0, 1))
	assert_eq(events[0]["type"], "climb")
	assert_eq(t.pos, Vector2i(0, 1))
	assert_eq(t.ap, 0, "le tour s'arrête sur le mur")
	TurnFlow.end_turn(s)
	s.dice.force([3])
	events = Movement.jump(s, t, Vector2i(1, 1))
	assert_eq(t.pos, Vector2i(1, 1))
	assert_eq(RulesFixture.events_of(events, "landing")[0]["result"], "ok")
	assert_eq(t.stunned_turns, 0)


func test_saut_manque_deux_tours_sur_place() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.thief(s)
	Movement.climb(s, t, Vector2i(0, 1))
	TurnFlow.end_turn(s)
	s.dice.force([4])
	Movement.jump(s, t, Vector2i(1, 1))
	assert_eq(t.ap, 0)
	TurnFlow.end_turn(s)
	assert_true(t.skips_turn, "premier tour perdu")
	TurnFlow.end_turn(s)
	assert_true(t.skips_turn, "second tour perdu")
	TurnFlow.end_turn(s)
	assert_false(t.skips_turn)
	assert_eq(t.ap, 6)


func test_sortir_par_une_fenetre_sans_arbre_oblige_a_sauter() -> void:
	var s := RulesFixture.without_guards(RulesFixture.game())
	# Fenêtre nord du salon au tapis rond, déjà franchie : le voleur est du côté du jardin.
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(14, 5), s.plan.opening_side(Vector2i(14, 5), "nord_ouest"))
	t.crossed = true
	assert_eq(s.plan.half_zone(t.pos, t.side), VillaPlan.OUTSIDE)
	s.dice.force([5])
	var events := Movement.move(s, t, [Vector2i(14, 4), Vector2i(13, 4)])
	var landing := RulesFixture.events_of(events, "landing")
	assert_eq(landing.size(), 1)
	if landing.size() == 1:
		assert_eq(landing[0]["result"], "ko")
	assert_eq(t.pos, Vector2i(14, 4), "sonné à l'atterrissage, il s'arrête")
	assert_eq(t.stunned_turns, 2)


func test_sortie_par_le_mur() -> void:
	var s := RulesFixture.game([[], []])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(1, 1))
	t.loot = ["lingot_d_or"]
	assert_eq(Movement.exit_way(s, t), "")
	Movement.climb(s, t, Vector2i(0, 1))
	TurnFlow.end_turn(s)
	TurnFlow.end_turn(s)
	assert_eq(Movement.exit_way(s, t), "mur")
	var events := Movement.leave(s, t)
	assert_eq(events[0]["type"], "leave")
	assert_eq(t.status, Pawn.Status.ESCAPED)
	assert_eq(Fence.payout(s, t)["total"], 5000)
