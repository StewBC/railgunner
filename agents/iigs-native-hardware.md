# Native IIgs hardware validation

Status: pending user validation. Audio is deferred. Emulator component proofs
and timing results do not establish hardware acceptance.

Use the packaged native S16 from `build/iigs/native-game-package/RAILGUNNER`, preserving
ProDOS type `$B3` and auxiliary type `$DB03`. The 800 KiB
`railgunner-iigs-transfer.2mg` contains the same executable on a ProDOS volume.
`railgunner-iigs.2mg` is a private copy of the caller's supplied GS/OS template
with System/Start replaced; it is not an independently supplied GS/OS release.
`railgunner-iigs-800K.po` is the same non-bootable transfer volume in raw
ProDOS order (819,200 bytes). Mount it under an existing GS/OS system.
Packaging checks all three volumes and extracts/compares the executable bytes.
The emulator speed option changes metadata/configuration only, not the game
executable. Target 7.159 MHz or faster; stock 2.8 MHz is currently unplayable.

Record the machine's ROM revision, installed RAM, accelerator model/speed, GS/OS
version and the build manifest's binary SHA256 and timing profile. Initial
emulator testing uses NTSC and 8 MiB expansion RAM; PAL and a hardware minimum-RAM
configuration have not been established.

For each stock/ZipGS/AppleSqueezer configuration being evaluated:

1. Launch from GS/OS. Check hires title art, text menu, high-score colors,
   Story (S), Instructions (I), and return to the menu. Space is fire/start;
   the hires art page first advances to the text menu.
2. Start a game. Check score, wave, pilots, deployment, all rails and bullets.
   Use arrows or WASD and Space. Release each independently; check several
   simultaneous holds, quick taps, and held-key behavior across transitions.
3. Play a busy later level. Look for sprite flashing, tears, random glyphs,
   stale object fragments and incomplete HUD changes. Check both sides of
   moving sprites, overlapping objects, screen edges and teleports.
4. Exercise death/respawn, mines, parcels, wave banners, game over, high-score
   entry and restart. Confirm a new game preserves the current high-score table.
5. Escape supplies the game's Run/Stop action. Ctrl-Q quits the application.
   Check the return to GS/OS, original display/palette/border restoration,
   keyboard operation in the caller and a second launch/quit cycle.

The installed GSSquared keyboard model can strand the third event in a burst
until another host event occurs. The port does not insert fake events to hide
this; real hardware burst/release behavior is an explicit check. Keys held
before application keyboard takeover may require release and repress.

Report the build hash, configuration, scene and observed symptom together.
Accelerator fallback and occasional late-frame tearing are approved; recurring
sprite flashing is not. Use the current beam-renderer handoff as the authority. Hardware acceptance remains pending until the user
reports these results.
