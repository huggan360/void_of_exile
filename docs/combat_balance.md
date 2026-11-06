# Realm combat balance

Updated 2026-11-04.

Each Speed point now adds 1.5% movement speed; each Dexterity point adds 2%
firing speed; each Attack point adds 1.4% weapon damage. These remain additive bonuses to
their respective base values. Base movement speed, base firing cooldown,
weapon damage ranges, stat growth and class caps are unchanged. The stat
panel and server hit validation use the same multipliers as combat.

[Burning](BURNING.md) now deals 10-15 armour-bypassing HP damage per second
to players and ordinary enemies. Bosses are immune. Fire shots ignite for
3-6 seconds, heavy shots for 10, and ground fire contact for 3.5 seconds;
water extinguishes it. Repeated burns refresh one effect instead of stacking.

Regular gods use a maximum of 80 base damage per hit, including nested ripple
and terminal projectile attacks. Ranges that previously exceeded 80 are reduced
proportionally, preserving their minimum-to-maximum relationship. Their authored
health budgets are reduced by 35%, with an upper limit of 1600 HP. The 28 current
gods now have 975-1600 HP. Both the runtime defaults and the checked-in server
configuration use these values. Server difficulty multipliers remain configurable.

Rimeheart Prism projectiles deal 30% more base damage in every phase, including
shards released by its crystal bloom orbs. Its health and non-projectile hazards
keep their existing values. Bosses are excluded from the regular god limits.

## Defence and the Realm of the Mad God reference

