<!-- Lineage: written by hand. Every problem found while building this repo, so none is forgotten. -->

# Problems

Every problem found so far. Status: **open**, **fixed**, **worked around**, **upstream** (the app's
bug), **app behaviour** (recorded, nothing to fix here), **limit**, or **yours** (needs the owner).

| # | Problem | Status | Fix or next step |
|---|---|---|---|
| 1 | mise's `latest` hides releases newer than `minimum_release_age` (resolved CADCraft to 0.12.0, not 0.13.0) | worked around | Exact versions pinned in `apps.json` |
| 2 | mise's `http:` and `github:` backends save a DMG without unpacking it | fixed | `scripts/unpack-dmg.sh` as `postinstall` |
| 3 | `open -a <App>` (CADCraft's `--launch`) can't find an app macOS has never registered | fixed | `unpack-dmg.sh` runs `lsregister -f`; `<app>:uninstall` runs `lsregister -u` |
| 4 | My guard in `unpack-dmg.sh` had an apostrophe inside `${…:?…}` that broke the script | fixed | Caught by testing before commit (80ccbe0) |
| 5 | CADCraft's first live call after `--launch` can fail with "missing or invalid control token" | upstream | Upstream #2087; the retry works. Report to storytold only with the owner's OK |
| 6 | A live server run as a mise task with `depends` lost the client's first MCP messages | worked around | Live servers run through `mise exec`, never `mise run` |
| 7 | Live servers in `.mcp.json` opened desktop apps whenever Claude Code started | fixed | Live servers moved out; `<app>:watch` adds one on request (9ddb5ce) |
| 8 | Claude Code merges `disabledMcpjsonServers` across settings files, so a project-wide "off" can't be turned back on per person | worked around | Watch tasks instead of settings |
| 9 | watch/unwatch replaced or removed same-named Claude Code servers this repo didn't add | fixed | `MISE_CRAFT_WATCH` marker (3a3c77c) |
| 10 | Claude Desktop rewrites its config while it runs, which could drop our change | worked around | `desktop:*` refuse while it's open |
| 11 | A jq round trip added a final newline Claude Desktop's config doesn't have | fixed | Tasks write without it; uninstall restores the file byte for byte |
| 12 | A checked app that isn't installed shows as a failed server in Claude Code (`.mcp.json` lists every checked app) | **open** | The design time / runtime split: see `docs/design-time-vs-runtime.md` |
| 13 | Headless MCP servers can read and write any file you can (no `--automation-read-root/--automation-write-root` passed) | **open** | Owner to decide whether to confine them, and to which folders |
| 14 | GridCraft's `screenshot` times out when its window is hidden | app behaviour | Recorded in `apps.json` limits |
| 15 | FigCraft's window capture fails when its window is hidden | app behaviour | Recorded in `apps.json` limits |
| 16 | EffectCraft's window screenshots are about 28 MB | app behaviour | Recorded; use `max_side` |
| 17 | VectorCraft's MCP server connects to port 7979 by default, which can be CADCraft's | worked around | Its headless server gets `--headless` |
| 18 | A port rule based on an app's place in the list would shift every later port when an app is added | fixed | Ports written per app in `apps.json` (c7b4300) |
| 19 | zsh word splitting and globbing broke two of my generator scripts | fixed | Generators run under bash |
| 20 | `mise install --locked` also checks the user's global mise tools, which aren't in this lockfile | limit | Name the tools: `mise install --locked cadcraft cadcraft-cli` |
| 21 | Every mise command warns about `experimental_monorepo_root` in another Claude session's leftover `mise.toml` | yours | Outside this repo: delete `/private/tmp/claude-501/…mise-cloudflare/…/scratchpad/mono/mise.toml` |
| 22 | GitHub API rate limits; mise ignores `github.credential_command` in a project file | limit | Global `credential_command` or `GITHUB_TOKEN` (README) |
| 23 | A safety check blocked deleting my test clone | yours | Delete `/private/tmp/claude-501/…/scratchpad/friend` |
| 24 | DeckCraft's `--help` lists `mcp` without its options | app behaviour | Recorded; `deckcraft-cli mcp --help` shows them |

App behaviours that aren't problems (what a fresh app holds, tools only the live server has, …) are
structured fields in `apps.json`, not entries here.
