# COMPLETENESS AUDIT — the "1000%" pass

**Date:** v1.2 → v1.3 audit · **Commander ask:** "ตรวจสอบเกมแล้วทำให้สมบูรณ์ 1000% ดูว่าขาดอะไรแบบละเอียดๆ แล้วเสริมเติมแต่งให้ครบ แล้วเอาขึ้น Git"
**Method:** real commands only — full headless smoke rerun, data JSON cross-checks (species vs rig maps vs bestiary), UI screen inventory, save-state tracing, ledger extraction.

## Verified COMPLETE (baseline green)

| Area | Evidence |
|---|---|
| Smoke suite | full rerun ALL GREEN (rigs 218/218 loadable+animated, tierb 188 built/0 failed/0 dupes, landmarks 15/15, perf budget_ok=true, music 7 tracks + 55 events, quests/drone/robot/worksites/party commands/autosave/quickload all pass) |
| Quest chain | 11 quests, linear chain terminates at Quest_VanguardProtocol (finale completes in smoke) |
| Death loop | die() → 5 s respawn timer → respawn_at_camp() |
| Save system | world+player+party+quests, v2 format, autosave 300 s, F5/F9 |
| Audio | 4 buses + persisted volume sliders, 7-track context music, 55 game-feel events, stingers |
| Map | 12 zones, discovery fog, camp + player marker |
| Mods | 3 mods, F7 manager, 6 modded species |
| Boot | `--import` clean (0 errors), headless boot green |

## GAPS FOUND (9) — all fixed in this pass

| # | Gap | Severity | Evidence |
|---|---|---|---|
| 1 | **14 species have no rig map → naked procedural bodies**: 6 production legendaries (Terraquill, Cindermule, Voltpylon, Bastionbeetle, Mistmender, Deepdelver), their **6 evolutions**, and **2 dungeon bosses** (Underlight Warden, Vault Colossus) | HIGH — the rarest, most exciting creatures look worst; smoke `procedural=3` | `data/species_models.json` maps=218, bestiary 204 + special 24 = 228 species |
| 2 | **Evolution never rebuilds the follower body** — `bind_entry()` updates stats/label only; your Terraquill evolves into TerraquillVerdant but still *looks* like a Terraquill | HIGH — core emotional payoff invisible | `scripts/creatures/echo.gd:1006` |
| 3 | **Landmark chests not persisted** — `chest_opened` lives only on the marker node; save/load resets all 15 chests → infinite 40×DawnShard+Resonator+2×AncientAlloy farming | HIGH — economy break | nothing in `scripts/autoload/saves.gd` mentions chest/landmark |
| 4 | **Map legend lies** — promises "★ landmarks discovered" but `_draw_map()` draws zero landmarks | MED | `scripts/ui/screens.gd:745` vs `_draw_map` body |
| 5 | **No charted-location tracking** — `Game` has `discovered_zones` but nothing for the 15 landmarks | MED | grep `Location_` in game.gd → no state |
| 6 | **Inventory cells are text-only buttons** ("Name\n×qty") — no icons although a 16-icon vector system exists | MED | `screens.gd:277-285` |
| 7 | **No in-game help/controls screen** — the full key table exists only in README; F1 unused | MED | screens inventory: inventory/crafting/research/journal/map/pause/dialogue/shop/mods |
| 8 | **No credits/license screen** — Quaternius, Kenney and CleytonKauffman (OGA) CC0 attribution invisible to players | MED (CC0 citizenship) | ledger has 215 rows, game shows none |
| 9 | **README species count stale** ("226 = 204+10+6+2" — sums to 222; real total 228 = 204+10+6+6evolutions+2 bosses) + no fullscreen toggle (F11 free) | LOW | `README.md` line 7 |

## Fix plan (executed as V12-a…f)

- **V12-a:** rig maps for all 14 (AABB-calibrated like build_rig_maps.py) + evolution body rebuild in `bind_entry` + smoke coverage assert **228/228**
- **V12-b:** `Game.opened_chests` + `Game.charted_locations` persisted through saves; chests stay opened after reload; map draws 15 ★ (bright = charted); journal "locations charted n/15"
- **V12-c:** inventory grid icons; **F1 Help & Controls screen**; **Credits & Licenses screen** (title + pause); **F11 fullscreen toggle** (+ pause button)
- **V12-d:** README count fix + smoke extensions for every new system
- **V12-e:** xvfb screenshots + VLM verification
- **V12-f:** release v1.3 (4-platform exports + web build + landing sync), push, STATUS BLOCK