DECA describes defence as protection against smaller shots, while encouraging
dodging and making small parties viable through health scaling. Its Vital Combat
update also makes regeneration and defence matter together. Source:
[DECA's Vital Combat development update](https://remaster.realmofthemadgod.com/?p=728).

The balance choice here follows that direction: regular gods have shorter fights
and bounded shot damage, while the first campaign boss has more threatening
patterns. These are Void of Exile values, rather than a copy of a particular
RotMG enemy's stats.

The existing player defence calculation is retained:
`max(raw_damage * 0.15, raw_damage - defence)`. Each defence point removes one
point of ordinary damage, with a 15% minimum; armour-piercing hits bypass defence.
For example, an 80-damage god shot against 30 defence deals 50 damage; against
80 defence it deals 12. No claim is made that this floor matches current RotMG.

Restart the server after editing its balance configuration. Custom configuration
folders have their own HP overrides and difficulty multipliers.

## Character progression

The five permanent combat stats start at zero for every class. HP/MP keep their
positive class-specific starting values. Attack caps are Archer 42, Wizard 45,
Priest 32, Alchemist 40 and Merrow 45; equipment and temporary buffs are additional.
Attack elixirs now grant one point. Other stat elixir strengths are unchanged.

Class-specific random gains target about ten elixirs below each permanent cap
at level 50. Combat rolls vary more than HP/MP rolls. A character may need more
or fewer elixirs after a good or bad set of rolls. Saved stats above the new caps
are clamped when loaded; existing legal potion gains are retained.

## Developer level command

Only accounts authenticated by the server as developers can use `/lvl`.
`/lvl` sets the current character to level 50; `/lvl 25` sets its level to 25.
`/lvl PlayerName 50` changes that player's current living character, and
`/lvl PlayerName` defaults to 50. Levels outside 1-50 and dead/switching
characters are rejected. Raising levels applies the same random class growth as
earning XP, targeting roughly ten remaining elixirs at level 50, and fills
HP/MP without granting account XP. Equipment, inventory and permanent potion
gains are retained. Lowering the level keeps permanent stats; this command is
for developer testing, not a rollback of earned character progression.

`/max` caps every permanent stat, including health and magic points, and refills
vitals. It keeps the current level, equipment and inventory. `/max PlayerName`
also works for another living character; both forms require a developer account.

Player weapon projectiles now use 60% of their authored range. Both local and
remote ally shots, including charged-shot modifiers, use `Item.projectile_range()`;
tooltips display the same effective range. Enemy shots and warp-ring radii keep
their own definitions.

Character roster summaries now include saved permanent stats (`base`, `base_hp`,
`base_mp`). The picker uses the same total calculations for active and inactive characters,
showing only name/level and HP/MP on its two text rows. Restart the account service as well as game servers
when deploying this change. Old services without saved-stat summaries show
unavailable values for trained inactive characters rather than gear bonuses or
invented totals.

## Account realm spawn

The account service stores one home town per account. A steward updates it through
`POST /server/home`, guarded by the character lease and account ownership. Later
claims apply it to every existing or newly created character. A legacy account
adopts the first played character's old home once; a stale character save cannot
overwrite a newer choice. Ordinary dungeon returns still use their saved entrance
positions rather than the shared town.

## UI continuity

Character snapshot replacement publishes one final stats change, hiding the
intermediate reset state from XP meters. Identical account progress refreshes do
not restart fill tweens. The account journey uses wrapped reward tooltips, eased
horizontal scrolling, and a backdrop that consumes clicks before underlying HUD
cards. Outside clicks and Escape close it. Button press styling keeps text and
control geometry fixed.

Campaign map-shard icons retain their color texture and invalidate the outline
and glow caches when the stack count changes. Outline generation works on a copy
of the image, preserving the original colored pixels as well as its texture.

Stewards now begin with Talk and explain the account-wide choice before offering
Yes/No. Yes commits the town and closes the conversation; No closes it without a
change. The choices appear on the final speech page, and Yes becomes available
once that page is revealed.

Campaign set-home objectives count every current party member's account home.
Members who are ready see "Wait for your party to set home in [town]" with a
ready/total count. Their completed objective route disappears. The story advances
only when all current members have the required home, including after a party
membership change or a character switch. Accounts already registered there count
as ready. Confirmation is persisted before it counts toward the quest.

Shield capacity and damage-triggered breaking have been removed. Total MAG uses
one shared diminishing-returns curve for every class:
`remaining = exp(-0.020953380151240326 * MAG - 0.000029288282669119175 * MAG^2)`.
Reduction is `1 - remaining`: 0 MAG gives 0%, 20 gives 35%, 70 gives about 80%,
and 110 gives 93%. Remaining damage has a small positive numerical floor so
even extreme gear cannot grant 100% reduction; the UI never rounds it to 100%.

The shield reduces raw regular-projectile damage first, then Defence mitigates
the remainder, including its existing 15% minimum-damage rule. For example,
100 damage against a held shield at 20 MAG and 10 Defence becomes
`100 * 0.65 - 10 = 55 HP`. Armour-piercing projectiles skip the Defence step.
Burning bypasses both. Magic projectiles retain their separate complete block.
Hits never drop the shield or trigger a recovery cooldown. Holding still drains
MP, and the shield drops when released or out of MP.

Permanent base MAG caps are Merrow 55, Archer 58, Alchemist 60, Wizard 65 and
Priest 70. Gear and timed effects can push total MAG above these caps. Existing
save loading clamps permanent MAG to the new class cap; growth, /lvl, /max and
elixir limits use these same caps. The existing target of about ten elixirs
remaining after level 50 still applies. MP caps and spell-damage scaling stay
unchanged. Former shield-strength multipliers were folded into the affected
items' visible MAG bonuses, so equal total MAG always means equal protection.

Level-up gains now sample a Gaussian rather than a uniform distribution.
Each stat's mean is recalculated from its current class cap, starting value,
and actual potion strength, targeting ten potions short after the 49 level-ups
to level 50. The target accounts for the partly used final potion so the
average is about ten actual potions, rather than drifting towards eleven.
Symmetric rejection outside two standard deviations prevents
negative gains without shifting the expected mean. Stochastic rounding keeps
fractional growth unbiased. Summed integer rolls give an approximately
bell-shaped spread of final stats, with lucky and unlucky characters either
side of the target. Combat gains vary more than HP/MP gains. Regular levelling
and `/lvl` share this sampler; `/max` still fills the class-specific caps.

Short verification: 31 MAG/shield checks and 56 existing shield-combat checks
passed. These cover the shared curve, diminishing returns, class save caps,
MAG-before-Defence ordering, the minimum damage floor, no hit-based breaking,
MP depletion, Burning bypass, magic blocking and projectile/shield collisions.
Existing headless shutdown cleanup warnings remain; no full playthrough ran.
