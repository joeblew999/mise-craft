<!-- Lineage: written by hand. Every problem found while building this repo, so none is forgotten. -->

# Problems

Which apps don't work comes first; everything below it can wait. The numbers never change.

## Apps that don't work yet

- **29. LightCraft, WordCraft: never checked.** They can be installed, but get no MCP servers. *Next: install, check and record each, one at a time.*

Working, as last checked: CADCraft, DeckCraft, DesignCraft, EffectCraft, FigCraft, FilmCraft,
GridCraft, PdfCraft (headless only, problem 37), PhotoCraft, SoundCraft, VectorCraft. `mise run apps:status`
shows each app's checked version.

## Later

- **13. Agents can read and write any file you can.** The headless MCP servers run with your
  full file access. Four of the CLIs can be confined to chosen folders
  (`--automation-read-root` / `--automation-write-root`), but this repo doesn't do it yet.
  FigCraft's live server (`--attach`) refuses those options: there the app confines it, and takes
  the same options alongside `--control`.
  *Next: the owner picks the folders.*
- **30. Inside `design/`, mise also loads the repo's root `mise.toml`**, so runtime tasks run from
  there too (`mise -C design run cadcraft:install` works). Design time and runtime aren't fully
  apart. *Next: find a way to keep `design/` from inheriting the root config.*

## Not bugs: how particular apps behave

- **14. GridCraft's `screenshot` times out when its window is hidden**, because a hidden window
  draws nothing. Bring GridCraft to the front first (`gridcraft-cli send <port> ui.focus`).
- **15. FigCraft's window capture fails when its window is hidden.** Without `window`, its
  `screenshot` renders the page instead.
- **16. EffectCraft's window screenshots are about 28 MB.** Its `screenshot` takes `max_side` to
  make them smaller.
- **17. VectorCraft's MCP server connects to port 7979 unless told otherwise**, which can be
  CADCraft's. Its headless server is started with `--headless` (in its `overrides`).
- **24. DeckCraft's `--help` lists `mcp` without its options.** `deckcraft-cli mcp --help` shows
  them.
- **26. FilmCraft's help has no `mcp [...]` usage line**, only `mcp  MCP server on stdio (headless,
  or --bridge to the live app)`; `--bridge <127.0.0.1:PORT>` is listed among its general options.
  `app:check` prints that description as its usage.
- **27. Some apps open with nothing to work on**, so the first tool call must make something:
  DeckCraft `new_presentation`; EffectCraft `command_run {"id": "comp.new"}`; FigCraft
  `run_command {"command": "file.new", "params": {}}`; VectorCraft
  `run_command {"command": "file.new"}`.
- **28. FilmCraft and PhotoCraft open their control port only to a token they share with their
  live server**, through `FILMCRAFT_CONTROL_TOKEN` and `PHOTOCRAFT_CONTROL_TOKEN`, made fresh for
  each session; the other apps keep their own token. Their `control_token_env` override makes
  `scripts/app-open.sh` create one and give it to both. So one of them opened some other way
  can't be driven: quit it first. (PhotoCraft, opened without one, makes its own and only prints
  it.) `open --env` puts the token on
  `open`'s command line for a moment, which FilmCraft's docs advise against.
- **36. SoundCraft's `mcp --help` starts its server instead of printing help**, and waits for
  input. `app:check` gives its help commands no input, so the server sees the end of it and stops.
  Its usage line is in `soundcraft-cli --help`, and it takes `--connect PORT`, the port alone.
- **37. PdfCraft has no live server.** `pdfcraft-cli mcp` always works on its own document (its
  docs: "there is no flag to connect it to a running app"); the desktop app is driven only by
  `pdfcraft-cli ui --control FILE`. Its overrides set `mcp.live` to `null`, so it gets a headless
  server and no watch tasks or port. Its `--help` puts several spaces after `mcp`.

## Limits to live with

- **20. `mise install --locked` with no tool names also checks your global mise tools**, which
  aren't in this repo's lockfile. Name the tools: `mise install --locked cadcraft cadcraft-cli`.
- **22. GitHub limits how often mise may download through its API.** mise ignores
  `github.credential_command` in a project file, so set it in your global mise config or export
  `GITHUB_TOKEN`.

## Fixed

Kept so they don't happen again.

- **1. mise's `latest` lagged behind new releases** (its `minimum_release_age`). Versions are pinned
  exactly.
- **2. mise saved the desktop apps' DMGs without unpacking them.** `scripts/dmg-unpack.sh` copies
  the app out after install.
- **3. `open -a <App>` couldn't find an app macOS had never registered** (`scripts/app-open.sh`
  uses it). The unpack step registers each app; uninstall unregisters it.
- **4. An apostrophe in my own guard broke `dmg-unpack.sh`.** Caught by testing before commit.
- **6. Running a live server as a mise task with `depends` lost Claude's first messages.** Live
  servers run through `mise exec` instead.
- **7. Live servers in `.mcp.json` opened desktop apps whenever Claude Code started.** They're
  added only on request, with `<app>:watch`.
- **8. Claude Code can't switch a project server back on for one person** once it's switched off
  for everyone (it merges `disabledMcpjsonServers` across files). Hence the watch tasks.
- **9. watch and unwatch could remove a server of the same name that wasn't ours.** They now mark
  their own with `MISE_CRAFT_WATCH`.
- **10. Claude Desktop rewrites its config while it's open**, which could drop our change. Its
  tasks refuse to run while it's open.
- **11. Rewriting Claude Desktop's config added a final newline it doesn't have.** Its tasks now
  restore the file byte for byte.
- **12. An app that wasn't installed showed as a failed server in Claude Code.** `.mcp.json` is now
  written per machine, for the apps actually installed.
- **18. Working out ports from an app's place in the list would shift them when an app is added.**
  Each checked app's port is written down.
- **19. zsh broke two of my generator scripts** (word splitting, globbing). They run under bash.
- **25. Installing an app could rewrite `mise.lock`.** Installs run with `--locked`, so they never
  write it.
- **31. `app:check` stopped without a word when a server didn't answer**, and left the app open.
  It now says which server failed, and closes the app on the way out either way.
- **32. `apps:status` listed no apps** after its task moved a folder down; the test only checked
  that it ran. The test now counts the apps.
- **33. Scripts hard-coded what every app shares** (`mcp`, `--control`, `docs/mcp.md`) instead of
  reading `design/family.json`, so an app couldn't override them.
- **5. CADCraft's first live call failed** with "missing or invalid control token" when its server
  opened the app itself (`--launch`): it read the old token before the app wrote a new one
  (CADCraft's bug, upstream #2087). CADCraft now opens through `scripts/app-open.sh` like every
  other app, which waits for the app's port first; in three cold starts the first call drew every
  time. Its override, and `opens_itself`, are gone.
- **35. `upstream:fetch` could hang on one slow GitHub request**, and stopped without a word when
  one failed. Each request now gets 30 seconds (a watchdog stops it: `gh` ignores the alarm
  signal), each doc is fetched once, and an app GitHub doesn't answer for shows `?` in its row.
- **34. `watch`, `unwatch` and `status` ignored `CLAUDE_CONFIG_DIR`**, so the test wrote into your
  own Claude Code config. They honour it now, and `repo:test` uses a config of its own.
