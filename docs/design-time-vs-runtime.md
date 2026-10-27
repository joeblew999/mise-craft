<!-- Lineage: written by hand. The design time / runtime split: what is built, and what is still open. -->

# Design time vs runtime

## The two

- **Design time** is what the repo says should exist, identical on every machine, changed only by
  editing and committing. It lives in `design/`: what you edit (`design/apps.json`) and the pipeline
  that turns it into files (`design/fetch`, `design/generate`, and the validate and lock stages
  defined in `design/mise.toml`). It never
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
3. **validate**, 4. **generate**, 5. **lock**: check `design/apps.json`, write the root's
   `mise.toml`, `.mcp.json` and `mcp-live.json`, then run `mise lock`. Each is its own task in
   `design/mise.toml` and depends on the one before it, so running any of them runs the earlier ones
   first; `mise -C design run gen` runs all three.

## Proposal: family, apps, servers (not built)

Sorting the problems by what each is about shows four axes: the Craft **family** (true of every app:
2, 3, 6, 18), one **app** (where it differs: 5, 13, 14, 15, 16, 17, 24), the **host** the servers
are registered in (Claude Code, Claude Desktop, VS Code; 7-12), and the **toolchain** (mise: 1, 20,
25). Today `design/apps.json` holds the first two in one object and repeats the family 13 times:
`repo`, both download patterns and the CLI name are identical for all 13 apps once `{id}` is filled
in, and the bundle and process name for all 8 checked apps once `{name}` is (measured 2026-10-27).

**Design files (design/):**

- `family.json`, written by hand: every field once, as the default for all apps, with `{id}`,
  `{name}`, `{version}` and `{port}` placeholders. Repo and download naming, CLI name, bundle and
  process name, how the headless server starts (`<cli> mcp`), the default live connection
  (`--connect 127.0.0.1:{port}`), how the desktop app takes its control port (`--control {port}`),
  and the port policy (one fixed port per checked app, never derived from list position).
- `apps.json`, one entry per app, each block with exactly one writer:
  - **you:** `id`, `name`, `version` (exact), `port` (checked apps), `overrides` (only where the app
    differs from the family, so every uncommon thing is literally listed under `overrides`),
    `first_step` and `opens_with` where they matter, and `problems` (numbers into
    `docs/problems.md`; the prose `limits` and `notes` go there, described once);
  - **`fetch`:** `upstream`;
  - **`check`** (new stage, runs the installed app): `observed`, meaning the version and date
    checked, the usage line, bundle and process name, the headless and live tool lists, and whether
    the CLI can confine files or launch the app.
- An app's full description is `family` with the app's `overrides` laid over it: objects merge,
  arrays and values replace, placeholders are filled last.

**Not a hosts file.** Hosts differ in behaviour, not data: Claude Code is driven through
`claude mcp`, Claude Desktop by editing a JSON file it must not have open. A data file can't make
those the same, so each host stays code (its own tasks, with lineage and problem numbers).

**What `generate` writes to the root:** `mise.toml`, then `mise.lock` (lock stage), and one neutral
`servers.json`: the headless and live command of every checked app. It no longer writes
`.mcp.json` or `mcp-live.json`.

**What runtime does per host:** Claude Code's `.mcp.json` becomes a runtime file, not committed,
written by `<app>:install` and `<app>:uninstall` from `servers.json` for the apps installed here
(fixes 12); `<app>:watch` takes its live server from `servers.json`; `desktop:install` writes the
installed apps' servers. Installs run in mise's locked mode, so runtime never rewrites `mise.lock`
(fixes 25).

**Validation:** schema files for `family.json` and `apps.json` define every field (replacing the
prose in `"//"`), and stage 3 checks against them, plus the cross-field rules: exact versions (1),
unique ports (18), a checked app has `port`, `observed` and a usable bundle.

**Every problem against it:** 1 schema (exact versions); 2, 3 family install convention plus the
unpack hook; 4, 19 process; 5, 14, 15, 16 app `problems`; 6 host code (live servers through
`mise exec`); 7, 8, 9 Claude Code host code (live servers only on watch, marker); 10, 11 Claude
Desktop host code; 12 runtime `.mcp.json`; 13 a `files` decision in `family.json` (read and write
roots, passed by `generate` to apps whose `observed` says they can confine files), the folder to
be chosen by the owner; 17 app `overrides` (headless `--headless`); 18 explicit ports plus
validation; 20, 22 README; 21, 23 owner; 24 `observed.usage`, with `check` trying `<cli> mcp --help`
as well; 25 locked installs.

**Building it, one step at a time, each committed only after its proof:**

1. `family.json` and the new `apps.json` shape, converted by script, not by hand; `generate`
   merges them. Proof: `mise.toml` byte-identical, and every server identical to today's.
2. Problem numbers replace `limits` and `notes`, with any text not yet in `docs/problems.md` moved
   there first.
3. `servers.json`; runtime `.mcp.json` from install and uninstall; watch and desktop read
   `servers.json`. Proof: the headless and live servers, watch and the Desktop round trip as
   today, plus an uninstalled app no longer showing as a failed server.
4. Locked installs. Proof: an install leaves `mise.lock` untouched.
5. The schema files and validation against them.
6. `check` filling `observed`, then the seven unchecked apps checked with it.

Problem 13 needs the owner: which folders the headless servers may read and write.

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
