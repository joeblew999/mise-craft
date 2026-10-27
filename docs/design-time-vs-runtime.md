<!-- Lineage: written by hand. The proposal for separating design time from runtime; nothing here is built yet. -->

# Design time vs runtime

**Status:** proposed, not built. Agree it with the owner before changing anything.

## The two

- **Design time** is what the repo says should exist, identical on every machine, changed only by
  editing and committing: `apps.json` (including its fetched `upstream` facts), the tasks and
  scripts, and everything generated from `apps.json`. Generation depends on `apps.json` alone, never
  on the state of the machine.
- **Runtime** is what exists on one machine now, changed only by running tasks (each with an undo),
  never committed: installed CLIs and apps, their registration with macOS, servers registered in
  Claude Code and Claude Desktop, running apps, token files, documents. `status` is the read-only
  view of runtime against design time.
- **The boundary:** design-time files never read runtime state; runtime tasks read design-time files
  but never edit them.

## Where they are mixed today

1. `.mcp.json` is committed (design time), but Claude Code treats it as "start these servers here"
   (runtime). That is problem 12.
2. A change, reverted before commit, had `gen` read what's installed and the install tasks call
   `gen`: mixing in both directions.
3. `checked` in `apps.json` records a runtime observation ("worked on this machine on this date")
   in design-time data. Probably fine as a record of evidence; owner to decide.

## Proposal

- **Design time** (committed; generated from `apps.json` only): `apps.json`, `mise.toml`, `mise.lock`,
  and one definitions file for every checked app's headless and live servers, which Claude Code
  never reads directly (it replaces `mcp-live.json`). Design-time tasks get their own prefix, such
  as `registry:gen` and `registry:fetch`.
- **Runtime** (per machine, each with an undo): `<app>:install` / `:uninstall` install the app and
  register its headless server here; `<app>:watch` / `:unwatch` register its live server;
  `desktop:install` / `:uninstall` the same for Claude Desktop. `.mcp.json` becomes a runtime file,
  written only by runtime tasks and not committed, listing servers for the apps installed here, so
  VS Code still sees them.

## Open questions for the owner

1. Does this split match yours, in particular `.mcp.json` becoming an uncommitted runtime file and the
   `registry:` prefix for design-time tasks?
2. Is `checked` acceptable as design-time data?
