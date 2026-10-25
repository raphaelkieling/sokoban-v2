# Project Guide for Agents

## Product and design direction

- This is a fantasy Sokoban puzzle game built with LÖVE. Keep the puzzle rules readable and let character classes create distinct, understandable ways to solve levels.
- The visual style is pixel-art inspired. Menus should remain centered, compact, and consistent, with a shared selector treatment; avoid adding visual panels or dividers unless a screen already calls for them.
- Use the title **Pushcraft** in the main menu only for now. Do not rename the application, window, credits, or other project metadata without being asked.
- Keep feedback focused and owned by the object it describes. Prefer a component or the object's sprite/state machine over a global effects manager such as `WorldEffects`.

## Architecture and code conventions

- The game uses `GameObject` with small, composable components. Put behavior and state with the object that owns it; avoid growing `PlayingScene`, `Board`, or another central coordinator into a home for unrelated object behavior.
- Reuse existing components and state machines where appropriate. Add a reusable component when behavior can belong to multiple objects, and keep object-specific rules in the relevant class/component.
- Character abilities live in their class implementations under `src/characters/classes/`. Movement rules should use the movement/session abstractions rather than directly mutating the board.
- Keep undo support in mind for any gameplay state change. Changes that affect positions, object status, or ability state should be represented in the existing snapshot/history flow and covered by tests.
- Keep presentation separate from gameplay rules. Components such as `SpriteRenderer`, `Animation`, and `Highlight` own visual rendering; LDtk describes level content and should not dictate how a sprite is animated or drawn.

## Levels and LDtk

- `maps-v2/Map.ldtk` is the source of level data. Do not delete, replace, or migrate legacy maps unless explicitly requested.
- Keep the loader generic across LDtk layers and tiles. Respect layer ordering from the project, drawing background layers before entities and foreground layers after them.
- Level ordering is controlled by the numeric `Order` field. It must be unique for levels that are included in gameplay.
- A level with `Skipped == true` is treated as nonexistent: it must not be listed, loaded, used for progression, or otherwise participate in level-facing systems.
- Map entity identifiers and enum values are part of the LDtk/loader contract. When adding or changing one, inspect the LDtk definitions and update the loader mapping and tests together.
- `Passthrough` marks a cell where movable objects may pass or fall; it is not a visual water system. Water or other scenery may be painted separately.
- Keep the distinction between floor, collision, and passthrough explicit. Missing ground is not automatically a special terrain type.
- Targets, boxes, bonfires, grass, triggers, and players are gameplay objects with their own components. Avoid introducing one new entity type per decorative or pushable object when an existing component/enum/property can express the distinction.
- The level selector presents progression as a horizontal node graph on a black background, focused/zoomed around the selected level instead of showing a full route overview. LDtk's `Free` world layout supplies node positions (`worldX`/`worldY`) and `__neighbours` supplies connections between touching levels; use these as the selector's source of truth. Keep the graph model explicit so routes can branch; left/right follows horizontal links and up/down can select vertical branches.

## Gameplay rules to preserve

- Players may be pushed into passthrough. A player that falls enters the existing sinking/dead flow; select another living player automatically, and never allow a lost/dead player to be selected.
- Boxes may enter passthrough when a push ends there; represent their lost/sinking state through the existing state/component flow so undo can restore them.
- Pushability/control is capability-based (for example, `Tetherable`), not inferred only from an object's name or whether it is a box. Apply the relevant capability to other movable objects, such as bonfires, when appropriate.
- The Puppeteer links touched tetherable objects and synchronizes its directly linked objects on the Puppeteer's own movement. Keep this class-owned and simple; do not turn it into a general dependency tree. Other characters should still move linked boxes normally, without invoking the Puppeteer's synchronization.
- Class-specific constraints (such as the Dwarf's one-box push limit) belong in that class's movement behavior and must remain test-covered.

## Events, triggers, analytics, and localization

- Use the shared event emitter for cross-system notifications. Analytics subscribes to events; gameplay and level code must not depend directly on analytics implementation details.
- Triggers are data-driven by their LDtk `TriggerName` and resolved through `src/game/TriggerRegistry.lua`. Keep trigger activation generic and put named responses in the registry. Support once/repeat behavior and duration where applicable.
- All player-facing text belongs in the localization catalogs under `src/i18n/locales/`. Keep Portuguese, English, and Spanish catalogs in sync; do not hard-code UI text in screens or trigger handlers.
- Bind tutorials and controls to configured key labels instead of embedding a key name that can become incorrect when controls change.

## Character voice generation

- Character voice clips are generated with ElevenLabs and stored as local audio assets under `assets/sounds/classes/<language>/<character>/`; the game plays these files locally.
- Use the selected game language when a localized voice pool exists; otherwise fall back to `en`.
- Load the local API key from the ignored `.env.local` file with `set -a; . ./.env.local; set +a`; use `$ELEVENLABS_API_KEY` as the `xi-api-key` header when calling `https://api.elevenlabs.io/v1/text-to-speech/<voice-id>`. Never print, commit, or copy the key into generated files or documentation.
- Use the user's assigned ElevenLabs voice IDs when generating English clips: Warrior / Eldrin `LvmvHEBEmMJBJw9UuhwO`, Wizard `Ix8C14HEHgIQkJswik2o`, Farmer `rl5Q2u6U81iTG1BKztyX`, Mysterious Priest / Matthew Schmitz `bwCXcoVxWNYMlC6Esa8u`, and Puppeteer / Dante `PrNINjunOMpMdmWJaLA1`.
- Keep generated clips consistent with the existing character voice pools and update `src/audio/SoundCatalog.lua` when adding them.

## Tests and verification

- Add or update focused tests for gameplay rules, loader behavior, events, and reusable component behavior. Include blocked movement, undo/restoration, and edge cases when relevant.
- Run the full suite with `lua tests/run.lua` after code changes, and run `git diff --check` before handing off.
- Preserve unrelated user changes in the worktree. Do not reset, clean, or rewrite map/backups as part of an unrelated task.

## Build and release

- Desktop packaging is handled by `scripts/build-desktop.sh` and the Desktop builds GitHub Actions workflow. See the README's “Publishing a new version” section for the tag-based release process.
