# Tech Stack — Embergrave

Two-developer team, ~4 weeks part-time to first playable. Bias: ship fast, runnable in browser, low ceremony.

## Stack

| Layer            | Choice                                  |
|------------------|-----------------------------------------|
| Engine           | **Godot 4.3** (GDScript primary)        |
| Language         | **GDScript** for gameplay; C# only if a hot path demands it (unlikely at our scale) |
| Art pipeline     | 2D pixel art, Aseprite source, PNG export, AI-assisted concept (Stable Diffusion / Midjourney refs) — final pixel art hand-cleaned in Aseprite |
| Audio pipeline   | SFX: jsfxr / sfxr-style synthesis + freesound CC0; Music: AI-generated stems (Suno / Udio) curated by Uma, exported as OGG |
| Save / data      | **JSON** save files in `user://` (Godot's built-in user data dir); content data (mobs, items, affixes) in **TRES** resource files version-controlled in repo |
| Build target     | **HTML5 + Windows + Linux + macOS** export from Godot. Distribution: itch.io for M1 sponsor playtest, Steam playtest later |
| CI / test        | **GitHub Actions** running `godot --headless --import` for asset import sanity, then GUT (Godot Unit Test) suite. Per-PR build artifact (HTML5 zip) auto-uploaded to itch.io via butler |
| Version control  | Git, single `main` branch with PR-based workflow, branch protection requiring CI green |
| Project layout   | `/game` (Godot project root), `/art` (Aseprite sources), `/audio` (sources), `/docs` (design), `/tools` (scripts) |

## Justifications vs alternatives

- **Godot vs Unity:** Godot is open-source, free, no install seat tax, exports to HTML5 cleanly out of the box (Unity's WebGL story is heavier and slower to iterate). Two devs, no licensing overhead, no editor lock-in.
- **Godot vs Unreal:** Unreal is wildly overkill for 2D pixel ARPG. C++/Blueprint friction, huge build sizes, no web export.
- **Godot vs Phaser / PixiJS (web-native):** A pure web stack would ship faster to browser but loses us native desktop builds, the Godot editor's scene composition, and the resource/animation tooling. Godot 4 HTML5 export gives us both.
- **GDScript vs C#:** GDScript iterates faster (no C# compile step, hot-reloads in editor), is the path of least resistance in Godot 4, and our hot paths are nowhere near needing native perf. Drop to C# only if profiling demands it.
- **JSON saves vs SQLite vs engine-native:** JSON is human-readable (debug-friendly), trivially diffable in PRs, fine at our save-size scale (kilobytes). SQLite is overkill for a single-player save. Godot's `ConfigFile`/`FileAccess` handles JSON natively.
- **Aseprite vs Photoshop vs Krita:** Aseprite is the pixel-art industry default, owns animation timeline, exports clean PNG sheets with `.json` metadata Godot consumes directly.
- **GitHub Actions vs none:** A 2-dev team must not block on each other's manual builds. CI guarantees `main` is always demoable to Sponsor.
- **itch.io vs Steam first:** itch.io accepts HTML5 builds, has zero gatekeeping, and is the standard playtest channel. Steam playtest comes after M2 when we have a spine of content worth Steam's submission overhead.

## Open questions parked (not blockers)

- Localization framework — defer until post-M2.
- Controller support — Godot gives this nearly free; Drew validates during M1 polish.
- Anti-cheat / save tampering — irrelevant for single-player offline; revisit if we ever ship leaderboards.
