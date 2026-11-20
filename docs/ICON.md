# Addon icon

Approved 2026-11-20: three tightly stacked rectangular bars with slightly rounded corners, turquoise/amber/violet fills at different stages, and a dark navy background. No lettering or addon name appears in the artwork.

- Approved master: `development/artwork/timer-bars-concept-v2.png` (built-in image editor).
- Runtime asset: `DoTBarsForever/Media/TimerBars.tga`, 256 x 256 uncompressed 32-bit BGRA, top-left origin.
- Rebuild texture: `powershell -File development/scripts/build-icon.ps1`.
- Integration: `Launcher.lua` normal texture and TOC `IconTexture`. Minimap positioning, input handlers, saved layouts and aura widgets are unchanged. Artwork is decorative; no additional controller focus stop or localized text is needed. Existing controller operation is not certified by this change.

## Evidence and verification

Target: WoW Forever, interface 16001. Canonical installed WoWAddonAPIAgents 2.8.0 snapshot: 1.60.1.70938, source commit `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`.

The Forever generated widget catalog declares `SimpleButtonAPI:SetNormalTexture(asset: TextureAsset)` in `SimpleButtonAPIDocumentation.lua`, line 432, with `CheckAllowChangeParent` and `SecretArguments: AllowedWhenUntainted`. This edit changes only the texture supplied to the existing addon-owned minimap button; it does not touch restricted aura descendants. Declaration evidence is not runtime permission or operation testing.

The canonical TOC guide documents `IconTexture`, but labels itself a historical Retail reference. Attempted upstream fallback retrieval of the pinned AddOnList consumer failed (guessed raw paths returned 404; tree lookup had a DNS failure). Forever addon-list consumption remains to be verified in game; no newer snapshot or successful source trace is claimed.

Validation: Lua syntax checks and 118 simulated assertions passed via `npm --prefix development test`. These are not in-game verification. Existing project preference is Witchcraft in-game; no game installation or runtime interaction was performed for this artwork change. Check the minimap at normal UI scale and the AddOns list after installing the release and restarting the client; confirm click/drag behavior and saved position remain intact.

## Collaboration

Worktree creation was attempted but this directory is not a Git repository. Production edits for this task are limited to the new `Media/TimerBars.tga`, one texture reference in `Launcher.lua`, and TOC icon metadata. The release ZIP is rebuilt from the current shared source. No Git initialization, unrelated source rewrites, or game installation was performed.
