# Shield Aura Forever v1.1.0 — Verification checklist

Use this checklist to verify the v1.1.0 customization options, saved-setting behavior, and absorb display after installing or upgrading. If anything fails, collect a screenshot and any BugSack/BugGrabber error text. **Do not delete SavedVariables** while upgrading.

## Install and first check

1. Back up the existing `WTF/Account/.../SavedVariables/ShieldAuraForever.lua` file (or the applicable SavedVariables file) before replacing the addon folder.
2. Replace `Interface/AddOns/ShieldAuraForever/` with v1.1.0, preserving saved settings. Run `/reload`.
3. Open `/saf`. Check whether the settings window and dropdown load without Lua errors.
4. On an **existing v1.0.1 account**, confirm the curved bar is still **gold, segmented, at its old position**. On a fresh profile, verify that it is curved/segmented and colored for the current class.

## Visual tests (use `/saf test` if you cannot cast a shield)

5. Unlock the HUD. Drag the curved bar to one spot, then set **Horizontal bar** and drag it above or below the character. Switch back to curved and confirm its former spot is restored. Switch to horizontal again and confirm its separate position is restored. Run `/reload` and repeat.
6. Test both **Segmented** and **Solid** in curved and horizontal layouts. Check all variants at 0.5x, 1x, and 2.5x scale if possible.
7. In the color dropdown choose **Original - Gold**, **Warlock - Purple**, **Hunter - Green**, and **Automatic - My Class**; confirm the menu text matches the tint. Test after `/reload`, especially with a new character.
8. Switch to horizontal, choose top/bottom absorb-number placement, and confirm the number stays legible. Use **Flip** to test right-first/left-first drain. The bar should be movable anywhere, including above/below the character.
9. Confirm the **shield-loss animation option is disabled in horizontal mode**, and remains enabled if you switch back to curved with the preference on.
10. Click **Reset HUD Layout**: appearance/positions should reset; shield calibration and minimap controls should remain. Test `/saf reset` only after backing up SavedVariables because it clears addon settings/calibration.

## Functional regression (best with a shield spell)

11. Cast a shield out of combat and in combat. Confirm the numerical total and bar decline with damage; verify normal expiry/removal. Test curved and horizontal.
12. Check minimap button, AddOn Compartment, settings panel, HUD locking/unlocking, calibration, and `/saf test` toggling.
13. Record client version/build and any texture glitches, UI errors, unusual disappearance, or positioning behavior.

**Not added in 1.1.0:** Mana Shield estimation, friendly-shield identification, school-specific potion colors, and two-sided HUDs. Those require later in-client verification.
