# V11 — De-Jank Pass (v1.2)

Trigger: player verdict on v1.1 — "the game still looks janky" (งอกง่อย).
The v1.0 evening report itself listed the four weakest surfaces; this pass
attacks exactly those, ship-or-skip, each verified with real captures.

## What shipped

### V11-a · Cinematic title screen
- `assets/ui/title_keyart.png` — AI-generated key art (z-ai, our own asset;
  2 candidates generated, VLM selected the campfire-valley one for calm
  upper-third title space). JPEG mislabeled as .png was re-encoded properly.
- Ken Burns zoom (42 s ping-pong, centered pivot after layout), radial
  vignette, 42 additive golden motes, spaced-caps logo with outline+shadow,
  styled amber menu buttons (Continue/Begin/Quit), controls card, version
  chip `v1.2 · Godot 4 · 226 species`, fade-in from black.
- New `--shot=title` capture mode (world never boots).
- VLM verdict: "polished, professional title screen for a shipped
  commercial indie game."

### V11-b · Vector UI icon system
- `scripts/ui/icons.gd` — `GameIcons` draws 16 icons in code (heart, bolt,
  meat, drop, paw, sword, shield, gear, book, map, flask, backpack, star,
  coin, eye, check). No external assets, works in gl_compatibility/Web.
- HUD vitals rows (icon + label + bar), party cards (paw), FIRST STEPS
  checklist (per-task icon, green check on completion), every screen title
  (backpack/gear/flask/book/map/star/coin).
- Fixed the long-standing `PanelContainer already has a parent` warning
  (onboarding panel was added to root twice).
- VLM: "significantly more polished, professional and intuitive."

### V11-c · All species on real rigs
- `tools/measure_rigs.gd` measured native AABB of all 54 Quaternius rigs
  headless; `tools/build_rig_maps.py` maps the 186 remaining procedural
  species deterministically (md5 of id → body_plan pool) with calibrated
  scale `TARGET[size_class]/native` (Tiny .8 / Small 1.4 / Medium 2 /
  Large 3.2 / Huge 4.6 m) ± 8% species jitter.
- Soft tint: atlas-textured rigs blend species color at 0.32 (was 0.60) so
  painted faces/eyes stay visible; untextured rigs keep full palette.
- Result: **0 species on primitives** (procedural builder kept only as
  never-crash fallback). Smoke: `rigs mapped=218 loadable=218 with_anims=218`,
  live world 78/80 creatures rigged, real Attack clips 36 → 56.

### V11-d/e · Atmosphere regrade + release v1.2
- Fog regrade (the "white void" player complaint): DAWN_FOG (0.88,0.70,0.55)→
  (0.72,0.54,0.42), NOON/DUSK deepened likewise; density base 0.0012→0.0007
  (arc 0.0006–0.0011); sun energy 1.6–3.0 → 1.3–2.2; ambient 1.2/0.85 →
  1.05/0.8. VLM on re-captured village aerial: "absolutely usable as a
  landing-page screenshot now."
- `--clean` screenshot flag (hides HUD/panels for world shots); gallery
  camera pulled back+up so the player body never blocks the frame.
- Exports: Windows 143 MB / Linux 109 MB / macOS 94 MB / Web 77 MB, all
  from Godot 4.7.2-stable; exported Linux binary smoke-tested green.
- GitHub Release **v1.2** (id 406758746) with 4 zips + honest notes.

## Verification summary
- Headless smoke: all green, 0 script errors (creatures, villages, dungeons,
  skiffs, worksites, save/load, quests, capture).
- VLM reviews: title "shipped commercial indie", HUD icons "professional",
  tierb lineup "actual models, cohesive bestiary", web embed boots to the
  new cinematic title in-browser (agent-browser E2E).

## Honest limits (unchanged from v1.0 report unless noted)
- UI still text-first English; no settings screen / gamepad rebinding.
- Screenshot QA runs through llvmpipe software GL — real-GPU feel untested.
- Tier-B rigs share 54 models across 186 species; variety is scale/tint/
  silhouette, not unique sculpts.
- macOS Gatekeeper + web-audio-unlock caveats remain (see ON_PC_TASKS.md).
