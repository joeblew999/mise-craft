# mise-craft

Install the [Craft App Suite](https://getartcraft.com/apps) with [mise](https://mise.jdx.dev) and
drive the apps from AI agents over MCP, while you watch the desktop app update live. Everything is
controlled from this repo's mise tasks, and everything it sets up has a task that removes it.

> **Status:** CADCraft, DesignCraft, EffectCraft and VectorCraft work on macOS: CLI, desktop app,
> and MCP servers both headless and driving the live app, in Claude Code. The Claude Desktop tasks
> are tested on a copy of its config (servers start as Claude Desktop starts them, and uninstall
> restores the file exactly) but not yet loaded in Claude Desktop itself. The other 9 apps are
> listed and locked but not yet checked.

## Use it

```sh
mise tasks                      # every control this repo has
mise run status                 # each app: version, installed, running, MCP servers
mise run cadcraft:install       # an app's CLI (with its MCP server) and desktop app
mise run vectorcraft:install
```

Then open this repo in Claude Code. [.mcp.json](.mcp.json) has two MCP servers per checked app,
started through mise so they use the pinned versions:

| Server | What it drives | Desktop app opens |
|---|---|---|
| `cadcraft` | A headless drawing, no window | Never |
| `cadcraft-app` | The CADCraft app on port 7979, live | At the first tool call (`--lazy --launch`) |
| `designcraft` | A headless document, no window | Never |
| `designcraft-app` | The DesignCraft app on port 7981, live | When the server starts |
| `effectcraft` | A headless project, no window | Never |
| `effectcraft-app` | The EffectCraft app on port 7982, live | When the server starts |
| `vectorcraft` | A headless document, no window | Never |
| `vectorcraft-app` | The VectorCraft app on port 7990, live | When the server starts |

Claude Code asks you to approve project servers the first time; `claude mcp list` shows whether
they connect.

**Claude Desktop** gets the same servers from `mise run desktop:install` (quit Claude Desktop first,
then reopen it). `mise run desktop:uninstall` takes them out again. Both need jq from this repo:
`mise install jq`.

## Tasks

| Task | Does | Undone by |
|---|---|---|
| `<app>:install` | Installs the app's CLI and desktop app, e.g. `cadcraft:install` | `<app>:uninstall` |
| `<app>:uninstall` | Removes every installed version of both and unregisters the app from macOS | `<app>:install` |
| `apps:install <app>...` / `apps:uninstall <app>...` | The same for several apps at once | each other |
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
| VectorCraft | `--connect ADDR` (or `--headless`) | No |
| GridCraft (not yet checked) | `--connect PORT` | ? |
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
| GridCraft | [storytold/gridcraft](https://github.com/storytold/gridcraft) | 0.12.1 | 7985 | | macOS universal |
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

1. ~~CADCraft, DesignCraft, EffectCraft and VectorCraft: installed by mise, headless and live MCP
   servers connected in Claude Code, and work made over MCP showing up in the running apps.~~
   Next: load them in Claude Desktop itself.
2. The other 9 apps, one at a time: work out each app's MCP options, add its two servers to
   `.mcp.json`, and check it end to end.
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
- **DesignCraft, EffectCraft and VectorCraft open when their servers start** (in Claude Code or
  Claude Desktop), because their MCP servers can't open the app on demand. Only CADCraft waits for
  the first tool call.
- **EffectCraft's window screenshots are large** (about 28 MB at full size); its `screenshot` tool
  takes `max_side` to scale them down.
- **`mise install --locked`** also checks your global mise tools, which aren't in this lockfile; name
  the tools: `mise install --locked cadcraft cadcraft-cli`.
- **Exact versions only.** mise's `minimum_release_age` hides releases newer than a set age, so
  `latest` can lag behind the newest release.
- Only PdfCraft publishes a CLI for Linux, and no app publishes one for Windows.
