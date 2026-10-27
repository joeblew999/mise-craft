# mise-craft

Install the [Craft App Suite](https://getartcraft.com/apps) with [mise](https://mise.jdx.dev) and
drive the apps from AI agents over MCP, while you watch the desktop app update live. Everything is
controlled from this repo's mise tasks, and everything it sets up has a task that removes it.

> **Status:** CADCraft, DesignCraft, EffectCraft, GridCraft and VectorCraft work on macOS: CLI,
> desktop app, and MCP servers both headless and driving the live app, in Claude Code. The Claude
> Desktop tasks are tested on a copy of its config (servers start as Claude Desktop starts them,
> and uninstall restores the file exactly) but not yet loaded in Claude Desktop itself. The other 8
> apps are listed and locked but not yet checked.

## Get started

You need macOS, [mise](https://mise.jdx.dev/getting-started.html) and
[Claude Code](https://code.claude.com/docs).

```sh
git clone https://github.com/joeblew999/mise-craft
cd mise-craft
mise trust                     # mise asks before it uses a repo's config
mise install jq                # the tasks use it
mise run status                # nothing is installed yet
mise run cadcraft:install      # the CADCraft CLI and desktop app, about 120 MB to download
mise run cadcraft:watch        # optional: let Claude drive the CADCraft window
claude                         # approve the project's MCP servers when asked
```

Then ask Claude to draw something in CADCraft. mise downloads through GitHub's API; if it hits
GitHub's rate limit, run `export GITHUB_TOKEN=$(gh auth token)` first.

## Use it

```sh
mise tasks                      # every control this repo has
mise run status                 # each app: version, installed, running, MCP servers
mise run cadcraft:install       # an app's CLI (with its MCP server) and desktop app
mise run vectorcraft:install
```

Then open this repo in Claude Code. [.mcp.json](.mcp.json) gives Claude a headless MCP server for
each checked app (`cadcraft`, `designcraft`, `effectcraft`, `gridcraft`, `vectorcraft`), started
through mise so it uses the pinned version. Headless servers work on a document with no window, so
no app opens.

To watch Claude work in a desktop app, switch on that app's live server:

```sh
mise run cadcraft:watch      # adds cadcraft-app to Claude Code, for this project only
mise run cadcraft:unwatch    # takes it out again
```

| Live server | Drives | Desktop app opens |
|---|---|---|
| `cadcraft-app` | CADCraft on port 7979 | At the first tool call (`--lazy --launch`) |
| `designcraft-app` | DesignCraft on port 7981 | When the server starts |
| `effectcraft-app` | EffectCraft on port 7982 | When the server starts |
| `gridcraft-app` | GridCraft on port 7985 | When the server starts |
| `vectorcraft-app` | VectorCraft on port 7990 | When the server starts |

The live servers are defined in [mcp-live.json](mcp-live.json). A watch is added in Claude Code's
local scope, so it's yours only, and loads in the next session or through `/mcp`. Claude Code asks
you to approve the project's servers the first time; `claude mcp list` shows whether they connect.

**Claude Desktop** gets the headless servers from `mise run desktop:install` (quit Claude Desktop
first, then reopen it). `mise run desktop:uninstall` takes them out again. Both need jq from this repo:
`mise install jq`.

## Tasks

| Task | Does | Undone by |
|---|---|---|
| `<app>:install` | Installs the app's CLI and desktop app, e.g. `cadcraft:install` | `<app>:uninstall` |
| `<app>:uninstall` | Removes every installed version of both and unregisters the app from macOS | `<app>:install` |
| `<app>:watch` | Adds the app's live MCP server (from `mcp-live.json`) to Claude Code for this project | `<app>:unwatch` |
| `<app>:unwatch` | Removes it | `<app>:watch` |
| `apps:install`, `apps:uninstall`, `apps:watch`, `apps:unwatch` `<app>...` | The same for several apps at once | each other |
| `desktop:install` | Adds the servers in `.mcp.json` to Claude Desktop | `desktop:uninstall` |
| `desktop:uninstall` | Removes exactly those servers; the rest of Claude Desktop's config is left byte-for-byte as it was | `desktop:install` |
| `status` | Shows each app's version, install state, whether it's running, and its MCP servers | (read-only) |

`mise.toml` lists all 13 apps at exact versions, but nothing downloads until you install an app by
name: mise's auto-install is off in this repo, so `mise exec`, `mise run` and a missing command
never fetch anything. (A bare `mise install` would install every app, about 3 GB.)

## What this repo puts on your machine

| What | Where | Added by | Removed by |
|---|---|---|---|
| App CLIs and desktop apps | `~/.local/share/mise/installs/<app>[-cli]/<version>/` | `<app>:install` | `<app>:uninstall` |
| Apps' registration with macOS (so `open -a <App>` finds them) | LaunchServices | `<app>:install` ([scripts/unpack-dmg.sh](scripts/unpack-dmg.sh)) | `<app>:uninstall` |
| Live MCP servers in Claude Code | This project's entry in `~/.claude.json` (Claude Code's local scope) | `<app>:watch` | `<app>:unwatch` |
| MCP servers in Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `desktop:install` | `desktop:uninstall` |

Files the apps write themselves (documents, preferences, control tokens such as
`~/.cache/cadcraft-control-7979.token`) belong to the apps, and the tasks don't touch them.

Installs are idempotent: each version lives in its own folder, so installing again downloads
nothing, and [mise.lock](mise.lock) pins every download's SHA-256 (all 26 match the releases'
`SHA256SUMS.txt`).

## How it works

- **Two tools per app.** `mise.toml` installs each app's GitHub repo twice under
  [tool aliases](https://mise.jdx.dev/dev-tools/backends/github.html): the CLI zip and the desktop
  app's DMG. [scripts/gen-mise-toml.sh](scripts/gen-mise-toml.sh) generates it, tasks included,
  from its list of apps and versions, so a version bump is one edit, a regenerate and `mise lock`.
- **DMG unpacking.** On macOS the desktop apps are published only as DMGs, which mise saves without
  unpacking. A `postinstall` step copies the `.app` out of the image and registers it with macOS.
  The apps stay in mise's install folders, not `/Applications`, and are signed and notarized by
  their publisher.
- **Opening the app for an agent.** Each app's MCP server takes different options, so `.mcp.json`
  is written and checked per app. Every app's desktop app takes `--control PORT`; each app gets
  its own port, 7979 plus its place in the alphabetical list (see [The apps](#the-apps)), because
  several apps default to 7979. CADCraft's server opens the app itself (`--launch`). The others
  can't, so [scripts/mcp-open-app.sh](scripts/mcp-open-app.sh) opens the app with its control port
  and then starts the server.
- **Claude Desktop** starts servers outside this repo with a minimal `PATH`, so `desktop:install`
  rewrites each `.mcp.json` entry to call mise by its full path with `-C <this repo>`. That
  `-C <this repo>` is also how `desktop:uninstall` finds its own entries.

| App | Live MCP option | Opens the app itself |
|---|---|---|
| CADCraft | `--connect HOST:PORT [--lazy] [--launch]` | Yes |
| DesignCraft | `--connect PORT` or `HOST:PORT` | No |
| EffectCraft | `--bridge PORT` | No |
| GridCraft | `--connect PORT` | No |
| VectorCraft | `--connect ADDR` (or `--headless`) | No |
| FigCraft (not yet checked) | `--attach PORT` | ? |

## The apps

The launcher comes first; the apps follow in alphabetical order. Every app has `<app>-cli mcp`.
Versions and CLI builds are as published on each repo's latest release (checked 2026-10-26).

| App | Repo | Pinned | Control port | Checked here | CLI builds |
|---|---|---|---|---|---|
| **ArtCraft Launcher** | [storytold/craft-launcher](https://github.com/storytold/craft-launcher) | | | | None: a desktop app that installs the apps below |
| CADCraft | [storytold/cadcraft](https://github.com/storytold/cadcraft) | 0.13.0 | 7979 | ✓ | macOS universal |
| DeckCraft | [storytold/deckcraft](https://github.com/storytold/deckcraft) | 0.11.1 | 7980 | | macOS universal |
| DesignCraft | [storytold/designcraft](https://github.com/storytold/designcraft) | 0.13.0 | 7981 | ✓ | macOS universal |
| EffectCraft | [storytold/effectcraft](https://github.com/storytold/effectcraft) | 0.17.0 | 7982 | ✓ | macOS universal |
| FigCraft | [storytold/figcraft](https://github.com/storytold/figcraft) | 0.11.2 | 7983 | | macOS universal |
| FilmCraft | [storytold/filmcraft](https://github.com/storytold/filmcraft) | 0.13.0 | 7984 | | macOS universal |
| GridCraft | [storytold/gridcraft](https://github.com/storytold/gridcraft) | 0.12.1 | 7985 | ✓ | macOS universal |
| LightCraft | [storytold/lightcraft](https://github.com/storytold/lightcraft) | 0.14.0 | 7986 | | macOS universal |
| PdfCraft | [storytold/pdfcraft](https://github.com/storytold/pdfcraft) | 0.14.0 | 7987 | | macOS universal, Linux x86_64, Linux aarch64 |
| PhotoCraft | [storytold/photocraft](https://github.com/storytold/photocraft) | 0.16.0 | 7988 | | macOS universal |
| SoundCraft | [storytold/soundcraft](https://github.com/storytold/soundcraft) | 0.13.1 | 7989 | | macOS universal |
| VectorCraft | [storytold/vectorcraft](https://github.com/storytold/vectorcraft) | 0.17.0 | 7990 | ✓ | macOS universal |
| WordCraft | [storytold/wordcraft](https://github.com/storytold/wordcraft) | 0.11.0 | 7991 | | macOS universal |

[craft-launcher](https://github.com/storytold/craft-launcher) installs the desktop apps into
`/Applications` from a GUI. mise-craft installs from the command line, pins versions per project,
and sets the apps up for agents.

## Plan

1. ~~CADCraft, DesignCraft, EffectCraft, GridCraft and VectorCraft: installed by mise, headless
   and live MCP servers connected in Claude Code, and work made over MCP showing up in the running
   apps.~~ Next: load them in Claude Desktop itself.
2. The other 8 apps, one at a time: work out each app's MCP options, add its headless server to
   `.mcp.json` and its live server to `mcp-live.json`, and check it end to end.
3. claude.ai connectors (web, mobile, synced into Claude Code), set up and removed by mise tasks
   like everything else. They need the servers reachable over HTTPS, so this means a bridge, a
   tunnel and authentication.
4. Linux and Windows: most apps publish no CLI build for them yet.

## Known limits

- **GitHub credential.** Downloads go through the GitHub API; set mise's `github.credential_command`
  in your global mise config (mise ignores it in a project file) or export `GITHUB_TOKEN`.
- **CADCraft's first live call can fail** with "missing or invalid control token" right after
  `--launch` opens the app: the bridge reads the old token before the app writes a new one
  (upstream #2087). The error says it is safe to send again, and the retry works.
- **A watched DesignCraft, EffectCraft or VectorCraft opens as soon as its live server starts**,
  because their MCP servers can't open the app on demand. Only CADCraft waits for the first tool
  call.
- **Claude Desktop gets only the headless servers** for now; watching an app there isn't wired up.
- **GridCraft's `screenshot` needs its window visible**: a hidden window draws no frames, so the call
  times out. Bring GridCraft to the front first.
- **EffectCraft's window screenshots are large** (about 28 MB at full size); its `screenshot` tool
  takes `max_side` to scale them down.
- **`mise install --locked`** also checks your global mise tools, which aren't in this lockfile; name
  the tools: `mise install --locked cadcraft cadcraft-cli`.
- **Exact versions only.** mise's `minimum_release_age` hides releases newer than a set age, so
  `latest` can lag behind the newest release.
- Only PdfCraft publishes a CLI for Linux, and no app publishes one for Windows.

## Working on this repo

These rules are for people and agents alike; Claude Code reads this README through
[CLAUDE.md](CLAUDE.md).

- **This repo controls everything it puts on the machine.** Anything created outside the repo
  folder is created by mise or a mise task, and has a matching task that removes it. Add the undo
  task in the same change as the do task, and add a row to
  [What this repo puts on your machine](#what-this-repo-puts-on-your-machine).
- **Undo restores the previous state exactly** and touches only what this repo added. A task that
  edits a shared file, such as Claude Desktop's config, finds its own entries by a marker and leaves
  everything else byte-for-byte as it was.
- **Exact versions, idempotent installs.** Never `latest`; keep `mise.lock` current. An installed
  version is never downloaded again.
- **Nothing downloads unless it's named**, and no desktop app opens unless asked for: auto-install
  stays off, and live servers stay out of `.mcp.json` until `<app>:watch`.
- **mise only.** No Homebrew, no ArtCraft Launcher, no manual DMG installs. macOS built-ins called
  from mise tasks and hooks (`hdiutil`, `lsregister`, `open`) are fine.
- **`mise.toml` is generated** by `scripts/gen-mise-toml.sh`: change the script, then regenerate.
  Tasks live in `mise-tasks/`.
- **Check each app end to end before adding it.** Each app's MCP server takes different options;
  its headless server goes in `.mcp.json` and its live server in `mcp-live.json`.
- **This README is the only documentation.** CLAUDE.md only imports it; don't add other Markdown
  files.
- **Never make memory files.** Agents don't keep notes about this repo anywhere else, such as
  Claude Code's memory folder: anything worth remembering goes in this README.
- **Make real changes and test them end to end** (install, MCP handshake, a tool call that shows up
  in the app), instead of proposing throwaway experiments first.
- **Run slow downloads in the background** and keep the conversation going; ask before anything
  that would download gigabytes.
