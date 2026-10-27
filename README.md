<!-- Lineage: written by hand; Claude Code reads it through CLAUDE.md. -->

# mise-craft

Install the apps of the [Craft App Suite](https://getartcraft.com/apps) with
[mise](https://mise.jdx.dev), and let AI agents drive them over MCP while you watch the desktop app
update. Everything runs from this repo's mise tasks, and everything they set up has a task that
removes it. macOS only for now; `mise run apps:status` shows which apps are checked end to end.

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
| `task:log <task> [args...]` | Runs any task and keeps its full output and exit code in `logs/`, one file per run (not committed) | (delete the file) |
| `apps:status` | Shows each app's pinned version, whether that version is checked end to end, its control port, whether its CLI and desktop app are installed, whether it's running, and its MCP servers | (read-only) |
| `<app>:install` | Installs the app's CLI and desktop app, then `claude-code:sync` | `<app>:uninstall` |
| `<app>:uninstall` | Unwatches the app, removes every installed version of both, unregisters the app from macOS, then `claude-code:sync` | `<app>:install` |
| `<app>:watch` | Adds the app's live MCP server to Claude Code, for this project | `<app>:unwatch` |
| `<app>:unwatch` | Removes it | `<app>:watch` |
| `apps:install`, `apps:uninstall`, `apps:watch`, `apps:unwatch` `<app>...` | The same for several apps at once | each other |
| `claude-code:sync` | Writes `.mcp.json` with the headless server of each checked app installed here | (rerun after any change) |
| `claude-desktop:install` | Makes Claude Desktop's servers from this repo match `.mcp.json` | `claude-desktop:uninstall` |
| `claude-desktop:uninstall` | Removes exactly those servers | `claude-desktop:install` |
| `repo:test` | Tests the repo top to bottom in a fresh clone of the last commit, with your global mise config and your Claude Code config switched off, and cleans up after itself | (nothing left behind) |

**MCP servers in Claude Code.** `.mcp.json` holds a headless server for each checked app installed
on this machine: it works on a document with no window, so no app opens. It's a runtime file, not
committed, written by `claude-code:sync` whenever you install or uninstall an app, so it never lists an
app you don't have. To watch Claude work in a desktop app, `<app>:watch` adds that app's live server
from [servers.json](servers.json) in Claude Code's local scope, so it's yours only; it loads in the
next session or through `/mcp`. Claude Code asks you to approve the project's servers the first
time, and `claude mcp list` shows whether they connect.

**Claude Desktop.** Quit it, run `mise run claude-desktop:install`, then reopen it.

## Design time

[design/](design) holds the registry, [design/family.json](design/family.json) and
[design/apps.json](design/apps.json), and the six stages that turn it into the files runtime reads.
Everything the stages produce lands at the repo root. They run in this order, as
[design/mise.toml](design/mise.toml) lists them:

```sh
mise -C design run upstream:fetch       # 1. prints each app's pinned and latest version, from GitHub
mise -C design run app:check cadcraft   # 2. prints what an installed app shows, and fails if it didn't work
                                        # 3. record: the maintainer edits family.json, apps.json
                                        #    and docs/problems.md
mise -C design run config:build         # 4-6. validate, generate mise.toml and servers.json, lock
```

Stages 1 and 2 bring in facts from outside, so they run only when asked, and they write nothing:
what they print is the log, and the maintainer decides what to record. Stage 2 is the only one that
runs anything on the machine: it needs the app installed, and opens it to list its live tools. Stages 4 to 6 are tasks of their own, and each
depends on the one before it, so running any of them runs the earlier ones first: nothing can be
locked before it is generated. Runtime tasks read what the stages produced and never change it:
installs run with `--locked`, so they never write `mise.lock`.

## The apps

What this repo knows about the Craft apps is in two files:

- **[design/family.json](design/family.json): what every Craft app shares,** defined once with
  `{id}`, `{name}` and `{port}` placeholders: the repo and where it documents MCP, the download
  names, the CLI's name, the bundle and process name, the option the desktop app takes its control
  port with (`--control`), whether the app shares a token with its live server
  (`control_token_env`), the CLI subcommand that starts the MCP server (`mcp`), and the usual
  options of the headless and live servers. No script holds any of these itself: each reads them
  from here, so an app that differs needs only an override.
- **[design/apps.json](design/apps.json): each app's definition, and nothing else.** Written by
  hand: `id`, `name`, `version` (the exact version installed), `checked` (the version that was
  checked end to end; without it the app is unchecked and gets no MCP servers), `port` (its control
  port, once checked) and `overrides` (only where it differs from the family, in the same shape, so
  every way an app differs is listed there). An app without `overrides` is either checked and the
  same as the family, or unchecked; `checked` says which.

An app's full description is the family with its `overrides` laid over it
([design/scripts/app-merge.jq](design/scripts/app-merge.jq)). How particular apps behave, such as which tool a
fresh app needs first, is in [docs/problems.md](docs/problems.md). Each app's CLI,
`<app>-cli`, runs a headless MCP server with `<app>-cli mcp`. The
[ArtCraft Launcher](https://github.com/storytold/craft-launcher) isn't used here: it installs the
desktop apps into `/Applications` from a GUI.

## What this repo puts on your machine

| What | Where | Added by | Removed by |
|---|---|---|---|
| App CLIs and desktop apps | `~/.local/share/mise/installs/<app>[-cli]/<version>/` | `<app>:install` | `<app>:uninstall` |
| The apps' registration with macOS | LaunchServices | `<app>:install` | `<app>:uninstall` |
| Live MCP servers in Claude Code | This project's entry in `~/.claude.json` | `<app>:watch` | `<app>:unwatch` |
| MCP servers in Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `claude-desktop:install` | `claude-desktop:uninstall` |

Files the apps write themselves, such as documents, preferences and control tokens
(`~/.cache/cadcraft-control-7979.token`), belong to the apps, and no task touches them.

## How it works

- **Two tools per app.** [mise.toml](mise.toml) installs each app's GitHub repo twice under
  [tool aliases](https://mise.jdx.dev/dev-tools/backends/github.html): `<app>-cli` from the CLI
  zip and `<app>` from the desktop app's DMG. It's generated, tasks included, by
  [design/scripts/5-config-generate](design/scripts/5-config-generate) from `design/family.json` and `design/apps.json`, as is
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
  unpacking. A `postinstall` step, [scripts/dmg-unpack.sh](scripts/dmg-unpack.sh), copies the `.app`
  out of the image and registers it with macOS so `open -a <App>` finds it. The apps stay in mise's
  install folders, not `/Applications`, and are signed and notarized by their publisher.
- **Control ports.** Each desktop app takes `--control PORT` (family.json's `control`). Several
  apps' own docs use 7979 (`upstream:fetch` shows each), so `design/apps.json` gives each checked
  app its own `port`. The port is
  written down, not worked out from the app's place in the list, so a newly published app never
  moves another app's port.
- **Opening the app for a live server.** An app whose server can open it (`opens_itself` in its
  `overrides`, CADCraft's `--launch`) opens at the first tool call. For the others,
  [scripts/app-open.sh](scripts/app-open.sh) opens the app with its control port and then
  starts the server, so the app opens as soon as its live server starts. For an app with a
  `control_token_env` (FilmCraft), it also makes a fresh token and gives it to both.
- **Watching.** Live servers stay out of `.mcp.json` because Claude Code starts every server it
  knows, at session start and on `claude mcp list`, and starting most live servers opens the app.
  Turning them off in settings doesn't work either: Claude Code merges `disabledMcpjsonServers`
  across its settings files, so a server switched off for everyone can't be switched back on for
  one person. `<app>:watch` adds the live server with a `MISE_CRAFT_WATCH` environment variable as
  its marker, and `<app>:unwatch` removes only servers that carry it, so a server of the same name
  that you added yourself is never replaced or removed.
- **Claude Desktop** starts servers outside this repo with a minimal `PATH`, so `claude-desktop:install`
  rewrites each `.mcp.json` entry to call mise by its full path with `-C <this repo>`. That marker
  is how it replaces, and `claude-desktop:uninstall` removes, only its own entries, leaving the rest of the
  file byte-for-byte as it was. Claude Desktop rewrites that file while it runs, so both tasks
  refuse to run while it's open.

## Files

What runs or reads what. Each file's header states its own lineage in full.

```
design/                          design time: the registry and its six stages (mise -C design run <task>)
  mise.toml                      the stages: what each reads and writes, in order; runs
                                 lock:update (stage 6) itself
  family.json                    what every Craft app shares, written by hand (stage 3)
  apps.json                      each app's definition, written by hand (stage 3); read by every stage
                                 and by apps:status
  scripts/                       the stages' scripts, run by the tasks in design/mise.toml
    1-upstream-fetch             stage 1, upstream:fetch: GitHub (through gh) → printed table
    2-app-check                  stage 2, app:check: an installed app → printed report
    4-registry-validate          stage 4, registry:validate: stops the build if the registry is wrong
    5-config-generate            stage 5, config:generate: registry → ../mise.toml, ../servers.json
    app-merge.jq                 the family + app merge, shared by stages 1, 2 and 5
mise-tasks/                      runtime, run by you: mise run <task>
  apps/status                    apps:status: reads design/apps.json, mise, .mcp.json, ~/.claude.json,
                                 Claude Desktop's config
  apps/install, uninstall        → mise install --locked / mise uninstall → scripts/dmg-unpack.sh
                                 (postinstall); then claude-code:sync
  apps/watch, unwatch            servers.json → claude mcp add-json / remove → ~/.claude.json
  claude-code/sync               claude-code:sync: servers.json + what's installed → .mcp.json
  claude-desktop/install, uninstall  .mcp.json → Claude Desktop's config
  repo/test                      repo:test: clones the last commit and runs every task and stage in it
scripts/                         runtime, run by mise and Claude Code, never by hand
  dmg-unpack.sh                  run by mise as each desktop app's postinstall
  app-open.sh                    run by Claude Code as part of a live server's command
mise.toml                        generated by design/scripts/5-config-generate; its <app>:* tasks run mise-tasks/apps/*
mise.lock                        generated by mise lock, in lock:update (stage 6)
servers.json                     generated by design/scripts/5-config-generate: read by claude-code:sync, apps:watch
.mcp.json                        runtime, not committed: written by claude-code:sync; read by Claude Code,
                                 VS Code, claude-desktop:install and apps:status
logs/                            runtime, not committed: one file per `mise run task:log <task>`
.gitignore                       keeps .mcp.json and logs/ out of git
docs/problems.md                 every problem found and how particular apps behave, by number
CLAUDE.md                        read by Claude Code; imports this README
```

## Known limits

- **Claude Desktop** is tested on a copy of its config (the servers start the way Claude Desktop
  starts them, and its tasks restore the file exactly) but not yet in Claude Desktop itself, and it
  gets only the headless servers.
- **The headless MCP servers can read and write any file you can.** This repo passes no
  `--automation-read-root` / `--automation-write-root`; `app:check` prints whether an app's CLI
  could confine it. A live server is confined only by the app it drives. (Problem 13.)
- **Each app's own problems** are in [docs/problems.md](docs/problems.md), which names the app.
- **`mise install --locked`** with no tool names also checks your global mise tools, which aren't
  in this lockfile, so name the tools: `mise install --locked cadcraft cadcraft-cli`.
- **Platforms.** This repo installs the macOS builds only. Which platforms each app's CLI and
  desktop app are published for is printed by `mise -C design run upstream:fetch`.

## Plan

1. Load the servers in Claude Desktop itself, and wire up watching there.
2. Check the remaining apps (stage 2 is built: `mise -C design run app:check <app>`).
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
  `mise -C design run config:build`. The pipeline is defined in `design/mise.toml`, which it never writes, so
  regenerating never rewrites its own definition.
- **`.mcp.json` is a runtime file.** Only `claude-code:sync` writes it, from `servers.json` and what's
  installed; it's never committed.
- **`mise-tasks/` holds what you run; `scripts/` holds what mise and Claude Code run.**
  `scripts/dmg-unpack.sh` is mise's postinstall hook, and `scripts/app-open.sh` sits in a live
  server's command, where stdin and stdout carry MCP messages that `mise run` disturbs: run as a
  task with `depends`, a live server lost the client's first messages. Neither is run by hand.
- **Record every unusual thing the moment you find it.** About one app: in its `overrides` if it
  differs from the family, otherwise in [docs/problems.md](docs/problems.md), naming the app. A
  problem goes in docs/problems.md too. About everything: in this README. Never leave it in a test log or a commit message only.
- **Every file states its lineage at the top**: what runs or reads it, what it runs, reads and
  writes, and what undoes it. Generated files also say what generates them: `mise.toml` and
  `servers.json` (`design/scripts/5-config-generate`), `mise.lock` (`mise lock`) and `.mcp.json`
  (`claude-code:sync`, at runtime); everything else is written by hand. JSON files, which can't
  hold comments, use a `"//"` key; `mise.lock` keeps the header mise writes.
- **`design/apps.json` records only verified facts.** A field nobody has confirmed is left out,
  never guessed: an app's `checked`, `port` and `overrides` once it's checked end to end.
- **Make real changes and test them end to end**, instead of proposing throwaway experiments
  first. Commit, then run `mise run task:log repo:test`, and push only if every step passes. For an app, that's install, `mise -C design run app:check <app>`, and a tool call that shows
  up in the app; then record its `checked`, `port` and `overrides` in `design/apps.json`, how it
  behaves in docs/problems.md, and run `mise -C design run config:build`.
- **Run slow downloads in the background** and keep the conversation going; ask before anything
  that would download gigabytes.
