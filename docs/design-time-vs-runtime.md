<!-- Lineage: written by hand. The design time / runtime split: what is built, and what is still open. -->

# Design time vs runtime

## The two

- **Design time** is what the repo says should exist, identical on every machine, changed only by
  editing and committing. It lives in `design/`: what you edit (`design/apps.json`) and the pipeline
  that turns it into files (`design/fetch`, `design/gen`, defined in `design/mise.toml`). It never
  reads the state of the machine.
- **Runtime** is what exists on one machine now, changed only by running tasks (each with an undo),
  never committed: installed CLIs and apps, their registration with macOS, servers registered in
  Claude Code and Claude Desktop, running apps, token files, documents.
- **The boundary:** everything the pipeline produces lands at the repo root (`mise.toml`,
  `mise.lock`, `.mcp.json`, `mcp-live.json`), where runtime reads it. Runtime never edits what
  design time produced.

## The pipeline (built)

Its stages run in this order, each reading only what the stages before it wrote:

1. **fetch** (`mise -C design run fetch`): GitHub → the `upstream` blocks in `design/apps.json`.
2. **edit**: you → the hand-written facts in `design/apps.json`.
3. **validate**, 4. **generate**, 5. **lock** (`mise -C design run gen`, always together, in order):
   check `design/apps.json`, write the root's `mise.toml`, `.mcp.json` and `mcp-live.json`, then
   run `mise lock`.

## Still open

1. **`.mcp.json` is design-time output that Claude Code treats as runtime registration** ("start these
   servers here"), so a checked app that isn't installed shows as a failed server (problem 12).
   Proposal: make `.mcp.json` a runtime file, written by the install tasks and not committed. Not
   built; agree it with the owner first.
2. **A runtime install rewrites `mise.lock`**, a design-time file (problem 25).
3. **`status` reads `design/apps.json` directly** (for each app's latest version, checked state and
   port), where every other runtime task reads only what the pipeline put at the root. Allowed by
   the boundary as written; the alternative is for `gen` to write a small summary at the root.
4. **`checked` in `design/apps.json`** records a runtime observation ("worked on this machine on this
   date") in design-time data. Probably fine as evidence; owner to decide.
