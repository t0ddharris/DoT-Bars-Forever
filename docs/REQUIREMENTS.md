# DoT Bars Forever revision 0.2.1

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


## 2026-11-20 review follow-up

The user accepted direct implementation of the review and requested adaptive options sizing plus a lower-right grip. Existing visual style is retained; no separate mock-up is needed. Witchcraft remains the established runtime route, but its connection is currently disconnected.

| ID | Required behavior | Acceptance |
|---|---|---|
| REQ-12 | Retire removed custom aura groups | Removal and profile switching stop obsolete stacked tracking |
| REQ-13 | Preserve manual layouts during tray edits | Add/remove/reorder/re-enable preserves geometry on all units; confirmed Arrange acts on one unit only |
| REQ-14 | Bind reset confirmation to profile identity | Changing profile before acceptance cannot reset another profile |
| REQ-15 | Adaptive, resizable options | Screen fit, lower-right grip, vertical scrolling, character-specific saved size |
| REQ-16 | Clear option scope and bounded labels | Selected unit highlighted; shared profile visible; independent dimensions use handles; full long names available in tooltips |

API evidence for new ordinary-window work: canonical plugin 2.8.0 generated Forever catalog, build 1.60.1.70938, commit bebcb6bf309cf41b41bd74f8ca651e6a105b2676. SetResizeBounds and SetScrollChild contracts were inspected; declarations do not establish runtime permission or visual fidelity. Existing ButtonFrameTemplate, UIPanelScrollFrameTemplate and resize-grip assets are reused. Upstream Forever head resolved to 734f065329cff4992835b01a84f210a297db91b6 (1.60.1.71037); no new upstream fallback was needed. Historical aura-source pins above remain historical.

Controller plan: decorative preview/banner do not take focus. Native buttons, sliders, scrollbars and close retain pointer behavior; Escape closes through UISpecialFrames. New Arrange uses the existing confirmation controls. Grip requires pointer drag; native directional focus acquisition, scrolling and gamepad activation are not verified or claimed. All new visible strings use the English fallback catalog; expanded-language rendering is not verified.


## Approved redesign implementation (2026-11-20)
REQ-17: approved native metal/charcoal shell, top tabs, grouped Layout controls, Appearance-only preview and persistent footer. REQ-18: fixed logical dimensions; slider and corner grip scale the entire frame, retaining top-left anchor, per-character preference and screen fit. REQ-19: one-time class-character copies, preserving source/custom profiles and manual geometry, realm collision handling and explicit sharing. In progress; native visual acceptance pending. Controller grip remains pointer-based; directional navigation unverified. English localization and Settings entry retained.

Implementation uses the existing canonical plugin 2.8.0 Forever catalog at bebcb6bf309cf41b41bd74f8ca651e6a105b2676 (1.60.1.70938): SimpleFrameAPI:SetScale and SimpleScriptRegionAPI:GetLeft declarations checked. These do not establish runtime permissions. Native shell follows the bundled FOREVER-NATIVE-ART reference; the linked DialogTemplates.xml at 9dc84f0d3bbae1768ac3405b3716000bd93eda06 was inspected to confirm DialogBorderTemplate has useParentLevel and BACKGROUND sublevel -5, so it does not cover parent text. This is a narrow source fallback for template composition, not a live rendering pass. All new strings use Locale.lua; English only. Pointer drag, native tab buttons, sliders, entry fields and Escape close are preserved; controller acquisition/navigation unverified.
