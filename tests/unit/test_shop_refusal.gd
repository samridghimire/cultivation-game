## WU-556: the greyed Buy button says why; the character sheet identity line.
extends TestCase


func test_buy_refusal_names_the_shortfall() -> void:
	var d := data()
	var c := new_character()
	c.add_item("spirit_stone", -c.item_count("spirit_stone"))
	c.add_item("spirit_stone", 10)
	assert_eq(ShopScreen.buy_refusal(c, d, "manual_basic_breathing", 15), "Need 15 spirit stones (you have 10)")
	assert_eq(ShopScreen.buy_refusal(c, d, "manual_basic_breathing", 5), "")
	assert_eq(ShopScreen.buy_refusal(c, d, "manual_basic_breathing", 0), "That is not for sale.")


func test_identity_line_by_gender() -> void:
	var c := new_character()
	c.surname = "Lin"
	c.gender = "male"
	assert_eq(CharacterSheet.identity_line(c), "Son of the Lin family")
	c.gender = "female"
	assert_eq(CharacterSheet.identity_line(c), "Daughter of the Lin family")
	c.gender = ""
	assert_eq(CharacterSheet.identity_line(c), "Child of the Lin family")
	c.surname = ""
	assert_eq(CharacterSheet.identity_line(c), "")
