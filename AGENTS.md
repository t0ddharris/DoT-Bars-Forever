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

## Session continuity

The `brief` and `start` skills are installed globally (`~/.claude/skills/` and
`~/.codex/skills/`, from https://github.com/t0ddharris/claude-code-skills). Run
`/start` at the beginning of a session and `/brief` at the end.

- `brief/session-brief.md` is the shared handoff for Claude and Codex. It is the
  one documented exception to the folder conventions above, because the skills
  hard-code that path. It is outside `DoTBarsForever/`, so it is never packaged.
- `brief/` is git-ignored: briefs stay local and are never committed or pushed.
  When `/brief` offers to commit, commit only the session's other work.
- `/brief` asks to run `reflect`, and `sync-skills` when `.agents/` exists. Neither
  is installed, and this project has no `.agents/`: skip both and say so in one line.
- When `/brief` commits, stage specific paths and never include
  `development/installed-backups/`, `development/savedvars-backup/` or `releases/`.
- `/start` should confirm the top open items against live state: the installed
  addon, the latest GitHub release, and whether the user has checked items in game.
