class_name Dots
## Dots: the account-wide currency (green dots by the account bar). Earned
## by dismantling items at the forge, the first time an account finishes a
## campaign, and from campaign packs. The account service keeps the count
## and pays dismantling with the same table (DISMANTLE_DOTS in
## void_of_exile_account repo, server/void_accounts.py): keep both in step.

const COLOR := Color(0.36, 0.95, 0.45)
const COLOR_DARK := Color(0.1, 0.45, 0.18)
## By grade (index = tier, G1..G8), and Divine.
const GRADE := [0, 10, 25, 45, 75, 120, 250, 450, 650]
const DIVINE := 1200
const CAMPAIGN_FIRST := 250
const PACK_FIRST := 1000


## Dots for dismantling `item` (0 = it can't be dismantled).
static func dismantle_value(item: Item) -> int:
	if item == null or item.is_story() or item.is_key():
		return 0
	var count := maxi(1, item.count)
	if item.id.begins_with("D_"):
		return DIVINE * count
	if item.id.length() > 2 and item.id[0] == "G" and item.id[1].is_valid_int():
		return int(GRADE[clampi(int(item.id[1]), 1, 8)]) * count
	if item.id.begins_with("elixir_of_"):
		return 40 * count
	if item.id == "backpack":
		return 20 * count
	return 0


static func format(amount: int) -> String:
	var text := str(absi(amount))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if amount < 0 else "") + text + out
