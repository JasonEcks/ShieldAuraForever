# Shield Aura Forever v1.1.0

A lightweight absorb HUD for **World of Warcraft: Forever**. Shield Aura Forever displays the player's remaining damage absorb as a single movable HUD near the character, with an optional numeric absorb value. Choose a curved or horizontal layout, segmented or solid styling, and class-labeled color presets.

Shield Aura Forever is a clean-room addon inspired by the general segmented shield-HUD concept. It does **not** include or reuse nanShield / WeakAuras source code or artwork.

## Features

- **Curved or horizontal** single-bar absorb HUD (movable in either layout)
- **Segmented or solid** styles for both shapes
- **Automatic class colors** for new installations, or selectable class-labeled color presets such as Warlock - Purple and Hunter - Green
- **Original Gold** color option, retained automatically for v1.0.1 upgrades
- **Separate saved positions** for curved and horizontal layouts
- Exact remaining absorb amount
- Tracks the player's total current absorb
- Dynamic depletion as damage is absorbed
- Optional shield-loss animation
- Configurable top-first or bottom-first drain direction
- Mirror the curve for left- or right-side placement
- Absorb value can be shown above or below the bar
- Movable and scalable HUD
- Movable standalone settings window
- Minimap button with adjustable angle and radial distance
- Blizzard Options → AddOns integration
- AddOn Compartment support
- Per-character shield calibration
- No external libraries or dependencies

## Compatibility

Shield Aura Forever is developed specifically for **World of Warcraft Forever**. This release adds HUD appearance and positioning options while retaining the existing absorb-tracking and calibration logic.

The **existing v1.0.1 behavior** was tested during the official Forever beta with:

- Priest **Power Word: Shield**
- Warlock Voidwalker **Sacrifice**
- Sacrifice values that include the current Forever spell-healing scaling
- Live absorb loss as damage is taken
- Shield expiration and removal
- Top-first and bottom-first drain directions
- Mirrored curve, animation toggle, movable HUD, minimap button, and settings persistence

The addon displays the player's **total current absorb**, so simultaneous absorb effects are combined.

## Install / update

1. Extract the `ShieldAuraForever` folder into your WoW Forever `Interface/AddOns/` folder.
2. Restart WoW or type `/reload`.
3. Type `/saf`, left-click the minimap button, or use the AddOn Compartment entry.

## Settings

Open the movable settings window with `/saf`, `/saf options`, the minimap button, or the AddOn Compartment.

Available controls include:

- Lock / unlock HUD
- HUD scale slider (0.50x–2.50x)
- Remaining absorb number toggle
- Absorb-number position: **bottom** (default) or **top**
- Top-first drain toggle (off = bottom-first)
- Shield-loss animation toggle for **curved** layouts; automatically disabled while horizontal is selected (the preference is retained)
- Mirror curve to left toggle (curved layout only)
- Horizontal bar toggle; can be positioned **above, below, or beside** the character simply by dragging while unlocked
- Solid vs. segmented style toggle
- Color dropdown: Automatic - My Class, Original - Gold, or one of nine labeled class-color presets
- Show/hide minimap button
- Minimap button distance slider (55–200 px)
- Test preview
- Shield calibration
- Reset HUD layout

The settings window can be dragged by its title area and remembers its position. The **curved and horizontal HUD positions are saved independently**, so moving one does not move the other.

**Upgrade behavior:** existing users who have v1.0.1 settings retain the historical segmented gold curve and all saved settings/position. Fresh v1.1.0 users start with the original curved segmented layout but use automatic class coloring. The original gold asset remains in the addon and can be selected by anyone. Resetting the HUD layout returns to the new-install defaults.

The **horizontal** bar's drain direction is right-first (or left-first if flipped); the curved bar retains top-first (or bottom-first if flipped). Color presets tint the HUD based on a chosen **class color**, not based on whichever spell created the absorb. This release does not add spell-specific absorb identification or Mana Shield simulation.

## Minimap button

- **Left-click:** toggle the movable settings window
- **Right-click:** open Blizzard Options → AddOns → Shield Aura Forever
- **Drag:** move the button around the minimap rim
- **Distance slider:** move the button toward or away from the minimap center
- Can be hidden from the settings window or with `/saf minimap off`

The default radial distance is 105 px. The 55–200 px range supports compact, wide, and double-ring minimap layouts.

## Shield-loss animation

When absorb is consumed on the **curved** HUD, a short fade-and-drift effect plays in the selected drain direction:

- **Top-first drain:** consumed shield drifts upward.
- **Bottom-first drain:** consumed shield drifts downward.

Animation direction is intentionally linked to drain direction so the two settings cannot conflict. Horizontal mode suppresses the loss animation until it can be verified in the Forever client; switching back to curved restores the user's animation preference.

## Known WoW Forever beta limitation

During earlier WoW Forever beta testing, the optional **bottom-first** drain direction could make the curved texture shift slightly sideways as absorb decreased. Whether the same rendering behavior persists in the official launch client is not yet verified. The default **top-first** direction does not show this behavior in testing.

Shield Aura Forever intentionally keeps a simple native StatusBar renderer rather than adding complex workarounds for a beta-client rendering quirk.

## Secret-value design

WoW Forever inherits modern secret-value restrictions. In combat, `UnitGetTotalAbsorbs("player")` may be a protected/secret number. Shield Aura Forever therefore passes absorb values directly into native Blizzard UI widgets rather than performing ordinary Lua percentage arithmetic on protected values during combat.

## Absorb support

Shield Aura Forever reads `UnitGetTotalAbsorbs("player")`, so it is not Priest-specific. Any effect that contributes to the player's total damage absorb should contribute to the displayed value.

Fresh **Power Word: Shield** and **Voidwalker Sacrifice** are explicitly recognized so their full shield can be captured automatically even when applied in combat. Out of combat, increases in total absorb also update the saved maximum for that character, improving compatibility with other absorb effects.

If several shields are active simultaneously, the HUD intentionally displays their combined total.

## Slash commands

- `/saf` or `/saf options` — toggle movable settings
- `/shieldaura` or `/shieldauraforever` — aliases for `/saf`
- `/saf blizzard` — open Blizzard Options → AddOns → Shield Aura Forever
- `/saf unlock` — unlock and drag the HUD
- `/saf lock` — lock the HUD
- `/saf scale 1.2` — resize HUD from 0.5 to 2.5
- `/saf text on|off` — toggle remaining absorb number
- `/saf textpos top|bottom` — place the absorb number above or below the aura
- `/saf flip` — reverse which end of the shield aura drains
- `/saf mirror` — toggle right-bowing / left-bowing curve
- `/saf mirror on|off` — explicitly choose mirrored state
- `/saf layout curved|horizontal` — switch display layout
- `/saf style segmented|solid` — switch bar style
- `/saf color auto|gold|warrior|paladin|hunter|rogue|priest|shaman|mage|warlock|druid` — choose color preset
- `/saf minimap on|off` — toggle minimap button
- `/saf radius 105` — set minimap button distance from 55 to 200 px
- `/saf animation on|off` — toggle shield-loss animation
- `/saf calibrate` — use current absorb as 100%
- `/saf test` — toggle the 72% visual preview
- `/saf reset` — reset all settings and calibration
- `/saf help` — print command reference

## License and contributing

Shield Aura Forever uses the **MIT License**. Anyone may use, modify, fork, redistribute, and maintain it under the terms of the license; see `LICENSE`. There is no promise that the original maintainer will immediately update it for every Forever client change.
