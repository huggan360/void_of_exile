# Watch the cutscenes

Each viewer plays one real cutscene offline, in the world the game plays it in,
then waits. No account or login; each launcher uses its own XDG data folder.
Launchers: `watch_<key>.sh` here, or `~/Desktop/Cutscene Watchers/` (numbered in
story order; HP = The Hidden Power, AF = The Astral Frontier).

`godot --path . -- --watch-cutscene=<key>`

Keys: any film id in `Cutscenes` (scripts/cinematic/, picked up automatically,
so a new film needs only a launcher line), plus the camera sequences outside it:
`castle_guardians`, `castle_throne` (castle_encounter.gd), `astral_launch`
(astral_launch_cinematic.gd), `nexus_intro`, `rocket_surface` (SpaceCinematic)
and `launch_intro` (the game start logo).

**R:** replay. **Escape:** close. Films keep their own hold-Space-to-skip.

Not covered: the Space Travels tutorial shots (`tutorial_ambush`,
`tutorial_repairs`) need a fleet ship from the account service; boss hatch
intros are in `tools/boss_watch/`.
