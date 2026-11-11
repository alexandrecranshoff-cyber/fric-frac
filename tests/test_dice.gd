extends TestCase


func test_meme_graine_meme_suite() -> void:
	var a := DiceRoller.new(42)
	var b := DiceRoller.new(42)
	for i in 20:
		assert_eq(a.d6(), b.d6())


func test_faces_entre_1_et_6() -> void:
	var d := DiceRoller.new(7)
	for i in 500:
		var f := d.d6()
		assert_true(f >= 1 and f <= 6, str(f))


func test_des_imposes_et_bonus() -> void:
	var d := DiceRoller.new()
	d.force([6, 2])
	var r := d.roll(2, 3, "test")
	assert_eq(r["total"], 11)
	assert_eq(d.history.size(), 1)


func test_d66_dizaines_puis_unites() -> void:
	# Livret, butin : « le premier indique les dizaines, le second les unités ».
	var d := DiceRoller.new()
	d.force([4, 4])
	assert_eq(d.d66("butin")["total"], 44)
	d.force([6, 1])
	assert_eq(d.d66()["total"], 61)


func test_reprise_meme_suite() -> void:
	var a := DiceRoller.new(9)
	a.d6()
	var b := DiceRoller.new()
	b.restore(a.rng_seed(), a.rng_state())
	assert_eq(a.d6(), b.d6())
