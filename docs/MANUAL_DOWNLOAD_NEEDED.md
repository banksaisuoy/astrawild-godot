# Manual Download Needed (or Not Needed)

**Phase V3 status: NOTHING is blocking.** Every asset in
`tools/asset_manifest.json` was fetched successfully from this sandbox
(135 requests, 944 files on disk, 0 failures, 98 MB used of the 250 MB
budget). See `docs/ASSET_LICENSE_LEDGER.md` for every row.

## Sources that were unreachable or closed (for the record)

| source | status | was it needed? |
|---|---|---|
| poly.pizza (Quaternius mirror) | HTTP 403 (Cloudflare blocks non-browser agents) | No — we download from Quaternius' own Google Drive instead |
| freepd.com (CC0 music) | **Site closed** ("FreePD.com - Site Closed") | No — music sourced from OpenGameArt CC0 instead |
| Quaternius Patreon "Pro/Source" editions | paid tiers, no free Drive link | No — free editions suffice |

## Optional extras you could fetch by hand (nice-to-have, NOT required)

These Quaternius packs exist but were deliberately skipped (style overlap,
budget discipline, or FBX-only format). If you want any of them, grab the
Google Drive folder from each pack page and unzip into
`assets/meshes/quaternius/<pack>/`, then re-run
`python3 tools/fetch_assets.py --reconcile` to ledger them:

| pack | page | why skipped |
|---|---|---|
| Ultimate Animated Monsters (newer) | https://quaternius.com/packs/animatedmonster.html | FBX-only export; current monsters cover Tier A |
| Ultimate Animated Dinosaurs | https://quaternius.com/packs/animateddinosaurs.html | FBX-only; Dino covers Sunscar already |
| Ultimate Animated Fish | https://quaternius.com/packs/animatedfish.html | FBX-only; Fish/Squidle/Hywirl cover water zones |
| Fantasy Farm Animals | https://quaternius.com/packs/farmanimal.html | FBX-only; animal roster already complete |
| Medieval Village MegaKit | https://quaternius.com/packs/medievalvillagemegakit.html | Patreon-gated; the free Medieval Village kit is already integrated |
| Fantasy Props MegaKit | https://quaternius.com/packs/fantasypropsmegakit.html | Patreon-gated |
| Modular Medieval Buildings | https://quaternius.com/packs/modularmedievalbuildings.html | no free Drive link |
| Ultimate Stylized Nature | https://quaternius.com/packs/ultimatestylizednature.html | texture-heavy (breaks the no-texture style); Kenney Nature Kit chosen instead |
| Bestiary Dungeon Monsters Kit | https://quaternius.com/packs/bestiarydungeonmonsterskit.html | newer patreon-era pack |

Poly Haven (`api.polyhaven.com`) and ambientCG (`ambientcg.com`) were both
reachable but **intentionally unused**: this project's style lock is
untextured flat-shaded low-poly, and both sources are texture/HDRI oriented.
No PBR textures were brought in on purpose.
