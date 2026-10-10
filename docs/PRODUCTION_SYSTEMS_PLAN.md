# ASTRAWILD Production Systems Plan — "เหมือนเกมโปรดักชั่นที่ขาย"

**Date:** v1.4 → v1.5 planning · **Commander ask:** "เอาแบบเหมือนเกมโปรดักชั่นที่ขายเลย ไปหาข้อมูลมา มันต้องมีระบบอะไรบ้าง หาแหล่งอ้างอิงหลายๆ เกม แล้วมาทำแผน แล้วทำต่อให้สมบูรณ์ ตรวจสอบว่าเล่นได้จริง ไม่มีบั๊ค งานภาพไฟนอลรึยัง"

**Method:** web research (Palworld wiki · Valheim wiki · gamedev shipping checklists) + genre
knowledge (Pokémon · Monster Hunter · RimWorld) cross-checked against the live v1.4 tree
(grep + smoke suite, not memory).

---

## 1. Reference systems — what shipped, sellable games in this genre have

Sources consulted: palworld.wiki (Fandom "Base", "List of All Tower Bosses", v1.0 patch notes),
valheim.fandom.com ("Progression guide", "Workbench", "Crafting", "Crafting structures"),
gamedev.stackexchange.com "Checklist for finished game", Indie Game Shipping Checklist.

| # | System | Palworld | Valheim | Pokémon | ASTRAWILD v1.4 |
|---|--------|----------|---------|---------|----------------|
| 1 | Core loop: gather → craft → survive → fight | ✅ | ✅ | — | ✅ 43 recipes, hunger/thirst/temp |
| 2 | Creature capture → bond → evolve | ✅ Pals | — | ✅ | ✅ 228 species, 6 trust stages, evolution+body rebuild |
| 3 | Creature **breeding + eggs + inheritance** | ✅ signature | — | ✅ signature | ❌ **GAP** |
| 4 | Party system + box/bench | ✅ 5 + boxes | — | ✅ 6 + PC | ✅ 3 + echo box + 5 commands |
| 5 | Boss-gated progression (tower bosses / biome bosses) | ✅ 9 towers | ✅ 5 bosses | ✅ gyms | ◐ 2 bosses + 11-quest chain, no boss health UI |
| 6 | Tech/research tree | ✅ tech tree | ✅ station tiers | — | ✅ research points + unlocks |
| 7 | Base building | ✅ | ✅ | — | ✅ pieces + power grid |
| 8 | **Base automation (workers)** | ✅ Pal labour + SAN | ◐ | — | ✅ drone/robot/worksites (v1.0.4) |
| 9 | Biome/zone-gated difficulty | ✅ | ✅ 6 biomes | ✅ routes | ✅ 12 zones + threat tiers |
| 10 | Dungeons | ◐ | ✅ crypts | ✅ | ✅ 2 procedural dungeons |
| 11 | **Floating damage numbers** | ✅ | ✐ mods | ✅ | ❌ **GAP** (hit-flash + sfx only) |
| 12 | **Fast travel / portals** | ✅ map waypoints | ✅ paired portals | ✅ fly/teleport | ❌ **GAP** (12-zone world, walk only) |
| 13 | **Minimap / compass** | ✅ | ✐ no minimap | — | ◐ compass strip (V7), no minimap |
| 14 | **Achievements / milestones** | — (platform) | — (platform) | ✅ | ❌ **GAP** |
| 15 | **Difficulty modes** | ✅ custom | — | ✐ | ❌ **GAP** (only solo grace days 1-3) |
| 16 | **Key rebinding** | ✅ | ✅ | ✅ | ❌ **GAP** (volume sliders only) |
| 17 | **Graphics settings** (vsync/AA/scale) | ✅ | ✅ | — | ❌ **GAP** (msaa fixed in project.godot) |
| 18 | **Loading UX** (progress, tips) | ✅ | ✅ | ✅ | ◐ static label; **worldgen freezes web builds 1-3 min** |
| 19 | Save/load + autosave | ✅ | ✅ | ✅ | ✅ v2 format, 300s autosave, F5/F9 |
| 20 | Map + discovery fog | ✅ | ✐ | ✅ | ✅ 12 zones, fog, 15 ★ landmarks |
| 21 | Music + audio buses + sliders | ✅ | ✅ | ✅ | ✅ 7 tracks, 55 events, 4 buses |
| 22 | Help/controls + credits | ✅ | ✅ | ✅ | ✅ F1 Field Manual + credits (V12-c) |
| 23 | Mods | ✅ | ◐ | — | ✅ 3 bundled, F7 manager |
| 24 | Onboarding / first-hour guidance | ◐ | ◐ | ✅ | ✅ 5 first-steps + compass diamond (V7) |

✅ shipped · ◐ partial · ❌ missing

## 2. Build plan for v1.5 "The Production Pass"

Ordered by player-visible impact per engineering cost; each item lands with smoke assertions.

