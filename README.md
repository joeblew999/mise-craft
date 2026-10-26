# mise-craft

Install the [Craft App Suite](https://getartcraft.com/apps) with [mise](https://mise.jdx.dev) and
drive the apps from AI agents over MCP, while you watch the desktop app update live.

> **Status:** CADCraft and VectorCraft work on macOS: CLI, desktop app, and MCP servers both
> headless and driving the live app. The other 11 apps are listed and locked but not yet checked.

## Use it

Install the apps you want, by name. Each app is two tools: `<app>-cli` (the CLI and its MCP server)
and `<app>` (the desktop app).

```sh
mise install cadcraft cadcraft-cli vectorcraft vectorcraft-cli
```

[mise.toml](mise.toml) lists all 13 apps at exact versions, but nothing downloads until you name it:
mise's auto-install is off in this repo, so `mise exec`, `mise run` and a missing command never
fetch anything. A bare `mise install` would install every app (about 3 GB).

Installs are idempotent. Each version lives in its own folder under
`~/.local/share/mise/installs/`, so installing again downloads nothing, and
[mise.lock](mise.lock) pins every download's SHA-256 (all 26 match the releases' `SHA256SUMS.txt`).

Then open this repo in Claude Code. [.mcp.json](.mcp.json) has two MCP servers per app, started
through mise so they use the pinned versions:

| Server | What it drives | Desktop app opens |
|---|---|---|
| `cadcraft` | A headless drawing, no window | Never |
| `cadcraft-app` | The CADCraft app on port 7979, live | At the first tool call (`--lazy --launch`) |
| `vectorcraft` | A headless document, no window | Never |
| `vectorcraft-app` | The VectorCraft app on port 7990, live | When Claude Code starts the server |

Claude Code asks you to approve project servers the first time; `claude mcp list` shows whether
they connect.

## How it works

- **Two tools per app.** `mise.toml` installs each app's GitHub repo twice under
  [tool aliases](https://mise.jdx.dev/dev-tools/backends/github.html): the CLI zip and the
  desktop app's DMG. [scripts/gen-mise-toml.sh](scripts/gen-mise-toml.sh) generates it from a list
  of `app:version` pairs, so a version bump is one edit and `mise lock`.
- **DMG unpacking.** On macOS the desktop apps are published only as DMGs, which mise saves without
  unpacking. A `postinstall` step, [scripts/unpack-dmg.sh](scripts/unpack-dmg.sh), copies the `.app`
  out of the image and registers it with macOS, so `open -a <App>` finds it. The apps stay in
  mise's install folders, not `/Applications`, and are signed and notarized by their publisher.
- **Opening the app for an agent.** Each app's MCP server takes different options, so `.mcp.json` is
  written and checked per app. CADCraft's server opens the app itself (`--launch`). VectorCraft's
  can't, so [scripts/mcp-open-app.sh](scripts/mcp-open-app.sh) opens it with its control port and
  then starts the server.

| App | Live MCP option | Opens the app itself |
|---|---|---|
| CADCraft | `--connect HOST:PORT [--lazy] [--launch]` | Yes |
| DesignCraft, GridCraft | `--connect PORT` | No |
| FigCraft | `--attach PORT` | No |
| VectorCraft | `--connect ADDR` (or `--headless`) | No |

## The apps

The launcher comes first; the apps follow in alphabetical order. Every app has `<app>-cli mcp`.
Versions and CLI builds are as published on each repo's latest release (checked 2026-10-26).

| App | Repo | Pinned | Checked here | CLI builds |
|---|---|---|---|---|
| **ArtCraft Launcher** | [storytold/craft-launcher](https://github.com/storytold/craft-launcher) | | | None: a desktop app that installs the apps below |
| CADCraft | [storytold/cadcraft](https://github.com/storytold/cadcraft) | 0.13.0 | ✓ | macOS universal |
| DeckCraft | [storytold/deckcraft](https://github.com/storytold/deckcraft) | 0.11.1 | | macOS universal |
| DesignCraft | [storytold/designcraft](https://github.com/storytold/designcraft) | 0.13.0 | | macOS universal |
| EffectCraft | [storytold/effectcraft](https://github.com/storytold/effectcraft) | 0.17.0 | | macOS universal |
| FigCraft | [storytold/figcraft](https://github.com/storytold/figcraft) | 0.11.2 | | macOS universal |
| FilmCraft | [storytold/filmcraft](https://github.com/storytold/filmcraft) | 0.13.0 | | macOS universal |
| GridCraft | [storytold/gridcraft](https://github.com/storytold/gridcraft) | 0.12.1 | | macOS universal |
| LightCraft | [storytold/lightcraft](https://github.com/storytold/lightcraft) | 0.14.0 | | macOS universal |
| PdfCraft | [storytold/pdfcraft](https://github.com/storytold/pdfcraft) | 0.14.0 | | macOS universal, Linux x86_64, Linux aarch64 |
| PhotoCraft | [storytold/photocraft](https://github.com/storytold/photocraft) | 0.16.0 | | macOS universal |
| SoundCraft | [storytold/soundcraft](https://github.com/storytold/soundcraft) | 0.13.1 | | macOS universal |
| VectorCraft | [storytold/vectorcraft](https://github.com/storytold/vectorcraft) | 0.17.0 | ✓ | macOS universal |
| WordCraft | [storytold/wordcraft](https://github.com/storytold/wordcraft) | 0.11.0 | | macOS universal |

[craft-launcher](https://github.com/storytold/craft-launcher) installs the desktop apps into
`/Applications` from a GUI. mise-craft installs from the command line, pins versions per project,
and sets the apps up for agents.

## Plan

1. ~~CADCraft and VectorCraft: installed by mise, headless and live MCP servers connected in Claude
   Code, and drawings made over MCP showing up in the running apps.~~
2. The other 11 apps, one at a time: work out each app's MCP options, add its two servers to
   `.mcp.json`, and check it end to end.
3. Linux and Windows: most apps publish no CLI build for them yet.

## Known limits

- **GitHub credential.** Downloads go through the GitHub API; set mise's `github.credential_command`
  in your global mise config (mise ignores it in a project file) or export `GITHUB_TOKEN`.
- **CADCraft's first live call can fail** with "missing or invalid control token" right after
  `--launch` opens the app: the bridge reads the old token before the app writes a new one
  (upstream #2087). The error says it is safe to send again, and the retry works.
- **VectorCraft opens when Claude Code starts**, because its MCP server can't open the app on demand.
- **`mise install --locked`** also checks your global mise tools, which aren't in this lockfile; name
  the tools: `mise install --locked cadcraft cadcraft-cli`.
- **Exact versions only.** mise's `minimum_release_age` hides releases newer than a set age, so
  `latest` can lag behind the newest release.
- Only PdfCraft publishes a CLI for Linux, and no app publishes one for Windows.
