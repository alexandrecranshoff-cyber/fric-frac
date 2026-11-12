extends TestCase
## Les gardes : ronde au dé, alarme, poursuite, arrestation.


func _ronde(die: int) -> GameState:
	var s := RulesFixture.game()
	s.dice.force([die])
	Guards.start_ronde(s, [])
	return s


func test_ronde_en_ligne_droite_jusqu_a_l_obstacle() -> void:
	# Dé 3 : le garde A part vers l'est, à travers le hall, jusqu'au mur de la grande pièce blanche.
	var s := _ronde(3)
	var a := RulesFixture.guard(s, "A")
	assert_eq(a.heading, "est")
	var events := []
	for i in 3:
		Guards.step(s, a, events)
	assert_eq(a.pos, Vector2i(16, 12))
	assert_true(RulesFixture.events_of(events, "guard_turn").is_empty())
	# Mur devant lui : on relance le dé (6, l'ouest, est libre).
	s.dice.force([6])
	Guards.step(s, a, events)
	assert_eq(a.heading, "ouest")
	assert_eq(a.pos, Vector2i(15, 12))


func test_on_relance_jusqu_a_une_direction_libre() -> void:
	var s := _ronde(3)
	var a := RulesFixture.guard(s, "A")
	for i in 3:
		Guards.step(s, a, [])
	# 3 : toujours le mur ; 2 : le mur du salon au tapis rond ; 1 : la porte de ce salon, libre.
	s.dice.force([3, 2, 1])
	var events := []
	Guards.step(s, a, events)
	assert_eq(RulesFixture.events_of(events, "guard_turn").size(), 3)
	assert_eq(a.heading, "nord_ouest")
	assert_eq(a.pos, Vector2i(15, 11), "les portes intérieures ne l'arrêtent pas")


func test_ni_fenetre_ni_porte_exterieure_en_ronde() -> void:
	var s := RulesFixture.game()
	# Porte intérieure du hall vers le salon au tapis rouge : libre. Porte d'entrée : obstacle.
	assert_true(Guards.can_walk(s, Vector2i(12, 11), Vector2i(12, 10), false))
	assert_false(Guards.can_walk(s, Vector2i(12, 19), Vector2i(12, 20), false))
	assert_true(Guards.can_walk(s, Vector2i(12, 19), Vector2i(12, 20), true), "en poursuite, il sort")
	assert_false(Guards.can_walk(s, Vector2i(15, 6), Vector2i(14, 5), true), "jamais par une fenêtre")


func test_l_alarme_double_le_pas_et_mene_au_plus_court() -> void:
	var s := RulesFixture.game()
	var a := RulesFixture.guard(s, "A")
	NoiseRules.alarm(s, Vector2i(13, 15), [])
	Guards.house_phase(s, 1, [])
	assert_eq(Hex.distance(a.pos, Vector2i(13, 15)), 1, "deux cases d'un coup, en ligne droite dans le hall")


func test_arrive_sur_les_lieux_il_reprend_sa_ronde() -> void:
	var s := RulesFixture.game()
	var a := RulesFixture.guard(s, "A")
	NoiseRules.alarm(s, Vector2i(14, 12), [])
	s.dice.force([6])
	Guards.step(s, a, [])
	assert_eq(a.pos, Vector2i(14, 12))
	assert_eq(a.target, Pawn.NO_CELL)
	assert_true(a.alerted, "il reste en alerte jusqu'à la fin")


func test_une_nouvelle_alarme_le_detourne() -> void:
	var s := RulesFixture.game()
	var a := RulesFixture.guard(s, "A")
	NoiseRules.alarm(s, Vector2i(13, 15), [])
	NoiseRules.alarm(s, Vector2i(16, 12), [])
	assert_eq(a.target, Vector2i(16, 12))


func test_meme_piece_poursuite_puis_arrestation() -> void:
	# Livret : un garde dans la même pièce qu'un voleur le poursuit jusqu'à son arrestation.
	var s := RulesFixture.game()
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(16, 12))
	t.loot = ["bague"]
	var a := RulesFixture.guard(s, "A")
	Guards.update_sight(s, [])
	assert_true(t.seen)
	assert_eq(a.chase_id, t.id)
	var events := []
	Guards.house_phase(s, 2, events)
	assert_eq(t.status, Pawn.Status.ARRESTED)
	assert_eq(t.loot, [], "le butin d'un voleur arrêté est perdu")
	assert_eq(RulesFixture.events_of(events, "arrest")[0]["guard"], a.id)


func test_pas_vu_derriere_un_mur() -> void:
	var s := RulesFixture.game()
	# Grande pièce blanche, juste derrière le mur est du hall.
	var t := RulesFixture.put(RulesFixture.thief(s), Vector2i(17, 12))
	Guards.update_sight(s, [])
	assert_false(t.seen)


func test_vingt_deux_les_gardes_avancent_de_trois_cases() -> void:
	var s := _ronde(3)
	Guards.advance(s, 3, [])
	assert_eq(RulesFixture.guard(s, "A").pos, Vector2i(16, 12))


func test_un_cadavre_donne_l_alarme() -> void:
	var s := RulesFixture.game()
	var body := RulesFixture.put(RulesFixture.thief(s), Vector2i(15, 13))
	body.status = Pawn.Status.DEAD
	Guards.update_sight(s, [])
	assert_true(s.alarm)
	assert_true(body.found)
