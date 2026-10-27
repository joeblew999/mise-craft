<!-- Lineage: written by hand; Claude Code reads it through CLAUDE.md. -->

# mise-craft

Install the apps of the [Craft App Suite](https://getartcraft.com/apps) with
[mise](https://mise.jdx.dev), and let AI agents drive them over MCP while you watch the desktop app
update. Everything runs from this repo's mise tasks, and everything they set up has a task that
removes it. macOS only for now; `mise run status` shows which apps are checked end to end.

## Get started

You need macOS, [mise](https://mise.jdx.dev/getting-started.html) and
[Claude Code](https://code.claude.com/docs).

```sh
git clone https://github.com/joeblew999/mise-craft
cd mise-craft
mise trust                  # mise asks before it uses a repo's config
mise install jq             # the tasks use it
mise run cadcraft:install   # the CADCraft CLI and desktop app, about 120 MB to download
mise run cadcraft:watch     # optional: let Claude drive the CADCraft window
claude                      # approve the project's MCP servers when asked
```

Then ask Claude to draw something in CADCraft.

mise downloads through GitHub's API. If it hits GitHub's rate limit, run
`export GITHUB_TOKEN=$(gh auth token)` first, or set `github.credential_command` in your global
mise config (mise ignores it in a project file).

## Use it

`mise tasks` lists the runtime tasks:

| Task | Does | Undone by |
|---|---|---|
| `status` | Shows each app's pinned and latest version, whether the pinned version is checked end to end, its control port, whether its CLI and desktop app are installed, whether it's running, and its MCP servers | (read-only) |
| `<app>:install` | Installs the app's CLI and desktop app, then `claude:sync` | `<app>:uninstall` |
| `<app>:uninstall` | Unwatches the app, removes every installed version of both, unregisters the app from macOS, then `claude:sync` | `<app>:install` |
| `<app>:watch` | Adds the app's live MCP server to Claude Code, for this project | `<app>:unwatch` |
| `<app>:unwatch` | Removes it | `<app>:watch` |
| `apps:install`, `apps:uninstall`, `apps:watch`, `apps:unwatch` `<app>...` | The same for several apps at once | each other |
| `claude:sync` | Writes `.mcp.json` with the headless server of each checked app installed here | (rerun after any change) |
| `desktop:install` | Makes Claude Desktop's servers from this repo match `.mcp.json` | `desktop:uninstall` |
| `desktop:uninstall` | Removes exactly those servers | `desktop:install` |

**MCP servers in Claude Code.** `.mcp.json` holds a headless server for each checked app installed
on this machine: it works on a document with no window, so no app opens. It's a runtime file, not
committed, written by `claude:sync` whenever you install or uninstall an app, so it never lists an
app you don't have. To watch Claude work in a desktop app, `<app>:watch` adds that app's live server
from [servers.json](servers.json) in Claude Code's local scope, so it's yours only; it loads in the
next session or through `/mcp`. Claude Code asks you to approve the project's servers the first
time, and `claude mcp list` shows whether they connect.

**Claude Desktop.** Quit it, run `mise run desktop:install`, then reopen it.

## Design time

[design/](design) holds the registry, [design/family.json](design/family.json) and
[design/apps.json](design/apps.json), and the six stages that turn it into the files runtime reads.
Everything the stages produce lands at the repo root. They run in this order, as
[design/mise.toml](design/mise.toml) lists them:

```sh
mise -C design run fetch           # 1. GitHub → every app's upstream block in apps.json
mise -C design run check cadcraft  # 2. an installed app → its observed block in apps.json
                                   # 3. record: the maintainer edits family.json and apps.json
mise -C design run gen             # 4-6. validate, generate mise.toml and servers.json, lock
```

Stages 1 and 2 bring in facts from outside, so they run only when asked, and what they wrote is
reviewed before stage 3. Stage 2 is the only one that runs anything on the machine: it needs the app
installed, and opens it to list its live tools. Stages 4 to 6 are tasks of their own, and each
depends on the one before it, so running any of them runs the earlier ones first: nothing can be
locked before it is generated. Runtime tasks read what the stages produced and never change it:
installs run with `--locked`, so they never write `mise.lock`.

## The apps

What this repo knows about the Craft apps is in two files:

- **[design/family.json](design/family.json): what every Craft app shares,** defined once with
  `{id}`, `{name}` and `{port}` placeholders: the repo and download naming, the CLI's name, the
  bundle and process name, how the headless server starts and the usual way the live server
  connects.
- **[design/apps.json](design/apps.json): each app, and only what is its own.** Written by hand:
  its id, name, the exact version pinned, its control port once checked, `overrides` (only where it
  differs from the family, so every uncommon thing about an app is listed there), `problems`
  (numbers into [docs/problems.md](docs/problems.md)) and `notes`. Written by `fetch`: `upstream`,
  its description, latest release, published platforms, MCP docs and the port its own docs use.
  Written by `check`: `observed`, the evidence of checking it end to end, such as its usage line,
  bundle, tools only its live server has, and whether file access can be confined (what a fresh app
  holds is recorded by hand). The file's
  `"//"` lines explain each field.

An app's full description is the family with its `overrides` laid over it. Each app's CLI,
`<app>-cli`, runs a headless MCP server with `<app>-cli mcp`. The
[ArtCraft Launcher](https://github.com/storytold/craft-launcher) isn't used here: it installs the
desktop apps into `/Applications` from a GUI.

## What this repo puts on your machine

| What | Where | Added by | Removed by |
|---|---|---|---|
| App CLIs and desktop apps | `~/.local/share/mise/installs/<app>[-cli]/<version>/` | `<app>:install` | `<app>:uninstall` |
| The apps' registration with macOS | LaunchServices | `<app>:install` | `<app>:uninstall` |
| Live MCP servers in Claude Code | This project's entry in `~/.claude.json` | `<app>:watch` | `<app>:unwatch` |
| MCP servers in Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `desktop:install` | `desktop:uninstall` |

Files the apps write themselves, such as documents, preferences and control tokens
(`~/.cache/cadcraft-control-7979.token`), belong to the apps, and no task touches them.

## How it works

- **Two tools per app.** [mise.toml](mise.toml) installs each app's GitHub repo twice under
  [tool aliases](https://mise.jdx.dev/dev-tools/backends/github.html): `<app>-cli` from the CLI
  zip and `<app>` from the desktop app's DMG. It's generated, tasks included, by
  [design/generate](design/generate) from `design/family.json` and `design/apps.json`, as is
  `servers.json`, the headless and live servers of every checked app for any host to use.
- **Exact versions.** mise's `minimum_release_age` hides releases newer than a set age, so `latest`
  can lag behind the newest release. [mise.lock](mise.lock) pins each download's SHA-256, matching
  the release's `SHA256SUMS.txt`. Each version installs to its own folder, so installing again
  downloads nothing, and installs run with `--locked`, so they install exactly what `mise.lock`
  names and never rewrite it.
- **Nothing installs by itself.** mise's auto-install is off in this repo, so `mise exec`,
  `mise run` and a missing command never download anything. A bare `mise install` would install
  every app, about 3 GB.
- **DMG unpacking.** The desktop apps are published for macOS only as DMGs, which mise saves without
  unpacking. A `postinstall` step, [scripts/unpack-dmg.sh](scripts/unpack-dmg.sh), copies the `.app`
  out of the image and registers it with macOS so `open -a <App>` finds it. The apps stay in mise's
  install folders, not `/Applications`, and are signed and notarized by their publisher.
- **Control ports.** Each desktop app takes `--control PORT`. Several apps' own docs use 7979
  (`upstream.docs_port`), so `design/apps.json` gives each checked app its own `port`. The port is
  written down, not worked out from the app's place in the list, so a newly published app never
  moves another app's port.
- **Opening the app for a live server.** An app whose server can open it (`opens_itself` in its
  `overrides`, CADCraft's `--launch`) opens at the first tool call. For the others,
  [scripts/mcp-open-app.sh](scripts/mcp-open-app.sh) opens the app with its control port and then
  starts the server, so the app opens as soon as its live server starts.
- **Watching.** Live servers stay out of `.mcp.json` because Claude Code starts every server it
  knows, at session start and on `claude mcp list`, and starting most live servers opens the app.
  Turning them off in settings doesn't work either: Claude Code merges `disabledMcpjsonServers`
  across its settings files, so a server switched off for everyone can't be switched back on for
  one person. `<app>:watch` adds the live server with a `MISE_CRAFT_WATCH` environment variable as
  its marker, and `<app>:unwatch` removes only servers that carry it, so a server of the same name
  that you added yourself is never replaced or removed.
- **Claude Desktop** starts servers outside this repo with a minimal `PATH`, so `desktop:install`
  rewrites each `.mcp.json` entry to call mise by its full path with `-C <this repo>`. That marker
  is how it replaces, and `desktop:uninstall` removes, only its own entries, leaving the rest of the
  file byte-for-byte as it was. Claude Desktop rewrites that file while it runs, so both tasks
  refuse to run while it's open.

## Files

What runs or reads what. Each file's header states its own lineage in full.

```
design/                      design time: the registry, and the six stages (mise -C design run <task>)
  mise.toml                  the stages: what each reads and writes, in order; it runs validate
                             (stage 4) and lock (stage 6) itself
  family.json                what every Craft app shares, written by hand (stage 3)
  apps.json                  each app: by hand (stage 3), except upstream (stage 1, fetch) and
                             observed (stage 2, check); read by validate, generate, check, status
  full.jq                    the family + app merge, shared by validate, generate and check
  fetch                      stage 1: GitHub (through gh) → every app's upstream block in apps.json
  check                      stage 2: an installed app → its observed block in apps.json
  generate                   stage 5: family.json + apps.json → ../mise.toml, ../servers.json
mise-tasks/                  runtime, run by you: mise run <task>
  status                     reads design/apps.json, mise, .mcp.json, ~/.claude.json, Claude Desktop's config
  apps/install, uninstall    → mise install --locked / mise uninstall → scripts/unpack-dmg.sh
                             (postinstall); then claude/sync
  apps/watch, unwatch        servers.json → claude mcp add-json / remove → ~/.claude.json
  claude/sync                servers.json + what's installed → .mcp.json
  desktop/install, uninstall .mcp.json → Claude Desktop's config
scripts/                     runtime, run by mise and Claude Code, never by hand
  unpack-dmg.sh              run by mise as each desktop app's postinstall
  mcp-open-app.sh            run by Claude Code as part of a live server's command
mise.toml                    generated by design/generate; its <app>:* tasks run mise-tasks/apps/*
mise.lock                    generated by mise lock, in the pipeline's lock stage
servers.json                 generated by design/generate: read by claude/sync and apps/watch
.mcp.json                    runtime, not committed: written by claude/sync; read by Claude Code,
                             VS Code, desktop/install and status
.gitignore                   keeps .mcp.json out of git
docs/problems.md             every problem found, and what it needs
CLAUDE.md                    read by Claude Code; imports this README
```

## Known limits

- **Claude Desktop** is tested on a copy of its config (the servers start the way Claude Desktop
  starts them, and its tasks restore the file exactly) but not yet in Claude Desktop itself, and it
  gets only the headless servers.
- **The headless MCP servers can read and write any file you can.** This repo passes no
  `--automation-read-root` / `--automation-write-root`; an app's `observed.file_roots` says whether
  its CLI could confine it. A live server is confined only by the app it drives. (Problem 13.)
- **Each app's own problems** are listed by number in its `problems` in
  [design/apps.json](design/apps.json), and described in [docs/problems.md](docs/problems.md).
- **`mise install --locked`** with no tool names also checks your global mise tools, which aren't
  in this lockfile, so name the tools: `mise install --locked cadcraft cadcraft-cli`.
- **Platforms.** This repo installs the macOS builds only. Which platforms each app's CLI and
  desktop app are published for is in its `upstream` block in `design/apps.json`.

## Plan

1. Load the servers in Claude Desktop itself, and wire up watching there.
2. Check the remaining apps (stage 2 is built: `mise -C design run check <app>`).
3. Confine the headless servers' file access (problem 13), once the folders are chosen.
4. claude.ai connectors (web, mobile, synced into Claude Code), set up and removed by mise tasks
   like everything else. They need the servers reachable over HTTPS: a bridge, a tunnel and
   authentication.
5. Linux and Windows, as the apps publish CLIs for them.

## Working on this repo

These rules are for people and agents alike; Claude Code reads this README through
[CLAUDE.md](CLAUDE.md).

- **This README documents the repo**, and each fact is stated once. CLAUDE.md only imports it.
  The only other Markdown is [docs/problems.md](docs/problems.md), which tracks every problem
  found. Never make memory files: agents keep no notes about this repo anywhere else, such as Claude
  Code's memory folder.
- **This repo controls everything it puts on the machine.** Anything created outside the repo
  folder is created by mise or a mise task, and has a matching task that removes it. Add the undo
  task in the same change as the do task, and add a row to
  [What this repo puts on your machine](#what-this-repo-puts-on-your-machine).
- **Undo restores the previous state exactly** and touches only what this repo added.
- **Exact versions only**, never `latest`; keep `mise.lock` current.
- **Nothing downloads or opens unless asked for**: keep auto-install off, and live servers out of
  `.mcp.json`.
- **mise only.** No Homebrew, no ArtCraft Launcher, no manual DMG installs. macOS built-ins called
  from mise tasks and hooks (`hdiutil`, `lsregister`, `open`) are fine.
- **Design time stays in `design/`; runtime stays outside it.** `design/` holds only what you edit
  and the pipeline's steps. Everything the pipeline produces lands at the repo root, where runtime
  reads it. Design time never reads the state of the machine, and runtime never edits what design
  time produced.
- **What every app shares goes in `design/family.json`, once; what is one app's own goes in
  `design/apps.json`.** Where an app differs from the family, the difference goes in its
  `overrides`, so every uncommon thing is in one visible place. Change those two files, never the
  files generated from them (`mise.toml`, `mise.lock`, `servers.json`), then run
  `mise -C design run gen`. The pipeline is defined in `design/mise.toml`, which it never writes, so
  regenerating never rewrites its own definition.
- **`.mcp.json` is a runtime file.** Only `claude:sync` writes it, from `servers.json` and what's
  installed; it's never committed.
- **`mise-tasks/` holds what you run; `scripts/` holds what mise and Claude Code run.**
  `scripts/unpack-dmg.sh` is mise's postinstall hook, and `scripts/mcp-open-app.sh` sits in a live
  server's command, where stdin and stdout carry MCP messages that `mise run` disturbs: run as a
  task with `depends`, a live server lost the client's first messages. Neither is run by hand.
- **Record every unusual thing the moment you find it.** About one app: in its `overrides` if it
  differs from the family, otherwise in `notes` (`check` writes what it can measure into
  `observed`). A problem
  goes in [docs/problems.md](docs/problems.md), and the app lists its number in `problems`. About
  everything: in this README. Never leave it in a test log or a commit message only.
- **Every file states its lineage at the top**: what runs or reads it, what it runs, reads and
  writes, and what undoes it. Generated files also say what generates them: `mise.toml` and
  `servers.json` (`design/generate`), `mise.lock` (`mise lock`), `.mcp.json` (`claude:sync`, at
  runtime), and in `design/apps.json` the `upstream` blocks (`design/fetch`) and most of `observed`
  (`design/check`); everything else is written by hand. JSON files, which can't hold comments, use a `"//"` key; `mise.lock` keeps the
  header mise writes.
- **`design/apps.json` records only verified facts.** A field nobody has confirmed is left out,
  never guessed: an app's `port` and `observed` once it's checked end to end.
- **Make real changes and test them end to end**, instead of proposing throwaway experiments
  first. For an app, that's install, `mise -C design run check <app>`, and a tool call that shows
  up in the app; then record its `port`, `overrides`, `problems` and what a fresh app holds in
  `design/apps.json`, and run `mise -C design run gen`.
- **Run slow downloads in the background** and keep the conversation going; ask before anything
  that would download gigabytes.
