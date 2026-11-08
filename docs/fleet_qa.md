# Fleet verification

The account-wide fleet update was tested with temporary accounts and an isolated SQLite database. No live accounts were charged by the tests.

| Suite | Result |
| --- | --- |
| Account-service transactions, authorization, migration, concurrent claims and retry handling | 14 tests passed |
| Runtime lifetime, nearby crew, absent owner, spacewalking, automatic storage, lease expiry and a fatal hit during an in-flight heartbeat | 10 checks passed |
| Headless game client + dedicated server + local account service: two purchases, distinct IDs, deployment, occupied-pad refusal, recall, free redeployment, replication, boarding, launch and Surface/Space transfer | 15 checks passed |
| Existing status-effect regressions | 82 checks passed |
| Previous session regressions: buffs, beer, targeting, projectiles, Tavern geometry and ship state import | 81 checks passed |

Final gameplay checks were headless. The UI preview performed earlier was before the instruction to stop visual testing; no further visual testing was performed after that instruction.

The production account service and database were backed up before deployment under `~/void_accounts/admin_backups/fleet_1794165997054445462/`. Service restart, fleet schema and public/local health checks passed. The game and its dedicated/Singleplayer server need restarting to use the new fleet behavior.

Known engine cleanup warnings still occur on shutdown; the successful online run had no GDScript errors. Multi-client ownership retention was checked through runtime fixtures; the end-to-end network run used one client.
