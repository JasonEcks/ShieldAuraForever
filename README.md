# Shield Aura Forever v1.0.1

A lightweight absorb HUD for **World of Warcraft: Forever**. Shield Aura Forever displays the player's remaining damage absorb as a curved segmented gold shield aura near the character, with an optional numeric absorb value.

Shield Aura Forever is a clean-room addon inspired by the general segmented shield-HUD concept. It does **not** include or reuse nanShield / WeakAuras source code or artwork.

## Features

- Curved segmented absorb-shield HUD
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

## Confirmed WoW Forever testing

Shield Aura Forever has been directly tested in the current WoW Forever client with:

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
- Shield-loss animation toggle; animation direction follows drain direction automatically
- Mirror curve to left toggle
- Show/hide minimap button
- Minimap button distance slider (55–200 px)
- Test preview
- Shield calibration
- Reset HUD layout

The settings window can be dragged by its title area and remembers its position.

## Minimap button

- **Left-click:** toggle the movable settings window
- **Right-click:** open Blizzard Options → AddOns → Shield Aura Forever
- **Drag:** move the button around the minimap rim
- **Distance slider:** move the button toward or away from the minimap center
- Can be hidden from the settings window or with `/saf minimap off`

The default radial distance is 105 px. The 55–200 px range supports compact, wide, and double-ring minimap layouts.

## Shield-loss animation

When absorb is consumed, a short fade-and-drift effect plays in the selected drain direction:

- **Top-first drain:** consumed shield drifts upward.
- **Bottom-first drain:** consumed shield drifts downward.

Animation direction is intentionally linked to drain direction so the two settings cannot conflict.

## Known WoW Forever beta limitation

In the current WoW Forever beta client, the optional **bottom-first** drain direction can make the curved texture shift slightly sideways as absorb decreases. The default **top-first** direction does not show this behavior in testing.

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
- `/saf minimap on|off` — toggle minimap button
- `/saf radius 105` — set minimap button distance from 55 to 200 px
- `/saf animation on|off` — toggle shield-loss animation
- `/saf calibrate` — use current absorb as 100%
- `/saf test` — toggle the 72% visual preview
- `/saf reset` — reset all settings and calibration
- `/saf help` — print command reference

## License and contributing

Shield Aura Forever uses the **MIT License**. Anyone may use, modify, fork, redistribute, and maintain it under the terms of the license. There is no promise that the original maintainer will immediately update it for every Forever client change.

## License

MIT. See `LICENSE`.
