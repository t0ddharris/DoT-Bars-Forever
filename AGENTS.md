# DoT Bars Forever development

Follow the shared folder conventions: runtime addon in `DoTBarsForever/`, tooling and
tests in `development/`, docs in `docs/`, packaged ZIPs in `releases/`.

The user's canonical source for WoW APIs and client-specific guidance is
https://github.com/JBurlison/WoWAddonAPIAgents . Consult its Forever references
and generated API catalogs first. Record the target snapshot and distinguish
source declarations from permitted runtime behavior. Use upstream source only
to fill explicit gaps, and identify that fallback in development notes.

Target WoW Forever, not Classic Era or Retail. Preserve existing saved layouts.
Never hand restricted aura-frame descendants to Smooth Animated Bars' external
renderer: its asynchronous texture updates can encounter forbidden objects.
Synthetic preview widgets must remain separate from live aura widgets.

Run `npm --prefix development test` and rebuild the release ZIP after changes.
Simulated tests are not in-game verification; report that distinction clearly.
