# Jak 1 freeze fix

Fixes a permanent freeze in Jak 1, most commonly right after a cutscene finishes (fuel cell victory sequences seem to trigger it the most). The game crashes at the same point in Boggy Swamp, leaving you no further way to progress

## The actual bug

This is not something this fork broke. It's in the original game's own code, `rpc-h.gc`. When the game plays a cutscene it waits for a response from the audio/streaming side, and that wait loop has no way to give up, it just assumes the response is always going to show up eventually. On real PS2 hardware that's basically always true. On Android through Wine/Box64 it isn't always true, and when the response never comes the loop just spins forever with nothing to break it.

See `rpc-h.gc.patch` in this folder for the exact diff, two loops in that file, same fix in both: give up after a lot of tries instead of looping forever. Nothing else about the game logic changes.

## What's in this folder

- `ENGINE.CGO` and `GAME.CGO`: the two files that actually contain the fix. These are compiled output from OpenGOAL's own open source `goal_src/jak1` code, built with OpenGOAL's own compiler (`goalc`), same as every OpenGOAL mod ships. No original PS2 game files (textures, models, audio, anything from your disc/ISO) are in here, that data stays on your own machine when you extract your own copy of the game, same as always. This patch only replaces two files that hold compiled game logic.
- `rpc-h.gc.patch`: the real source diff, so you can see exactly what changed, or apply it yourself and build it if you'd rather not use the compiled files.
- `apply-jak1-rpc-stall-fix.ps1`: drops the two files into your install and backs up your originals first.

## How to use it

Run the script, pointing it at your Jak 1 folder (the one with `Jak_and_Daxter_OpenGOAL\versions\...` in it):

```powershell
.\apply-jak1-rpc-stall-fix.ps1 -InstallPath "C:\Users\me\Desktop\Jak and Daxter"
```

If you patched a folder on your PC, copy it back onto your device the same way you did the first time. If your Jak 1 folder is already on the device and your PC can reach it, just point the script straight at that and skip the copy step.

Your original ENGINE.CGO/GAME.CGO get backed up next to the new ones (`.before-rpc-stall-fix` suffix) before anything's touched, so you can always put them back.

## Just Jak 1 for now

Haven't checked Jak 2 or Jak 3 for this yet, as I'm currently playing Jak 1. If you're hitting the same kind of freeze there it's probably the same bug, but there's no patch for it yet.
