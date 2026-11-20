# Just DoT Timer revision 0.2.0

Target: WoW Forever, interface 16001. Canonical reference: JBurlison/WoWAddonAPIAgents, installed plugin 2.7.0. Bundled API snapshot: 1.60.1.70862, commit 9dc84f0d3bbae1768ac3405b3716000bd93eda06. Fresh upstream pin for handwritten loading/timer details: 1.60.1.70959, commit 3d8abb1da73acd38e412e24fb3f99454a6392346.

| ID | Required behavior | Acceptance |
|---|---|---|
| REQ-01 | Active DoTs only, separately bound to target, targettarget, focus | Changes/expiry clear old bars; no live placeholders |
| REQ-02 | Fix forbidden SAB integration and frozen display | Restricted live descendants never registered with SAB; native duration bindings drain |
| REQ-03 | Animated preview | Editing samples and options sample count down; SAB can render only unrestricted samples |
| REQ-04 | Movable/resizable bars | Independent and stacked layouts persist; native resize grip replaces slash |
| REQ-05 | Minimap button | Opens options; right-click toggles layout; draggable position persists; hide setting |
| REQ-06 | Popup spell tray, drag placement | Class/custom DoT entries can be dragged onto selected unit's layout; no combat placement |
| REQ-07 | Up/down growth | Per-unit persisted direction affects stack engine and new free placements |
| REQ-08 | SAB/Forever visual style | Native window shell, buttons, fonts, gold headings and dark insets |
| REQ-09 | Options, localization, controller assessment | Settings entry remains; English fallback catalog; no unverified controller support claim |
| REQ-10 | Preserve project convention and saved data | development/, docs/, releases/; existing character settings migrate |

UI choice: implement corrections directly; user explicitly requested SAB/Forever styling after the original screenshot. No separate mock-up requested. Runtime testing choice: **Witchcraft** (user-authorized, including its addon, helper addons and local daemon; see local developer notes (local developer notes, not published)). The user performs gameplay and combat. Local simulation is not real-client acceptance.

| REQ-11 | Plain bar styles (2026-11-17) | Stock textures Flat / Classic / Raid / Skill on previews and live bars; SAB support removed at the user's request |

Live liquid is not provided. Live aura bars are locked to addon code and `C_UnitAuras` refuses target auras in combat (tested in game 2026-11-17). The user chose native fills over a cast-estimated timer, and SAB support was removed.

Controller assessment: timers/preview art are decorative. Options, tray selection, toggles and close use ordinary native controls and preserve mouse/keyboard input. Drag placement and resize currently require pointer input; native directional controller acquisition/navigation and hardware operation are unverified. No settings/bindings are changed to force controller input.

Localization scope: English fallback only; other language translations and expanded-text rendering remain untested. Fonts use the client's `STANDARD_TEXT_FONT` with FRIZQT as fallback.
