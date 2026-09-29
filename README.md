# Shield Aura Forever

A lightweight curved absorb-shield HUD for World of Warcraft Forever.

Shield Aura Forever displays the player's remaining damage absorb as a curved segmented gold shield aura near the character, with an optional numeric absorb value.

Shield Aura Forever is a clean-room addon inspired by the general segmented shield-HUD concept. It does not include or reuse nanShield / WeakAuras source code or artwork.

## Download

The recommended installation method is through CurseForge:

https://www.curseforge.com/wow/addons/shield-aura-forever

## Features

- Curved segmented absorb-shield HUD
- Exact remaining absorb value
- Dynamic depletion as damage is absorbed
- Optional shield-loss animation
- Configurable drain direction
- Mirrored left/right curve
- Absorb value can be shown above or below the bar
- Movable and scalable HUD
- Movable settings window
- Minimap button with adjustable position
- Blizzard AddOns settings integration
- Per-character shield calibration
- No external dependencies

## Tested in WoW Forever

Currently tested with:

- Priest — Power Word: Shield
- Warlock — Voidwalker Sacrifice

Shield Aura Forever reads the absorb value calculated by the WoW Forever client rather than reproducing individual spell formulas, so normal scaling and modifiers are reflected automatically.

## Known visual limitation

When using Bottom First drain direction in the tested WoW Forever beta client, the curved bar may shift slightly as the shield is consumed.

Top First, which is the default, does not exhibit this behavior in testing.

The underlying cause has not been confirmed.

## Commands

`/saf` — open the settings window

`/saf help` — show command help

## Contributing

Issues, fixes, forks, and improvements are welcome.

The project is intentionally kept lightweight and straightforward so others can maintain or modify it if needed.

## License

Shield Aura Forever is released under the MIT License.
