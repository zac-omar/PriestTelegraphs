# Priest Telegraphs

Ground telegraphs for **Azeroth Survivors** priests: the areas your spells and their effects hit, drawn on the floor around your hero.

Mind Flay's cone fills with its cooldown. Holy Nova and Psychic Scream flash when they go off. Your shield shows the burst it will release when it breaks. Kill explosions and crit splashes from your amulets show where they land.

## Install

1. Download this repository (**Code → Download ZIP**) and unzip it.
2. Put the folder in your game's `benilla-config\AddOns\` folder, and make sure it is named exactly `PriestTelegraphs`. The ZIP unpacks as `PriestTelegraphs-main`, so rename it. You should end up with:
   ```
   <game folder>\benilla-config\AddOns\PriestTelegraphs\PriestTelegraphs.toc
   ```
   With git instead: `git clone https://github.com/zac-omar/PriestTelegraphs` inside `benilla-config\AddOns\`.
3. Start the game. If the addon isn't loaded, enable it on the AddOns screen at character select.

Type **`/tele`** in game to open the options.

## Telegraphs

| Telegraph | When it shows | Size |
|---|---|---|
| **Mind Flay** | Always, filling with its cooldown, or briefly on each cast | Read live from your spell's tooltip, so every bonus is included; 120° wide |
| **Holy Nova** | Briefly on each cast (or always, with a cooldown sweep) | Read from its tooltip |
| **Psychic Scream** | Briefly on each cast (or always, with a cooldown sweep) | Read from its tooltip |
| **Shield burst** | While Power Word: Shield is up, if you have Divine Aegis (10 yd) or the Power Word: Shield amulet (8 yd); flashes when the shield breaks | Game data |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |
| **Choker of the Fire Lord** | Where an enemy you kill explodes, while you wear it | 6 yd |
| **Pendant of the Plague** | Where an enemy dies with your Shadow Word: Pain (or Devouring Plague) on it, while you wear it | 6 yd |
| **Shadowform burst** | Where an enemy dies with your Shadow Word: Pain on it, with the Shadowform capstone | 6 yd |
| **Onyxia Tooth Pendant** | Where your critical hits splash, while you wear it | From the amulet's text (5 yd, more when empowered) |
| **Custom ring** | A ring of any size around you (off by default; `/ring 10` sets it to 10 yd) | Your setting |

Telegraphs for items and talents only appear while your hero has them. Amulets are checked as you swap them during a run. The amulets' "at most N times a second" limits are read from their own text.

## Options

Each telegraph has its own settings in `/tele`:

- **Style**: *Smooth* (solid fills and outlines with a glow) or *Dots*.
- **When**: briefly on cast, or always with a cooldown fill.
- **Colours and opacity** for the outline and the fill, with presets or a colour picker.
- **Size override**, if you'd rather set a size yourself.
- **Most at once**: for the enemy effects, a limit on how many rings are drawn when a pack dies together. Off by default; set it if your frame rate drops.
- **Test** shows the telegraph for 3 seconds so you can see your changes.

If your frame rate drops, lower **Fill detail**, turn off **Glow**, or set **Most at once**.

## Commands

| Command | What it does |
|---|---|
| `/tele` | Open or close the options |
| `/ring <yards>` | Turn on the custom ring at that size (`/ring` alone toggles it) |
| `/tele debug` | Show what the addon reads: spells, sizes, cooldowns, problems |
| `/tele events` | Show the last combat hit and the items and talents it detected |
| `/tele mirror`, `/tele rotate <degrees>` | Fix a cone that points the wrong way |

## Notes

- Priest only for now. Telegraphs for other spells are entries in the `DEFS` table at the top of `PriestTelegraphs.lua`.
- The addon draws through the game's world-anchor API. It needs at least one enemy, cache or lair on the map to place shapes, so telegraphs can be missing for the first moment of a run.
- This is an unofficial fan-made addon.
