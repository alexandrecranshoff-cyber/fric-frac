extends TestCase
## Combats (tableau 2) et dormeurs.


func _face_a_face(equipment: Array) -> GameState:
	# Le voleur dans le hall, juste à l'est du garde A.
	var s := RulesFixture.game([equipment])
	RulesFixture.put(RulesFixture.thief(s), Vector2i(14, 12))
	return s


func test_assommer_un_garde_a_la_matraque() -> void:
	var s := _face_a_face(["matraque"])
	var t := RulesFixture.thief(s)
	var a := RulesFixture.guard(s, "A")
	s.dice.force([4])
	var events := Combat.attack(s, t, a, "matraque")
	assert_eq(RulesFixture.events_of(events, "strike")[0]["result"], "ko")
	assert_eq(a.status, Pawn.Status.KO)
	assert_true(t.has_knocked_out)
	assert_eq(t.ap, 4, "une attaque coûte deux points")
	assert_true(Combat.attack(s, t, a, "matraque").is_empty(), "une attaque par tour")


func test_un_garde_assomme_se_releve_apres_deux_tours_de_l_attaquant() -> void:
	# Sans le garde B, qui sinon accourrait du bout du hall.
	var s := RulesFixture.without_guards(_face_a_face(["matraque"]), ["B"])
	var t := RulesFixture.thief(s)
	var a := RulesFixture.guard(s, "A")
	s.dice.force([4])
	Combat.attack(s, t, a, "matraque")
	TurnFlow.end_turn(s)
	assert_eq(a.status, Pawn.Status.KO, "fin du tour de l'attaque")
	TurnFlow.end_turn(s)
	assert_eq(a.status, Pawn.Status.KO, "un tour entier")
	var events := TurnFlow.end_turn(s)
	assert_eq(a.status, Pawn.Status.ACTIVE, "deux tours entiers")
	assert_false(RulesFixture.events_of(events, "recovers").is_empty())
	assert_true(s.alarm, "revenu à lui, il donne l'alarme")


func test_le_garde_riposte_au_revolver() -> void:
	var s := _face_a_face([])
	var t := RulesFixture.thief(s)
	var a := RulesFixture.guard(s, "A")
	# Main nue : 2, le garde est indemne. Il tire : 4, le voleur est tué. Le coup de feu donne l'alarme.
	s.dice.force([2, 4])
	var events := Combat.attack(s, t, a, "main_nue")
	var strikes := RulesFixture.events_of(events, "strike")
	assert_eq(strikes.size(), 2)
	assert_eq(strikes[1]["mode"], "revolver")
	assert_eq(t.status, Pawn.Status.DEAD)
	assert_true(s.alarm)


func test_le_pare_balles_retire_des_points_au_de() -> void:
	var s := _face_a_face(["pare_balles_2"])
	var t := RulesFixture.thief(s)
	var a := RulesFixture.guard(s, "A")
	# Le garde tire un 6 ; le pare-balles 2 le ramène à 4 : tué quand même. Puis un 3 : ramené
	# à 1, sous le dé minimal, lu comme 1 : KO au revolver.
	s.dice.force([1, 6])
	Combat.attack(s, t, a, "main_nue")
	assert_eq(t.status, Pawn.Status.DEAD)
	var s2 := _face_a_face(["pare_balles_2"])
	var t2 := RulesFixture.thief(s2)
	s2.dice.force([1, 3])
	var events := Combat.attack(s2, t2, RulesFixture.guard(s2, "A"), "main_nue")
	assert_eq(RulesFixture.events_of(events, "strike")[1]["value"], 1)
	assert_eq(t2.status, Pawn.Status.KO)


func test_couteau_lance_a_distance() -> void:
	# Chaque case qui sépare les adversaires enlève un point au dé.
	var s := RulesFixture.game([["couteau"]])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(16, 12))
	var a := RulesFixture.guard(s, "A")
	assert_false(Combat.can_strike(s, t, a, "couteau"), "au contact seulement")
	assert_true(Combat.can_strike(s, t, a, "couteau_lance"))
	s.dice.force([6, 1])
	var events := Combat.attack(s, t, a, "couteau_lance")
	var strike: Dictionary = RulesFixture.events_of(events, "strike")[0]
	assert_eq(strike["gap"], 2)
	assert_eq(strike["value"], 4)
	assert_eq(strike["result"], "ko")


func test_pas_de_combat_a_travers_un_mur() -> void:
	var s := RulesFixture.game([["revolver"]])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(17, 12))
	assert_false(Combat.can_strike(s, t, RulesFixture.guard(s, "A"), "revolver"))


func test_entre_voleurs_le_vainqueur_prend_le_butin() -> void:
	var s := RulesFixture.without_guards(RulesFixture.game([["matraque"], []]))
	var t1 := RulesFixture.put(RulesFixture.thief(s, 0), Vector2i(5, 2))
	var t2 := RulesFixture.put(RulesFixture.thief(s, 1), Vector2i(6, 2))
	t2.loot = ["bague", "portefeuille"]
	# 1 : indemne ; riposte à main nue, 2 : indemne ; 5 : KO.
	s.dice.force([1, 2, 5])
	Combat.attack(s, t1, t2, "matraque")
	assert_eq(t2.status, Pawn.Status.KO)
	assert_eq(t1.loot, ["bague", "portefeuille"])
	assert_eq(t2.loot, [])
	assert_false(t1.has_knocked_out, "assommer un rival ne déprécie pas le butin")


func test_dormeur_ok_donne_l_alarme() -> void:
	# Livret : sur un OK, le dormeur ne combat pas mais donne immédiatement l'alarme.
	var s := RulesFixture.game([["matraque"]], [{"type": "lit", "cases": [[17, 7], [18, 7]]}])
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(15, 7))
	Movement.move(s, t, [Vector2i(16, 7)])
	var sleeper := s.sleepers()[0]
	s.dice.force([1])
	Combat.attack(s, t, sleeper, "matraque")
	assert_true(s.alarm)
	assert_true(sleeper.awake)


func test_dormeur_reveille_par_le_bruit() -> void:
	# Livret : le dormeur se réveille si la case de sa tête est dans une zone de bruit.
	var s := RulesFixture.without_guards(RulesFixture.game([[]], [{"type": "lit", "cases": [[17, 7], [18, 7]]}]))
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(14, 7))
	Movement.move(s, t, [Vector2i(15, 7), Vector2i(16, 7)])
	# Deux cases de marche, bruit à deux cases depuis (16, 7) : la tête du lit est à une case.
	assert_true(s.sleepers()[0].awake)
	assert_true(s.alarm)


func test_dormeur_ne_reveille_pas_un_lit_encore_cache() -> void:
	var s := RulesFixture.without_guards(RulesFixture.game([[]], [{"type": "lit", "cases": [[19, 7], [19, 8]]}]))
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(13, 7))
	Movement.move(s, t, [Vector2i(14, 7), Vector2i(15, 7), Vector2i(16, 7)])
	assert_false(s.get_furniture(1).revealed)
	assert_false(s.alarm)
