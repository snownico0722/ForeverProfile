<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Media/Logo-Wordmark-Dark.png">
    <img src="Media/Logo-Wordmark-Light.png" alt="ForeverProfiles" width="480">
  </picture>
</p>

# Forever Profiles

An addon for WoW Forever **1.60.1 / Interface 16001**. Save your custom graphics settings and switch between configurations using a compact window, a favorites bar, or a keyboard shortcut.

## Getting started

Copy this repository's contents into `_forever_/Interface/AddOns/ForeverProfiles` in your World of Warcraft installation. The `ForeverProfiles.toc` file must be directly inside that folder. If you added the addon while WoW was running, restart the game so it discovers the new folder. Enable **Forever Profiles** in the addon list.

1. Configure your graphics in the game's options and click **Apply**.
2. Open `/fp`, click **Save current settings**, and name the profile "High quality".
3. Configure and apply your performance settings in the game, then save a second profile.
4. Select the profile you want and click **Apply profile**.
5. Add up to three favorites with the **Favorite** button. Open the **Favorite bar** tab and enable **Show favorite quick bar** to switch with one click.

Selecting a profile lets you inspect it. Only applying a profile changes your game settings. Creating or duplicating a profile captures or copies settings without applying them. Profiles are not automatically applied at login.

## Features

- A WoW-style window with charcoal surfaces, metallic edges, gold headings, beveled buttons, and a red **Apply profile** action. **Profiles** and **Favorite bar** tabs keep profile management separate from bar preferences.
- Up to **40 profiles**, with renaming, duplication, updating, and deletion. Updating or deleting a profile requires confirmation.
- General graphics settings, separate raid/battleground settings, and the native raid settings toggle saved together, when exposed by the client.
- Render scale, antialiasing, vertical sync, and FPS limits supported by the client.
- A movable bar with **3 favorites**: drag its handle or background to move it. The **FP** button opens the main window.
- A **Lock favorite bar** checkbox in `/fp` → **Favorite bar**: fixes the bar's position and hides its drag handle while keeping its buttons usable. Uncheck it to move the bar again. The lock setting is saved between sessions.
- Bar scale adjustable from **60 to 180%** in the main window or with the mouse wheel over its handle. Buttons and text scale together. Position and scale are saved between sessions.
- **Independent width and height** in `/fp`: width from 160 to 1,000 and height from 28 to 120. Buttons share the available space without stretching the text. Dimensions are set before the overall bar scale and saved between sessions. **Auto width** restores sizing based on the number of favorites. On small screens, each dimension is constrained separately to the available space.
- **Restore previous settings** returns to the configuration captured before the last switch. This temporary backup lasts for the current session; `/reload` or restarting the game clears it.
- **Active**, **Modified**, and **Applied partially** statuses based on current values. After a partial application, the profile shows settings that differ, with their reasons in tooltips.
- A movable window that adapts to small screens and closes with Escape.
- The interface, dialogs, tooltips, shortcut labels, and messages stay **in English on every client locale**. Existing profile names are preserved as entered.
- Configurable shortcuts under **Options → Key Bindings → Forever Profiles** for the window, three favorites, and restoration. An entry is also available under **Options → AddOns**.

## Commands

| Command | Action |
| --- | --- |
| `/fp` or `/foreverprofiles` | Open or close the window |
| `/fp save High quality` | Save current settings under this name |
| `/fp apply High quality` | Apply the named profile |
| `/fp restore` | Restore the configuration preceding the last switch |
| `/fp quick` | Show or hide the favorites bar |
| `/fp list` | List profiles and their statuses |
| `/fp diagnostics` | Show the version and number of accessible settings |

## Storage and compatibility

Profiles and positions are stored in `ForeverProfilesDB`, an account-wide SavedVariable shared by characters on this installation. WoW writes this data during `/reload` or a normal logout. A crash or forced shutdown can lose recent changes.

The graphics engine uses an explicit list of supported settings, bounded values, verification after all writes, and a second delayed check. It skips unavailable options when capturing settings and reports options that become unavailable when applying a profile. Settings enforced by another addon, such as Leatrix Plus's weather settings, may therefore appear as differences.

Resolution, monitor, fullscreen, graphics backend, GPU, and HDR options are outside this version's scope. Experimental CVars and direct shadow resolution/cascade settings are not written. No minimum-quality preset is imposed: profiles restore your choices, including combat effects.

Changes in combat are attempted through the standard APIs, and client refusals are reported. Refused changes are not silently applied later. Reading back a matching value confirms the configuration value; whether an option also requires a graphics engine reload still needs to be verified in the Forever client.

## Development and testing

- `Init.lua`: version, English text helpers, and shortcut labels.
- `Graphics.lua`: settings catalog, capture, validation, application, comparison, and summary.
- `Profiles.lua`: versioned storage and profile operations.
- `UI.lua`: window, dialogs, and favorites bar.
- `Core.lua`: lifecycle, orchestration, restoration, commands, and options integration.
- `Bindings.xml`: shortcuts discovered automatically by the game's dedicated binding loader. It uses a `<Bindings>` root without the UI namespace and must not be listed in the TOC.

From the repository folder, run `python tests/run.py`. The runner requires Python and `lupa` with its Lua 5.1 runtime (`python -m pip install lupa`). It checks Lua 5.1 syntax, TOC files, binding XML, and behavior in a simulated client. Tests do not change your game settings. The optional preview (`--preview preview.png`) also requires Pillow and Windows fonts.

Real-client validation of the interface, graphics effects, combat behavior, and persistence remains to be completed using the [in-game checklist](tests/IN_GAME.md).
