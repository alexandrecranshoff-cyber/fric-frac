extends TestCase
## Effraction (tableau 1) : le temps contre le bruit. Un point d'action vaut un tour sur place.


func test_forcer_la_grille_d_un_coup_s_entend_jusqu_au_garde_b() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.thief(s)
	Movement.approach_gate(s, t, Vector2i(13, 24))
	BreakIn.work(s, t, {"cell": Vector2i(13, 24)}, 1)
	var events := BreakIn.open(s, t, {"cell": Vector2i(13, 24)})
	# Tableau 1, grille, 1 tour : 6 cases. Le garde B est à 6 cases.
	assert_eq(events[0]["noise"], 6)
	assert_eq(Hex.distance(Vector2i(13, 24), RulesFixture.guard(s, "B").pos), 6)
	assert_true(s.alarm)
	assert_true(RulesFixture.guard(s, "B").alerted)
	assert_eq(t.side, 1, "le voleur est passé du côté de la cour")


func test_les_points_s_ajoutent_d_un_tour_a_l_autre() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.thief(s)
	Movement.approach_gate(s, t, Vector2i(13, 24))
	BreakIn.work(s, t, {"cell": Vector2i(13, 24)}, 5)
	assert_eq(BreakIn.noise_preview(s, t, {"cell": Vector2i(13, 24)}), 2)
	TurnFlow.end_turn(s)
	BreakIn.work(s, t, {"cell": Vector2i(13, 24)}, 2)
	assert_eq(t.work_points, 7)
	var events := BreakIn.open(s, t, {"cell": Vector2i(13, 24)})
	assert_eq(events[0]["column"], 7)
	assert_eq(events[0]["noise"], 0)
	assert_false(s.alarm)
	# Le voleur passe dans la cour avec ses derniers points.
	Movement.move(s, t, [Vector2i(13, 23)])
	assert_eq(t.pos, Vector2i(13, 23))


func test_passe_partout() -> void:
	# Lecture retenue : le passe-partout « 2 tours » fait lire le tableau deux colonnes plus loin.
	var s := RulesFixture.game([["passe_partout_2"]])
	var t := RulesFixture.thief(s)
	Movement.approach_gate(s, t, Vector2i(13, 24))
	assert_eq(BreakIn.noise_preview(s, t, {"cell": Vector2i(13, 24)}, 1), 4, "grille, colonne 3")
	assert_eq(BreakIn.noise_preview(s, t, {"cell": Vector2i(13, 24)}, 4), 1, "grille, colonne 6")


func test_porte_d_entree_et_debut_de_la_ronde() -> void:
	# Livret : dès qu'un voleur entre dans la villa, les gardes commencent leur ronde.
	var s := RulesFixture.game()
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(12, 21))
	Movement.move(s, t, [Vector2i(12, 20)])
	assert_eq(t.pos, Vector2i(12, 20))
	assert_eq(s.plan.half_zone(t.pos, t.side), VillaPlan.OUTSIDE)
	assert_false(s.ronde_started)
	BreakIn.work(s, t, {"cell": Vector2i(12, 20)}, 4)
	s.dice.force([2])
	var events := BreakIn.open(s, t, {"cell": Vector2i(12, 20)})
	# Porte extérieure, 4 tours : 1 case.
	assert_eq(events[0]["noise"], 1)
	assert_eq(s.plan.half_zone(t.pos, t.side), "h")
	assert_true(s.ronde_started)
	assert_eq(RulesFixture.guard(s, "A").heading, "nord_est", "dé 2 : direction 2 du garde A")
	assert_eq(RulesFixture.guard(s, "B").heading, "sud_ouest", "dé 2 : direction 2 du garde B")
	# Le garde B est dans le hall : il voit le voleur et le poursuit.
	assert_true(t.seen)
	assert_eq(RulesFixture.guard(s, "B").chase_id, t.id)


func test_on_ne_force_que_la_porte_ou_l_on_se_tient() -> void:
	var s := RulesFixture.game()
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(12, 21))
	assert_true(BreakIn.work(s, t, {"cell": Vector2i(12, 20)}, 1).is_empty())
	assert_true(BreakIn.work(s, t, {"cell": Vector2i(12, 21)}, 1).is_empty(), "pas d'obstacle sur le perron")


func test_l_effraction_est_a_refaire() -> void:
	# Livret : l'effraction est à refaire même si l'obstacle a déjà été franchi.
	var s := RulesFixture.without_guards(RulesFixture.game())
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(12, 21))
	Movement.move(s, t, [Vector2i(12, 20)])
	BreakIn.work(s, t, {"cell": Vector2i(12, 20)}, 3)
	BreakIn.open(s, t, {"cell": Vector2i(12, 20)})
	Movement.move(s, t, [Vector2i(12, 19)])
	assert_eq(t.pos, Vector2i(12, 19))
	# Retour sur la porte, côté hall : on ne repasse pas sans la forcer à nouveau.
	TurnFlow.end_turn(s)
	Movement.move(s, t, [Vector2i(12, 20)])
	assert_eq(Movement.step_cost(s, t.pos, t.side, Vector2i(12, 21)), -1)
