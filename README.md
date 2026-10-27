<!-- Lineage: written by hand; Claude Code reads it through CLAUDE.md. -->

# mise-craft

Install the apps of the [Craft App Suite](https://getartcraft.com/apps) with
[mise](https://mise.jdx.dev), and let AI agents drive them over MCP while you watch the desktop app
update. Everything runs from this repo's mise tasks, and everything they set up has a task that
removes it. macOS only for now; [The apps](#the-apps) shows which apps are checked end to end.

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

`mise tasks` lists every task:

| Task | Does | Undone by |
|---|---|---|
| `status` | Shows each app's pinned version, whether its CLI and desktop app are installed, whether it's running, and its MCP servers | (read-only) |
| `gen` | Regenerates `mise.toml` from the app list in [mise-tasks/gen](mise-tasks/gen) and updates `mise.lock` | (run it again after editing the script) |
| `<app>:install` | Installs the app's CLI and desktop app | `<app>:uninstall` |
| `<app>:uninstall` | Removes every installed version of both and unregisters the app from macOS | `<app>:install` |
| `<app>:watch` | Adds the app's live MCP server to Claude Code, for this project | `<app>:unwatch` |
| `<app>:unwatch` | Removes it | `<app>:watch` |
| `apps:install`, `apps:uninstall`, `apps:watch`, `apps:unwatch` `<app>...` | The same for several apps at once | each other |
| `desktop:install` | Adds the headless MCP servers to Claude Desktop | `desktop:uninstall` |
| `desktop:uninstall` | Removes exactly those servers | `desktop:install` |

**MCP servers in Claude Code.** [.mcp.json](.mcp.json) has a headless server for each checked app:
it works on a document with no window, so no app opens. To watch Claude work in a desktop app,
`<app>:watch` adds that app's live server from [mcp-live.json](mcp-live.json) in Claude Code's
local scope, so it's yours only; it loads in the next session or through `/mcp`. Claude Code asks
you to approve the project's servers the first time, and `claude mcp list` shows whether they
connect.

**Claude Desktop.** Quit it, run `mise run desktop:install`, then reopen it.

## The apps

Each app's CLI, `<app>-cli`, runs a headless MCP server with `<app>-cli mcp`, and drives the running
desktop app with the option in the table. Versions are pinned in the app list in
[mise-tasks/gen](mise-tasks/gen); `mise run status` shows them.

| App | Checked here | Port | Live server connects with | Desktop app opens after `watch` |
|---|---|---|---|---|
| **[ArtCraft Launcher](https://github.com/storytold/craft-launcher)** | Not used here: it installs the desktop apps into `/Applications` from a GUI | | | |
| [CADCraft](https://github.com/storytold/cadcraft) | ✓ | 7979 | `--connect HOST:PORT --lazy --launch` | At the first tool call |
| [DeckCraft](https://github.com/storytold/deckcraft) | | | | |
| [DesignCraft](https://github.com/storytold/designcraft) | ✓ | 7981 | `--connect PORT` | When the live server starts |
| [EffectCraft](https://github.com/storytold/effectcraft) | ✓ | 7982 | `--bridge PORT` | When the live server starts |
| [FigCraft](https://github.com/storytold/figcraft) | | | `--attach PORT` (from its usage text) | |
| [FilmCraft](https://github.com/storytold/filmcraft) | | | | |
| [GridCraft](https://github.com/storytold/gridcraft) | ✓ | 7985 | `--connect PORT` | When the live server starts |
| [LightCraft](https://github.com/storytold/lightcraft) | | | | |
| [PdfCraft](https://github.com/storytold/pdfcraft) | | | | |
| [PhotoCraft](https://github.com/storytold/photocraft) | | | | |
| [SoundCraft](https://github.com/storytold/soundcraft) | | | | |
| [VectorCraft](https://github.com/storytold/vectorcraft) | ✓ | 7990 | `--connect ADDR` | When the live server starts |
| [WordCraft](https://github.com/storytold/wordcraft) | | | | |

VectorCraft's server connects to a running app on port 7979 by default, so its headless server is
started with `--headless`.

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
  [mise-tasks/gen](mise-tasks/gen) from its list of apps and versions.
- **Exact versions.** mise's `minimum_release_age` hides releases newer than a set age, so `latest`
  can lag behind the newest release. [mise.lock](mise.lock) pins each download's SHA-256, matching
  the release's `SHA256SUMS.txt`. Each version installs to its own folder, so installing again
  downloads nothing.
- **Nothing installs by itself.** mise's auto-install is off in this repo, so `mise exec`,
  `mise run` and a missing command never download anything. A bare `mise install` would install
  every app, about 3 GB.
- **DMG unpacking.** The desktop apps are published for macOS only as DMGs, which mise saves without
  unpacking. A `postinstall` step, [scripts/unpack-dmg.sh](scripts/unpack-dmg.sh), copies the `.app`
  out of the image and registers it with macOS so `open -a <App>` finds it. The apps stay in mise's
  install folders, not `/Applications`, and are signed and notarized by their publisher.
- **Control ports.** Each desktop app takes `--control PORT`. Several apps default to 7979, so each
  gets its own: 7979 plus its place in the alphabetical list.
- **Opening the app for a live server.** CADCraft's server opens the app itself (`--launch`). The
  others can't, so [scripts/mcp-open-app.sh](scripts/mcp-open-app.sh) opens the app with its
  control port and then starts the server.
- **Claude Desktop** starts servers outside this repo with a minimal `PATH`, so `desktop:install`
  rewrites each `.mcp.json` entry to call mise by its full path with `-C <this repo>`. That marker
  is how `desktop:uninstall` finds its own entries, leaving the rest of the file byte-for-byte as
  it was.

## Known limits

- **Claude Desktop** is tested on a copy of its config (the servers start the way Claude Desktop
  starts them, and uninstall restores the file exactly) but not yet in Claude Desktop itself, and
  it gets only the headless servers.
- **CADCraft's first live call can fail** with "missing or invalid control token" right after
  `--launch` opens the app: the bridge reads the old token before the app writes a new one
  (upstream #2087). The error says it is safe to send again, and the retry works.
- **GridCraft's `screenshot` needs its window visible**: a hidden window draws no frames, so the
  call times out. Bring GridCraft to the front first.
- **EffectCraft's window screenshots are about 28 MB** at full size; its `screenshot` tool takes
  `max_side` to scale them down.
- **`mise install --locked`** also checks your global mise tools, which aren't in this lockfile, so
  name the tools: `mise install --locked cadcraft cadcraft-cli`.
- **Platforms.** Every app publishes its CLI for macOS; only PdfCraft also publishes one for Linux,
  and none publishes one for Windows.

## Plan

1. Load the servers in Claude Desktop itself, and wire up watching there.
2. Check the other apps, one at a time.
3. claude.ai connectors (web, mobile, synced into Claude Code), set up and removed by mise tasks
   like everything else. They need the servers reachable over HTTPS: a bridge, a tunnel and
   authentication.
4. Linux and Windows, as the apps publish CLIs for them.

## Working on this repo

These rules are for people and agents alike; Claude Code reads this README through
[CLAUDE.md](CLAUDE.md).

- **This README is the only documentation**, and each fact is stated once. CLAUDE.md only imports
  it. Don't add other Markdown files, and never make memory files: agents keep no notes about this
  repo anywhere else, such as Claude Code's memory folder.
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
- **Change the app list in `mise-tasks/gen`, not `mise.toml`**, then run `mise run gen`. `gen` is a
  file task, not part of `mise.toml`, so regenerating never rewrites its own definition.
- **`mise-tasks/` holds what you run; `scripts/` holds what mise and Claude Code run.**
  `scripts/unpack-dmg.sh` is mise's postinstall hook, and `scripts/mcp-open-app.sh` sits in a live
  server's command, where stdin and stdout carry MCP messages that `mise run` would disturb. Neither
  is run by hand.
- **Every file states its lineage at the top**: what runs or reads it, what it runs, reads and
  writes, and what undoes it. Generated files also say what generates them: `mise.toml`
  (`mise-tasks/gen`) and `mise.lock` (`mise lock`); every other file is written by hand.
  JSON files, which can't hold comments, use a `"//"` key; `mise.lock` keeps the header mise writes.
- **Make real changes and test them end to end**, instead of proposing throwaway experiments
  first. For an app, that's install, an MCP handshake, and a tool call that shows up in the app;
  then add its headless server to `.mcp.json`, its live server to `mcp-live.json`, and its row to
  [The apps](#the-apps).
- **Run slow downloads in the background** and keep the conversation going; ask before anything
  that would download gigabytes.
