# EVENING REPORT — Visual & World Directive V1 (v1.1)

## 1 · Before vs after (honest)

**Before (v1.0.4):** a promising low-poly world (real GLB trees/rocks/ruins,
vertex-coloured terrain, warm sun ramp) populated by **coloured boxes** —
214 of 228 species were primitive assemblies, every village hut was a
cylinder+prism, every NPC was the player's own model recoloured, the UI was
text-only, and the game had **no music at all**. First-impression VLM scores:
world 6/10, creatures 2.5/10, village 3/10, UI 2/10.

**After (v1.1):** 32 hero/named species run real rigged CC0 models with
attack animations (VLM: "real shaped low-poly animal models… large golden
dragon, boss-sized"); the remaining 188 species are procedurally rebuilt with
per-family features (VLM: "designed creatures, distinct silhouettes, not plain
boxes"); Dawnstead is a timber village with paths (VLM: "real house models
with sloped roofs, timber framing, arched doors"); there are 15 landmarks,
per-zone colour grading, a compass, an onboarding checklist, a 7-track
soundtrack, and hit/harvest/chest feedback everywhere.

## 2 · Asset ledger summary

**215 ledger rows / 215 files on disk** (docs/ASSET_LICENSE_LEDGER.md — path,
source, direct URL, license, sha256, date for every file):

| source | files | MB |
|---|---|---|
| Quaternius (Google Drive direct) | 121 | 67 |
| Kenney (direct zips → extracted GLB/OGG) | 587 | 25 |
| OpenGameArt CC0 music | 7 | 10 |
| **total fetched** | **944 → 215 kept** | **≈102 MB** |

(Kenney zips expand to hundreds of small files; only GLB/OGG matching the
manifest were kept. One 'Preview.ogg' collision is cosmetic and harmless.)

## 3 · Coverage

- **Tier S (16)**: 14 already had production rigs; **2 new** (Mosspaw→Fox,
  Lumewisp→Ghost) → **16/16 real rigs**.
- **Tier A (30)**: **all 30** (+4 modded legendaries incl. Solaris→Dragon_Evolved)
  mapped to Quaternius rigs with per-species scale + tint variation.
- **Tier B (188)**: procedural builder upgrade, **188/188 unique** signatures,
  0 failures, VLM-verified family features.
- **Live world check**: 54 rigged creatures on screen at once
  (43 Quaternius + 11 production), 28 procedural.

## 4 · Could NOT get (with exact URLs)

Nothing **blocked**. Optional extras you could fetch by hand (see
docs/MANUAL_DOWNLOAD_NEEDED.md for the full table): Quaternius Patreon packs
(Medieval Village MegaKit — https://quaternius.com/packs/medievalvillagemegakit.html,
Fantasy Props MegaKit — https://quaternius.com/packs/fantasypropsmegakit.html),
FBX-only animated packs (animatedmonster/dinosaurs/fish/farmanimal — free Drive
links on their pages). FreePD.com is **closed** (music came from OpenGameArt
instead); poly.pizza blocks non-browser agents (unused — we used Quaternius'
own Drive).

## 5 · Needs your eyes

→ **docs/ON_PC_TASKS.md** (8 items: playtest, hit-box feel vs bigger rigs,
Solaris fairness, music mix defaults, night-raid grace, web audio unlock,
macOS Gatekeeper, real-GPU frame rate).

## 6 · Size budget

| constraint | limit | used |
|---|---|---|
| repo asset growth | 250 MB | **111 MB** |
| single file | 20 MB | 5.2 MB largest |
| web export total | 150 MB | **77 MB** |

## 7 · Honest verdict: **7/10 — visually presentable**

Defence: the world now reads as a coherent stylized low-poly game end-to-end —
real creatures with animations, a real village, landmarks worth navigating by,
zone moods, and sound/music that make it feel alive. Not 8+: the UI is still
text-only (no icons), title screen is still a dark rectangle, Tier-B creatures
are improved primitives rather than models, and everything was judged through
software-rendered screenshots + VLM — a real GPU playtest could still surface
framerate or feel problems.

## 8 · Top 5 next actions (ranked)

1. **Human playtest of items 1-3 in ON_PC_TASKS** — hit-box feel and Solaris
   fairness gate everything else.
2. **UI icons + title-screen art** — the last naked-plain text surfaces.
3. **Tier A uniqueness pass** — several zone icons share Goleling-family rigs;
   Quaternius' animated FBX packs (dinosaurs/fish) would diversify them.
4. **Landing-page v1.1 sync** — the website still says v1.0.4.
5. **Settings screen + gamepad rebinding** (rebuild of the lost v1.0.5 layer).
