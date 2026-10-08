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
| 1 | **2 mod species (Echo_Petalume, Echo_Corallume from glimmer_garden) had NO rig map → naked procedural bodies**. Initial audit also flagged 14 species (6 production legendaries + 6 evolutions + 2 bosses) as unmapped — deep-check showed they resolve via their own production GLB models (`def.model`), so they were never naked; the rig-map gap for them was cosmetic bookkeeping only | HIGH for the 2 | `data/species_models.json` maps=218 vs 234 real species (incl. mods); smoke `procedural=3` (spawn RNG: 2 mod species + 1 borderline) |
| 2 | **Evolution never rebuilds the follower body** — `bind_entry()` updates stats/label only; your Terraquill evolves into TerraquillVerdant but still *looks* like a Terraquill | HIGH — core emotional payoff invisible | `scripts/creatures/echo.gd:1006` |
| 3 | **Landmark chests not persisted** — `chest_opened` lives only on the marker node; save/load resets all 15 chests → infinite 40×DawnShard+Resonator+2×AncientAlloy farming | HIGH — economy break | nothing in `scripts/autoload/saves.gd` mentions chest/landmark |
| 4 | **Map legend lies** — promises "★ landmarks discovered" but `_draw_map()` draws zero landmarks | MED | `scripts/ui/screens.gd:745` vs `_draw_map` body |
| 5 | **No charted-location tracking** — `Game` has `discovered_zones` but nothing for the 15 landmarks | MED | grep `Location_` in game.gd → no state |
| 6 | **Inventory cells are text-only buttons** ("Name\n×qty") — no icons although a 16-icon vector system exists | MED | `screens.gd:277-285` |
| 7 | **No in-game help/controls screen** — the full key table exists only in README; F1 unused | MED | screens inventory: inventory/crafting/research/journal/map/pause/dialogue/shop/mods |
| 8 | **No credits/license screen** — Quaternius, Kenney and CleytonKauffman (OGA) CC0 attribution invisible to players | MED (CC0 citizenship) | ledger has 215 rows, game shows none |
| 9 | **README species count stale** ("226 = 204+10+6+2" — sums to 222; real total 228 = 204+10+6+6evolutions+2 bosses) + no fullscreen toggle (F11 free) | LOW | `README.md` line 7 |

## Fix plan (executed as V12-a…f) — ALL VERIFIED GREEN in smoke

- **V12-a ✓:** rig maps for Echo_Petalume (Mushnub) + Echo_Corallume (Glub), AABB-calibrated; evolution body rebuild in `bind_entry` + smoke asserts `visual coverage 234/234 missing=[]`, `evolution body rebuilt=true`, `live procedural=0`
- **V12-b ✓:** `Game.opened_chests` + `Game.charted_locations` persisted through saves; chests stay opened after reload; map draws 15 ★ (bright = charted + name, faint dots = rumours in known zones); journal field-notes counters — smoke `chest persistence=true`, `location persistence=true`, `landmark_list=15`
- **V12-c ✓:** inventory grid icons (category/name-aware vector icons, equipped = gold); **F1 Field Manual** (all controls + survival wisdom, pauses game); **Credits & Licenses** screen (title menu + pause menu — Quaternius/Kenney/CleytonKauffman CC0 attribution + ledger pointer); **F11 fullscreen** (+ pause button) — smoke `help screen=true`, `credits screen=true`, `inventory icons=true`
- **V12-d ✓:** README corrected to 228 species (+ 6 modded = 234), F1/F11/Esc rows added, duplicate Esc row removed; smoke suite extended with 6 new assertion groups
- **V12-e ✓:** xvfb (Xvfb :99, llvmpipe) screenshots of title/help/credits/inventory/map/gallery; VLM-verified: help 9/10 readable two-column key-chips, inventory icons + equipped-gold confirmed, map stars + live 5/15 legend + label backing plates confirmed, credits attribution confirmed, gallery = real distinct models. Two VLM-found defects fixed (stale legend counter, label/zone collision).
- **V12-f ✓:** 4-platform export (Win 77 MB / Linux 67 MB / macOS 99 MB / Web 82 MB first-load), **shipped Linux binary re-smoked: 93/93 assertions GREEN incl. all V12 systems**; tag v1.3 pushed, release 406847277 live with 4 assets + honest notes; landing page synced to v1.3 (frontend subagent, browser-verified E2E incl. in-browser boot to the v1.3 title screen + a latent sizeCanvas infinite-recursion bug fixed as bonus)
