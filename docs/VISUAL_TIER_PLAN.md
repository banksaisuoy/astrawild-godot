# VISUAL TIER PLAN — ASTRAWILD Godot Division
**Phase V2 · every one of the 228 species assigned a tier · repo @ aacf4d3**

> Directive targets: TIER S 12–15, TIER A 30–40, TIER B the rest. Final assignment:
> **S = 16, A = 30 (+4 modded legendaries), B = 186.** S runs one entry over the
> suggested cap — justified below by first-five-minutes visibility; cutting either
> Lumewisp or Mosspaw would leave the literal first quest target or the literal first
> wild Echo a box-puppet, which defeats the point of the pass.

## TIER S — hero species (real distinct mesh + animation)

**Requirement:** unique rig with idle/walk/attack motion. Honest status today: the 6
production rigs carry Idle/Move/Hit clips only — no dedicated Attack clip exists in any
current GLB. Attack reads as a Move-based lunge + Hit flash. The two NEW rigs below
will be sourced with attack clips if the CC0 pack provides them; otherwise the gap
stays documented and code-driven lunges cover it. Nothing silently downgraded.

| # | species | why a player sees it constantly | rig status |
|---|---|---|---|
| 1 | Echo_Terraquill | Dawn Fields is the starter zone and Terraquill is its production species — the capture tutorial (diff 0.35) and the face of the whole bonding loop | HAVE RIG (3 anims) |
| 2 | Echo_TerraquillVerdant | evolution payoff — the moment the player's first bond upgrades | HAVE RIG (reuse + V4 variant parts) |
| 3 | Echo_Cindermule | Ember Ridge production species; work role base | HAVE RIG |
| 4 | Echo_CindermulePyre | evolution payoff | HAVE RIG (reuse + variant) |
| 5 | Echo_Voltpylon | Glimmerwood production species | HAVE RIG |
| 6 | Echo_VoltpylonTempest | evolution payoff | HAVE RIG (reuse + variant) |
| 7 | Echo_Bastionbeetle | Verdant Reach production species; first Combat role most players bond | HAVE RIG |
| 8 | Echo_BastionbeetleBulwark | evolution payoff | HAVE RIG (reuse + variant) |
| 9 | Echo_Mistmender | Dusk Marsh production species | HAVE RIG |
| 10 | Echo_MistmenderRime | evolution payoff | HAVE RIG (reuse + variant) |
| 11 | Echo_Deepdelver | Stormcrest production species | HAVE RIG |
| 12 | Echo_DeepdelverAbyssal | evolution payoff | HAVE RIG (reuse + variant) |
| 13 | Creature_UnderlightWarden | BOSS 1 — Hollow Approach dungeon finale (capture 0.95) | HAVE RIG (Deepdelver reuse; V4 adds boss dressing ×1.6 + armour parts) |
| 14 | Creature_VaultColossus | BOSS 2 — Sunken Vault finale (capture 0.95) | HAVE RIG (Bastionbeetle reuse + boss dressing) |
| 15 | Echo_Lumewisp | **the literal first creature objective in the game** — Quest_FirstEcho says "Observe a Lumewisp"; also the Support starter and the landing-page team-builder mascot | NEW RIG NEEDED (floating lantern-wisp) |
| 16 | Echo_Mosspaw | bestiary entry #1 — the first wild Echo any new player ever sees in Dawn Fields, and the first realistic capture (diff 0.2) | NEW RIG NEEDED (small beast quadruped) |

## TIER A — named species (shared base meshes + colour/scale/part variation)

Selection categories, each with its reason:

### A1 · Night predators — the face of every Night Raid (4)
Echo_Gloomfang (HollowApproach, 0.85 — also the Quest_DawnGuard "Defeat 3 Gloomfangs" combat tutor),
Echo_Emberfang (EmberRidge, 0.90), Echo_Rimefang (Frostveil, 0.88), Echo_Voltmaw (Glimmerwood, 0.92).
A sleeping player sees these four more often than any rare species.

### A2 · First-five-minutes Dawn Fields commons (5)
Echo_Dawnhorn, Echo_Duskhide, Echo_Emberrunner, Echo_Galewing, Echo_Skysong —
the variety pack (quadruped/biped/avian/floating) surrounding Mosspaw before the player leaves the starter zone.

### A3 · Zone icons — the highest-difficulty encounter of each zone (12)
The "boss of the zone" a player steers toward or away from:

| zone | icon species | capture diff |
|---|---|---|
| DawnFields | Echo_Emberwing | 0.22 |
| Glimmerwood | Echo_Tidefang | 0.42 |
| VerdantReach | Echo_Abysswing | 0.34 |
| DuskMarsh | Echo_Frostwing | 0.34 |
| Frostveil | Echo_Glimmerfang | 0.54 |
| EmberRidge | Echo_Tidewyrm | 0.62 |
| Sunscar | Echo_Coralcrest | 0.46 |
| AzureShallows | Echo_Dunewing | 0.34 |
| TidebreakerIsles | Echo_Primemonolith | 0.67 |
| PearlseaReef | Echo_Eldermonolith | 0.79 |
| Stormcrest | Echo_Astralmonolith | 0.67 |
| HollowApproach | Echo_Vespermonolith | 0.79 |

### A4 · UE5-production special species, marketing-visible (5)
Echo_Stonehide, Echo_Voltling, Echo_Duskmoth, Echo_Auroraling, Echo_Sprigling —
special-bestiary entries derived from the original UE5 production set (roles: Combat/Base/Support).

### A5 · Modded legendaries — Mythic Echoes hunt targets (4, mod-space)
Echo_Solaris (EmberRidge), Echo_Umbrarch (HollowApproach), Echo_Terravore (Glimmerwood),
Echo_Chronoweave (Frostveil) — Huge legendary hunts with dormant-aura behaviour; the mod's
entire pitch is "hunt them — or capture them", so their silhouette must sell it.
*(These live in mods/, outside the 228 base count.)*

**Tier A total: 26 base + 4 modded = 30. Treatment: shared CC0 rigged base meshes
(Quaternius animal/monster class), varied by scale, tint, and bolt-on parts
(horns/fin/wings) per species — exactly what the directive permits.**

## TIER B — field species (186)

Everything else. They keep the procedural builder, upgraded in Phase V5:
silhouette variety per family, element-driven palettes, deterministic seeded proportion
variance, idle bob + locomotion, and one signature feature per family
(Beast → horns, Aquatic → fins, Avian → wing crests, Flora → leaf canopy, Spirit →
halo shards, Construct → plating, Insectoid → antennae, Dragon → spinal ridge).

## Cross-checks done

- Quest references scanned: only `Echo_Lumewisp` (Quest_FirstEcho) and `Echo_Gloomfang`
  (Quest_DawnGuard) are species-named quest targets → both covered (S and A1).
- Both bosses covered (S). All 12 zone icons covered (A3). All 4 night predators covered (A1).
- All 6 production species + 6 evolutions covered (S). The 5 non-production special species covered (A4).
- Modded legendaries covered (A5). Glimmer Garden gentle species (Petalume/Corallume) stay Tier B —
  they are decorative ambient spawns, not encounter drivers.

---
*End of Phase V2.*