# Quest trails

CampaignClient supplies its existing main and side objective/portal markers to QuestGuide. Yellow marks the main quest, green marks the side quest. Both the minimap and world streaks consume the same forward-only route; yellow takes priority wherever the paths overlap.

QuestPathfinder uses bounded, incremental A* with a binary heap. It integrates travel-time cost over half-metre edge samples, using Player.ROAD_SPEED and Player.STEP_HEIGHT. Ground and road cells are both allowed, so a shorter forest crossing can win against a longer road detour. Diagonals cannot cut blocked corners, and each segment checks intermediate heights and blockers. A blocked objective can end at a reachable approach cell within interaction range; unreachable paths never turn into unchecked direct lines.

The guide uses one-metre cells near objectives and in authored worlds, and two-metre cells for distant island goals. It caches immutable terrain columns and spatially indexes obstacle plans. Planned tree and building collision boxes are checked before streamed colliders exist. Loaded prop colliders and closed stronghold gates are checked too. Searches run in small per-frame budgets; a slow side search cannot delay a completed main route.

Leading segments are consumed as the player moves. Objectives, broken obstacles, gate changes and deviation from a path trigger updates. Nearby segments are rechecked against fresh collision data. The world ribbon is ground-conforming, depth-tested, short-range and low-opacity, with animated waving streaks rather than spawned lights or a particle cloud. It hides during focused NPC conversations and cinematics. The minimap draws only the part of each route inside its circular viewport.

Relevant files:

- `scripts/world/quest_pathfinder.gd`: grid search and travel-time calculation.
- `scripts/world/quest_guide.gd`: goals, world probes, collision caches and route lifecycle.
- `scripts/world/quest_trail.gd` and `shaders/quest_trail.gdshader`: subtle world rendering.
- `scripts/ui/minimap.gd` and `shaders/minimap.gdshader`: map routes and carved stone/brass frame.

Regression scenes:

- `tools/test_quest_pathfinder.tscn`: roads, forest shortcuts, exact targets, blocked endpoints, barriers, corners, height changes, multiple goals and time slicing.
- `tools/test_quest_guide.tscn`: shared displays, passed-route removal, collider checks, overlap and independent main/side publication.
- `tools/test_quest_realm_navigation.tscn`: planned obstacles and buildings before streaming. Add `-- --benchmark` for an optional realm search timing check.
- `tools/test_hud_skin.tscn`: resources, numeric pills, slots, backpack, XP ring and the pixel loading screen.
