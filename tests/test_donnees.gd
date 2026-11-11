extends TestCase
## Les tables du livret, telles qu'elles sont saisies dans data/.


func test_effraction_tableau_1() -> void:
	var d := GameData.load_default()
	var table: Dictionary = d.effraction["portee_bruit"]
	assert_eq(table.size(), 7)
	for kind in table:
		var row: Array = table[kind]
		assert_eq(row.size(), 8, kind)
		for i in range(1, row.size()):
			assert_true(row[i] <= row[i - 1], kind + " : le bruit ne remonte jamais avec le temps")
	# Quelques cases du tableau.
	assert_eq(d.break_in_noise("grille", 1), 6)
	assert_eq(d.break_in_noise("porte_exterieure", 4), 1)
	assert_eq(d.break_in_noise("fenetre", 1), 1)
	assert_eq(d.break_in_noise("fenetre", 2), 0)
	assert_eq(d.break_in_noise("porte_interieure", 2), 1)
	assert_eq(d.break_in_noise("secretaire", 3), 1)
	assert_eq(d.break_in_noise("armoire", 5), 1)
	assert_eq(d.break_in_noise("coffre_fort", 1), 7)
	assert_eq(d.break_in_noise("coffre_fort", 7), 1)
	assert_eq(d.break_in_noise("coffre_fort", 8), 0)


func test_combat_tableau_2() -> void:
	var d := GameData.load_default()
	var expected := {
		"saut": "ok ok ok ko ko ko",
		"main_nue": "ok ok ok ko ko ko",
		"matraque": "ok ok ko ko ko tue",
		"couteau": "ok ko ko ko tue tue",
		"revolver": "ko ko ko tue tue tue",
	}
	assert_eq(d.combat["resultats"].size(), 5)
	for kind in expected:
		var got: Array[String] = []
		for die in range(1, 7):
			got.append(d.combat_result(kind, die))
		assert_eq(" ".join(got), expected[kind], kind)
	# Un dé ramené sous 1 par la distance ou le pare-balles se lit comme un 1.
	assert_eq(d.combat_result("revolver", -1), "ko")
	assert_eq(d.combat_result("couteau", 0), "ok")


func test_butin_tableau_3() -> void:
	var d := GameData.load_default()
	var table: Dictionary = d.butin["table"]
	assert_eq(table.size(), 36)
	var count := {}
	for tens in range(1, 7):
		for units in range(1, 7):
			var e := d.loot_entry(tens * 10 + units)
			var key: String = e["effet"]
			if key == "butin":
				key = e["objet"]
				assert_true(d.butin["objets"].has(key), key)
			count[key] = int(count.get(key, 0)) + 1
	assert_eq(count["rien"], 7)
	assert_eq(count["alarme"], 2)
	assert_eq(count["bruit"], 3)
	assert_eq(count["portefeuille"], 3)
	assert_eq(count["pieces_d_or"], 3)
	assert_eq(count["lingot_d_or"], 3)
	assert_eq(count["lettre_compromettante"], 3)
	assert_eq(count["portefeuille_d_actions"], 3)
	assert_eq(count["dossier_secret"], 3)
	assert_eq(d.loot_entry(22)["effet"], "gardes")
	assert_eq(d.loot_entry(32)["effet"], "passage_secret")
	assert_eq(d.loot_entry(13)["effet"], "gaz")
	assert_eq(d.loot_entry(44)["objet"], "bague")
	assert_eq(d.loot_entry(55)["objet"], "collier_de_perles")
	assert_eq(d.loot_entry(66)["objet"], "riviere_de_diamants")
	assert_eq(int(d.butin["objets"]["riviere_de_diamants"]["valeur"]), 500000)
	assert_eq(int(d.butin["objets"]["bague"]["valeur"]), 100000)
	assert_eq(int(d.butin["receleur"]["diviseur"]["a_assomme"]), 5)
	assert_eq(int(d.butin["receleur"]["diviseur"]["a_tue"]), 10)


func test_equipement_trois_points() -> void:
	var d := GameData.load_default()
	var o: Dictionary = d.equipement["objets"]
	assert_eq(int(d.equipement["points"]), 3)
	assert_eq(int(o["passe_partout_1"]["cout"]), 2)
	assert_eq(int(o["passe_partout_2"]["cout"]), 3)
	assert_eq(int(o["chaussures_silencieuses"]["cout"]), 1)
	assert_eq(int(o["pare_balles_1"]["cout"]), 1)
	assert_eq(int(o["pare_balles_2"]["cout"]), 2)
	assert_eq(int(o["matraque"]["cout"]), 1)
	assert_eq(int(o["couteau"]["cout"]), 2)
	assert_eq(int(o["revolver"]["cout"]), 3)


func test_mobilier_36_pions() -> void:
	var d := GameData.load_default()
	var total := 0
	for kind in d.mobilier["types"]:
		total += int(d.mobilier["types"][kind]["nombre"])
	assert_eq(total, 36)
	assert_eq(total, int(d.mobilier["total"]))
	# Les meubles à butin de la table 3 existent bien comme pions et comme lignes de la table 1.
	for kind in d.butin["tirages_par_meuble"]:
		assert_true(d.mobilier["types"][kind]["butin"], kind)
		assert_true(d.effraction["portee_bruit"].has(kind), kind)
