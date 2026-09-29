# Changelog

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