### P0 — felt in the first 5 minutes

| ID | System | Spec | Ref |
|----|--------|------|-----|
| PS-1 | **Floating damage numbers** | world-space labels at hit point; colour-coded (normal white-gold / weakness ×1.5 amber / resisted ×0.8 grey / weak-point crit ×2 orange-red / heals green); rise+fade 0.8s; batched into one overlay; player-taken damage red at screen edge via existing HUD | Palworld/Monster Hunter |
| PS-2 | **Staged loading with live progress** | split `world.build()` into 18 named stages; progress bar + % + rotating survival tips; engine renders between stages (`await process_frame`) so web builds never freeze; stage names honest ("Carving terrain… Dressing Frostveil… Waking echoes…") | all |
| PS-3 | **Difficulty modes** | New Expedition menu: Explorer (incoming ×0.7, needs ×0.85) / Standard / Veteran (incoming ×1.35, needs ×1.15, night raids +33%); persisted in save; live HP bar label | Palworld custom |

### P1 — signature systems the reference games are *sold* on

| ID | System | Spec | Ref |
|----|--------|------|-----|
| PS-4 | **Fast travel** | map screen: click any **charted landmark / village / camp** → travel for 3 DawnShards (free to Home Camp); confirmation popup; poof FX + stinger; guards: not in combat, not in dungeon | Valheim portals |
| PS-5 | **Achievements (18)** | first capture, first evolve, all 6 trust stages, 5/15 landmarks charted, all 12 zones, first boss, both dungeons, 50 crafts, party of 3, breeding (ties PS-7), 100% bestiary seen, veteran day-10 survive, ancient alloy, level-10 weapon; toast + journal tab + persistent in save | platform-standard |
| PS-6 | **Settings screen** (rebind + graphics) | pause/title: rebind 22 gameplay actions (click → press key, conflicts cleared); graphics: vsync, MSAA off/2/4/8, render scale 60–100%, FOV 60–90, toggle shadows; persisted to `user://settings.json` beside audio | every sold game |
| PS-7 | **Breeding & eggs** | build **Echo Nest** (new building piece, research unlock): bench two bonded (trust ≥ Familiar) party/box echoes → egg with 60s hatch (offline-safe timer via save); child inherits: family/element mix, 60% max parent stat rolls ±10%, family-name blend ("Emberx + Mosspaw → Emberkit"); once per pair cooldown 1 in-game day | Palworld/Pokémon |
| PS-8 | **Minimap** | HUD corner 180px circle radar: player arrow, live creature blips (hostile red / passive green / party gold), landmark diamonds, north lock, zone name under | genre-standard |

### P2 — polish if time

- PS-9: boss health bar overlay with name + phase pips (exists as toast only)
- PS-10: version string audit (`GAME_VERSION` still says v1.3 → v1.5), title screen version chip

### Verification gates (per item)

1. `--check-only` parse · 2. headless smoke: new assertion group each system ·
3. xvfb screenshot + VLM honest review · 4. full 4-platform export + re-smoke shipped Linux binary ·
5. GitHub release v1.5 + landing-page sync.

## 3. Art finality assessment (asked: "งานภาพเป็นแบบไฟนอลรึยัง")

Honest answer, evidence-based:

- **Tier S (16 hero species)**: FINAL for stylised-low-poly scope — real rigged GLBs, tint blends,
  attack clips (93 creatures with real Attack clips at v1.4 smoke).
- **Tier B (~188)**: designed procedural bodies with family features — reads as intentional
  art direction, but not hand-modelled; final *for this budget*, upgradeable forever.
- **World**: real Quaternius buildings, Kenney prop kits ×3 density, 15 landmark structures,
  zone grading — final-ish; VLM still flags spawn-area flatness + horizon repetition (logged
  next-round, not claimed fixed).
- **UI**: vector icons everywhere, title key art — final; damage numbers (PS-1) close the last
  "feels cheap" gap in combat feedback.
- **Missing vs AAA**: no post-processing stack (compatibility renderer), no per-creature
  textures (style lock C1: flat low-poly only). This is a **deliberate style**, not unfinished.

Verdict: **art is "production-stylised final"** — consistent, shipped-looking, no placeholder
geometric primitives visible anywhere (234/234 coverage, naked=true at smoke).

## 4. Current completion vs original design (UE5 prototype feature port)

228 species (204 base + 10 zone-special + 6 evolution + 2 boss + 6 modded) · 12 zones · 2
dungeons · 11 quests · 43 recipes · research tree · power grid · drone/robot automation ·
3 mods · 7 music tracks · 55 sfx events · save v2 · bestiary/journal/map/F1/credits — the full
original prototype scope is ported and machine-verified (93→ growing smoke assertions).
v1.5 adds the *production comfort layer* the originals never had (damage numbers, difficulty,
rebinding, achievements, fast travel, breeding, minimap, real loading UX).
