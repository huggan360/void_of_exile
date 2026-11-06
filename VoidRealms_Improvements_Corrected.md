# VoidRealms Improvements

1. ✅ **Names above characters:** The names above characters' heads scale strangely with the camera zoom. Make them behave exactly like the buff indicators. The name should sit right below the buffs or the quest marker.

2. ✅ **Campaign conversations:** Some conversations don't happen properly. For example, I walk up to Gerald, click the interact button, and immediately get sent away. When interacting with an NPC, the first card should only display the NPC's name, a quest symbol if the NPC has a quest, and a button that says **Talk**. Only after clicking **Talk** should the camera zoom in and the conversation begin.

3. ✅ **Camera during NPC interactions:** Fix the camera view during conversations with NPCs or similar interactions. Sometimes a building or another object blocks the camera, so all I can see is the building instead of my character and the NPC.

4. ✅ **Server-controlled NPCs:** NPCs should also be controlled by the server. Right now, they are unique to each client, which feels wrong, especially when players can interact with them during quests.

5. ✅ **Missing campaign chests:** Sometimes story chests don't spawn. For example, in Goblins Cave, the chest didn't appear, so I couldn't get the necklace and was left stranded in the campaign.

6. ✅ **Quest markers across worlds:** Quest markers should always show me where I need to go, even when I'm not in the correct world. For example, if I'm in the Tavern and need to enter a dungeon to kill a boss, the portal should have a quest marker. Once I'm in the Realm, the next portal should be marked, and so on. The quest markers should always guide me along the route.

7. ✅ **First campaign pacing and encounters:** I played the first campaign, and the quests were far too close together. The first boss even spawned in the town. Also, most of the side quests here should really be main quests or encounters instead of side quests, with perhaps a few exceptions. The Goblin Master should spawn together with his goblin minions as a pack. The quest marker should point to where they spawn, and it shouldn't be on the same side of the forest as the city we're in.

8. ✅ **Graphics quality settings:** Introduce quality settings. I assume we're currently playing at maximum quality, but we need Medium and Low options for weaker PCs. There should also be separate settings for different graphical features so players can tailor the game to their systems.

9. **GUI fixes:**
   - ✅ The account XP bar at the top starts from zero every time we receive account XP. I don't know why; it might be a server issue.
   - ✅ The Friends and Party panels grow larger every time they fetch data, and they glitch and get stuck at that size.
   - ✅ `/t` doesn't display your own message to you, but it should.
   - ✅ The quest panel stays visible when a boss HP bar appears. It should hide, because otherwise it blocks the boss.
   - ✅ Remove the little toggle arrow underneath the account XP bar. Instead, let us click the top HP bar like a button.
   - ✅ This should also let us move the quest panel and boss HP bar a little higher, closer to the account XP bar.

10. ✅ **Personal vault — Chambers:** We need a personal vault called **Chambers**. It should be another world that we can teleport to from the Tavern. Initially, it should contain four wooden chests that close again once we're no longer standing in them. Chambers should look like a cozy little hall with red carpets and our chests. By earning account XP, we should be able to unlock more chests. Items stored here should never disappear, and any character on the same account should be able to retrieve them. Essentially, it should be an account-wide vault where we can safely store any item in persistent chests.

11. ✅ **Player p1's Chambers:** Give player `p1` lots of chests and put all the items currently in the game inside them, except story items.

12. ✅ **Developer `/give` command:** Add a `/give` command that allows developer accounts to give a specific item to a player. Only developers should be allowed to use this command on servers. Make `p1` a developer.

13. ✅ **Other campaigns:** Make sure the other campaigns don't have the same problems I described with Campaign 1.

14. ✅ **In-game currency — Dots:** Add an in-game currency called **Dots**. They should be green dots displayed to the right of the account XP bar, with a dot icon followed by the amount. Players can earn Dots by dismantling items at a forge. The amount should depend on item quality: G1 items could give around 10 Dots, G5 around 120, G7 around 450, G8 around 650, and Divine items even more. Players should also earn Dots for completing campaigns for the first time and from campaign packs.

15. ✅ **Forges and dismantling:** Add forges. Create a forge-house model and replace the house where the smith stands with it. When interacting with the smith, players should see their inventory and a forge item slot. They can place an item in the slot, see how many Dots they'll receive above it, and click a red **Dismantle** button underneath. When dismantling an item, animate Dots flying from the forge up to the Dots counter in the GUI, where the number increases. This animation should happen whenever players receive Dots, with a satisfying, impactful pop effect.

16.
