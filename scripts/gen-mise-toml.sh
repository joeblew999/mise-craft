#!/usr/bin/env bash
# Writes mise.toml for the given Craft apps to stdout. To change a version or add an app, edit
# the list and regenerate:
#   scripts/gen-mise-toml.sh cadcraft:0.13.0 vectorcraft:0.17.0 ... > mise.toml && mise lock
set -euo pipefail
cat <<'EOF'
# Each Craft app's GitHub repo is installed twice under aliases: `<app>-cli` (the CLI, with its MCP
# server) and `<app>` (the desktop app). Each alias gets its own install directory. macOS only for
# now: it's the one platform every app publishes a CLI for.
#
# Every app is listed, but nothing downloads until you name it: `mise install cadcraft cadcraft-cli`.
# (A bare `mise install` still installs them all.)

[settings]
# Don't install missing tools behind your back: not when .mcp.json starts a server with
# `mise exec`, not on `mise run`, and not when a shell can't find a command.
exec_auto_install = false
task.run_auto_install = false
not_found_auto_install = false

[tool_alias]
EOF
for a in "$@"; do
  n=${a%%:*}
  printf '%s-cli = "github:storytold/%s"\n%s = "github:storytold/%s"\n' "$n" "$n" "$n" "$n"
done
printf '\n[tools]\n'
for a in "$@"; do
  n=${a%%:*} v=${a##*:}
  printf '%s-cli = { version = "%s", asset_pattern = "%s-cli-*-macos-universal.zip", os = ["macos"] }\n' "$n" "$v" "$n"
  printf '%s = { version = "%s", asset_pattern = "%s-*-macos-universal.dmg", os = ["macos"], postinstall = '"'"'sh "{{ config_root }}/scripts/unpack-dmg.sh"'"'"' }\n' "$n" "$v" "$n"
done
