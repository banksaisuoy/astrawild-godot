# On-PC Tasks — things that need YOUR eyes (v1.1)

Machine verification covers boot, asserts and headless screenshots, but these
need a human playing the game for real:

1. **First-30-minutes playtest** — does the onboarding → capture → craft loop
   feel guided? Is the compass diamond pointing somewhere useful at all times?
2. **Rig hit-box feel** — the new Quaternius rigs are bigger/fluffier than the
   old box bodies; melee sweeps (1.4m range) should still connect visually.
   If attacks feel like they "miss" despite hitting, tell me — the sweep
   radius may need +0.3m.
3. **Legendary encounter (EmberRidge, Solaris)** — a huge golden dragon with
   520 HP now. Watch it wake from dormancy and decide if the wake-up damage
   window feels fair solo.
4. **Music mix** — 7 tracks at -16dB on the Music bus. If ambience/music
   fight, the pause sliders are live; tell me your preferred defaults.
5. **Night raid pressure with grace** (days 1-3 ×0.65) — too easy now?
6. **Web build on a real browser** — 77MB first load; check WASM audio unlock
   (browsers need a click before sound).
7. **macOS Gatekeeper** — unsigned build, right-click → Open on first run.
8. **Frame rate on your GPU** — llvmpipe software rendering here can't judge
   real perf; the perf budget (6.7k MultiMesh instances) is fine but only a
   real GPU confirms it.
