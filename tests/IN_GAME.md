# In-game validation for WoW Forever

Observed target: 1.60.1, build 70707, Interface 16001. Record `/fp diagnostics` before each test session when the Forever client updates.

- [ ] Cold launch: addon appears, no Lua errors at login, and no automatic changes to graphics settings.
- [ ] `/fp`, Options → AddOns, and the opening shortcut work. Escape closes the action menu, dialogs, and main window.
- [ ] WoW-style frame, metallic borders, gold titles, beveled buttons, and red Apply action remain legible at different resolutions and UI scales.
- [ ] All interface labels, messages, tooltips, and shortcuts stay in English on both English and French clients. Saved profile names retain their original text.
- [ ] Profiles and Favorite bar tabs switch without changing game settings. Long profile lists and summaries remain scrollable.
- [ ] The profile action menu opens Rename, Duplicate, and Delete. It dismisses on outside click, profile selection, tab switching, and closing the window.
- [ ] General and Raid / instance summary tabs show the saved values for the appropriate mode; common settings remain visible.
- [ ] Create two different native configurations after clicking Apply, capture each, then check the values after switching back.
- [ ] Repeated switches faithfully restore detailed options, custom values, antialiasing, render scale, and FPS limits.
- [ ] Separate raid/battleground settings and their native enable toggle work outdoors and in an instance.
- [ ] Three favorites maximum. The handle and background move the bar without opening the window; FP opens the window and favorite buttons apply their profiles in one click.
- [ ] Favorite slot summaries open the corresponding profile without applying it or changing favorite order.
- [ ] Bar scale: slider 60–180% and mouse wheel over the handle resize buttons and text together. Scale survives refresh, changes to favorites, and reload.
- [ ] Independent dimensions: width keeps height and font size; height keeps width. Test three favorites at minimum width/height, 180% scale, and on a small screen. Full names remain available in tooltips.
- [ ] Auto width follows favorite count and lock state. Manual width remains fixed when favorites or locking change; dimensions survive reload and restart.
- [ ] Locking hides the handle without a blank gap, stops background dragging, and keeps FP/favorite buttons usable. Unlocking restores movement; the setting survives reload and restart.
- [ ] Restore previous settings returns to the configuration preceding the last switch. Applying an already active profile does not overwrite this backup.
- [ ] Rename and duplicate work; updating/deleting can be confirmed or canceled. Switching profile selection while a dialog is open does not change the dialog's target.
- [ ] Native option changes update profile status without overwriting saved settings.
- [ ] With Leatrix Plus enforcing weather, partial application and readable differences/reasons are displayed.
- [ ] In-combat switches cause no taint. Refused settings are reported, and combat cues remain readable according to the saved profile.
- [ ] Identify options requiring an additional operation despite a matching CVar value.
- [ ] Reload, relog, and normal shutdown/restart preserve profiles, favorites, dimensions, locking, and positions. The temporary restoration backup resets.
- [ ] With window/bar hidden, no permanent update loop runs. Compare FPS in the same scene.
