# Changelog

## 1.2.0 (November 7, 2026 — accessibility and settings update)
- Rebuilt the movable settings window with a compact, searchable sidebar. Search results expose matching settings directly, and a clickable X clears search.
- Added optional independent positioning for the exact absorb-number text, plus font-size controls. Existing attached above/below positions remain available.
- Added slider **and** exact numeric entry for ranged settings, including HUD scale, horizontal width/height, font size, opacity, and minimap-button distance.
- Fixed the Blizzard AddOns minimap-distance field to display its saved value immediately while remaining editable (Enter to apply, Escape to cancel).
- Added adjustable horizontal-bar width and height while preserving proportional scaling for curved bars.
- Added **HUD opacity**, defaulting to 100% and applied to the bar and number together. Optional independent number opacity is available for improved legibility.
- Added optional combat-only HUD visibility, with unlock and test-preview overrides for editing.
- Added custom RGB/HEX colors and a native color picker while preserving automatic class colors, named presets, and Original Gold.
- Preserved existing settings, calibration, curved/horizontal positions, and original absorb-tracking logic through upgrades.
- Weakened Soul detection/glow is **not included** in this release; investigation continues separately.

## 1.1.0 (November 3, 2026 — visual customization update)
- Added horizontal and solid single-bar styles alongside the original curved segmented HUD.
- Added a class-labeled color preset dropdown. New installations default to the player's class color; **existing settings migrate to Original Gold**, preserving the v1.0.1 appearance.
- Kept the original gold textures byte-for-byte and added separate neutral tintable textures for colored and solid variants.
- Curved and horizontal HUDs remember **separate dragged positions**; horizontal starts centered below the player until moved.
- Horizontal mode disables only the shield-loss ghost animation; returning to curved mode restores the user's saved animation choice.
- Reused the existing native single StatusBar and unchanged absorb-tracking/combat-calibration logic. No aura inspection or Mana Shield estimation added.
- Added `/saf layout`, `/saf style`, `/saf color` commands and a compact in-window help pointer to make room for the visual settings.

## 1.0.1
- Fixed CurseForge/Blizzard addon packaging compatibility by adding the required base `ShieldAuraForever.toc` file matching the addon folder name.
- Retained `ShieldAuraForever_Camelot.toc` for WoW Forever-specific loading with Interface 16001.
- No gameplay, HUD, absorb-tracking, or settings behavior changed from v1.0.0.

## 1.0.0
- Initial public release of **Shield Aura Forever**.
- Curved segmented absorb-shield HUD with exact remaining absorb value.
- Confirmed current-client testing with Priest **Power Word: Shield** and Warlock Voidwalker **Sacrifice**.
- Supports WoW Forever absorb scaling by reading the client-calculated total absorb value.
- Optional shield-loss animation linked to drain direction.
- Configurable top-first or bottom-first drain, mirrored curve, and top/bottom absorb-number placement.
- Movable/scalable HUD, movable settings window, minimap controls, Blizzard AddOns settings integration, and AddOn Compartment support.
- Per-character calibration and total-absorb tracking.
- Documents the current WoW Forever beta limitation affecting bottom-first curved-bar rendering.

## 0.9.0-rc1
- Release-candidate cleanup based on the proven v0.8.0 single-StatusBar renderer.
- Added configurable absorb-number position: **bottom** (default) or **top**.
- Added `/saf textpos top|bottom` plus equivalent command aliases.
- Centralized visible version strings to avoid stale version text in the settings pages.
- Documented the current Forever beta limitation where bottom-first reverse fill can make the curved texture shift slightly as the absorb decreases.
- Removed the experimental v0.8.1-v0.8.3 rendering workarounds from the release-candidate code path.
- Retained per-character calibration, PW:S and Voidwalker Sacrifice automatic capture, linked loss animation direction, mirroring, minimap controls, and total-absorb behavior from v0.8.0.

## 0.8.0
- Linked shield-loss animation direction to drain direction: top-first drains drift upward; bottom-first drains drift downward.
- Moved the animation toggle next to the drain-direction option and clarified that its direction follows the bar automatically.
- Added per-character calibration storage so shield maxima do not leak between Priest, Warlock, or other characters.
- Added automatic full-shield capture for Warlock Voidwalker **Sacrifice** rank spell IDs used by Forever.
- Kept automatic full-shield capture for fresh Power Word: Shield.
- Added safe out-of-combat auto-calibration when total absorb increases, improving support for other absorb effects.
- Kept total-absorb behavior: simultaneous shields are combined in the displayed value.

## 0.7.1
- Standardized the complete addon identity as **Shield Aura Forever** across the folder, SavedVariables, Lua globals, frame names, media filenames, TOC callbacks, slash registration, and documentation.
- Package now intentionally behaves as a fresh addon installation rather than migrating prototype settings.
- Expanded minimap-button radial distance to **55–200 px**.
- Kept the default minimap-button distance at 105 px.
- Slash aliases are `/saf`, `/shieldaura`, and `/shieldauraforever`.
- No functional changes to absorb tracking, animation, HUD geometry, calibration, or mirroring.

## 0.6.0
- Corrected default minimap-button radius to 105 px.
- Increased the visual bow/curvature of the segmented shield display.
- Added a mirrored left-bowing texture and live **Mirror curve to left** toggle.
- Added `/saf mirror [on|off]`.
- Mirroring also applies to the shield-loss ghost animation.

## 0.5.0
- Added adjustable minimap-button radial distance.
- Added radial distance control to the movable settings window and Blizzard AddOns page.
- Added upward/fade shield-loss animation using a second native StatusBar.
- Added animation toggle and `/saf animation on|off`.
- Added `/saf radius N` / `/saf minimapradius N`.

## 0.4.0
- Added movable standalone settings window.
- Added custom minimap button and AddOn Compartment support.
- Added Blizzard AddOns launcher/preferences page.

## 0.3.0
- Added Blizzard Options → AddOns integration and live settings controls.

## 0.2.0
- Refined HUD scale/geometry, narrower chevron segments, and top-first drain default.
- Replaced frame scaling with geometry resizing to avoid drag-position snapping.

## 0.1.0
- Initial proof-of-concept secret-safe absorb HUD.
