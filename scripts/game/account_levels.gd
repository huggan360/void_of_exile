class_name AccountLevels
## The account level curve, the same as the account service's
## (account_service/void_accounts.py xp_to_next): every character's XP also
## counts for its account, and so does part of what a dead character earned
## and carried.

const MAX_LEVEL := 100


static func xp_to_next(level: int) -> int:
	return 600 + 400 * (level - 1)


## {level, into (XP into this level), needed (for the next)} for total XP.
static func progress(total_xp: int) -> Dictionary:
	var level := 1
	var left := total_xp
	while level < MAX_LEVEL and left >= xp_to_next(level):
		left -= xp_to_next(level)
		level += 1
	return {xp = total_xp, level = level, into = left, needed = xp_to_next(level)}
